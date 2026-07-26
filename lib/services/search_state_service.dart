import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SearchStateService extends ChangeNotifier {
  // Keys for SharedPreferences
  static const String _keyCenterLat = 'search_center_lat';
  static const String _keyCenterLng = 'search_center_lng';
  static const String _keyZoom = 'search_zoom';
  static const String _keyIsSatellite = 'search_is_satellite';
  static const String _keyHasImagesOnly = 'search_has_images_only';
  static const String _keySelectedSpotSource = 'search_selected_spot_source'; // null = all, "" = native, string = specific source
  static const String _keyFilterArea = 'search_filter_area'; // "amenities" | "source" | null
  static const String _keySpotAccess = 'search_spot_access'; // when amenities: list of "public" | "restricted" | "paid" for OR query
  static const String _keySpotFacilitiesCovered = 'search_spot_facilities_covered'; // when amenities: "yes"
  static const String _keySpotFacilitiesLighting = 'search_spot_facilities_lighting'; // when amenities: "yes"
  static const String _keySpotFacilitiesWaterTap = 'search_spot_facilities_water_tap'; // when amenities: "yes"
  static const String _keySpotFacilitiesToilet = 'search_spot_facilities_toilet'; // when amenities: "yes"
  static const String _keySpotFacilitiesParking = 'search_spot_facilities_parking'; // when amenities: "yes"
  static const String _keyGoodFor = 'search_good_for'; // when amenities: list for array-contains-any
  static const String _keySpotFeatures = 'search_spot_features'; // when amenities: list for array-contains-any
  static const String _keyAttributeFilterMode = 'search_attribute_filter_mode'; // "goodFor" | "spotFeatures"
  static const String _keySelectedFolders = 'search_selected_folders'; // JSON map of sourceId -> List<String> (multiple folders, empty list = all folders)
  static const String _keySelectedListId = 'search_selected_list_id'; // Selected spot list ID for highlighting
  static const String _keyLastKnownUserLat = 'search_last_known_user_lat';
  static const String _keyLastKnownUserLng = 'search_last_known_user_lng';

  // Backing fields
  double? _centerLat;
  double? _centerLng;
  double? _zoom;
  bool _isSatellite = false;
  bool _hasImagesOnly = false;
  String? _filterArea; // "amenities" | "source" | null (default = amenities)
  String? _selectedSpotSource; // null = all sources, "" = native only, string = specific source ID
  List<String> _spotAccess = []; // when filterArea=amenities: ["public", "restricted", "paid"] for OR query, empty = any
  bool? _spotFacilitiesCovered; // when filterArea=amenities: true = "yes"
  bool? _spotFacilitiesLighting; // when filterArea=amenities: true = "yes"
  bool? _spotFacilitiesWaterTap; // when filterArea=amenities: true = "yes"
  bool? _spotFacilitiesToilet; // when filterArea=amenities: true = "yes"
  bool? _spotFacilitiesParking; // when filterArea=amenities: true = "yes"
  List<String> _goodFor = []; // when filterArea=amenities: array-contains-any
  List<String> _spotFeatures = []; // when filterArea=amenities: array-contains-any
  String _attributeFilterMode = 'goodFor'; // "goodFor" | "spotFeatures" - which attribute chip section to show
  Map<String, List<String>> _selectedFolders = {}; // sourceId -> list of selected folder names (empty list = all folders)
  String? _selectedListId; // Selected spot list ID for highlighting
  double? _lastKnownUserLat;
  double? _lastKnownUserLng;

  // Getters
  double? get centerLat => _centerLat;
  double? get centerLng => _centerLng;
  double? get zoom => _zoom;
  bool get isSatellite => _isSatellite;
  bool get hasImagesOnly => _hasImagesOnly;
  String? get filterArea => _filterArea;
  String? get selectedSpotSource => _selectedSpotSource;
  List<String> get spotAccess => List.unmodifiable(_spotAccess);
  bool? get spotFacilitiesCovered => _spotFacilitiesCovered;
  bool? get spotFacilitiesLighting => _spotFacilitiesLighting;
  bool? get spotFacilitiesWaterTap => _spotFacilitiesWaterTap;
  bool? get spotFacilitiesToilet => _spotFacilitiesToilet;
  bool? get spotFacilitiesParking => _spotFacilitiesParking;
  List<String> get goodFor => List.unmodifiable(_goodFor);
  List<String> get spotFeatures => List.unmodifiable(_spotFeatures);
  String get attributeFilterMode => _attributeFilterMode;
  Map<String, List<String>> get selectedFolders => Map.unmodifiable(_selectedFolders);
  String? get selectedListId => _selectedListId;
  double? get lastKnownUserLat => _lastKnownUserLat;
  double? get lastKnownUserLng => _lastKnownUserLng;
  
  /// Get selected folders for a specific source (empty list = all folders)
  List<String> getSelectedFoldersForSource(String sourceId) {
    return _selectedFolders[sourceId] ?? [];
  }
  
  /// Check if a specific folder is selected for a source
  bool isFolderSelectedForSource(String sourceId, String folder) {
    final folders = _selectedFolders[sourceId];
    return folders != null && folders.contains(folder);
  }
  
  /// Toggle folder selection for a source (add if not selected, remove if selected)
  Future<void> toggleFolderForSource(String sourceId, String folder) async {
    final currentFolders = _selectedFolders[sourceId] ?? [];
    if (currentFolders.contains(folder)) {
      // Remove folder
      final updated = List<String>.from(currentFolders)..remove(folder);
      if (updated.isEmpty) {
        _selectedFolders.remove(sourceId);
      } else {
        _selectedFolders[sourceId] = updated;
      }
    } else {
      // Add folder
      _selectedFolders[sourceId] = List<String>.from(currentFolders)..add(folder);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final foldersJson = jsonEncode(_selectedFolders.map((key, value) => MapEntry(key, value)));
      await prefs.setString(_keySelectedFolders, foldersJson);
    } catch (e) {
      // Ignore SharedPreferences errors - settings will not persist but app continues to work
    }
  }
  
  /// Clear all folder selections for a source (select all folders)
  Future<void> clearFoldersForSource(String sourceId) async {
    _selectedFolders.remove(sourceId);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final foldersJson = jsonEncode(_selectedFolders.map((key, value) => MapEntry(key, value)));
      await prefs.setString(_keySelectedFolders, foldersJson);
    } catch (e) {
      // Ignore SharedPreferences errors - settings will not persist but app continues to work
    }
  }

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _centerLat = prefs.getDouble(_keyCenterLat);
      _centerLng = prefs.getDouble(_keyCenterLng);
      _zoom = prefs.getDouble(_keyZoom);
      _isSatellite = prefs.getBool(_keyIsSatellite) ?? false;
      _hasImagesOnly = prefs.getBool(_keyHasImagesOnly) ?? false;
      final storedFilterArea = prefs.getString(_keyFilterArea);
      _selectedSpotSource = prefs.getString(_keySelectedSpotSource); // null if not set (all sources)
      final foldersJson = prefs.getString(_keySelectedFolders);
      // Migration: "source" used to be the default value.
      // Keep legacy migration, but preserve explicit source filters.
      final hasStoredSourceFilters = _selectedSpotSource != null || _hasStoredFolderSelections(foldersJson);
      if (storedFilterArea == 'source' && !hasStoredSourceFilters) {
        _filterArea = null;
        await prefs.remove(_keyFilterArea);
      } else {
        _filterArea = storedFilterArea;
      }
      final accessJson = prefs.getString(_keySpotAccess);
      if (accessJson != null && accessJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(accessJson);
          if (decoded is List) {
            _spotAccess = List<String>.from(decoded.map((v) => v.toString()));
          } else if (decoded is String) {
            _spotAccess = [decoded]; // Migrate old single-value JSON format
          } else {
            _spotAccess = [];
          }
        } catch (e) {
          _spotAccess = [accessJson]; // Migrate old format: raw string stored directly
        }
      } else {
        _spotAccess = [];
      }
      _spotFacilitiesCovered = prefs.getBool(_keySpotFacilitiesCovered);
      _spotFacilitiesLighting = prefs.getBool(_keySpotFacilitiesLighting);
      _spotFacilitiesWaterTap = prefs.getBool(_keySpotFacilitiesWaterTap);
      _spotFacilitiesToilet = prefs.getBool(_keySpotFacilitiesToilet);
      _spotFacilitiesParking = prefs.getBool(_keySpotFacilitiesParking);
      _goodFor = _loadStringListFromPrefs(prefs, _keyGoodFor);
      _spotFeatures = _loadStringListFromPrefs(prefs, _keySpotFeatures);
      _attributeFilterMode = prefs.getString(_keyAttributeFilterMode) ?? 'goodFor';
      if (_attributeFilterMode != 'goodFor' && _attributeFilterMode != 'spotFeatures') {
        _attributeFilterMode = 'goodFor';
      }
      _selectedListId = prefs.getString(_keySelectedListId); // null if not set
      _lastKnownUserLat = prefs.getDouble(_keyLastKnownUserLat);
      _lastKnownUserLng = prefs.getDouble(_keyLastKnownUserLng);
      
      // Load selected folders (migrate from old format if needed)
      if (foldersJson != null) {
        try {
          final decoded = jsonDecode(foldersJson) as Map<String, dynamic>;
          _selectedFolders = decoded.map((key, value) {
            // Handle migration from old String format to new List<String> format
            if (value is List) {
              // Already in new format
              return MapEntry(key, List<String>.from(value.map((v) => v.toString())));
            } else if (value is String) {
              // Old single folder format - convert to list
              return MapEntry(key, [value]);
            } else {
              // null or invalid - return empty list (all folders)
              return MapEntry(key, <String>[]);
            }
          });
        } catch (e) {
          // Silent fail - reset to empty map
          _selectedFolders = {};
        }
      }
      
      notifyListeners();
    } catch (e) {
      // Silent fail - persistence is best-effort
    }
  }

  Future<void> saveMapCamera(double centerLat, double centerLng, double zoom) async {
    _centerLat = centerLat;
    _centerLng = centerLng;
    _zoom = zoom;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyCenterLat, centerLat);
      await prefs.setDouble(_keyCenterLng, centerLng);
      await prefs.setDouble(_keyZoom, zoom);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> setSatellite(bool isSatellite) async {
    _isSatellite = isSatellite;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsSatellite, isSatellite);
    } catch (e) {
      // Ignore SharedPreferences errors - settings will not persist but app continues to work
    }
  }

  Future<void> setHasImagesOnly(bool value) async {
    _hasImagesOnly = value;
    notifyListeners();
    await _persistFilterState();
  }

  /// Set filter area: "amenities" | "source" | null (null = amenities)
  /// When switching to amenities, clears source/folder. When switching to source, clears amenities.
  Future<void> setFilterArea(String? filterArea) async {
    if (_filterArea == filterArea) return;
    _filterArea = filterArea;
    if (filterArea == 'amenities') {
      _selectedSpotSource = null;
      _selectedFolders = {};
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_keySelectedSpotSource);
        await prefs.setString(_keySelectedFolders, '{}');
      } catch (e) {
        // Ignore SharedPreferences errors
      }
    } else if (filterArea == 'source' || filterArea == null) {
      _spotAccess = [];
      _spotFacilitiesCovered = null;
      _spotFacilitiesLighting = null;
      _spotFacilitiesWaterTap = null;
      _spotFacilitiesToilet = null;
      _spotFacilitiesParking = null;
      _goodFor = [];
      _spotFeatures = [];
      _attributeFilterMode = 'goodFor';
    }
    notifyListeners();
    await _persistFilterState();
  }

  /// Reset all source and amenities filters to defaults.
  Future<void> clearAllFilters() async {
    _hasImagesOnly = false;
    _filterArea = 'source';
    _selectedSpotSource = null;
    _selectedFolders = {};
    _spotAccess = [];
    _spotFacilitiesCovered = null;
    _spotFacilitiesLighting = null;
    _spotFacilitiesWaterTap = null;
    _spotFacilitiesToilet = null;
    _spotFacilitiesParking = null;
    _goodFor = [];
    _spotFeatures = [];
    _attributeFilterMode = 'goodFor';

    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySelectedSpotSource);
      await prefs.setString(_keySelectedFolders, '{}');
    } catch (e) {
      // Ignore SharedPreferences errors - settings will not persist but app continues to work
    }

    await _persistFilterState();
  }

  /// Toggle access level (add if not selected, remove if selected). Empty = any.
  Future<void> toggleSpotAccess(String accessKey) async {
    if (_spotAccess.contains(accessKey)) {
      _spotAccess = List<String>.from(_spotAccess)..remove(accessKey);
    } else {
      _spotAccess = List<String>.from(_spotAccess)..add(accessKey);
    }
    notifyListeners();
    await _persistFilterState();
  }

  /// Clear all access selections (any)
  Future<void> clearSpotAccess() async {
    _spotAccess = [];
    notifyListeners();
    await _persistFilterState();
  }

  Future<void> setSpotFacilitiesCovered(bool? value) async {
    _spotFacilitiesCovered = value;
    notifyListeners();
    await _persistFilterState();
  }

  Future<void> setSpotFacilitiesLighting(bool? value) async {
    _spotFacilitiesLighting = value;
    notifyListeners();
    await _persistFilterState();
  }

  Future<void> setSpotFacilitiesWaterTap(bool? value) async {
    _spotFacilitiesWaterTap = value;
    notifyListeners();
    await _persistFilterState();
  }

  Future<void> setSpotFacilitiesToilet(bool? value) async {
    _spotFacilitiesToilet = value;
    notifyListeners();
    await _persistFilterState();
  }

  Future<void> setSpotFacilitiesParking(bool? value) async {
    _spotFacilitiesParking = value;
    notifyListeners();
    await _persistFilterState();
  }

  /// Switch attribute filter mode: 'goodFor' clears spotFeatures, 'spotFeatures' clears goodFor.
  Future<void> setAttributeFilterMode(String mode) async {
    _attributeFilterMode = mode;
    if (mode == 'goodFor') {
      _spotFeatures = [];
    } else if (mode == 'spotFeatures') {
      _goodFor = [];
    }
    notifyListeners();
    await _persistFilterState();
  }

  Future<void> toggleGoodFor(String key) async {
    if (_goodFor.contains(key)) {
      _goodFor = List<String>.from(_goodFor)..remove(key);
    } else {
      _spotFeatures = []; // Mutual exclusivity: Good For clears Spot Features
      _goodFor = List<String>.from(_goodFor)..add(key);
    }
    notifyListeners();
    await _persistFilterState();
  }

  Future<void> toggleSpotFeatures(String key) async {
    if (_spotFeatures.contains(key)) {
      _spotFeatures = List<String>.from(_spotFeatures)..remove(key);
    } else {
      _goodFor = []; // Mutual exclusivity: Spot Features clears Good For
      _spotFeatures = List<String>.from(_spotFeatures)..add(key);
    }
    notifyListeners();
    await _persistFilterState();
  }

  Future<void> _persistFilterState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasImagesOnly, _hasImagesOnly);
      if (_filterArea == null) {
        await prefs.remove(_keyFilterArea);
      } else {
        await prefs.setString(_keyFilterArea, _filterArea!);
      }
      if (_spotAccess.isEmpty) {
        await prefs.remove(_keySpotAccess);
      } else {
        await prefs.setString(_keySpotAccess, jsonEncode(_spotAccess));
      }
      if (_spotFacilitiesCovered == null) {
        await prefs.remove(_keySpotFacilitiesCovered);
      } else {
        await prefs.setBool(_keySpotFacilitiesCovered, _spotFacilitiesCovered!);
      }
      if (_spotFacilitiesLighting == null) {
        await prefs.remove(_keySpotFacilitiesLighting);
      } else {
        await prefs.setBool(_keySpotFacilitiesLighting, _spotFacilitiesLighting!);
      }
      if (_spotFacilitiesWaterTap == null) {
        await prefs.remove(_keySpotFacilitiesWaterTap);
      } else {
        await prefs.setBool(_keySpotFacilitiesWaterTap, _spotFacilitiesWaterTap!);
      }
      if (_spotFacilitiesToilet == null) {
        await prefs.remove(_keySpotFacilitiesToilet);
      } else {
        await prefs.setBool(_keySpotFacilitiesToilet, _spotFacilitiesToilet!);
      }
      if (_spotFacilitiesParking == null) {
        await prefs.remove(_keySpotFacilitiesParking);
      } else {
        await prefs.setBool(_keySpotFacilitiesParking, _spotFacilitiesParking!);
      }
      if (_goodFor.isEmpty) {
        await prefs.remove(_keyGoodFor);
      } else {
        await prefs.setString(_keyGoodFor, jsonEncode(_goodFor));
      }
      if (_spotFeatures.isEmpty) {
        await prefs.remove(_keySpotFeatures);
      } else {
        await prefs.setString(_keySpotFeatures, jsonEncode(_spotFeatures));
      }
      await prefs.setString(_keyAttributeFilterMode, _attributeFilterMode);
    } catch (e) {
      // Ignore SharedPreferences errors
    }
  }

  /// Set the selected spot source filter
  /// null = all sources, "" = native only, string = specific source ID
  Future<void> setSelectedSpotSource(String? spotSource) async {
    _selectedSpotSource = spotSource;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (spotSource == null) {
        await prefs.remove(_keySelectedSpotSource);
      } else {
        await prefs.setString(_keySelectedSpotSource, spotSource);
      }
    } catch (e) {
      // Ignore SharedPreferences errors - settings will not persist but app continues to work
    }
  }

  /// Set selected folders for a specific source (empty list = all folders)
  /// This method is kept for backward compatibility but prefer using toggleFolderForSource
  Future<void> setSelectedFoldersForSource(String sourceId, List<String> folders) async {
    if (folders.isEmpty) {
      _selectedFolders.remove(sourceId);
    } else {
      _selectedFolders[sourceId] = List<String>.from(folders);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final foldersJson = jsonEncode(_selectedFolders.map((key, value) => MapEntry(key, value)));
      await prefs.setString(_keySelectedFolders, foldersJson);
    } catch (e) {
      // Ignore SharedPreferences errors - settings will not persist but app continues to work
    }
  }

  /// Set the selected spot list ID for highlighting (null = no highlighting)
  Future<void> setSelectedListId(String? listId) async {
    _selectedListId = listId;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (listId == null) {
        await prefs.remove(_keySelectedListId);
      } else {
        await prefs.setString(_keySelectedListId, listId);
      }
    } catch (e) {
      // Ignore SharedPreferences errors - settings will not persist but app continues to work
    }
  }

  static List<String> _loadStringListFromPrefs(SharedPreferences prefs, String key) {
    final json = prefs.getString(key);
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return List<String>.from(decoded.map((v) => v.toString()));
      }
    } catch (_) {}
    return [];
  }

  static bool _hasStoredFolderSelections(String? foldersJson) {
    if (foldersJson == null || foldersJson.isEmpty) return false;
    try {
      final decoded = jsonDecode(foldersJson);
      if (decoded is Map<String, dynamic>) {
        return decoded.values.any((value) {
          if (value is List) return value.isNotEmpty;
          if (value is String) return value.isNotEmpty;
          return false;
        });
      }
    } catch (_) {}
    return false;
  }

  /// Save the last known user location
  Future<void> saveLastKnownUserLocation(double lat, double lng) async {
    _lastKnownUserLat = lat;
    _lastKnownUserLng = lng;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyLastKnownUserLat, lat);
      await prefs.setDouble(_keyLastKnownUserLng, lng);
    } catch (e) {
      // Silent fail - persistence is best-effort
    }
  }
}
