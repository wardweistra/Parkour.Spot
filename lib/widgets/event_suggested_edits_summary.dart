import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/event_report.dart';
import '../utils/event_schedule_utils.dart';
import 'location_review_map.dart';

/// Summarizes which fields a user suggested changing on an existing event.
///
/// Shows compact field chips for quick scanning, plus optional detail rows
/// with the proposed values.
class EventSuggestedEditsSummary extends StatelessWidget {
  const EventSuggestedEditsSummary({
    super.key,
    required this.report,
    this.showChips = true,
    this.showDetails = true,
    this.showLocationMap = true,
    this.sectionTitle,
    this.currentLocation,
    this.compactMap = false,
  });

  final EventReport report;
  final bool showChips;
  final bool showDetails;
  final bool showLocationMap;
  final String? sectionTitle;
  final LatLng? currentLocation;
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
          ..._buildDetailRows(context, l10n),
        ],
        if (showLocationMap) ...[
          ..._buildLocationMap(context, l10n),
        ],
      ],
    );
  }

  LatLng? _resolvedCurrentLocation() {
    final override = currentLocation;
    if (override != null) return override;
    final lat = report.latitude;
    final lng = report.longitude;
    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return null;
  }

  LatLng? _resolvedSuggestedLocation() {
    if (report.suggestedLatitude != null && report.suggestedLongitude != null) {
      return LatLng(report.suggestedLatitude!, report.suggestedLongitude!);
    }
    return null;
  }

  List<Widget> _buildLocationMap(BuildContext context, AppLocalizations l10n) {
    final current = _resolvedCurrentLocation();
    final suggested = _resolvedSuggestedLocation();

    if (report.suggestedLocationRemoved) {
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
      chips.add(
        Chip(
          label: Text(label),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    if (report.suggestedTitle?.trim().isNotEmpty ?? false) {
      addChip(l10n.addEventTitleLabel);
    }
    if (report.suggestedDescription?.trim().isNotEmpty ?? false) {
      addChip(l10n.addEventDescriptionLabel.replaceAll(' (optional)', ''));
    }
    if (report.suggestedWebsiteUrl?.trim().isNotEmpty ?? false) {
      addChip(l10n.addEventWebsiteLabel.replaceAll(' (optional)', ''));
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
    if (report.suggestedSpotIds != null) {
      addChip(l10n.addEventLinkingSectionTitle);
    }
    if (report.suggestedLocationRemoved) {
      addChip(l10n.eventSuggestionLocationRemoved);
    } else if (report.suggestedLatitude != null &&
        report.suggestedLongitude != null) {
      addChip(l10n.addEventLocationSectionTitle);
    }

    return chips;
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
        '${l10n.addEventDescriptionLabel.replaceAll(' (optional)', '')}: ${report.suggestedDescription!.trim()}',
      );
    }
    if (report.suggestedWebsiteUrl?.trim().isNotEmpty ?? false) {
      addRow('${l10n.addEventWebsiteLabel.replaceAll(' (optional)', '')}: ${report.suggestedWebsiteUrl!.trim()}', isLink: true);
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
    if (report.suggestedSpotIds != null) {
      addRow(
        '${l10n.addEventLinkingSectionTitle}: ${l10n.eventSuggestionLinkedSpotsCount(report.suggestedSpotIds!.length)}',
      );
    }
    if (report.suggestedLocationRemoved) {
      addRow(
        '${l10n.addEventLocationSectionTitle}: ${l10n.eventSuggestionLocationRemoved}',
      );
    } else if (report.suggestedLatitude != null &&
        report.suggestedLongitude != null) {
      final locationParts = <String>[
        '${report.suggestedLatitude!.toStringAsFixed(5)}, ${report.suggestedLongitude!.toStringAsFixed(5)}',
      ];
      final address = report.suggestedAddress?.trim();
      if (address?.isNotEmpty ?? false) {
        locationParts.add(address!);
      }
      final city = report.suggestedCity?.trim();
      final countryCode = report.suggestedCountryCode?.trim().toUpperCase();
      if (city?.isNotEmpty ?? false) {
        if (countryCode?.isNotEmpty ?? false) {
          locationParts.add('$city, $countryCode');
        } else {
          locationParts.add(city!);
        }
      } else if (countryCode?.isNotEmpty ?? false) {
        locationParts.add(countryCode!);
      }
      addRow(
        '${l10n.addEventLocationSectionTitle}: ${locationParts.join(' · ')}',
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
