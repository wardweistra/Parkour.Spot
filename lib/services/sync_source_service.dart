import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SyncSource {
  final String id;
  final String name;
  final String? description;
  final bool isPublic;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSyncAt;
  final Map<String, dynamic>? lastSyncStats;

  SyncSource({
    required this.id,
    required this.name,
    this.description,
    required this.isPublic,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.lastSyncAt,
    this.lastSyncStats,
  });

  factory SyncSource.fromMap(Map<String, dynamic> data) {
    return SyncSource(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'],
      isPublic: data['isPublic'] ?? true,
      isActive: data['isActive'] ?? true,
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      lastSyncAt: _parseTimestamp(data['lastSyncAt']),
      lastSyncStats: data['lastSyncStats'],
    );
  }

  static DateTime? _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return null;
    
    // Handle cloud_firestore.Timestamp objects
    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }
    
    // Handle Map format from Firebase Functions
    if (timestamp is Map<String, dynamic>) {
      final seconds = timestamp['_seconds'] as int?;
      final nanoseconds = timestamp['_nanoseconds'] as int? ?? 0;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + (nanoseconds / 1000000).round(),
        );
      }
    }
    
    return null;
  }
}

class SyncSourceService extends ChangeNotifier {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  
  List<SyncSource> _sources = [];
  bool _isLoading = false;
  String? _error;
  Map<String, String> _sourceNameCache = {};

  List<SyncSource> get sources => _sources;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get all sync sources
  Future<void> fetchSyncSources({bool includeInactive = false}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('getSyncSources');
      final result = await callable.call({
        'includeInactive': includeInactive,
      });

      if (result.data['success'] == true) {
        _sources = (result.data['sources'] as List)
            .map((source) => SyncSource.fromMap(source))
            .toList();
        
        // Update cache
        _sourceNameCache.clear();
        for (final source in _sources) {
          _sourceNameCache[source.id] = source.name;
        }
      } else {
        _error = 'Failed to fetch sync sources';
      }
    } catch (e) {
      _error = 'Failed to fetch sync sources: $e';
      debugPrint('Error fetching sync sources: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get source name by ID (from cache or fetch if needed)
  Future<String?> getSourceName(String sourceId) async {
    // Check cache first
    if (_sourceNameCache.containsKey(sourceId)) {
      return _sourceNameCache[sourceId];
    }

    // If not in cache and sources not loaded, fetch them silently
    if (_sources.isEmpty && !_isLoading) {
      await _fetchSyncSourcesSilently(includeInactive: true);
    }

    // Return from cache (should be populated after fetch)
    return _sourceNameCache[sourceId];
  }

  // Get source name synchronously from cache
  String? getSourceNameSync(String sourceId) {
    return _sourceNameCache[sourceId];
  }

  // Fetch sync sources without notifying listeners (for internal use)
  Future<void> _fetchSyncSourcesSilently({bool includeInactive = false}) async {
    try {
      _isLoading = true;
      _error = null;

      final callable = _functions.httpsCallable('getSyncSources');
      final result = await callable.call({
        'includeInactive': includeInactive,
      });

      if (result.data['success'] == true) {
        _sources = (result.data['sources'] as List)
            .map((source) => SyncSource.fromMap(source))
            .toList();
        
        // Update cache
        _sourceNameCache.clear();
        for (final source in _sources) {
          _sourceNameCache[source.id] = source.name;
        }
      } else {
        _error = 'Failed to fetch sync sources';
      }
    } catch (e) {
      _error = 'Failed to fetch sync sources: $e';
      debugPrint('Error fetching sync sources: $e');
    } finally {
      _isLoading = false;
      // Note: No notifyListeners() call here to avoid setState during build
    }
  }
}
