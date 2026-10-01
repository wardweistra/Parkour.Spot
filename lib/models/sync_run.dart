import 'package:cloud_firestore/cloud_firestore.dart';

/// Durable sync-run report (spot or event) written by Cloud Functions.
class SyncRun {
  final String id;
  final String sourceKind;
  final String sourceId;
  final String sourceName;
  final String syncType;
  final String status;
  final String? trigger;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int invocationCount;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> added;
  final List<Map<String, dynamic>> updated;
  final List<Map<String, dynamic>> removed;
  final List<Map<String, dynamic>> issues;
  final String? errorMessage;

  const SyncRun({
    required this.id,
    required this.sourceKind,
    required this.sourceId,
    required this.sourceName,
    required this.syncType,
    required this.status,
    this.trigger,
    this.startedAt,
    this.finishedAt,
    this.invocationCount = 1,
    this.stats = const {},
    this.added = const [],
    this.updated = const [],
    this.removed = const [],
    this.issues = const [],
    this.errorMessage,
  });

  bool get isRunning => status == 'running';
  bool get isSucceeded => status == 'succeeded';
  bool get isFailed => status == 'failed';

  factory SyncRun.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SyncRun.fromMap(doc.id, data);
  }

  factory SyncRun.fromMap(String id, Map<String, dynamic> data) {
    return SyncRun(
      id: id,
      sourceKind: data['sourceKind']?.toString() ?? '',
      sourceId: data['sourceId']?.toString() ?? '',
      sourceName: data['sourceName']?.toString() ?? '',
      syncType: data['syncType']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      trigger: data['trigger']?.toString(),
      startedAt: _parseTimestamp(data['startedAt']),
      finishedAt: _parseTimestamp(data['finishedAt']),
      invocationCount: _asInt(data['invocationCount']) ?? 1,
      stats: _asStringKeyedMap(data['stats']) ?? const {},
      added: _asObjectList(data['added']),
      updated: _asObjectList(data['updated']),
      removed: _asObjectList(data['removed']),
      issues: _asObjectList(data['issues']),
      errorMessage: data['errorMessage']?.toString(),
    );
  }

  /// Plain-text report for clipboard copy.
  String toReportText() {
    final lines = <String>[
      'Source: $sourceName',
      'Kind: $sourceKind',
      'Type: $syncType',
      'Status: $status',
      if (trigger != null && trigger!.isNotEmpty) 'Trigger: $trigger',
      'Invocations: $invocationCount',
      if (startedAt != null) 'Started: $startedAt',
      if (finishedAt != null) 'Finished: $finishedAt',
      if (errorMessage != null && errorMessage!.isNotEmpty)
        'Error: $errorMessage',
    ];

    if (stats.isNotEmpty) {
      lines.add('Stats:');
      for (final entry in stats.entries) {
        lines.add('  ${entry.key}: ${entry.value}');
      }
    }

    void listSection(String title, List<Map<String, dynamic>> items) {
      if (items.isEmpty) return;
      lines.add('$title (${items.length}):');
      for (final item in items) {
        final name = item['name']?.toString();
        final id = item['id']?.toString();
        lines.add('  - ${name ?? id ?? item.toString()}');
      }
    }

    listSection('Added', added);
    listSection('Updated', updated);
    listSection('Removed', removed);

    if (issues.isNotEmpty) {
      lines.add('Issues (${issues.length}):');
      for (final issue in issues) {
        final parts = <String>[
          if (issue['type'] != null) issue['type'].toString(),
          if (issue['videoId'] != null) issue['videoId'].toString(),
          if (issue['spotName'] != null) issue['spotName'].toString(),
        ];
        lines.add('  - ${parts.join(' | ')}');
      }
    }

    return lines.join('\n');
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is Map) {
      final m = Map<String, dynamic>.from(timestamp);
      final secondsRaw = m['_seconds'] ?? m['seconds'];
      final nanosecondsRaw = m['_nanoseconds'] ?? m['nanoseconds'] ?? 0;
      final seconds = secondsRaw is int
          ? secondsRaw
          : secondsRaw is num
          ? secondsRaw.toInt()
          : null;
      final nanoseconds = nanosecondsRaw is int
          ? nanosecondsRaw
          : nanosecondsRaw is num
          ? nanosecondsRaw.toInt()
          : 0;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanoseconds / 1000000).round(),
        );
      }
    }
    return null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static Map<String, dynamic>? _asStringKeyedMap(dynamic raw) {
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  static List<Map<String, dynamic>> _asObjectList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}

/// Optional last-error payload stored on sync source docs.
class SyncSourceLastError {
  final String message;
  final DateTime? at;

  const SyncSourceLastError({required this.message, this.at});

  factory SyncSourceLastError.fromDynamic(dynamic raw) {
    if (raw is String) {
      return SyncSourceLastError(message: raw);
    }
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      return SyncSourceLastError(
        message: map['message']?.toString() ?? 'Unknown error',
        at: SyncRun._parseTimestamp(map['at']),
      );
    }
    return const SyncSourceLastError(message: 'Unknown error');
  }
}
