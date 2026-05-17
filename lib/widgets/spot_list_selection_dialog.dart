import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_list.dart';
import '../services/spot_list_service.dart';

/// Admin dialog: pick a public or unlisted spot list by id or /list/{id} URL.
class SpotListSelectionDialog extends StatefulWidget {
  const SpotListSelectionDialog({super.key});

  @override
  State<SpotListSelectionDialog> createState() => _SpotListSelectionDialogState();
}

class _SpotListSelectionDialogState extends State<SpotListSelectionDialog> {
  final TextEditingController _inputController = TextEditingController();
  SpotList? _foundList;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
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

    setState(() {
      _isLoading = true;
      _error = null;
      _foundList = null;
    });

    try {
      final list = await context.read<SpotListService>().getSpotListById(listId);
      if (!mounted) return;
      if (list == null || list.id == null) {
        setState(() {
          _error = l10n.adminSpotListSelectionNotFound;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.adminSpotListSelectionTitle),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
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
              : () => Navigator.of(context).pop(_foundList!.id),
          child: Text(l10n.adminSpotListSelectionSelect),
        ),
      ],
    );
  }
}
