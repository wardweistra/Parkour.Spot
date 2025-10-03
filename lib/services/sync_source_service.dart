import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SyncSource {
  final String id;
  final String name;
  final String sourceType; // KMZ, GEOJSON, UMAP_GEOJSON
  final String? kmzUrl;
  final String? geojsonUrl;
  final String? description;
  final String? publicUrl;
  final String? instagramHandle; // Instagram handle for the source owner
  final bool isPublic;
  final bool isActive;
  final List<String>? includeFolders; // Optional list of folders to include
  final bool? recordFolderName; // Whether to store folder name on spots
  final List<String>? allFolders; // List of all folders found during sync (when recordFolderName is true)
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSyncAt;
  final Map<String, dynamic>? lastSyncStats;

  SyncSource({
    required this.id,
    required this.name,
    required this.sourceType,
    this.kmzUrl,
    this.geojsonUrl,
    this.description,
    this.publicUrl,
    this.instagramHandle,
    required this.isPublic,
    required this.isActive,
    this.includeFolders,
    this.recordFolderName,
    this.allFolders,
    this.createdAt,
    this.updatedAt,
    this.lastSyncAt,
    this.lastSyncStats,
  });

  factory SyncSource.fromMap(Map<String, dynamic> data) {
    final String type = (data['sourceType'] ?? 'KMZ').toString();
    return SyncSource(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      sourceType: type,
      kmzUrl: data['kmzUrl'],
      geojsonUrl: data['geojsonUrl'],
      description: data['description'],
      publicUrl: data['publicUrl'],
      instagramHandle: data['instagramHandle'],
      isPublic: data['isPublic'] ?? true,
      isActive: data['isActive'] ?? true,
      includeFolders: data['includeFolders'] != null
          ? List<String>.from((data['includeFolders'] as List).map((e) => e.toString()))
          : null,
      recordFolderName: data['recordFolderName'] is bool ? data['recordFolderName'] as bool : null,
      allFolders: data['allFolders'] != null
          ? List<String>.from((data['allFolders'] as List).map((e) => e.toString()))
          : null,
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
  bool _isSyncingAll = false;
  final Set<String> _syncingSources = <String>{};
  String? _error;
  final Map<String, String> _sourceNameCache = {};

  List<SyncSource> get sources => _sources;
  bool get isLoading => _isLoading;
  bool get isSyncingAll => _isSyncingAll;
  Set<String> get syncingSources => _syncingSources;
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

  Future<bool> createSource({
    required String name,
    required String sourceType, // 'KMZ' | 'GEOJSON' | 'UMAP_GEOJSON'
    String? kmzUrl,
    String? geojsonUrl,
    String? description,
    String? publicUrl,
    String? instagramHandle,
    bool isPublic = true,
    bool isActive = true,
    List<String>? includeFolders,
    bool? recordFolderName,
  }) async {
    try {
      final callable = _functions.httpsCallable('createSyncSource');
      final payload = <String, dynamic>{
        'name': name,
        'sourceType': sourceType,
        'description': description,
        'publicUrl': publicUrl,
        'instagramHandle': instagramHandle,
        'isPublic': isPublic,
        'isActive': isActive,
        if (includeFolders != null) 'includeFolders': includeFolders,
        if (recordFolderName != null) 'recordFolderName': recordFolderName,
      };
      if (sourceType.toUpperCase() == 'KMZ') {
        payload['kmzUrl'] = kmzUrl;
      } else {
        payload['geojsonUrl'] = geojsonUrl;
      }
      final result = await callable.call(payload);
      final success = result.data['success'] == true;
      if (success) {
        await fetchSyncSources(includeInactive: true);
      }
      return success;
    } catch (e) {
      _error = 'Failed to create source: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSource({
    required String sourceId,
    String? name,
    String? kmzUrl,
    String? geojsonUrl,
    String? sourceType,
    String? description,
    String? publicUrl,
    String? instagramHandle,
    bool? isPublic,
    bool? isActive,
    List<String>? includeFolders,
    bool? recordFolderName,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateSyncSource');
      final payload = <String, dynamic>{'sourceId': sourceId};
      if (name != null) payload['name'] = name;
      if (kmzUrl != null) payload['kmzUrl'] = kmzUrl;
      if (description != null) payload['description'] = description;
      if (geojsonUrl != null) payload['geojsonUrl'] = geojsonUrl;
      if (sourceType != null) payload['sourceType'] = sourceType;
      if (publicUrl != null) payload['publicUrl'] = publicUrl;
      if (instagramHandle != null) payload['instagramHandle'] = instagramHandle;
      if (isPublic != null) payload['isPublic'] = isPublic;
      if (isActive != null) payload['isActive'] = isActive;
      if (includeFolders != null) payload['includeFolders'] = includeFolders;
      if (recordFolderName != null) payload['recordFolderName'] = recordFolderName;
      final result = await callable.call(payload);
      final success = result.data['success'] == true;
      if (success) {
        await fetchSyncSources(includeInactive: true);
      }
      return success;
    } catch (e) {
      _error = 'Failed to update source: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSource(String sourceId) async {
    try {
      final callable = _functions.httpsCallable('deleteSyncSource');
      final result = await callable.call({'sourceId': sourceId});
      final success = result.data['success'] == true;
      if (success) {
        _sources.removeWhere((s) => s.id == sourceId);
        _sourceNameCache.remove(sourceId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      _error = 'Failed to delete source: $e';
      debugPrint(_error);
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> syncAllSources() async {
    try {
      _isSyncingAll = true;
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('syncAllSources');
      final result = await callable.call();
      
      _isSyncingAll = false;
      notifyListeners();
      
      if (result.data['success'] == true) {
        // Refresh the sources list to update last sync time
        await fetchSyncSources(includeInactive: true);
        return Map<String, dynamic>.from(result.data as Map);
      } else {
        _error = 'Sync failed: ${result.data['error'] ?? 'Unknown error'}';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _isSyncingAll = false;
      _error = 'Failed to sync all sources: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> syncSingleSource(String sourceId) async {
    try {
      _syncingSources.add(sourceId);
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('syncSingleSource');
      final result = await callable.call({'sourceId': sourceId});
      
      _syncingSources.remove(sourceId);
      notifyListeners();
      
      if (result.data['success'] == true) {
        // Refresh the sources list to update last sync time
        await fetchSyncSources(includeInactive: true);
        return Map<String, dynamic>.from(result.data as Map);
      } else {
        _error = 'Sync failed: ${result.data['error'] ?? 'Unknown error'}';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _syncingSources.remove(sourceId);
      _error = 'Failed to sync single source: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> cleanupUnusedImages() async {
    try {
      final callable = _functions.httpsCallable('cleanupUnusedImages');
      final result = await callable.call();
      return result.data;
    } catch (e) {
      _error = 'Failed to cleanup unused images: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> findMissingImages() async {
    try {
      final callable = _functions.httpsCallable('findMissingImages');
      final result = await callable.call();
      return result.data;
    } catch (e) {
      _error = 'Failed to find missing images: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> findOrphanedSpots() async {
    try {
      final callable = _functions.httpsCallable('findOrphanedSpots');
      final result = await callable.call({});
      return result.data;
    } catch (e) {
      _error = 'Failed to find orphaned spots: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> deleteSpot(String spotId) async {
    try {
      final callable = _functions.httpsCallable('deleteSpot');
      final result = await callable.call({'spotId': spotId});
      return result.data;
    } catch (e) {
      _error = 'Failed to delete spot: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> deleteSpots(List<String> spotIds) async {
    try {
      final callable = _functions.httpsCallable('deleteSpots');
      final result = await callable.call({'spotIds': spotIds});
      return result.data;
    } catch (e) {
      _error = 'Failed to delete spots: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> uploadReplacementImage({
    required String filename,
    required String imageData,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final callable = _functions.httpsCallable('uploadReplacementImage');
      final result = await callable.call({
        'filename': filename,
        'imageData': imageData,
        'contentType': contentType,
      });
      return result.data;
    } catch (e) {
      _error = 'Failed to upload replacement image: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
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
