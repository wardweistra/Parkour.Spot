import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/audit_log_changes.dart';

void main() {
  group('auditValuesEquivalent', () {
    test('treats null and empty list as equivalent', () {
      expect(auditValuesEquivalent(null, <String>[]), isTrue);
      expect(auditValuesEquivalent(<String>[], null), isTrue);
      expect(auditValuesEquivalent(<String>[], <String>[]), isTrue);
      expect(auditValuesEquivalent(null, null), isTrue);
    });

    test('treats null and empty map as equivalent', () {
      expect(auditValuesEquivalent(null, <String, String>{}), isTrue);
      expect(auditValuesEquivalent(<String, String>{}, null), isTrue);
      expect(
        auditValuesEquivalent(<String, String>{}, <String, String>{}),
        isTrue,
      );
    });

    test('does not treat blank string as empty collection', () {
      expect(auditValuesEquivalent(null, ''), isFalse);
      expect(auditValuesEquivalent('', null), isFalse);
    });

    test('compares list contents', () {
      expect(auditValuesEquivalent(['a'], ['a']), isTrue);
      expect(auditValuesEquivalent(['a'], ['b']), isFalse);
      expect(auditValuesEquivalent(['a'], ['a', 'b']), isFalse);
      expect(auditValuesEquivalent(null, ['a']), isFalse);
    });

    test('compares map contents', () {
      expect(
        auditValuesEquivalent({'covered': 'yes'}, {'covered': 'yes'}),
        isTrue,
      );
      expect(
        auditValuesEquivalent({'covered': 'yes'}, {'covered': 'no'}),
        isFalse,
      );
      expect(auditValuesEquivalent(null, {'covered': 'yes'}), isFalse);
    });
  });

  group('filterMeaningfulAuditChanges', () {
    test('drops empty-to-empty list noise like youtubeVideoIds', () {
      final filtered = filterMeaningfulAuditChanges({
        'youtubeVideoIds': {'from': null, 'to': <String>[]},
        'name': {'from': 'Old', 'to': 'New'},
      });

      expect(filtered.keys, ['name']);
    });

    test('drops empty-to-empty map noise like spotFacilities', () {
      final filtered = filterMeaningfulAuditChanges({
        'spotFacilities': {'from': null, 'to': <String, String>{}},
        'description': {'from': 'a', 'to': 'b'},
      });

      expect(filtered.keys, ['description']);
    });

    test('keeps real list additions and removals', () {
      final filtered = filterMeaningfulAuditChanges({
        'youtubeVideoIds': {
          'from': null,
          'to': <String>['OF32ZeuXTK8'],
        },
        'imageUrls': {
          'from': <String>['https://a.example/1.jpg', 'https://a.example/2.jpg'],
          'to': <String>['https://a.example/2.jpg'],
        },
      });

      expect(filtered.keys.toSet(), {'youtubeVideoIds', 'imageUrls'});
    });

    test('drops list membership no-ops including reorder-only', () {
      final filtered = filterMeaningfulAuditChanges({
        'imageUrls': {
          'from': <String>['https://a.example/1.jpg', 'https://a.example/2.jpg'],
          'to': <String>['https://a.example/2.jpg', 'https://a.example/1.jpg'],
        },
      });

      expect(filtered, isEmpty);
    });

    test('keeps map key additions', () {
      final filtered = filterMeaningfulAuditChanges({
        'spotFacilities': {
          'from': <String, String>{},
          'to': <String, String>{'lighting': 'yes'},
        },
      });

      expect(filtered.keys, ['spotFacilities']);
    });
  });

  group('isNoOpAuditListChange', () {
    test('null and empty are no-ops', () {
      expect(isNoOpAuditListChange(null, <dynamic>[]), isTrue);
      expect(isNoOpAuditListChange(<dynamic>[], null), isTrue);
      expect(isNoOpAuditListChange(<dynamic>[], <dynamic>[]), isTrue);
    });

    test('added or removed items are meaningful', () {
      expect(isNoOpAuditListChange(['a'], ['a', 'b']), isFalse);
      expect(isNoOpAuditListChange(['a', 'b'], ['a']), isFalse);
    });
  });
}
