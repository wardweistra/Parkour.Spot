import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/event_report.dart';
import '../models/parkour_event.dart';
import '../utils/event_schedule_utils.dart';
import 'location_review_map.dart';
import 'text_diff_view.dart';

enum _SuggestedWhereKind { none, pin, spots, list, cleared }

/// Summarizes which fields a user suggested changing on an existing event.
///
/// Shows compact field chips for quick scanning, plus optional detail rows.
/// When [currentEvent] is provided, details use the same unified diff view as
/// duplicate field updates.
class EventSuggestedEditsSummary extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!report.hasSuggestedEdits) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final title = sectionTitle ?? l10n.eventSuggestionChangedFieldsTitle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.secondary,
          ),
        ),
        if (showChips) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildFieldChips(context, l10n),
          ),
        ],
        if (showDetails) ...[
          const SizedBox(height: 8),
          if (currentEvent != null)
            ..._buildDiffRows(context, l10n, currentEvent!)
          else
            ..._buildDetailRows(context, l10n),
        ],
        if (showLocationMap) ...[..._buildLocationMap(context, l10n)],
      ],
    );
  }

  LatLng? _resolvedCurrentLocation() {
    final override = currentLocation;
    if (override != null) return override;
    final event = currentEvent;
    if (event?.latitude != null && event?.longitude != null) {
      return LatLng(event!.latitude!, event.longitude!);
    }
    final lat = report.latitude;
    final lng = report.longitude;
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return null;
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

  LatLng? _resolvedSuggestedLocation() {
    if (_suggestedWhereKind != _SuggestedWhereKind.pin) return null;
    if (report.suggestedLatitude != null && report.suggestedLongitude != null) {
      return LatLng(report.suggestedLatitude!, report.suggestedLongitude!);
    }
    return null;
  }

  List<Widget> _buildLocationMap(BuildContext context, AppLocalizations l10n) {
    final current = _resolvedCurrentLocation();
    final suggested = _resolvedSuggestedLocation();

    if (_suggestedWhereKind == _SuggestedWhereKind.cleared) {
      if (current == null) return const <Widget>[];
      return [
        const SizedBox(height: 12),
        LocationReviewMap(
          current: current,
          height: compactMap ? 180 : 220,
          showSatelliteToggle: !compactMap,
          interactive: !compactMap,
        ),
      ];
    }

    if (suggested == null) return const <Widget>[];

    return [
      const SizedBox(height: 12),
      LocationReviewMap(
        current: current,
        suggested: suggested,
        height: compactMap ? 180 : 280,
        showSatelliteToggle: !compactMap,
        interactive: !compactMap,
      ),
    ];
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

  String _locationSummary({
    required double? latitude,
    required double? longitude,
    required String? address,
    required String? city,
    required String? countryCode,
    required AppLocalizations l10n,
  }) {
    final parts = <String>[];
    if (latitude != null && longitude != null) {
      parts.add(
        '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
      );
    }
    final trimmedAddress = address?.trim();
    if (trimmedAddress?.isNotEmpty ?? false) {
      parts.add(trimmedAddress!);
    }
    final trimmedCity = city?.trim();
    final trimmedCountry = countryCode?.trim().toUpperCase();
    if (trimmedCity?.isNotEmpty ?? false) {
      if (trimmedCountry?.isNotEmpty ?? false) {
        parts.add('$trimmedCity, $trimmedCountry');
      } else {
        parts.add(trimmedCity!);
      }
    } else if (trimmedCountry?.isNotEmpty ?? false) {
      parts.add(trimmedCountry!);
    }
    if (parts.isEmpty) return _empty(l10n);
    return parts.join(' · ');
  }

  String _currentWhereSummary(ParkourEvent event, AppLocalizations l10n) {
    if (event.spotListIds.isNotEmpty) {
      return '${l10n.addEventLinkListButton}: ${event.spotListIds.length}';
    }
    if (event.spotIds.isNotEmpty) {
      return '${l10n.addEventLinkingSectionTitle}: ${l10n.eventSuggestionLinkedSpotsCount(event.spotIds.length)}';
    }
    if (event.latitude != null && event.longitude != null) {
      return _locationSummary(
        latitude: event.latitude,
        longitude: event.longitude,
        address: event.address,
        city: event.city,
        countryCode: event.countryCode,
        l10n: l10n,
      );
    }
    return _empty(l10n);
  }

  String _suggestedWhereSummary(AppLocalizations l10n) {
    switch (_suggestedWhereKind) {
      case _SuggestedWhereKind.spots:
        return '${l10n.addEventLinkingSectionTitle}: ${l10n.eventSuggestionLinkedSpotsCount(report.suggestedSpotIds!.length)}';
      case _SuggestedWhereKind.list:
        return '${l10n.addEventLinkListButton}: ${report.suggestedSpotListIds!.length}';
      case _SuggestedWhereKind.cleared:
        return l10n.eventSuggestionLocationRemoved;
      case _SuggestedWhereKind.pin:
        return _locationSummary(
          latitude: report.suggestedLatitude,
          longitude: report.suggestedLongitude,
          address: report.suggestedAddress,
          city: report.suggestedCity,
          countryCode: report.suggestedCountryCode,
          l10n: l10n,
        );
      case _SuggestedWhereKind.none:
        return _empty(l10n);
    }
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
    if (_suggestedWhereKind != _SuggestedWhereKind.none) {
      addDiff(
        l10n.addEventLocationSectionTitle,
        _currentWhereSummary(event, l10n),
        _suggestedWhereSummary(l10n),
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
    switch (_suggestedWhereKind) {
      case _SuggestedWhereKind.spots:
        addRow(
          '${l10n.addEventLinkingSectionTitle}: ${l10n.eventSuggestionLinkedSpotsCount(report.suggestedSpotIds!.length)}',
        );
      case _SuggestedWhereKind.list:
        addRow(
          '${l10n.addEventLinkListButton}: ${report.suggestedSpotListIds!.length}',
        );
      case _SuggestedWhereKind.cleared:
        addRow(
          '${l10n.addEventLocationSectionTitle}: ${l10n.eventSuggestionLocationRemoved}',
        );
      case _SuggestedWhereKind.pin:
        break;
      case _SuggestedWhereKind.none:
        break;
    }
    if (_suggestedWhereKind == _SuggestedWhereKind.pin &&
        report.suggestedLatitude != null &&
        report.suggestedLongitude != null) {
      addRow(
        '${l10n.addEventLocationSectionTitle}: ${_locationSummary(
          latitude: report.suggestedLatitude,
          longitude: report.suggestedLongitude,
          address: report.suggestedAddress,
          city: report.suggestedCity,
          countryCode: report.suggestedCountryCode,
          l10n: l10n,
        )}',
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
