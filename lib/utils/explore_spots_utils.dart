import '../models/spot.dart';

/// Returns [primary] plus any spots from [additional] whose IDs are not already present.
List<Spot> mergeSpotsById(List<Spot> primary, List<Spot> additional) {
  final seen = primary.map((s) => s.id).whereType<String>().toSet();
  final merged = List<Spot>.from(primary);
  for (final spot in additional) {
    final id = spot.id;
    if (id != null && seen.add(id)) {
      merged.add(spot);
    }
  }
  return merged;
}
