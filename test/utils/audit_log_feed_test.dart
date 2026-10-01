import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/audit_log.dart';
import 'package:parkour_spot/models/audit_log_entry.dart';
import 'package:parkour_spot/utils/audit_log_feed.dart';

void main() {
  group('auditLogCategoryForAction', () {
    test('maps sync actions', () {
      expect(
        auditLogCategoryForAction(AuditLogAction.spotSourceSync),
        AuditLogCategory.spotSyncs,
      );
      expect(
        auditLogCategoryForAction(AuditLogAction.eventSourceSync),
        AuditLogCategory.eventSyncs,
      );
    });

    test('maps moderator actions', () {
      expect(
        auditLogCategoryForAction(AuditLogAction.spotEdit),
        AuditLogCategory.moderatorActions,
      );
      expect(
        auditLogCategoryForAction(AuditLogAction.photoAdded),
        AuditLogCategory.moderatorActions,
      );
      expect(
        auditLogCategoryForAction(AuditLogAction.spotDelete),
        AuditLogCategory.moderatorActions,
      );
    });
  });

  group('auditLogCategoryForEntry', () {
    test('maps creations by entry type', () {
      final entry = AuditLogEntry(
        type: AuditLogEntryType.spotCreation,
        timestamp: DateTime(2026, 1, 1),
      );
      expect(auditLogCategoryForEntry(entry), AuditLogCategory.creations);
    });

    test('maps audit actions from metadata', () {
      final entry = AuditLogEntry(
        type: AuditLogEntryType.auditLogAction,
        timestamp: DateTime(2026, 1, 1),
        metadata: {'action': 'AuditLogAction.spotSourceSync'},
      );
      expect(auditLogCategoryForEntry(entry), AuditLogCategory.spotSyncs);
    });
  });

  group('filterAuditLogEntriesByCategories', () {
    final entries = [
      AuditLogEntry(
        type: AuditLogEntryType.spotCreation,
        timestamp: DateTime(2026, 1, 3),
        title: 'Spot',
      ),
      AuditLogEntry(
        type: AuditLogEntryType.auditLogAction,
        timestamp: DateTime(2026, 1, 2),
        title: 'Sync',
        metadata: {'action': 'spotSourceSync'},
      ),
      AuditLogEntry(
        type: AuditLogEntryType.auditLogAction,
        timestamp: DateTime(2026, 1, 1),
        title: 'Edit',
        metadata: {'action': 'AuditLogAction.spotEdit'},
      ),
    ];

    test('keeps only selected categories', () {
      final filtered = filterAuditLogEntriesByCategories(entries, {
        AuditLogCategory.spotSyncs,
      });
      expect(filtered, hasLength(1));
      expect(filtered.single.title, 'Sync');
    });

    test('empty selection yields empty list', () {
      expect(
        filterAuditLogEntriesByCategories(entries, {}),
        isEmpty,
      );
    });

    test('default all categories keeps everything', () {
      final filtered = filterAuditLogEntriesByCategories(
        entries,
        defaultSelectedAuditLogCategories(),
      );
      expect(filtered, hasLength(3));
    });
  });

  group('extend date window', () {
    final range = DateTimeRange(
      start: DateTime.utc(2026, 9, 30, 12),
      end: DateTime.utc(2026, 10, 1, 12),
    );

    test('extend older subtracts 24 hours from start', () {
      final extended = extendAuditLogRangeOlder(range);
      expect(extended.start, DateTime.utc(2026, 9, 29, 12));
      expect(extended.end, range.end);
    });

    test('extend newer adds 24 hours but caps at now', () {
      final now = DateTime.utc(2026, 10, 1, 18);
      final extended = extendAuditLogRangeNewer(range, now: now);
      expect(extended.start, range.start);
      expect(extended.end, now);
    });

    test('extend newer uncapped when within step of now', () {
      final now = DateTime.utc(2026, 10, 3, 12);
      final extended = extendAuditLogRangeNewer(range, now: now);
      expect(extended.end, DateTime.utc(2026, 10, 2, 12));
    });

    test('canExtendAuditLogRangeNewer respects epsilon', () {
      final now = DateTime.utc(2026, 10, 1, 12, 0, 30);
      expect(
        canExtendAuditLogRangeNewer(range, now: now),
        isFalse,
      );
      expect(
        canExtendAuditLogRangeNewer(
          range,
          now: DateTime.utc(2026, 10, 1, 13),
        ),
        isTrue,
      );
    });
  });

  group('syncRunIdFromAuditLogEntry', () {
    test('reads nested metadata.runId', () {
      final entry = AuditLogEntry(
        type: AuditLogEntryType.auditLogAction,
        timestamp: DateTime(2026, 1, 1),
        metadata: {
          'action': 'AuditLogAction.spotSourceSync',
          'metadata': {'runId': ' run-123 ', 'sourceId': 's1'},
        },
      );
      expect(syncRunIdFromAuditLogEntry(entry), 'run-123');
    });

    test('returns null when missing', () {
      final entry = AuditLogEntry(
        type: AuditLogEntryType.spotCreation,
        timestamp: DateTime(2026, 1, 1),
      );
      expect(syncRunIdFromAuditLogEntry(entry), isNull);
    });
  });
}
