import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/parkour_event.dart';
import '../services/admin_events_service.dart';

/// Admin dialog: choose a **native** event (not a duplicate) as the canonical original.
class EventSelectionDialog extends StatefulWidget {
  const EventSelectionDialog({super.key, required this.currentEventId});

  final String currentEventId;

  @override
  State<EventSelectionDialog> createState() => _EventSelectionDialogState();
}

class _EventSelectionDialogState extends State<EventSelectionDialog> {
  final TextEditingController _inputController = TextEditingController();
  ParkourEvent? _foundEvent;
  bool _isLoading = false;
  bool _isLoadingSuggestions = false;
  String? _error;
  List<ParkourEvent> _suggestions = const <ParkourEvent>[];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final adminEvents = context.read<AdminEventsService>();
      final list = await adminEvents.fetchNativeOriginalEventCandidates(
        excludeEventId: widget.currentEventId,
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

  Future<void> _search() async {
    final l10n = AppLocalizations.of(context)!;
    final raw = _inputController.text;
    final id = _extractEventId(raw);
    if (id == null) {
      setState(() {
        _error = l10n.eventDetailMarkDuplicateNotFoundOrInvalid;
        _foundEvent = null;
      });
      return;
    }
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
      debugPrint('EventSelectionDialog search: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = l10n.eventDetailMarkDuplicateNotFoundOrInvalid;
        });
      }
    }
  }

  void _select(ParkourEvent event) {
    Navigator.of(context).pop<String>(event.id);
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
              TextField(
                controller: _inputController,
                decoration: InputDecoration(
                  labelText: l10n.eventDetailMarkDuplicateSearchHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _isLoading ? null : _search,
                  ),
                ),
                onSubmitted: (_) => _search(),
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
                  child: ListTile(
                    title: Text(_foundEvent!.title),
                    subtitle: Text(
                      _foundEvent!.id ?? '',
                      style: theme.textTheme.bodySmall,
                    ),
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
                  (e) => ListTile(
                    dense: true,
                    title: Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      e.id ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: e.id == null ? null : () => Navigator.of(context).pop(e.id),
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
