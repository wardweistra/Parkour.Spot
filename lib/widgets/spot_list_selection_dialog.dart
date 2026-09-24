import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_list.dart';
import '../services/spot_list_service.dart';
import '../utils/event_linked_spot_loader.dart';

/// Pick a public or unlisted spot list from your lists or by id / /list/{id} URL.
class SpotListSelectionDialog extends StatefulWidget {
  const SpotListSelectionDialog({super.key, this.excludeListIds = const {}});

  final Set<String> excludeListIds;

  static Future<SpotList?> show(
    BuildContext context, {
    Set<String> excludeListIds = const {},
  }) {
    return showDialog<SpotList>(
      context: context,
      builder: (_) => SpotListSelectionDialog(excludeListIds: excludeListIds),
    );
  }

  @override
  State<SpotListSelectionDialog> createState() =>
      _SpotListSelectionDialogState();
}

class _SpotListSelectionDialogState extends State<SpotListSelectionDialog> {
  final TextEditingController _inputController = TextEditingController();
  SpotList? _foundList;
  List<SpotList> _yourLists = const [];
  bool _isLoading = false;
  bool _isLoadingYourLists = true;
  String? _error;

  Set<String> get _excludedIds => widget.excludeListIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadYourLists();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadYourLists() async {
    try {
      final lists = await context.read<SpotListService>().getUserSpotLists();
      if (!mounted) return;
      final excluded = _excludedIds;
      setState(() {
        _yourLists = lists
            .where((list) {
              final id = list.id?.trim();
              if (id == null || id.isEmpty || excluded.contains(id)) {
                return false;
              }
              return isSpotListExpandableForEventPins(list);
            })
            .toList(growable: false);
        _isLoadingYourLists = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _yourLists = const [];
        _isLoadingYourLists = false;
      });
    }
  }

  String? _extractListId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final urlPattern = RegExp(
      r'(https?://[^\s<>"()]+|/[^\s<>"()]+)',
      caseSensitive: false,
    );

    for (final match in urlPattern.allMatches(trimmed)) {
      final urlCandidate = match.group(0);
      if (urlCandidate == null) continue;

      try {
        final uri = Uri.parse(
          urlCandidate.startsWith('http')
              ? urlCandidate
              : 'https://parkour.spot$urlCandidate',
        );
        final segments = uri.pathSegments;
        final idx = segments.indexOf('list');
        if (idx >= 0 && idx + 1 < segments.length) {
          final id = segments[idx + 1];
          if (id.isNotEmpty) return id;
        }
      } catch (_) {
        continue;
      }
    }

    if (!trimmed.contains('/') && !trimmed.contains(' ')) {
      return trimmed;
    }
    return null;
  }

  bool _isExcluded(String? listId) {
    final id = listId?.trim() ?? '';
    return id.isNotEmpty && _excludedIds.contains(id);
  }

  Future<void> _lookup() async {
    final l10n = AppLocalizations.of(context)!;
    final listId = _extractListId(_inputController.text);
    if (listId == null) {
      setState(() {
        _error = l10n.adminSpotListSelectionInvalidInput;
        _foundList = null;
      });
      return;
    }
    if (_isExcluded(listId)) {
      setState(() {
        _error = l10n.spotListSelectionAlreadyLinked;
        _foundList = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _foundList = null;
    });

    try {
      final list = await context.read<SpotListService>().getSpotListById(
        listId,
      );
      if (!mounted) return;
      if (list == null || list.id == null) {
        setState(() {
          _error = l10n.adminSpotListSelectionNotFound;
          _isLoading = false;
        });
        return;
      }
      if (_isExcluded(list.id)) {
        setState(() {
          _error = l10n.spotListSelectionAlreadyLinked;
          _isLoading = false;
        });
        return;
      }
      if (list.visibility == SpotListVisibility.private) {
        setState(() {
          _error = l10n.adminSpotListSelectionPrivateList;
          _isLoading = false;
        });
        return;
      }
      setState(() {
        _foundList = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.adminSpotListSelectionLoadFailed;
        _isLoading = false;
      });
    }
  }

  void _select(SpotList list) {
    if (_isExcluded(list.id)) return;
    Navigator.of(context).pop(list);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Keep web map platform-views from receiving clicks through the dialog.
    return PointerInterceptor(
      child: AlertDialog(
        title: Text(l10n.adminSpotListSelectionTitle),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isLoadingYourLists)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_yourLists.isNotEmpty) ...[
                  Text(
                    l10n.spotListSelectionYourLists,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _yourLists.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final list = _yourLists[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.list_alt_outlined),
                          title: Text(list.name),
                          subtitle: Text(
                            l10n.adminSpotListSelectionFoundSubtitle(
                              list.visibility.label,
                              list.spotCount,
                            ),
                          ),
                          onTap: () => _select(list),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.spotListSelectionLookUpOther,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: _inputController,
                  decoration: InputDecoration(
                    labelText: l10n.adminSpotListSelectionInputLabel,
                    hintText: l10n.adminSpotListSelectionInputHint,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _lookup(),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _lookup,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(l10n.adminSpotListSelectionLookup),
                ),
                if (_foundList != null) ...[
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.list),
                    title: Text(_foundList!.name),
                    subtitle: Text(
                      l10n.adminSpotListSelectionFoundSubtitle(
                        _foundList!.visibility.label,
                        _foundList!.spotCount,
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.profileCancel),
          ),
          FilledButton(
            onPressed: _foundList?.id == null
                ? null
                : () => _select(_foundList!),
            child: Text(l10n.adminSpotListSelectionSelect),
          ),
        ],
      ),
    );
  }
}
