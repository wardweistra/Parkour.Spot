import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchStateService extends ChangeNotifier {
  // Keys for SharedPreferences
  static const String _keyCenterLat = 'search_center_lat';
  static const String _keyCenterLng = 'search_center_lng';
  static const String _keyZoom = 'search_zoom';
  static const String _keyIsSatellite = 'search_is_satellite';
  static const String _keyIncludeWithoutPictures = 'search_include_without_pictures';
  static const String _keyIncludeParkourNative = 'search_include_parkour_native';
  static const String _keyIncludeExternalSources = 'search_include_external_sources';
  static const String _keySelectedExternalSourceIds = 'search_selected_external_source_ids';

  // Backing fields
  double? _centerLat;
  double? _centerLng;
  double? _zoom;
  bool _isSatellite = false;
  bool _includeSpotsWithoutPictures = false; // Default: exclude spots without pictures
  bool _includeParkourNative = true;
  bool _includeExternalSources = true;
  Set<String> _selectedExternalSourceIds = <String>{};

  // Getters
  double? get centerLat => _centerLat;
  double? get centerLng => _centerLng;
  double? get zoom => _zoom;
  bool get isSatellite => _isSatellite;
  bool get includeSpotsWithoutPictures => _includeSpotsWithoutPictures;
  bool get includeParkourNative => _includeParkourNative;
  bool get includeExternalSources => _includeExternalSources;
  Set<String> get selectedExternalSourceIds => _selectedExternalSourceIds;

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _centerLat = prefs.getDouble(_keyCenterLat);
      _centerLng = prefs.getDouble(_keyCenterLng);
      _zoom = prefs.getDouble(_keyZoom);
      _isSatellite = prefs.getBool(_keyIsSatellite) ?? false;
      _includeSpotsWithoutPictures = prefs.getBool(_keyIncludeWithoutPictures) ?? false;
      _includeParkourNative = prefs.getBool(_keyIncludeParkourNative) ?? true;
      _includeExternalSources = prefs.getBool(_keyIncludeExternalSources) ?? true;
      final savedSources = prefs.getStringList(_keySelectedExternalSourceIds);
      if (savedSources != null) {
        _selectedExternalSourceIds = savedSources.toSet();
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
    } catch (e) {}
  }

  Future<void> setIncludeSpotsWithoutPictures(bool value) async {
    _includeSpotsWithoutPictures = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIncludeWithoutPictures, value);
    } catch (e) {}
  }

  Future<void> setIncludeParkourNative(bool value) async {
    _includeParkourNative = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIncludeParkourNative, value);
    } catch (e) {}
  }

  Future<void> setIncludeExternalSources(bool value) async {
    _includeExternalSources = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIncludeExternalSources, value);
    } catch (e) {}
  }

  Future<void> setSelectedExternalSourceIds(Set<String> ids) async {
    _selectedExternalSourceIds = ids;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keySelectedExternalSourceIds, ids.toList());
    } catch (e) {}
  }
}

