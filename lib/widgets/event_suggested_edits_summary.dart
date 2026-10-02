import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/event_report.dart';
import '../models/parkour_event.dart';
import '../models/spot.dart';
import '../services/spot_list_service.dart';
import '../services/spot_service.dart';
import '../utils/event_schedule_utils.dart';
import 'location_suggestion_review.dart';
import 'text_diff_view.dart';

enum _SuggestedWhereKind { none, pin, spots, list, cleared }

/// Summarizes which fields a user suggested changing on an existing event.
///
/// Shows compact field chips for quick scanning, plus optional detail rows.
/// When [currentEvent] is provided, non-location details use the same unified
/// diff view as duplicate field updates. Location changes use the shared
/// [LocationSuggestionReview] (map + named linked spots).
class EventSuggestedEditsSummary extends StatefulWidget {
  const EventSuggestedEditsSummary({
    super.key,
    required this.report,
    this.showChips = true,
    this.showDetails = true,
    this.showLocationMap = true,
    this.sectionTitle,
    this.currentLocation,
    this.currentEvent,
    this.compactMap = false,
  });

  final EventReport report;
  final bool showChips;
  final bool showDetails;
  final bool showLocationMap;
  final String? sectionTitle;
  final LatLng? currentLocation;
  final ParkourEvent? currentEvent;
  final bool compactMap;

  @override
  State<EventSuggestedEditsSummary> createState() =>
      _EventSuggestedEditsSummaryState();
}

class _EventSuggestedEditsSummaryState
    extends State<EventSuggestedEditsSummary> {
  Map<String, Spot> _spotsById = const <String, Spot>{};
  Map<String, String> _listNamesById = const <String, String>{};
  bool _loadingLinked = false;

  EventReport get report => widget.report;

  @override
  void initState() {
    super.initState();
    _loadLinkedEntities();
  }

  @override
  void didUpdateWidget(covariant EventSuggestedEditsSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.id != widget.report.id ||
        oldWidget.currentEvent?.id != widget.currentEvent?.id ||
        !_sameIds(
          oldWidget.report.suggestedSpotIds,
          widget.report.suggestedSpotIds,
        ) ||
        !_sameIds(
          oldWidget.report.suggestedSpotListIds,
          widget.report.suggestedSpotListIds,
        ) ||
        !_sameIds(oldWidget.report.spotIds, widget.report.spotIds) ||
        !_sameIds(oldWidget.report.spotListIds, widget.report.spotListIds) ||
        !_sameIds(
          oldWidget.currentEvent?.spotIds,
          widget.currentEvent?.spotIds,
        ) ||
        !_sameIds(
          oldWidget.currentEvent?.spotListIds,
          widget.currentEvent?.spotListIds,
        )) {
      _loadLinkedEntities();
    }
  }

  T? _maybeRead<T>(BuildContext context) {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  bool _sameIds(List<String>? a, List<String>? b) {
    final left = (a ?? const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final right = (b ?? const <String>[])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  Set<String> _collectSpotIds() {
    final ids = <String>{};
    void addAll(List<String>? values) {
      if (values == null) return;
      for (final id in values) {
        final trimmed = id.trim();
        if (trimmed.isNotEmpty) ids.add(trimmed);
      }
    }

    addAll(report.suggestedSpotIds);
    addAll(report.spotIds);
    addAll(widget.currentEvent?.spotIds);
    return ids;
  }

  Set<String> _collectListIds() {
    final ids = <String>{};
    void addAll(List<String>? values) {
      if (values == null) return;
      for (final id in values) {
        final trimmed = id.trim();
        if (trimmed.isNotEmpty) ids.add(trimmed);
      }
    }

    addAll(report.suggestedSpotListIds);
    addAll(report.spotListIds);
    addAll(widget.currentEvent?.spotListIds);
    return ids;
  }

  Future<void> _loadLinkedEntities() async {
    final spotIds = _collectSpotIds();
    final listIds = _collectListIds();
    if (spotIds.isEmpty && listIds.isEmpty) {
      if (mounted) {
        setState(() {
          _spotsById = const <String, Spot>{};
          _listNamesById = const <String, String>{};
          _loadingLinked = false;
        });
      }
      return;
    }

    final spotService = _maybeRead<SpotService>(context);
    final listService = _maybeRead<SpotListService>(context);

    setState(() => _loadingLinked = true);

    final spotsById = <String, Spot>{};
    final listNamesById = <String, String>{};

    try {
      if (spotService != null && spotIds.isNotEmpty) {
        for (final id in spotIds) {
          final spot = await spotService.getSpotById(id);
          if (spot != null) spotsById[id] = spot;
        }
      }
      if (listService != null && listIds.isNotEmpty) {
        for (final id in listIds) {
          final list = await listService.getSpotListById(id);
          final name = list?.name.trim();
          if (name != null && name.isNotEmpty) {
            listNamesById[id] = name;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading linked entities for edit suggestion: $e');
    }

    if (!mounted) return;
    setState(() {
      _spotsById = spotsById;
      _listNamesById = listNamesById;
      _loadingLinked = false;
    });
  }

  bool _hasSuggestedIds(List<String>? ids) {
    return ids != null && ids.any((id) => id.trim().isNotEmpty);
  }

  _SuggestedWhereKind get _suggestedWhereKind {
    if (_hasSuggestedIds(report.suggestedSpotListIds)) {
      return _SuggestedWhereKind.list;
    }
    if (_hasSuggestedIds(report.suggestedSpotIds)) {
      return _SuggestedWhereKind.spots;
    }
    if (report.suggestedLatitude != null && report.suggestedLongitude != null) {
      return _SuggestedWhereKind.pin;
    }
    if (report.suggestedLocationRemoved) {
      return _SuggestedWhereKind.cleared;
    }
    return _SuggestedWhereKind.none;
  }

  LocationSuggestionSide? _currentLocationSide(AppLocalizations l10n) {
    final event = widget.currentEvent;
    final listIds = event?.spotListIds ?? report.spotListIds;
    if (listIds.any((id) => id.trim().isNotEmpty)) {
      return LocationSuggestionSide.linkedLists(
        listIds: listIds,
        listNamesById: _listNamesById,
        fallbackLabel: l10n.addEventLinkListButton,
      );
    }

    final spotIds = event?.spotIds ?? report.spotIds;
    if (spotIds.any((id) => id.trim().isNotEmpty)) {
      return LocationSuggestionSide.linkedSpots(
        spotIds: spotIds,
        spotsById: _spotsById,
        fallbackLabel: l10n.eventSuggestionLinkedSpotsCount(
          spotIds.where((id) => id.trim().isNotEmpty).length,
        ),
      );
    }

    final override = widget.currentLocation;
    if (override != null) {
      return LocationSuggestionSide.pin(
        latitude: override.latitude,
        longitude: override.longitude,
        address: event?.address ?? report.address,
        city: event?.city ?? report.city,
        countryCode: event?.countryCode ?? report.countryCode,
      );
    }

    final lat = event?.latitude ?? report.latitude;
    final lng = event?.longitude ?? report.longitude;
    if (lat != null && lng != null) {
      return LocationSuggestionSide.pin(
        latitude: lat,
        longitude: lng,
        address: event?.address ?? report.address,
        city: event?.city ?? report.city,
        countryCode: event?.countryCode ?? report.countryCode,
      );
    }

    return null;
  }

  LocationSuggestionSide? _suggestedLocationSide(AppLocalizations l10n) {
    switch (_suggestedWhereKind) {
      case _SuggestedWhereKind.spots:
        return LocationSuggestionSide.linkedSpots(
          spotIds: report.suggestedSpotIds!,
          spotsById: _spotsById,
          fallbackLabel: l10n.eventSuggestionLinkedSpotsCount(
            report.suggestedSpotIds!
                .where((id) => id.trim().isNotEmpty)
                .length,
          ),
        );
      case _SuggestedWhereKind.list:
        return LocationSuggestionSide.linkedLists(
          listIds: report.suggestedSpotListIds!,
          listNamesById: _listNamesById,
          fallbackLabel: l10n.addEventLinkListButton,
        );
      case _SuggestedWhereKind.cleared:
        return LocationSuggestionSide.cleared(l10n.eventSuggestionLocationRemoved);
      case _SuggestedWhereKind.pin:
        return LocationSuggestionSide.pin(
          latitude: report.suggestedLatitude!,
          longitude: report.suggestedLongitude!,
          address: report.suggestedAddress,
          city: report.suggestedCity,
          countryCode: report.suggestedCountryCode,
        );
      case _SuggestedWhereKind.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!report.hasSuggestedEdits) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title = widget.sectionTitle ?? l10n.eventSuggestionChangedFieldsTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        if (widget.showChips) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildFieldChips(context, l10n),
          ),
        ],
        if (widget.showDetails) ...[
          const SizedBox(height: 8),
          if (widget.currentEvent != null)
            ..._buildDiffRows(context, l10n, widget.currentEvent!)
          else
            ..._buildDetailRows(context, l10n),
          if (_suggestedWhereKind != _SuggestedWhereKind.none) ...[
            const SizedBox(height: 10),
            if (_loadingLinked &&
                (_suggestedWhereKind == _SuggestedWhereKind.spots ||
                    _suggestedWhereKind == _SuggestedWhereKind.list))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            LocationSuggestionReview(
              current: _currentLocationSide(l10n) ??
                  LocationSuggestionSide(
                    summaryLines: <String>[l10n.eventDuplicateChangesNoValue],
                  ),
              suggested: _suggestedLocationSide(l10n)!,
              compactMap: widget.compactMap,
              showMap: widget.showLocationMap,
              hint: widget.showLocationMap &&
                      !widget.compactMap &&
                      (_currentLocationSide(l10n)?.pins.isNotEmpty == true ||
                          _suggestedLocationSide(l10n)?.pins.isNotEmpty == true)
                  ? l10n.locationSuggestionReviewHint
                  : null,
            ),
          ],
        ] else if (widget.showLocationMap &&
            _suggestedWhereKind != _SuggestedWhereKind.none) ...[
          const SizedBox(height: 8),
          LocationSuggestionReview(
            current: _currentLocationSide(l10n) ??
                const LocationSuggestionSide(),
            suggested: _suggestedLocationSide(l10n)!,
            compactMap: widget.compactMap,
            showMap: true,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildFieldChips(BuildContext context, AppLocalizations l10n) {
    final chips = <Widget>[];

    void addChip(String label) {
      chips.add(Chip(label: Text(label), visualDensity: VisualDensity.compact));
    }

    if (report.suggestedTitle?.trim().isNotEmpty ?? false) {
      addChip(l10n.addEventTitleLabel);
    }
    if (report.suggestedDescription?.trim().isNotEmpty ?? false) {
      addChip(l10n.addEventDescriptionLabel);
    }
    if (report.suggestedWebsiteUrl?.trim().isNotEmpty ?? false) {
      addChip(l10n.addEventWebsiteLabel);
    }
    if (report.suggestedIsDateOnly != null) {
      addChip(l10n.addEventAllDay);
    }
    if (report.suggestedTimeZone?.trim().isNotEmpty ?? false) {
      addChip(l10n.addEventTimezoneLabel);
    }
    if (report.suggestedStartAt != null) {
      addChip(l10n.eventDetailStartsLabel);
    }
    if (report.suggestedEndAt != null) {
      addChip(l10n.eventDetailEndsLabel);
    }
    switch (_suggestedWhereKind) {
      case _SuggestedWhereKind.spots:
        addChip(l10n.addEventLinkingSectionTitle);
      case _SuggestedWhereKind.list:
        addChip(l10n.addEventLinkListButton);
      case _SuggestedWhereKind.cleared:
        addChip(l10n.eventSuggestionLocationRemoved);
      case _SuggestedWhereKind.pin:
        addChip(l10n.addEventLocationSectionTitle);
      case _SuggestedWhereKind.none:
        break;
    }

    return chips;
  }

  String _empty(AppLocalizations l10n) => l10n.eventDuplicateChangesNoValue;

  String _displayText(String? value, AppLocalizations l10n) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return _empty(l10n);
    return trimmed;
  }

  String _yesNo(bool value) => value ? 'Yes' : 'No';

  String _formatDateTime(
    BuildContext context,
    DateTime value, {
    required bool isDateOnly,
    required String? timeZone,
  }) {
    return EventScheduleUtils.formatSummaryLine(
      context,
      startAt: value,
      isDateOnly: isDateOnly,
      timeZone: timeZone,
    );
  }

  String _formatOptionalDateTime(
    BuildContext context,
    DateTime? value,
    AppLocalizations l10n, {
    required bool isDateOnly,
    required String? timeZone,
  }) {
    if (value == null) return _empty(l10n);
    return _formatDateTime(
      context,
      value,
      isDateOnly: isDateOnly,
      timeZone: timeZone,
    );
  }

  List<Widget> _buildDiffRows(
    BuildContext context,
    AppLocalizations l10n,
    ParkourEvent event,
  ) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    final rows = <Widget>[];

    void addDiff(String label, String before, String after) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 10));
      }
      rows.add(Text(label, style: labelStyle));
      rows.add(const SizedBox(height: 2));
      rows.add(TextDiffView(before: before, after: after));
    }

    if (report.suggestedTitle?.trim().isNotEmpty ?? false) {
      addDiff(
        l10n.addEventTitleLabel,
        _displayText(event.title, l10n),
        _displayText(report.suggestedTitle, l10n),
      );
    }
    if (report.suggestedDescription?.trim().isNotEmpty ?? false) {
      addDiff(
        l10n.addEventDescriptionLabel,
        _displayText(event.description, l10n),
        _displayText(report.suggestedDescription, l10n),
      );
    }
    if (report.suggestedWebsiteUrl?.trim().isNotEmpty ?? false) {
      addDiff(
        l10n.addEventWebsiteLabel,
        _displayText(event.websiteUrl, l10n),
        _displayText(report.suggestedWebsiteUrl, l10n),
      );
    }
    if (report.suggestedIsDateOnly != null) {
      addDiff(
        l10n.addEventAllDay,
        _yesNo(event.isDateOnly),
        _yesNo(report.suggestedIsDateOnly!),
      );
    }
    if (report.suggestedTimeZone?.trim().isNotEmpty ?? false) {
      addDiff(
        l10n.addEventTimezoneLabel,
        _displayText(event.timeZone, l10n),
        _displayText(report.suggestedTimeZone, l10n),
      );
    }
    if (report.suggestedStartAt != null) {
      addDiff(
        l10n.eventDetailStartsLabel,
        _formatOptionalDateTime(
          context,
          event.startAt,
          l10n,
          isDateOnly: event.isDateOnly,
          timeZone: event.timeZone,
        ),
        _formatDateTime(
          context,
          report.suggestedStartAt!,
          isDateOnly: report.suggestedIsDateOnly ?? event.isDateOnly,
          timeZone: report.suggestedTimeZone ?? event.timeZone,
        ),
      );
    }
    if (report.suggestedEndAt != null) {
      addDiff(
        l10n.eventDetailEndsLabel,
        _formatOptionalDateTime(
          context,
          event.endAt,
          l10n,
          isDateOnly: event.isDateOnly,
          timeZone: event.timeZone,
        ),
        _formatDateTime(
          context,
          report.suggestedEndAt!,
          isDateOnly: report.suggestedIsDateOnly ?? event.isDateOnly,
          timeZone: report.suggestedTimeZone ?? event.timeZone,
        ),
      );
    }

    return rows;
  }

  List<Widget> _buildDetailRows(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final rows = <Widget>[];

    void addRow(String text, {bool isLink = false}) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: 4));
      }
      rows.add(
        isLink
            ? SelectableText(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              )
            : Text(text, style: theme.textTheme.bodyMedium),
      );
    }

    if (report.suggestedTitle?.trim().isNotEmpty ?? false) {
      addRow('${l10n.addEventTitleLabel}: ${report.suggestedTitle!.trim()}');
    }
    if (report.suggestedDescription?.trim().isNotEmpty ?? false) {
      addRow(
        '${l10n.addEventDescriptionLabel}: ${report.suggestedDescription!.trim()}',
      );
    }
    if (report.suggestedWebsiteUrl?.trim().isNotEmpty ?? false) {
      addRow(
        '${l10n.addEventWebsiteLabel}: ${report.suggestedWebsiteUrl!.trim()}',
        isLink: true,
      );
    }
    if (report.suggestedIsDateOnly != null) {
      addRow(
        '${l10n.addEventAllDay}: ${report.suggestedIsDateOnly! ? 'Yes' : 'No'}',
      );
    }
    if (report.suggestedTimeZone?.trim().isNotEmpty ?? false) {
      addRow(
        '${l10n.addEventTimezoneLabel}: ${report.suggestedTimeZone!.trim()}',
      );
    }
    if (report.suggestedStartAt != null) {
      addRow(
        '${l10n.eventDetailStartsLabel}: ${_formatSuggestedDateTime(context, report.suggestedStartAt!)}',
      );
    }
    if (report.suggestedEndAt != null) {
      addRow(
        '${l10n.eventDetailEndsLabel}: ${_formatSuggestedDateTime(context, report.suggestedEndAt!)}',
      );
    }

    return rows;
  }

  String _formatSuggestedDateTime(BuildContext context, DateTime value) {
    return EventScheduleUtils.formatSummaryLine(
      context,
      startAt: value,
      isDateOnly: report.suggestedIsDateOnly ?? report.isDateOnly,
      timeZone: report.suggestedTimeZone ?? report.timeZone,
    );
  }
}
