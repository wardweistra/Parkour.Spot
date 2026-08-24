import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/spot_attributes.dart';
import '../l10n/app_localizations.dart';
import '../models/spot.dart';

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
      if (description.length <= 80) return description;
      return '${description.substring(0, 79)}…';
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
