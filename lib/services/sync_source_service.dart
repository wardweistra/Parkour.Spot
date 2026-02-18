import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Lightweight summary for filter lists. Only id, name, and folder data.
/// Use fetchSyncSourceById for full details when opening the details dialog.
class SyncSourceSummary {
  final String id;
  final String name;
  final bool? recordFolderName;
  final List<String>? allFolders;

  const SyncSourceSummary({
    required this.id,
    required this.name,
    this.recordFolderName,
    this.allFolders,
  });

  factory SyncSourceSummary.fromMap(Map<String, dynamic> data) {
    return SyncSourceSummary(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      recordFolderName: data['recordFolderName'] is bool ? data['recordFolderName'] as bool : null,
      allFolders: data['allFolders'] != null
          ? List<String>.from((data['allFolders'] as List).map((e) => e.toString()))
          : null,
    );
  }
}

class SyncSource {
  final String id;
  final String name;
  final String kmzUrl;
  final String? description;
  final String? publicUrl;
  final String? instagramHandle; // Instagram handle for the source owner
  final bool isActive;
  final List<String>? includeFolders; // Optional list of folders to include
  final bool? recordFolderName; // Whether to store folder name on spots
  final List<String>? allFolders; // List of all folders found during sync (when recordFolderName is true)
  final Map<String, dynamic>? defaultSpotAttributes; // Defaults for all new spots in this source
  final Map<String, Map<String, dynamic>>? folderSpotAttributes; // Folder-specific defaults for new spots
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSyncAt;
  final Map<String, dynamic>? lastSyncStats;
  final String? lightSyncSchedule; // Cron expression for light sync
  final String? fullSyncSchedule; // Cron expression for full sync
  final bool? autoSyncEnabled; // Whether auto-sync is enabled
  final DateTime? lastLightSyncAt;
  final DateTime? lastFullSyncAt;
  final bool? syncInProgress; // Whether a sync is currently in progress
  final String? syncType; // "light" or "full" - type of sync in progress
  final Map<String, dynamic>? syncProgress; // Progress tracking: {processedCount, totalCount, lastProcessedIndex}

  SyncSource({
    required this.id,
    required this.name,
    required this.kmzUrl,
    this.description,
    this.publicUrl,
    this.instagramHandle,
    required this.isActive,
    this.includeFolders,
    this.recordFolderName,
    this.allFolders,
    this.defaultSpotAttributes,
    this.folderSpotAttributes,
    this.createdAt,
    this.updatedAt,
    this.lastSyncAt,
    this.lastSyncStats,
    this.lightSyncSchedule,
    this.fullSyncSchedule,
    this.autoSyncEnabled,
    this.lastLightSyncAt,
    this.lastFullSyncAt,
    this.syncInProgress,
    this.syncType,
    this.syncProgress,
  });

  factory SyncSource.fromMap(Map<String, dynamic> data) {
    return SyncSource(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      kmzUrl: data['kmzUrl'] ?? '',
      description: data['description'],
      publicUrl: data['publicUrl'],
      instagramHandle: data['instagramHandle'],
      isActive: data['isActive'] ?? true,
      includeFolders: data['includeFolders'] != null
          ? List<String>.from((data['includeFolders'] as List).map((e) => e.toString()))
          : null,
      recordFolderName: data['recordFolderName'] is bool ? data['recordFolderName'] as bool : null,
      allFolders: data['allFolders'] != null
          ? List<String>.from((data['allFolders'] as List).map((e) => e.toString()))
          : null,
      defaultSpotAttributes: _parseDefaultSpotAttributes(data['defaultSpotAttributes']),
      folderSpotAttributes: _parseFolderSpotAttributes(data['folderSpotAttributes']),
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      lastSyncAt: _parseTimestamp(data['lastSyncAt']),
      lastSyncStats: data['lastSyncStats'],
      lightSyncSchedule: data['lightSyncSchedule'],
      fullSyncSchedule: data['fullSyncSchedule'],
      autoSyncEnabled: data['autoSyncEnabled'],
      lastLightSyncAt: _parseTimestamp(data['lastLightSyncAt']),
      lastFullSyncAt: _parseTimestamp(data['lastFullSyncAt']),
      syncInProgress: data['syncInProgress'],
      syncType: data['syncType'],
      syncProgress: data['syncProgress'] != null
          ? Map<String, dynamic>.from(data['syncProgress'] as Map)
          : null,
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

  static Map<String, dynamic>? _parseDefaultSpotAttributes(dynamic raw) {
    if (raw is! Map) return null;
    final parsed = Map<String, dynamic>.from(raw);
    return parsed.isEmpty ? null : parsed;
  }

  static Map<String, Map<String, dynamic>>? _parseFolderSpotAttributes(dynamic raw) {
    if (raw is! Map) return null;
    final parsed = <String, Map<String, dynamic>>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      if (entry.value is! Map) continue;
      final valueMap = Map<String, dynamic>.from(entry.value as Map);
      if (valueMap.isEmpty) continue;
      parsed[key] = valueMap;
    }
    return parsed.isEmpty ? null : parsed;
  }
}

class SyncSourceService extends ChangeNotifier {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
  
  List<SyncSource> _sources = [];
  List<SyncSourceSummary> _sourceSummaries = [];
  bool _isLoading = false;
  bool _isLoadingSummaries = false;
  bool _isSyncingAll = false;
  final Set<String> _syncingSources = <String>{};
  String? _error;
  String? _summariesError;
  final Map<String, String> _sourceNameCache = {};
  final Map<String, SyncSource> _sourceDetailsCache = {};

  List<SyncSource> get sources => _sources;
  List<SyncSourceSummary> get sourceSummaries => _sourceSummaries;
  bool get isLoading => _isLoading;
  bool get isLoadingSummaries => _isLoadingSummaries;
  String? get summariesError => _summariesError;
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

  /// Fetches lightweight summaries (id, name, folders) for filter lists.
  /// Much faster than fetchSyncSources. Use fetchSyncSourceById for full details.
  Future<void> fetchSyncSourceSummaries({bool includeInactive = false}) async {
    try {
      _isLoadingSummaries = true;
      _summariesError = null;
      notifyListeners();

      final callable = _functions.httpsCallable('getSyncSources');
      final result = await callable.call({
        'includeInactive': includeInactive,
        'summaryOnly': true,
      });

      if (result.data['success'] == true) {
        _sourceSummaries = (result.data['sources'] as List)
            .map((s) => SyncSourceSummary.fromMap(s))
            .toList();
        _sourceNameCache.addAll({
          for (final s in _sourceSummaries) s.id: s.name,
        });
      } else {
        _summariesError = 'Failed to load sources';
      }
    } catch (e) {
      _summariesError = 'Failed to load sources: $e';
      debugPrint('Error fetching sync source summaries: $e');
    } finally {
      _isLoadingSummaries = false;
      notifyListeners();
    }
  }

  /// Fetches full source details by ID. Results are cached.
  /// Use when opening the source details dialog.
  Future<SyncSource?> fetchSyncSourceById(String sourceId) async {
    if (_sourceDetailsCache.containsKey(sourceId)) {
      return _sourceDetailsCache[sourceId];
    }
    try {
      final callable = _functions.httpsCallable('getSyncSource');
      final result = await callable.call({'sourceId': sourceId});
      if (result.data['success'] == true && result.data['source'] != null) {
        final source = SyncSource.fromMap(
          Map<String, dynamic>.from(result.data['source'] as Map),
        );
        _sourceDetailsCache[sourceId] = source;
        _sourceNameCache[sourceId] = source.name;
        return source;
      }
    } catch (e) {
      debugPrint('Error fetching sync source $sourceId: $e');
    }
    return null;
  }

  Future<bool> createSource({
    required String name,
    required String kmzUrl,
    String? description,
    String? publicUrl,
    String? instagramHandle,
    bool isActive = true,
    List<String>? includeFolders,
    bool? recordFolderName,
    Map<String, dynamic>? defaultSpotAttributes,
    Map<String, dynamic>? folderSpotAttributes,
    String? lightSyncSchedule,
    String? fullSyncSchedule,
    bool autoSyncEnabled = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('createSyncSource');
      final result = await callable.call({
        'name': name,
        'kmzUrl': kmzUrl,
        'description': description,
        'publicUrl': publicUrl,
        'instagramHandle': instagramHandle,
        'isActive': isActive,
        if (includeFolders != null) 'includeFolders': includeFolders,
        if (recordFolderName != null) 'recordFolderName': recordFolderName,
        if (defaultSpotAttributes != null) 'defaultSpotAttributes': defaultSpotAttributes,
        if (folderSpotAttributes != null) 'folderSpotAttributes': folderSpotAttributes,
        if (lightSyncSchedule != null && lightSyncSchedule.isNotEmpty) 'lightSyncSchedule': lightSyncSchedule,
        if (fullSyncSchedule != null && fullSyncSchedule.isNotEmpty) 'fullSyncSchedule': fullSyncSchedule,
        'autoSyncEnabled': autoSyncEnabled,
      });
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
    String? description,
    String? publicUrl,
    String? instagramHandle,
    bool? isActive,
    List<String>? includeFolders,
    bool? recordFolderName,
    Map<String, dynamic>? defaultSpotAttributes,
    Map<String, dynamic>? folderSpotAttributes,
    bool updateSpotAttributeDefaults = false,
    String? lightSyncSchedule,
    String? fullSyncSchedule,
    bool? autoSyncEnabled,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateSyncSource');
      final payload = <String, dynamic>{'sourceId': sourceId};
      if (name != null) payload['name'] = name;
      if (kmzUrl != null) payload['kmzUrl'] = kmzUrl;
      if (description != null) payload['description'] = description;
      if (publicUrl != null) payload['publicUrl'] = publicUrl;
      if (instagramHandle != null) payload['instagramHandle'] = instagramHandle;
      if (isActive != null) payload['isActive'] = isActive;
      if (includeFolders != null) payload['includeFolders'] = includeFolders;
      if (recordFolderName != null) payload['recordFolderName'] = recordFolderName;
      if (updateSpotAttributeDefaults) {
        payload['defaultSpotAttributes'] = defaultSpotAttributes;
        payload['folderSpotAttributes'] = folderSpotAttributes;
      }
      if (lightSyncSchedule != null) {
        payload['lightSyncSchedule'] = lightSyncSchedule.isEmpty ? null : lightSyncSchedule;
      }
      if (fullSyncSchedule != null) {
        payload['fullSyncSchedule'] = fullSyncSchedule.isEmpty ? null : fullSyncSchedule;
      }
      if (autoSyncEnabled != null) payload['autoSyncEnabled'] = autoSyncEnabled;
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
        _sourceSummaries.removeWhere((s) => s.id == sourceId);
        _sourceNameCache.remove(sourceId);
        _sourceDetailsCache.remove(sourceId);
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

  Future<Map<String, dynamic>?> syncAllSources({bool updateImagesForExistingSpots = false}) async {
    try {
      _isSyncingAll = true;
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('syncAllSources');
      final result = await callable.call({
        'updateImagesForExistingSpots': updateImagesForExistingSpots,
      });
      
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

  Future<Map<String, dynamic>?> syncSingleSource(String sourceId, {bool updateImagesForExistingSpots = false}) async {
    try {
      _syncingSources.add(sourceId);
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('syncSingleSource');
      final result = await callable.call({
        'sourceId': sourceId,
        'updateImagesForExistingSpots': updateImagesForExistingSpots,
      });
      
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

  Future<Map<String, dynamic>?> resumeSync(String sourceId) async {
    try {
      _syncingSources.add(sourceId);
      _error = null;
      notifyListeners();

      final callable = _functions.httpsCallable('resumeSync');
      final result = await callable.call({
        'sourceId': sourceId,
      });
      
      _syncingSources.remove(sourceId);
      notifyListeners();
      
      if (result.data['success'] == true) {
        // Refresh the sources list to update sync progress
        await fetchSyncSources(includeInactive: true);
        return Map<String, dynamic>.from(result.data as Map);
      } else {
        _error = 'Resume sync failed: ${result.data['error'] ?? 'Unknown error'}';
        notifyListeners();
        return null;
      }
    } catch (e) {
      _syncingSources.remove(sourceId);
      _error = 'Failed to resume sync: $e';
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

  Future<Map<String, dynamic>?> updateSpotSourceNames({String? sourceId}) async {
    try {
      final callable = _functions.httpsCallable('updateSpotSourceNames');
      final result = await callable.call({
        if (sourceId != null) 'sourceId': sourceId,
      });
      return result.data;
    } catch (e) {
      _error = 'Failed to update spot source names: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  /// One-time backfill: populates spotSearchTerms for all spots (Explore autocomplete).
  /// Run once after deploying searchSpotsByTitle changes.
  Future<Map<String, dynamic>?> backfillSpotNameLower() async {
    try {
      final callable = _functions.httpsCallable(
        'backfillSpotNameLower',
        options: HttpsCallableOptions(
          timeout: const Duration(minutes: 9),
        ),
      );
      final result = await callable.call({});
      return result.data as Map<String, dynamic>?;
    } catch (e) {
      _error = 'Failed to backfill spotSearchTerms: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> backfillSourceSpotAttributes({String? sourceId}) async {
    try {
      final callable = _functions.httpsCallable(
        'backfillSourceSpotAttributes',
        options: HttpsCallableOptions(
          timeout: const Duration(minutes: 9),
        ),
      );
      final result = await callable.call({
        if (sourceId != null) 'sourceId': sourceId,
      });
      return result.data;
    } catch (e) {
      _error = 'Failed to backfill source spot attributes: $e';
      debugPrint(_error);
      notifyListeners();
      return null;
    }
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
