/// Helpers for audit-log field diffs (write-time equality + display filtering).
library;

bool _isEffectivelyEmptyCollection(Object? value) {
  if (value == null) return true;
  if (value is List) return value.isEmpty;
  if (value is Map) return value.isEmpty;
  return false;
}

/// True when [a] and [b] should not produce an audit change.
///
/// Null and empty [List]/[Map] are treated as equivalent so edits that only
/// normalize missing collections do not create noisy diffs.
bool auditValuesEquivalent(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (_isEffectivelyEmptyCollection(a) && _isEffectivelyEmptyCollection(b)) {
    // Only treat null/empty List/Map as interchangeable, not other empties
    // like blank strings or zero.
    final aIsCollection = a == null || a is List || a is Map;
    final bIsCollection = b == null || b is List || b is Map;
    if (aIsCollection && bIsCollection) return true;
  }
  if (a == null || b == null) return false;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
  return a == b;
}

List<dynamic> _asList(Object? value) {
  if (value is List) return List<dynamic>.from(value);
  return <dynamic>[];
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

/// True when a list from/to pair has no added or removed items (including
/// null↔empty and reorder-only / identical membership).
bool isNoOpAuditListChange(Object? from, Object? to) {
  if ((from != null && from is! List) || (to != null && to is! List)) {
    return false;
  }
  final fromList = _asList(from);
  final toList = _asList(to);
  final removed = fromList.where((item) => !toList.contains(item));
  final added = toList.where((item) => !fromList.contains(item));
  return removed.isEmpty && added.isEmpty;
}

/// True when a map from/to pair has no added, removed, or changed keys
/// (including null↔empty).
bool isNoOpAuditMapChange(Object? from, Object? to) {
  if ((from != null && from is! Map) || (to != null && to is! Map)) {
    return false;
  }
  final fromMap = _asMap(from);
  final toMap = _asMap(to);
  final allKeys = {...fromMap.keys, ...toMap.keys};
  for (final key in allKeys) {
    final inFrom = fromMap.containsKey(key);
    final inTo = toMap.containsKey(key);
    if (inFrom != inTo) return false;
    if (inFrom && inTo && fromMap[key] != toMap[key]) return false;
  }
  return true;
}

/// Whether a single `{from, to}` change entry is meaningful to show.
bool isMeaningfulAuditChange(Object? changeData) {
  if (changeData is! Map) return true;
  final fromValue = changeData['from'];
  final toValue = changeData['to'];

  if (fromValue is List || toValue is List) {
    return !isNoOpAuditListChange(fromValue, toValue);
  }
  if (fromValue is Map || toValue is Map) {
    return !isNoOpAuditMapChange(fromValue, toValue);
  }
  return true;
}

/// Drops no-op collection diffs from a stored audit `changes` map.
Map<String, dynamic> filterMeaningfulAuditChanges(
  Map<String, dynamic> changes,
) {
  return Map<String, dynamic>.fromEntries(
    changes.entries.where((entry) => isMeaningfulAuditChange(entry.value)),
  );
}
