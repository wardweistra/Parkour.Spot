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
  static const String _keySelectedFolders = 'search_selected_folders'; // JSON map of sourceId -> String (single folder)

  // Backing fields
  double? _centerLat;
  double? _centerLng;
  double? _zoom;
  bool _isSatellite = false;
  bool _includeSpotsWithoutPictures = true; // Default: include spots without pictures
  String? _selectedSpotSource; // null = all sources, "" = native only, string = specific source ID
  Map<String, String?> _selectedFolders = {}; // sourceId -> selected folder name (null = all folders)

  // Getters
  double? get centerLat => _centerLat;
  double? get centerLng => _centerLng;
  double? get zoom => _zoom;
  bool get isSatellite => _isSatellite;
  bool get includeSpotsWithoutPictures => _includeSpotsWithoutPictures;
  String? get selectedSpotSource => _selectedSpotSource;
  Map<String, String?> get selectedFolders => Map.unmodifiable(_selectedFolders);
  
  /// Get selected folder for a specific source (null = all folders)
  String? getSelectedFolderForSource(String sourceId) {
    return _selectedFolders[sourceId];
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
      
      // Load selected folders (migrate from old format if needed)
      final foldersJson = prefs.getString(_keySelectedFolders);
      if (foldersJson != null) {
        try {
          final decoded = jsonDecode(foldersJson) as Map<String, dynamic>;
          _selectedFolders = decoded.map((key, value) {
            // Handle migration from old List format to new String? format
            if (value is List && value.isNotEmpty) {
              // Take first folder from old list format
              return MapEntry(key, value[0] as String?);
            } else if (value is String) {
              return MapEntry(key, value);
            } else {
              return MapEntry(key, null);
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

  /// Set selected folder for a specific source (null = all folders)
  Future<void> setSelectedFolderForSource(String sourceId, String? folder) async {
    if (folder == null) {
      _selectedFolders.remove(sourceId);
    } else {
      _selectedFolders[sourceId] = folder;
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final foldersJson = jsonEncode(_selectedFolders);
      await prefs.setString(_keySelectedFolders, foldersJson);
    } catch (e) {
      // Ignore SharedPreferences errors - settings will not persist but app continues to work
    }
  }
}

