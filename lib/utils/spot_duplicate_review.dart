import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/spot_attributes.dart';
import '../l10n/app_localizations.dart';
import '../models/spot.dart';
import 'duplicate_field_comparison.dart';

/// Transferable field groups used when reviewing post-link duplicate changes.
enum SpotDuplicateFieldGroup {
  photos,
  youtube,
  name,
  description,
  location,
  attributes,
}

extension SpotDuplicateFieldGroupX on SpotDuplicateFieldGroup {
  String get firestoreValue {
    switch (this) {
      case SpotDuplicateFieldGroup.photos:
        return 'photos';
      case SpotDuplicateFieldGroup.youtube:
        return 'youtube';
      case SpotDuplicateFieldGroup.name:
        return 'name';
      case SpotDuplicateFieldGroup.description:
        return 'description';
      case SpotDuplicateFieldGroup.location:
        return 'location';
      case SpotDuplicateFieldGroup.attributes:
        return 'attributes';
    }
  }

  String label(AppLocalizations l10n) {
    switch (this) {
      case SpotDuplicateFieldGroup.photos:
        return l10n.spotDetailMarkDuplicatePhotos;
      case SpotDuplicateFieldGroup.youtube:
        return l10n.spotDetailMarkDuplicateYoutube;
      case SpotDuplicateFieldGroup.name:
        return l10n.spotDetailMarkDuplicateName;
      case SpotDuplicateFieldGroup.description:
        return l10n.spotDetailMarkDuplicateDescription;
      case SpotDuplicateFieldGroup.location:
        return l10n.spotDetailMarkDuplicateLocation;
      case SpotDuplicateFieldGroup.attributes:
        return l10n.spotDetailMarkDuplicateSpotAttributes;
    }
  }
}

SpotDuplicateFieldGroup? spotDuplicateFieldGroupFromString(String value) {
  switch (value.trim()) {
    case 'photos':
      return SpotDuplicateFieldGroup.photos;
    case 'youtube':
      return SpotDuplicateFieldGroup.youtube;
    case 'name':
      return SpotDuplicateFieldGroup.name;
    case 'description':
      return SpotDuplicateFieldGroup.description;
    case 'location':
      return SpotDuplicateFieldGroup.location;
    case 'attributes':
      return SpotDuplicateFieldGroup.attributes;
    default:
      return null;
  }
}

List<SpotDuplicateFieldGroup> parseSpotDuplicateChangedFieldGroups(
  Iterable<String> values,
) {
  final result = <SpotDuplicateFieldGroup>[];
  final seen = <SpotDuplicateFieldGroup>{};
  for (final value in values) {
    final group = spotDuplicateFieldGroupFromString(value);
    if (group == null || seen.contains(group)) continue;
    seen.add(group);
    result.add(group);
  }
  return result;
}

bool _nullableStringsEqual(String? left, String? right) {
  final normalizedLeft = left?.trim();
  final normalizedRight = right?.trim();
  final leftValue = (normalizedLeft == null || normalizedLeft.isEmpty)
      ? null
      : normalizedLeft;
  final rightValue = (normalizedRight == null || normalizedRight.isEmpty)
      ? null
      : normalizedRight;
  return leftValue == rightValue;
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

bool _stringSetsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  final sortedLeft = [...left]..sort();
  final sortedRight = [...right]..sort();
  return _stringListsEqual(sortedLeft, sortedRight);
}

bool _stringMapsEqual(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) return false;
  for (final key in left.keys) {
    if (left[key] != right[key]) return false;
  }
  return true;
}

List<String> _normalizedList(List<String>? values) {
  if (values == null) return const <String>[];
  return [
    for (final value in values)
      if (value.trim().isNotEmpty) value.trim(),
  ];
}

Map<String, String> _normalizedMap(Map<String, String>? values) {
  if (values == null) return const <String, String>{};
  final result = <String, String>{};
  values.forEach((key, value) {
    final trimmedKey = key.trim();
    final trimmedValue = value.trim();
    if (trimmedKey.isNotEmpty && trimmedValue.isNotEmpty) {
      result[trimmedKey] = trimmedValue;
    }
  });
  return result;
}

/// Field groups that differ between [previous] (baseline) and [current].
List<SpotDuplicateFieldGroup> changedSpotDuplicateFieldGroups({
  required Spot previous,
  required Spot current,
}) {
  final changed = <SpotDuplicateFieldGroup>[];
  if (!_stringListsEqual(
    _normalizedList(previous.imageUrls),
    _normalizedList(current.imageUrls),
  )) {
    changed.add(SpotDuplicateFieldGroup.photos);
  }
  if (!_stringListsEqual(
    _normalizedList(previous.youtubeVideoIds),
    _normalizedList(current.youtubeVideoIds),
  )) {
    changed.add(SpotDuplicateFieldGroup.youtube);
  }
  if (!_nullableStringsEqual(previous.name, current.name)) {
    changed.add(SpotDuplicateFieldGroup.name);
  }
  if (!_nullableStringsEqual(previous.description, current.description)) {
    changed.add(SpotDuplicateFieldGroup.description);
  }
  if (previous.latitude != current.latitude ||
      previous.longitude != current.longitude ||
      !_nullableStringsEqual(previous.address, current.address) ||
      !_nullableStringsEqual(previous.city, current.city) ||
      !_nullableStringsEqual(previous.countryCode, current.countryCode)) {
    changed.add(SpotDuplicateFieldGroup.location);
  }
  if (!_nullableStringsEqual(previous.spotAccess, current.spotAccess) ||
      !_stringSetsEqual(
        _normalizedList(previous.spotFeatures),
        _normalizedList(current.spotFeatures),
      ) ||
      !_stringMapsEqual(
        _normalizedMap(previous.spotFacilities),
        _normalizedMap(current.spotFacilities),
      ) ||
      !_stringSetsEqual(
        _normalizedList(previous.goodFor),
        _normalizedList(current.goodFor),
      )) {
    changed.add(SpotDuplicateFieldGroup.attributes);
  }
  return changed;
}

/// Snapshot stored on the duplicate at last review / mark-as-duplicate.
Map<String, dynamic> buildSpotDuplicateReviewBaseline(Spot spot) {
  return {
    'name': spot.name,
    if (spot.description.trim().isNotEmpty)
      'description': spot.description.trim(),
    'imageUrls': _normalizedList(spot.imageUrls),
    'youtubeVideoIds': _normalizedList(spot.youtubeVideoIds),
    'latitude': spot.latitude,
    'longitude': spot.longitude,
    if (spot.address != null && spot.address!.trim().isNotEmpty)
      'address': spot.address!.trim(),
    if (spot.city != null && spot.city!.trim().isNotEmpty)
      'city': spot.city!.trim(),
    if (spot.countryCode != null && spot.countryCode!.trim().isNotEmpty)
      'countryCode': spot.countryCode!.trim(),
    if (spot.spotAccess != null && spot.spotAccess!.trim().isNotEmpty)
      'spotAccess': spot.spotAccess!.trim(),
    'spotFeatures': _normalizedList(spot.spotFeatures),
    'spotFacilities': _normalizedMap(spot.spotFacilities),
    'goodFor': _normalizedList(spot.goodFor),
  };
}

/// Clears pending-change flags and rewrites the baseline to current fields.
Map<String, dynamic> buildSpotDuplicateReviewAcknowledgedUpdates(Spot spot) {
  return {
    'duplicateReviewBaseline': buildSpotDuplicateReviewBaseline(spot),
    'duplicateChangedFields': FieldValue.delete(),
    'duplicateHasPendingChanges': false,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

/// Deletes review fields together with duplicate status.
Map<String, dynamic> buildSpotDuplicateReviewClearUpdates() {
  return {
    'duplicateReviewBaseline': FieldValue.delete(),
    'duplicateChangedFields': FieldValue.delete(),
    'duplicateHasPendingChanges': FieldValue.delete(),
  };
}

String formatSpotDuplicateFieldGroupValue({
  required Spot spot,
  required SpotDuplicateFieldGroup group,
  required AppLocalizations l10n,
}) {
  switch (group) {
    case SpotDuplicateFieldGroup.photos:
      return l10n.spotDuplicateChangesPhotosValue(spot.imageUrls?.length ?? 0);
    case SpotDuplicateFieldGroup.youtube:
      return l10n.spotDuplicateChangesYoutubeValue(
        spot.youtubeVideoIds?.length ?? 0,
      );
    case SpotDuplicateFieldGroup.name:
      final name = spot.name.trim();
      return name.isEmpty ? l10n.spotDuplicateChangesNoValue : name;
    case SpotDuplicateFieldGroup.description:
      final description = spot.description.trim();
      if (description.isEmpty) return l10n.spotDuplicateChangesNoValue;
      return description;
    case SpotDuplicateFieldGroup.location:
      final city = spot.city?.trim();
      if (city != null && city.isNotEmpty) return city;
      final address = spot.address?.trim();
      if (address != null && address.isNotEmpty) return address;
      if (spot.latitude != 0.0 || spot.longitude != 0.0) {
        return '${spot.latitude.toStringAsFixed(5)}, '
            '${spot.longitude.toStringAsFixed(5)}';
      }
      return l10n.spotDuplicateChangesNoValue;
    case SpotDuplicateFieldGroup.attributes:
      final parts = <String>[];
      final access = spot.spotAccess?.trim();
      if (access != null && access.isNotEmpty) {
        parts.add(SpotAttributes.getLabel('access', access));
      }
      for (final feature in _normalizedList(spot.spotFeatures)) {
        parts.add(SpotAttributes.getLabel('features', feature));
      }
      spot.spotFacilities?.forEach((key, value) {
        if (key.trim().isEmpty) return;
        parts.add(SpotAttributes.getLabel('facilities', key));
      });
      for (final skill in _normalizedList(spot.goodFor)) {
        parts.add(SpotAttributes.getLabel('goodFor', skill));
      }
      if (parts.isEmpty) return l10n.spotDuplicateChangesNoValue;
      return parts.join(', ');
  }
}

/// Display model for a stored review baseline. Null when none was saved.
Spot? spotFromDuplicateReviewBaseline(Map<String, dynamic>? baseline) {
  if (baseline == null) return null;
  return Spot.fromMap(baseline);
}

/// Whether [native] still matches [previous] for [group].
/// Null when either record is missing.
bool? spotDuplicateNativeMatchesPrevious({
  required Spot? previous,
  required Spot? native,
  required SpotDuplicateFieldGroup group,
}) {
  if (previous == null || native == null) return null;
  return !changedSpotDuplicateFieldGroups(
    previous: previous,
    current: native,
  ).contains(group);
}

/// External from/to lines and the native match for one changed group.
DuplicateFieldComparison buildSpotDuplicateFieldComparison({
  required Spot current,
  required Spot? previous,
  required Spot? native,
  required SpotDuplicateFieldGroup group,
  required AppLocalizations l10n,
}) {
  final summary = formatSpotDuplicateFieldGroupValue(
    spot: current,
    group: group,
    l10n: l10n,
  );
  final nativeSummary = native == null
      ? null
      : formatSpotDuplicateFieldGroupValue(
          spot: native,
          group: group,
          l10n: l10n,
        );
  if (previous == null) {
    return DuplicateFieldComparison(
      lines: const [],
      currentSummary: summary,
      nativeSummary: nativeSummary,
      previousUnavailable: true,
      nativeUnavailable: native == null,
    );
  }
  return DuplicateFieldComparison(
    lines: _spotChangeLines(
      previous: previous,
      current: current,
      native: native,
      group: group,
      l10n: l10n,
    ),
    currentSummary: summary,
    nativeSummary: nativeSummary,
    previousUnavailable: false,
    nativeUnavailable: native == null,
    nativeMatchesPrevious: spotDuplicateNativeMatchesPrevious(
      previous: previous,
      native: native,
      group: group,
    ),
  );
}

String _displayText(String? value, AppLocalizations l10n) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return l10n.spotDuplicateChangesNoValue;
  }
  return trimmed;
}

String _labeledList(
  List<String>? values,
  String category,
  AppLocalizations l10n,
) {
  final labels = [
    for (final value in _normalizedList(values))
      SpotAttributes.getLabel(category, value),
  ]..sort();
  if (labels.isEmpty) return l10n.spotDuplicateChangesNoValue;
  return labels.join(', ');
}

String _formatFacilities(Spot spot, AppLocalizations l10n) {
  final facilities = _normalizedMap(spot.spotFacilities);
  if (facilities.isEmpty) return l10n.spotDuplicateChangesNoValue;
  final keys = facilities.keys.toList()..sort();
  return keys
      .map((key) {
        final label = SpotAttributes.getLabel('facilities', key);
        return '$label: ${facilities[key]}';
      })
      .join(', ');
}

String _spotCoordinates(Spot spot) {
  return '${spot.latitude.toStringAsFixed(5)}, '
      '${spot.longitude.toStringAsFixed(5)}';
}

String _nativeText(String? value) => value ?? '';

DuplicateChangeLine _countLine({
  required String from,
  required String to,
  required String native,
  required bool sameCount,
  required bool contentsEqual,
}) {
  return DuplicateChangeLine(
    from: from,
    to: to,
    native: native,
    contentsChanged: sameCount && !contentsEqual,
  );
}

List<DuplicateChangeLine> _spotChangeLines({
  required Spot previous,
  required Spot current,
  required Spot? native,
  required SpotDuplicateFieldGroup group,
  required AppLocalizations l10n,
}) {
  switch (group) {
    case SpotDuplicateFieldGroup.photos:
      final previousUrls = _normalizedList(previous.imageUrls);
      final currentUrls = _normalizedList(current.imageUrls);
      return [
        _countLine(
          from: l10n.spotDuplicateChangesPhotosValue(previousUrls.length),
          to: l10n.spotDuplicateChangesPhotosValue(currentUrls.length),
          native: _nativeText(
            native == null
                ? null
                : l10n.spotDuplicateChangesPhotosValue(
                    _normalizedList(native.imageUrls).length,
                  ),
          ),
          sameCount: previousUrls.length == currentUrls.length,
          contentsEqual: _stringListsEqual(previousUrls, currentUrls),
        ),
      ];
    case SpotDuplicateFieldGroup.youtube:
      final previousIds = _normalizedList(previous.youtubeVideoIds);
      final currentIds = _normalizedList(current.youtubeVideoIds);
      return [
        _countLine(
          from: l10n.spotDuplicateChangesYoutubeValue(previousIds.length),
          to: l10n.spotDuplicateChangesYoutubeValue(currentIds.length),
          native: _nativeText(
            native == null
                ? null
                : l10n.spotDuplicateChangesYoutubeValue(
                    _normalizedList(native.youtubeVideoIds).length,
                  ),
          ),
          sameCount: previousIds.length == currentIds.length,
          contentsEqual: _stringListsEqual(previousIds, currentIds),
        ),
      ];
    case SpotDuplicateFieldGroup.name:
    case SpotDuplicateFieldGroup.description:
      return [
        DuplicateChangeLine(
          from: formatSpotDuplicateFieldGroupValue(
            spot: previous,
            group: group,
            l10n: l10n,
          ),
          to: formatSpotDuplicateFieldGroupValue(
            spot: current,
            group: group,
            l10n: l10n,
          ),
          native: _nativeText(
            native == null
                ? null
                : formatSpotDuplicateFieldGroupValue(
                    spot: native,
                    group: group,
                    l10n: l10n,
                  ),
          ),
        ),
      ];
    case SpotDuplicateFieldGroup.location:
      return _locationLines(previous, current, native, l10n);
    case SpotDuplicateFieldGroup.attributes:
      return _attributeLines(previous, current, native, l10n);
  }
}

void _addLine({
  required List<DuplicateChangeLine> lines,
  required bool changed,
  required String label,
  required String from,
  required String to,
  required String native,
}) {
  if (!changed) return;
  lines.add(
    DuplicateChangeLine(label: label, from: from, to: to, native: native),
  );
}

List<DuplicateChangeLine> _locationLines(
  Spot previous,
  Spot current,
  Spot? native,
  AppLocalizations l10n,
) {
  final lines = <DuplicateChangeLine>[];
  _addLine(
    lines: lines,
    changed: !_nullableStringsEqual(previous.address, current.address),
    label: l10n.duplicateChangesAddress,
    from: _displayText(previous.address, l10n),
    to: _displayText(current.address, l10n),
    native: _nativeText(
      native == null ? null : _displayText(native.address, l10n),
    ),
  );
  _addLine(
    lines: lines,
    changed: !_nullableStringsEqual(previous.city, current.city),
    label: l10n.duplicateChangesCity,
    from: _displayText(previous.city, l10n),
    to: _displayText(current.city, l10n),
    native: _nativeText(
      native == null ? null : _displayText(native.city, l10n),
    ),
  );
  _addLine(
    lines: lines,
    changed: !_nullableStringsEqual(previous.countryCode, current.countryCode),
    label: l10n.duplicateChangesCountry,
    from: _displayText(previous.countryCode, l10n),
    to: _displayText(current.countryCode, l10n),
    native: _nativeText(
      native == null ? null : _displayText(native.countryCode, l10n),
    ),
  );
  _addLine(
    lines: lines,
    changed:
        previous.latitude != current.latitude ||
        previous.longitude != current.longitude,
    label: l10n.duplicateChangesCoordinates,
    from: _spotCoordinates(previous),
    to: _spotCoordinates(current),
    native: _nativeText(native == null ? null : _spotCoordinates(native)),
  );
  if (lines.isNotEmpty) return lines;
  return [
    DuplicateChangeLine(
      from: formatSpotDuplicateFieldGroupValue(
        spot: previous,
        group: SpotDuplicateFieldGroup.location,
        l10n: l10n,
      ),
      to: formatSpotDuplicateFieldGroupValue(
        spot: current,
        group: SpotDuplicateFieldGroup.location,
        l10n: l10n,
      ),
      native: _nativeText(
        native == null
            ? null
            : formatSpotDuplicateFieldGroupValue(
                spot: native,
                group: SpotDuplicateFieldGroup.location,
                l10n: l10n,
              ),
      ),
    ),
  ];
}

List<DuplicateChangeLine> _attributeLines(
  Spot previous,
  Spot current,
  Spot? native,
  AppLocalizations l10n,
) {
  final lines = <DuplicateChangeLine>[];
  _addLine(
    lines: lines,
    changed: !_nullableStringsEqual(previous.spotAccess, current.spotAccess),
    label: l10n.duplicateChangesAccess,
    from: _accessLabel(previous, l10n),
    to: _accessLabel(current, l10n),
    native: _nativeText(native == null ? null : _accessLabel(native, l10n)),
  );
  _addLine(
    lines: lines,
    changed: !_stringSetsEqual(
      _normalizedList(previous.spotFeatures),
      _normalizedList(current.spotFeatures),
    ),
    label: l10n.duplicateChangesFeatures,
    from: _labeledList(previous.spotFeatures, 'features', l10n),
    to: _labeledList(current.spotFeatures, 'features', l10n),
    native: _nativeText(
      native == null
          ? null
          : _labeledList(native.spotFeatures, 'features', l10n),
    ),
  );
  _addLine(
    lines: lines,
    changed: !_stringMapsEqual(
      _normalizedMap(previous.spotFacilities),
      _normalizedMap(current.spotFacilities),
    ),
    label: l10n.duplicateChangesFacilities,
    from: _formatFacilities(previous, l10n),
    to: _formatFacilities(current, l10n),
    native: _nativeText(
      native == null ? null : _formatFacilities(native, l10n),
    ),
  );
  _addLine(
    lines: lines,
    changed: !_stringSetsEqual(
      _normalizedList(previous.goodFor),
      _normalizedList(current.goodFor),
    ),
    label: l10n.duplicateChangesGoodFor,
    from: _labeledList(previous.goodFor, 'goodFor', l10n),
    to: _labeledList(current.goodFor, 'goodFor', l10n),
    native: _nativeText(
      native == null ? null : _labeledList(native.goodFor, 'goodFor', l10n),
    ),
  );
  if (lines.isNotEmpty) return lines;
  return [
    DuplicateChangeLine(
      from: formatSpotDuplicateFieldGroupValue(
        spot: previous,
        group: SpotDuplicateFieldGroup.attributes,
        l10n: l10n,
      ),
      to: formatSpotDuplicateFieldGroupValue(
        spot: current,
        group: SpotDuplicateFieldGroup.attributes,
        l10n: l10n,
      ),
      native: _nativeText(
        native == null
            ? null
            : formatSpotDuplicateFieldGroupValue(
                spot: native,
                group: SpotDuplicateFieldGroup.attributes,
                l10n: l10n,
              ),
      ),
    ),
  ];
}

String _accessLabel(Spot spot, AppLocalizations l10n) {
  final access = spot.spotAccess?.trim();
  if (access == null || access.isEmpty) {
    return l10n.spotDuplicateChangesNoValue;
  }
  return SpotAttributes.getLabel('access', access);
}
