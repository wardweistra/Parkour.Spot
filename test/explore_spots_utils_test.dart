import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot.dart';
import 'package:parkour_spot/utils/explore_spots_utils.dart';

Spot _spot(String id) =>
    Spot(id: id, name: 'Spot $id', description: '', latitude: 0, longitude: 0);

void main() {
  group('mergeSpotsById', () {
    test('returns primary unchanged when additional is empty', () {
      final primary = [_spot('a'), _spot('b')];
      expect(mergeSpotsById(primary, []), primary);
    });

    test('appends additional spots with new IDs', () {
      final primary = [_spot('a')];
      final additional = [_spot('b'), _spot('c')];
      final merged = mergeSpotsById(primary, additional);
      expect(merged.map((s) => s.id).toList(), ['a', 'b', 'c']);
    });

    test('skips additional spots already in primary', () {
      final primary = [_spot('a'), _spot('b')];
      final additional = [_spot('b'), _spot('c')];
      final merged = mergeSpotsById(primary, additional);
      expect(merged.map((s) => s.id).toList(), ['a', 'b', 'c']);
    });

    test('ignores additional spots without IDs', () {
      final primary = [_spot('a')];
      final additional = [
        Spot(name: 'No id', description: '', latitude: 0, longitude: 0),
      ];
      final merged = mergeSpotsById(primary, additional);
      expect(merged.map((s) => s.id).toList(), ['a']);
    });
  });
}
