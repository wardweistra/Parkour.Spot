import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/check_in_time.dart';

void main() {
  group('defaultExpectedEndAt', () {
    test('floors one hour later to nearest quarter hour', () {
      final from = DateTime(2025, 3, 27, 10, 7, 30);
      final end = defaultExpectedEndAt(from);
      expect(end, DateTime(2025, 3, 27, 11, 0));
    });

    test('10:53 start yields 11:45 after floor', () {
      final from = DateTime(2025, 3, 27, 10, 53);
      final end = defaultExpectedEndAt(from);
      expect(end, DateTime(2025, 3, 27, 11, 45));
    });

    test('on exact quarter boundary stays on boundary', () {
      final from = DateTime(2025, 3, 27, 9, 0);
      final end = defaultExpectedEndAt(from);
      expect(end, DateTime(2025, 3, 27, 10, 0));
    });
  });
}
