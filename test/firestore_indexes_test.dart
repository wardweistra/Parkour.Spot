import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'notifications.createdAt has collection-group and collection field overrides',
    () {
      final file = File('firestore.indexes.json');
      expect(file.existsSync(), isTrue, reason: 'run flutter test from repo root');

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final overrides = json['fieldOverrides'];
      expect(overrides, isA<List>());

      final createdAt = (overrides as List).cast<dynamic>().whereType<Map>().firstWhere(
        (override) =>
            override['collectionGroup'] == 'notifications' &&
            override['fieldPath'] == 'createdAt',
        orElse: () => <String, dynamic>{},
      );
      expect(
        createdAt,
        isNotEmpty,
        reason:
            'Admin All notifications uses collectionGroup("notifications").orderBy(createdAt). '
            'A fieldOverride with COLLECTION_GROUP DESC is required. Keep COLLECTION indexes '
            'in the same override so per-user inboxes keep working.',
      );

      final indexes = (createdAt['indexes'] as List).cast<dynamic>().whereType<Map>();
      expect(
        indexes.any(
          (index) =>
              index['order'] == 'DESCENDING' &&
              index['queryScope'] == 'COLLECTION_GROUP',
        ),
        isTrue,
      );
      expect(
        indexes.any(
          (index) =>
              index['order'] == 'DESCENDING' && index['queryScope'] == 'COLLECTION',
        ),
        isTrue,
        reason:
            'Field overrides replace automatic single-field indexes. '
            'COLLECTION DESC must remain for users/{uid}/notifications inbox queries.',
      );
    },
  );
}
