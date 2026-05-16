import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

Map<String, dynamic> _callableMap(dynamic value) {
  if (value is! Map) {
    throw FormatException('Expected Map, got ${value.runtimeType}');
  }
  return Map<String, dynamic>.from(value);
}

List<dynamic> _callableList(dynamic value) {
  if (value == null) return <dynamic>[];
  if (value is List) return List<dynamic>.from(value);
  if (value is Iterable) return value.toList();
  throw FormatException('Expected List/Iterable, got ${value.runtimeType}');
}

DateTime? _parseTimestamp(dynamic timestamp) {
  if (timestamp == null) return null;
  if (timestamp is Timestamp) return timestamp.toDate();
  if (timestamp is DateTime) return timestamp;
  if (timestamp is Map) {
    final map = Map<String, dynamic>.from(timestamp);
    final secondsRaw = map['_seconds'];
    final nanosecondsRaw = map['_nanoseconds'];
    final seconds = secondsRaw is int
        ? secondsRaw
        : (secondsRaw as num?)?.toInt();
    final nanoseconds = nanosecondsRaw is int
        ? nanosecondsRaw
        : (nanosecondsRaw as num?)?.toInt() ?? 0;
    if (seconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000 + (nanoseconds / 1000000).round(),
      );
    }
  }
  return null;
}

class EventSyncSource {
  final String id;
  final String name;
  final String icsUrl;
  final String? description;
  final String? publicUrl;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSyncAt;
  final Map<String, dynamic>? lastSyncStats;

  const EventSyncSource({
    required this.id,
    required this.name,
    required this.icsUrl,
    this.description,
    this.publicUrl,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.lastSyncAt,
    this.lastSyncStats,
  });

  factory EventSyncSource.fromMap(Map<String, dynamic> data) {
    return EventSyncSource(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      icsUrl: data['icsUrl']?.toString() ?? '',
      description: data['description'] as String?,
      publicUrl: data['publicUrl'] as String?,
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      lastSyncAt: _parseTimestamp(data['lastSyncAt']),
      lastSyncStats: data['lastSyncStats'] is Map
          ? Map<String, dynamic>.from(data['lastSyncStats'] as Map)
          : null,
    );
  }
}

class EventSyncSourceService extends ChangeNotifier {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );

  List<EventSyncSource> _sources = <EventSyncSource>[];
  final Map<String, EventSyncSource> _sourceDetailsCache =
      <String, EventSyncSource>{};
  bool _isLoading = false;
  bool _isSyncingAll = false;
  final Set<String> _syncingSources = <String>{};
  String? _error;

  List<EventSyncSource> get sources => _sources;
  bool get isLoading => _isLoading;
  bool get isSyncingAll => _isSyncingAll;
  Set<String> get syncingSources => _syncingSources;
  String? get error => _error;

  /// Fetches public event source details by ID. Results are cached.
  Future<EventSyncSource?> fetchEventSyncSourceById(String sourceId) async {
    if (_sourceDetailsCache.containsKey(sourceId)) {
      return _sourceDetailsCache[sourceId];
    }
    try {
      final callable = _functions.httpsCallable('getEventSyncSource');
      final result = await callable.call({'sourceId': sourceId});
      final data = _callableMap(result.data);
      if (data['success'] == true && data['source'] != null) {
        final source = EventSyncSource.fromMap(_callableMap(data['source']));
        _sourceDetailsCache[sourceId] = source;
        return source;
      }
    } catch (e) {
      debugPrint('Error fetching event sync source $sourceId: $e');
    }
    return null;
  }

  Future<void> fetchSources({bool includeInactive = true}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('getEventSyncSources');
      final result = await callable.call({'includeInactive': includeInactive});
      final data = _callableMap(result.data);
      if (data['success'] == true) {
        _sources = _callableList(
          data['sources'],
        ).map((item) => EventSyncSource.fromMap(_callableMap(item))).toList();
      } else {
        _error = 'Failed to fetch event sources';
      }
    } catch (e) {
      _error = 'Failed to fetch event sources: $e';
      debugPrint('EventSyncSourceService.fetchSources error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createSource({
    required String name,
    required String icsUrl,
    String? description,
    String? publicUrl,
    bool isActive = true,
  }) async {
    try {
      final callable = _functions.httpsCallable('createEventSyncSource');
      final result = await callable.call({
        'name': name,
        'icsUrl': icsUrl,
        'description': description,
        'publicUrl': publicUrl,
        'isActive': isActive,
      });
      final success = _callableMap(result.data)['success'] == true;
      if (success) {
        await fetchSources(includeInactive: true);
      }
      return success;
    } catch (e) {
      _error = 'Failed to create event source: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSource({
    required String sourceId,
    String? name,
    String? icsUrl,
    String? description,
    String? publicUrl,
    bool? isActive,
  }) async {
    try {
      final payload = <String, dynamic>{'sourceId': sourceId};
      if (name != null) payload['name'] = name;
      if (icsUrl != null) payload['icsUrl'] = icsUrl;
      if (description != null) payload['description'] = description;
      if (publicUrl != null) payload['publicUrl'] = publicUrl;
      if (isActive != null) payload['isActive'] = isActive;

      final callable = _functions.httpsCallable('updateEventSyncSource');
      final result = await callable.call(payload);
      final success = _callableMap(result.data)['success'] == true;
      if (success) {
        await fetchSources(includeInactive: true);
      }
      return success;
    } catch (e) {
      _error = 'Failed to update event source: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSource(String sourceId) async {
    try {
      final callable = _functions.httpsCallable('deleteEventSyncSource');
      final result = await callable.call({'sourceId': sourceId});
      final success = _callableMap(result.data)['success'] == true;
      if (success) {
        _sources.removeWhere((source) => source.id == sourceId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'Failed to delete event source: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> syncSource(String sourceId) async {
    try {
      _syncingSources.add(sourceId);
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('syncEventSource');
      final result = await callable.call({'sourceId': sourceId});
      _syncingSources.remove(sourceId);
      notifyListeners();

      final data = _callableMap(result.data);
      if (data['success'] == true) {
        await fetchSources(includeInactive: true);
        return data;
      }
      _error = data['error']?.toString() ?? 'Sync failed';
      notifyListeners();
      return null;
    } catch (e) {
      _syncingSources.remove(sourceId);
      _error = 'Failed to sync event source: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> syncAllSources() async {
    try {
      _isSyncingAll = true;
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('syncAllEventSources');
      final result = await callable.call({});
      _isSyncingAll = false;
      notifyListeners();

      final data = _callableMap(result.data);
      if (data['success'] == true) {
        await fetchSources(includeInactive: true);
        return data;
      }
      _error = data['error']?.toString() ?? 'Sync all failed';
      notifyListeners();
      return null;
    } catch (e) {
      _isSyncingAll = false;
      _error = 'Failed to sync all event sources: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }
}
