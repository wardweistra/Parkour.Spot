import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/spot.dart';
import 'location_review_map.dart';
import 'text_diff_view.dart';

/// One side of a location edit suggestion (current or suggested).
class LocationSuggestionSide {
  const LocationSuggestionSide({
    this.pins = const <LatLng>[],
    this.summaryLines = const <String>[],
  });

  /// Map pins for this side (pin location and/or linked spot coordinates).
  final List<LatLng> pins;

  /// Human-readable lines: address parts, linked spot names, list names, etc.
  final List<String> summaryLines;

  bool get isEmpty => pins.isEmpty && summaryLines.isEmpty;

  String summaryText(String emptyLabel) {
    if (summaryLines.isEmpty) return emptyLabel;
    return summaryLines.join('\n');
  }

  /// Pin-only location (spot coordinate edits).
  factory LocationSuggestionSide.pin({
    required double latitude,
    required double longitude,
    String? address,
    String? city,
    String? countryCode,
    int coordinateDecimals = 5,
  }) {
    final lines = <String>[
      '${latitude.toStringAsFixed(coordinateDecimals)}, '
          '${longitude.toStringAsFixed(coordinateDecimals)}',
    ];
    final trimmedAddress = address?.trim();
    if (trimmedAddress != null && trimmedAddress.isNotEmpty) {
      lines.add(trimmedAddress);
    }
    final trimmedCity = city?.trim();
    final trimmedCountry = countryCode?.trim().toUpperCase();
    if (trimmedCity != null && trimmedCity.isNotEmpty) {
      if (trimmedCountry != null && trimmedCountry.isNotEmpty) {
        lines.add('$trimmedCity, $trimmedCountry');
      } else {
        lines.add(trimmedCity);
      }
    } else if (trimmedCountry != null && trimmedCountry.isNotEmpty) {
      lines.add(trimmedCountry);
    }
    return LocationSuggestionSide(
      pins: <LatLng>[LatLng(latitude, longitude)],
      summaryLines: lines,
    );
  }

  /// Linked spots, optionally with loaded [Spot] records for names and pins.
  factory LocationSuggestionSide.linkedSpots({
    required List<String> spotIds,
    Map<String, Spot> spotsById = const <String, Spot>{},
    String? fallbackLabel,
  }) {
    final ids = spotIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final pins = <LatLng>[];
    final lines = <String>[];
    for (final id in ids) {
      final spot = spotsById[id];
      if (spot != null) {
        pins.add(LatLng(spot.latitude, spot.longitude));
        final name = spot.name.trim();
        lines.add(name.isNotEmpty ? name : id);
      } else {
        lines.add(id);
      }
    }
    if (lines.isEmpty && fallbackLabel != null && fallbackLabel.isNotEmpty) {
      lines.add(fallbackLabel);
    }
    return LocationSuggestionSide(pins: pins, summaryLines: lines);
  }

  /// Linked spot lists by display name.
  factory LocationSuggestionSide.linkedLists({
    required List<String> listIds,
    Map<String, String> listNamesById = const <String, String>{},
    String? fallbackLabel,
  }) {
    final ids = listIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final lines = <String>[];
    for (final id in ids) {
      final name = listNamesById[id]?.trim();
      lines.add(name != null && name.isNotEmpty ? name : id);
    }
    if (lines.isEmpty && fallbackLabel != null && fallbackLabel.isNotEmpty) {
      lines.add(fallbackLabel);
    }
    return LocationSuggestionSide(summaryLines: lines);
  }

  factory LocationSuggestionSide.cleared(String label) {
    return LocationSuggestionSide(summaryLines: <String>[label]);
  }
}

/// Shared moderator UI for reviewing a location edit suggestion on a spot or
/// event: comparison map (when pins exist) plus unified text diff of summaries.
class LocationSuggestionReview extends StatelessWidget {
  const LocationSuggestionReview({
    super.key,
    required this.current,
    required this.suggested,
    this.title,
    this.hint,
    this.compactMap = false,
    this.showMap = true,
    this.mapHeight,
    this.header,
  });

  final LocationSuggestionSide current;
  final LocationSuggestionSide suggested;
  final String? title;
  final String? hint;
  final bool compactMap;
  final bool showMap;
  final double? mapHeight;
  final Widget? header;

  bool get _hasMapPins =>
      showMap && (current.pins.isNotEmpty || suggested.pins.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final empty = l10n.eventDuplicateChangesNoValue;
    final sectionTitle = title ?? l10n.addEventLocationSectionTitle;
    final before = current.summaryText(empty);
    final after = suggested.summaryText(empty);
    final height = mapHeight ?? (compactMap ? 180.0 : 280.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null)
          header!
        else
          Text(
            sectionTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        if (hint != null && hint!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_hasMapPins) ...[
          const SizedBox(height: 8),
          LocationReviewMap(
            currentPins: current.pins,
            suggestedPins: suggested.pins,
            height: height,
            showSatelliteToggle: !compactMap,
            interactive: !compactMap,
          ),
        ],
        if (before != after || !_hasMapPins) ...[
          const SizedBox(height: 8),
          TextDiffView(before: before, after: after),
        ],
      ],
    );
  }
}
