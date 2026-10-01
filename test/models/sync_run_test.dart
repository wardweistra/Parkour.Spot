import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/sync_run.dart';

void main() {
  group('SyncRun', () {
    test('fromMap parses fields and builds report text', () {
      final run = SyncRun.fromMap('run1', {
        'sourceKind': 'spot',
        'sourceId': 'src1',
        'sourceName': 'Demo source',
        'syncType': 'full',
        'status': 'succeeded',
        'trigger': 'manual',
        'invocationCount': 2,
        'stats': {'created': 3, 'updated': 1, 'total': 10},
        'added': [
          {'id': 'a', 'name': 'Alpha'},
        ],
        'updated': [
          {'id': 'b', 'name': 'Beta'},
        ],
        'removed': <Map<String, dynamic>>[],
        'issues': [
          {
            'type': 'youtube_missing_thumbnail',
            'videoId': 'yt123',
            'spotName': 'Alpha',
          },
        ],
      });

      expect(run.id, 'run1');
      expect(run.isSucceeded, isTrue);
      expect(run.invocationCount, 2);
      expect(run.added.single['name'], 'Alpha');
      expect(run.issues.single['videoId'], 'yt123');

      final report = run.toReportText();
      expect(report, contains('Source: Demo source'));
      expect(report, contains('Status: succeeded'));
      expect(report, contains('Invocations: 2'));
      expect(report, contains('created: 3'));
      expect(report, contains('Alpha'));
      expect(report, contains('yt123'));
      expect(report, contains('youtube_missing_thumbnail'));
    });

    test('SyncSourceLastError parses map and string', () {
      final fromMap = SyncSourceLastError.fromDynamic({
        'message': 'Boom',
        'at': {'_seconds': 1700000000, '_nanoseconds': 0},
      });
      expect(fromMap.message, 'Boom');
      expect(fromMap.at, isNotNull);

      final fromString = SyncSourceLastError.fromDynamic('Plain error');
      expect(fromString.message, 'Plain error');
      expect(fromString.at, isNull);
    });
  });
}
