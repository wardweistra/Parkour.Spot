import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SearchStateService extends ChangeNotifier {
  // Keys for SharedPreferences
  static const String _keyCenterLat = 'search_center_lat';
  static const String _keyCenterLng = 'search_center_lng';
  static const String _keyZoom = 'search_zoom';
  static const String _keyIsSatellite = 'search_is_satellite';
  static const String _keyIncludeWithoutPictures = 'search_include_without_pictures';
  static const String _keySelectedSpotSource = 'search_selected_spot_source'; // null = all, "" = native, string = specific source
  static const String _keySelectedFolders = 'search_selected_folders'; // JSON map of sourceId -> List<String> (multiple folders, empty list = all folders)
  static const String _keySelectedListId = 'search_selected_list_id'; // Selected spot list ID for highlighting
  static const String _keyLastKnownUserLat = 'search_last_known_user_lat';
  static const String _keyLastKnownUserLng = 'search_last_known_user_lng';

  // Backing fields
  double? _centerLat;
  double? _centerLng;
  double? _zoom;
  bool _isSatellite = false;
  bool _includeSpotsWithoutPictures = true; // Default: include spots without pictures
  String? _selectedSpotSource; // null = all sources, "" = native only, string = specific source ID
  Map<String, List<String>> _selectedFolders = {}; // sourceId -> list of selected folder names (empty list = all folders)
  String? _selectedListId; // Selected spot list ID for highlighting
  double? _lastKnownUserLat;
  double? _lastKnownUserLng;

  // Getters
  double? get centerLat => _centerLat;
  double? get centerLng => _centerLng;
  double? get zoom => _zoom;
  bool get isSatellite => _isSatellite;
  bool get includeSpotsWithoutPictures => _includeSpotsWithoutPictures;
  String? get selectedSpotSource => _selectedSpotSource;
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
      _includeSpotsWithoutPictures = prefs.getBool(_keyIncludeWithoutPictures) ?? true;
      _selectedSpotSource = prefs.getString(_keySelectedSpotSource); // null if not set (all sources)
      _selectedListId = prefs.getString(_keySelectedListId); // null if not set
      _lastKnownUserLat = prefs.getDouble(_keyLastKnownUserLat);
      _lastKnownUserLng = prefs.getDouble(_keyLastKnownUserLng);
      
      // Load selected folders (migrate from old format if needed)
      final foldersJson = prefs.getString(_keySelectedFolders);
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

  Future<void> setIncludeSpotsWithoutPictures(bool value) async {
    _includeSpotsWithoutPictures = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIncludeWithoutPictures, value);
    } catch (e) {
      // Ignore SharedPreferences errors - settings will not persist but app continues to work
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

