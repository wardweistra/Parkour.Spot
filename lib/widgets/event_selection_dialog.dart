import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/parkour_event.dart';
import '../services/admin_events_service.dart';
import '../utils/event_date_window.dart';
import '../utils/explore_search_autocomplete.dart';

/// Admin dialog: choose a **native** event (not a duplicate) as the canonical original.
class EventSelectionDialog extends StatefulWidget {
  const EventSelectionDialog({
    super.key,
    required this.currentEventId,
    required this.referenceStartAt,
    this.referenceEndAt,
  });

  final String currentEventId;
  final DateTime referenceStartAt;
  final DateTime? referenceEndAt;

  @override
  State<EventSelectionDialog> createState() => _EventSelectionDialogState();
}

class _EventSelectionDialogState extends State<EventSelectionDialog> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  ParkourEvent? _foundEvent;
  bool _isLoading = false;
  bool _isLoadingSuggestions = false;
  String? _error;
  List<ParkourEvent> _suggestions = const <ParkourEvent>[];

  EventDateWindow get _dateWindow => EventDateWindow.aroundEvent(
    startAt: widget.referenceStartAt,
    endAt: widget.referenceEndAt,
  );

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final adminEvents = context.read<AdminEventsService>();
      final list = await adminEvents.fetchNativeOriginalEventCandidates(
        excludeEventId: widget.currentEventId,
        aroundStartAt: widget.referenceStartAt,
        aroundEndAt: widget.referenceEndAt,
      );
      if (mounted) {
        setState(() {
          _suggestions = list;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      debugPrint('EventSelectionDialog suggestions: $e');
      if (mounted) {
        setState(() => _isLoadingSuggestions = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _buildAutocompleteOptions(
    String query,
  ) async {
    if (!mounted) return [];
    final adminEvents = context.read<AdminEventsService>();
    return buildEventTitleAutocompleteOptions(
      query: query,
      eventsService: adminEvents,
      excludeEventIds: {widget.currentEventId},
      dateWindow: _dateWindow,
    );
  }

  String? _extractEventId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final urlPattern = RegExp(
      r'(https?://[^\s<>"()]+|/[^\s<>"()]+)',
      caseSensitive: false,
    );

    for (final match in urlPattern.allMatches(trimmed)) {
      final urlCandidate = match.group(0);
      if (urlCandidate == null) continue;

      String? fromUri(String raw) {
        try {
          final uri = Uri.parse(
            raw.startsWith('http') ? raw : 'https://parkour.spot$raw',
          );
          final segments = uri.pathSegments;
          final idx = segments.indexOf('event');
          if (idx >= 0 && idx + 1 < segments.length) {
            final id = segments[idx + 1];
            if (id.isNotEmpty) return id;
          }
        } catch (_) {}
        return null;
      }

      if (urlCandidate.startsWith('http://') ||
          urlCandidate.startsWith('https://')) {
        final id = fromUri(urlCandidate);
        if (id != null) return id;
      }
      if (urlCandidate.startsWith('/')) {
        final id = fromUri(urlCandidate);
        if (id != null) return id;
      }
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        final segments = uri.pathSegments;
        final idx = segments.indexOf('event');
        if (idx >= 0 && idx + 1 < segments.length) return segments[idx + 1];
      } catch (_) {}
      return null;
    }

    if (trimmed.startsWith('/')) {
      try {
        final uri = Uri.parse('https://parkour.spot$trimmed');
        final segments = uri.pathSegments;
        final idx = segments.indexOf('event');
        if (idx >= 0 && idx + 1 < segments.length) return segments[idx + 1];
      } catch (_) {}
      return null;
    }

    if (RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }

  Future<void> _lookupEventById(String id) async {
    final l10n = AppLocalizations.of(context)!;
    if (id == widget.currentEventId) {
      setState(() {
        _error = l10n.eventDetailMarkDuplicateNotFoundOrInvalid;
        _foundEvent = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _foundEvent = null;
    });

    try {
      final adminEvents = context.read<AdminEventsService>();
      final event = await adminEvents.getEventById(id);
      if (!mounted) return;

      if (event == null) {
        setState(() {
          _isLoading = false;
          _error = l10n.eventDetailMarkDuplicateNotFoundOrInvalid;
        });
        return;
      }

      if (!event.isNativeEvent) {
        setState(() {
          _isLoading = false;
          _error = l10n.eventDetailMarkDuplicateTargetNotNative;
        });
        return;
      }

      final dup = event.duplicateOf?.trim();
      if (dup != null && dup.isNotEmpty) {
        setState(() {
          _isLoading = false;
          _error = l10n.eventDetailMarkDuplicateTargetIsDuplicate;
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _foundEvent = event;
      });
    } catch (e) {
      debugPrint('EventSelectionDialog lookup: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = l10n.eventDetailMarkDuplicateNotFoundOrInvalid;
        });
      }
    }
  }

  Future<void> _search() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = _inputController.text;
    final id = _extractEventId(raw);
    if (id != null) {
      await _lookupEventById(id);
      return;
    }

    final trimmed = raw.trim();
    if (trimmed.length >= 2) {
      final options = await _buildAutocompleteOptions(trimmed);
      if (!mounted) return;
      if (options.length == 1) {
        final eventId = options.first['eventId'] as String?;
        if (eventId != null) {
          await _lookupEventById(eventId);
          return;
        }
      }
    }

    setState(() {
      _error = l10n.eventDetailMarkDuplicateNotFoundOrInvalid;
      _foundEvent = null;
    });
  }

  void _onAutocompleteSelected(Map<String, dynamic> option) {
    final eventId = option['eventId'] as String?;
    if (eventId == null) return;
    _lookupEventById(eventId);
  }

  void _select(ParkourEvent event) {
    Navigator.of(context).pop<String>(event.id);
  }

  Widget _buildEventCandidateTile(
    ParkourEvent event, {
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(
        event.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        formatEventCandidateSubtitle(event),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.eventDetailMarkDuplicatePickNativeTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.eventDetailMarkDuplicateNativeOnlyHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              RawAutocomplete<Map<String, dynamic>>(
                textEditingController: _inputController,
                focusNode: _inputFocusNode,
                optionsBuilder: (textEditingValue) async {
                  return _buildAutocompleteOptions(textEditingValue.text);
                },
                onSelected: _onAutocompleteSelected,
                displayStringForOption: (option) =>
                    option['description'] as String? ?? '',
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: l10n.eventDetailMarkDuplicateSearchHint,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _isLoading ? null : _search,
                          ),
                        ),
                        onSubmitted: (_) => _search(),
                      );
                    },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: PointerInterceptor(
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 240,
                            maxWidth: 420,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              final description =
                                  option['description'] as String? ?? '';
                              final secondary =
                                  option['secondary'] as String?;
                              return ListTile(
                                leading: const Icon(Icons.event_outlined),
                                dense: true,
                                title: Text(
                                  description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: secondary != null
                                    ? Text(
                                        secondary,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_foundEvent != null && !_isLoading) ...[
                const SizedBox(height: 12),
                Card(
                  child: _buildEventCandidateTile(
                    _foundEvent!,
                    trailing: FilledButton(
                      onPressed: () => _select(_foundEvent!),
                      child: Text(l10n.eventDetailMarkDuplicateUseButton),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                l10n.eventDetailMarkDuplicateSuggestionsHeader,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (_isLoadingSuggestions)
                const Center(child: CircularProgressIndicator())
              else if (_suggestions.isEmpty)
                Text(
                  l10n.eventDetailMarkDuplicateNoSuggestions,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ..._suggestions.map(
                  (event) => _buildEventCandidateTile(
                    event,
                    onTap: event.id == null
                        ? null
                        : () => Navigator.of(context).pop(event.id),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<String>(),
          child: Text(l10n.profileCancel),
        ),
      ],
    );
  }
}
