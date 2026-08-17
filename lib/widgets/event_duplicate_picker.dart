import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/parkour_event.dart';
import '../services/admin_events_service.dart';
import '../utils/explore_search_autocomplete.dart';

/// Whether an event can be confirmed as the duplicate original in the picker.
enum EventDuplicatePickerMode { userReport, moderatorMark }

/// Whether an event can serve as the native canonical original for duplicate linking.
bool isValidNativeDuplicateOriginal(ParkourEvent event) {
  if (!event.isNativeEvent) return false;
  final dup = event.duplicateOf?.trim();
  return dup == null || dup.isEmpty;
}

/// Returns whether the event can be confirmed for the given picker mode.
bool canConfirmEventDuplicateSelection({
  required ParkourEvent event,
  required String currentEventId,
  required EventDuplicatePickerMode mode,
}) {
  if (event.id == currentEventId) return false;
  if (mode == EventDuplicatePickerMode.userReport) return true;
  return isValidNativeDuplicateOriginal(event);
}

/// Picks an event as the suggested original for a duplicate link.
///
/// Autocomplete shows all upcoming non-duplicate events (native and external).
/// User report mode allows confirming any found event; moderator mark mode only
/// allows native non-duplicate events, with clear feedback for blocked picks.
class EventDuplicatePicker extends StatefulWidget {
  const EventDuplicatePicker({
    super.key,
    required this.currentEventId,
    required this.referenceStartAt,
    this.referenceEndAt,
    this.nativeOnlyOriginals = true,
    this.onEventSelected,
    this.selectedEvent,
    this.showNativeOnlyHint = true,
  });

  final String currentEventId;
  final DateTime referenceStartAt;
  final DateTime? referenceEndAt;
  final bool nativeOnlyOriginals;
  final ValueChanged<ParkourEvent>? onEventSelected;
  final ParkourEvent? selectedEvent;
  final bool showNativeOnlyHint;

  EventDuplicatePickerMode get _mode => nativeOnlyOriginals
      ? EventDuplicatePickerMode.moderatorMark
      : EventDuplicatePickerMode.userReport;

  @override
  State<EventDuplicatePicker> createState() => _EventDuplicatePickerState();
}

class _EventDuplicatePickerState extends State<EventDuplicatePicker> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  ParkourEvent? _foundEvent;
  bool _isLoading = false;
  bool _isLoadingSuggestions = false;
  String? _error;
  List<ParkourEvent> _suggestions = const <ParkourEvent>[];

  Future<List<Map<String, dynamic>>> _buildAutocompleteOptions(
    String query,
  ) async {
    if (!mounted) return [];
    final adminEvents = context.read<AdminEventsService>();
    return buildEventTitleAutocompleteOptions(
      query: query,
      eventsService: adminEvents,
      excludeEventIds: {widget.currentEventId},
    );
  }

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
      final list = widget.nativeOnlyOriginals
          ? await adminEvents.fetchNativeOriginalEventCandidates(
              excludeEventId: widget.currentEventId,
              aroundStartAt: widget.referenceStartAt,
              aroundEndAt: widget.referenceEndAt,
            )
          : await adminEvents.fetchEventDuplicateReportCandidates(
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
      debugPrint('EventDuplicatePicker suggestions: $e');
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

  bool _canConfirm(ParkourEvent event) {
    return canConfirmEventDuplicateSelection(
      event: event,
      currentEventId: widget.currentEventId,
      mode: widget._mode,
    );
  }

  String? _confirmBlockedMessage(AppLocalizations l10n, ParkourEvent event) {
    if (_canConfirm(event)) return null;
    if (event.id == widget.currentEventId) {
      return l10n.eventDetailMarkDuplicateNotFoundOrInvalid;
    }
    if (widget._mode == EventDuplicatePickerMode.moderatorMark) {
      if (!event.isNativeEvent) {
        return l10n.eventDetailMarkDuplicateTargetNotNative;
      }
      final dup = event.duplicateOf?.trim();
      if (dup != null && dup.isNotEmpty) {
        return l10n.eventDetailMarkDuplicateTargetIsDuplicate;
      }
    }
    return null;
  }

  void _selectEvent(ParkourEvent event) {
    if (!_canConfirm(event)) return;
    widget.onEventSelected?.call(event);
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

      setState(() {
        _isLoading = false;
        _foundEvent = event;
      });
    } catch (e) {
      debugPrint('EventDuplicatePicker lookup: $e');
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

  String? _eventSourceLabel(ParkourEvent event) {
    if (event.isNativeEvent) return null;
    final name = event.eventSourceName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final id = event.eventSourceId?.trim();
    if (id != null && id.isNotEmpty) return id;
    return null;
  }

  Widget _buildEventCandidateTile(
    AppLocalizations l10n,
    ParkourEvent event, {
    VoidCallback? onTap,
    Widget? trailing,
    bool isSelected = false,
    bool showBlockedHint = false,
  }) {
    final theme = Theme.of(context);
    final sourceLabel = _eventSourceLabel(event);
    final blockedMessage = showBlockedHint
        ? _confirmBlockedMessage(l10n, event)
        : null;
    final subtitleParts = <String>[
      formatEventCandidateSubtitle(event),
      if (sourceLabel != null) sourceLabel,
    ];

    return ListTile(
      dense: true,
      selected: isSelected,
      enabled: onTap != null,
      title: Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitleParts.join(' · '),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (blockedMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              blockedMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selected = widget.selectedEvent;
    final foundEvent = _foundEvent;
    final foundCanConfirm = foundEvent != null && _canConfirm(foundEvent);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showNativeOnlyHint && widget.nativeOnlyOriginals) ...[
          Text(
            l10n.eventDetailMarkDuplicateNativeOnlyHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
        RawAutocomplete<Map<String, dynamic>>(
          textEditingController: _inputController,
          focusNode: _inputFocusNode,
          optionsBuilder: (textEditingValue) async {
            return _buildAutocompleteOptions(textEditingValue.text);
          },
          onSelected: _onAutocompleteSelected,
          displayStringForOption: (option) =>
              option['description'] as String? ?? '',
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
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
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 240,
                      maxWidth: 420,
                    ),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(4),
                      shrinkWrap: true,
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        final description =
                            option['description'] as String? ?? '';
                        final secondary = option['secondary'] as String?;
                        return ListTile(
                          leading: const Icon(Icons.event_outlined),
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
        if (foundEvent != null && !_isLoading) ...[
          const SizedBox(height: 12),
          Card(
            child: _buildEventCandidateTile(
              l10n,
              foundEvent,
              isSelected: selected?.id == foundEvent.id,
              showBlockedHint: !foundCanConfirm,
              trailing: FilledButton(
                onPressed: foundCanConfirm
                    ? () => _selectEvent(foundEvent)
                    : null,
                child: Text(l10n.eventDetailMarkDuplicateUseButton),
              ),
            ),
          ),
        ],
        if (selected != null) ...[
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            child: _buildEventCandidateTile(
              l10n,
              selected,
              isSelected: true,
              trailing: Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          widget.nativeOnlyOriginals
              ? l10n.eventDetailMarkDuplicateSuggestionsHeader
              : l10n.eventDetailFlagDuplicateSuggestionsHeader,
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
          ..._suggestions.map((event) {
            final canConfirm = _canConfirm(event);
            return _buildEventCandidateTile(
              l10n,
              event,
              isSelected: selected?.id == event.id,
              showBlockedHint: widget.nativeOnlyOriginals && !canConfirm,
              onTap: event.id == null || !canConfirm
                  ? null
                  : () => _selectEvent(event),
            );
          }),
      ],
    );
  }
}
