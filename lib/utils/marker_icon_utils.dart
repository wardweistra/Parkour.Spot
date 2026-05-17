import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/spot.dart';

/// Utility class for creating custom map marker icons
class MarkerIconUtils {
  /// Teardrop PNG (128×160), transparent — default spot pin on the map.
  static const String mapPinNormalAsset =
      'assets/images/map/map-icon-normal-64x64.png';

  /// Teardrop PNG (128×160), transparent — spot belongs to the active list filter.
  static const String mapPinListAsset =
      'assets/images/map/map-icon-list-64x64.png';

  /// Selected spot (checkmark), when not in the active list filter.
  static const String mapPinNormalSelectedAsset =
      'assets/images/map/map-icon-normal-64x64-selected.png';

  /// Selected spot in the active list filter.
  static const String mapPinListSelectedAsset =
      'assets/images/map/map-icon-list-64x64-selected.png';

  /// Long-press / right-click “add new spot” pin on Explore.
  static const String mapPinAddAsset =
      'assets/images/map/map-icon-normal-64x64-add.png';

  /// Standalone event venue pin on Explore.
  static const String mapPinEventAsset =
      'assets/images/map/map-icon-event-64x64.png';

  /// Selected standalone event venue pin.
  static const String mapPinEventSelectedAsset =
      'assets/images/map/map-icon-event-64x64-selected.png';

  /// Spot with an upcoming event (not selected / not in list filter).
  static const String mapPinSpotEventAsset =
      'assets/images/map/map-icon-spotevent-64x64.png';

  /// Selected spot with an upcoming event.
  static const String mapPinSpotEventSelectedAsset =
      'assets/images/map/map-icon-spotevent-64x64-selected.png';

  /// Source PNG dimensions (filenames say 64×64 but assets are 128×160).
  static const double mapPinAssetWidth = 128;
  static const double mapPinAssetHeight = 160;

  /// Explore and spot-list-detail pins; width follows asset aspect ratio.
  static const double mapPinBrowseLogicalHeight = 34;

  /// Single-spot preview maps (detail, add/edit, picker) and moderator
  /// location-review map.
  static const double mapPinSingleSpotLogicalHeight = 38;

  static double mapPinLogicalWidthForHeight(double logicalHeight) =>
      logicalHeight * mapPinAssetWidth / mapPinAssetHeight;

  static double get mapPinLogicalWidth =>
      mapPinLogicalWidthForHeight(mapPinBrowseLogicalHeight);

  /// North → south draw order: northern spots first, southern spots on top when overlapping.
  static List<Spot> sortSpotsForMapDrawOrder(Iterable<Spot> spots) {
    final List<Spot> ordered = List<Spot>.from(spots);
    ordered.sort((Spot a, Spot b) => b.latitude.compareTo(a.latitude));
    return ordered;
  }

  /// Approximate fill when PNG is missing from the bundle (e.g. stale `build/`).
  static const Color mapPinNormalFallbackFill = Color(0xFF1A237E);
  static const Color mapPinListFallbackFill = Color(0xFFE91E63);
  static const Color mapPinAddFallbackFill = Color(0xFFE53935);
  static const Color mapPinEventFallbackFill = Color(0xFF7B1FA2);
  static const Color mapPinEventSelectedFallbackFill = Color(0xFFE53935);

  /// Selected normal pin for single-spot maps (detail, add/edit, location picker).
  static Future<BitmapDescriptor> loadNormalSelectedMapPin() => loadMapPinPng(
        mapPinNormalSelectedAsset,
        fallbackFill: mapPinNormalFallbackFill,
        logicalHeight: mapPinSingleSpotLogicalHeight,
      );

  /// Loads a marker PNG from the asset bundle.
  ///
  /// Decodes to [BitmapDescriptor.bytes] so Google Maps **web** uses a blob URL
  /// for the marker image (the Maps plugin does not re-fetch the asset URL).
  ///
  /// On web, [rootBundle.load] requests
  /// `{origin}/assets/` + your pubspec path (e.g. `assets/images/...`), which
  /// looks like a doubled `assets/` segment but matches the output of
  /// `flutter build web` under `build/web/assets/assets/...`.
  ///
  /// If the file is missing from the current build (stale incremental build),
  /// uses [createMarkerIcon] so markers are not default Google pins.
  static Future<BitmapDescriptor> loadMapPinPng(
    String assetPath, {
    required Color fallbackFill,
    double? logicalHeight,
  }) async {
    final double height = logicalHeight ?? mapPinBrowseLogicalHeight;
    final double width = mapPinLogicalWidthForHeight(height);
    try {
      final ByteData data = await rootBundle.load(assetPath);
      final Uint8List bytes = data.buffer.asUint8List();
      return BitmapDescriptor.bytes(
        bytes,
        width: width,
        height: height,
        bitmapScaling: MapBitmapScaling.auto,
      );
    } catch (e, stackTrace) {
      debugPrint('loadMapPinPng failed for $assetPath: $e\n$stackTrace');
      return createMarkerIcon(size: 22, fillColor: fallbackFill);
    }
  }

  /// Creates a custom circular marker icon with a white ring and colored fill.
  /// 
  /// [size] - The size of the icon in pixels (default: 22)
  /// [fillColor] - The color of the inner fill circle (default: Colors.black)
  /// 
  /// Returns a [BitmapDescriptor] that can be used for map markers.
  static Future<BitmapDescriptor> createMarkerIcon({
    double size = 22,
    Color fillColor = Colors.black,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final double radius = size / 2;
    final Offset center = Offset(radius, radius);

    final Paint shadowPaint = Paint()..color = Colors.black.withValues(alpha: 0.2);
    final Paint ringPaint = Paint()..color = Colors.white;
    final Paint fillPaint = Paint()..color = fillColor;

    // Calculate proportional border thickness (was 4px for 96px icon, now scales)
    final double borderThickness = size * 4 / 96; // Scale from 4px at 96px size
    final double innerRadius = radius - borderThickness;

    // Shadow circle
    canvas.drawCircle(center, radius, shadowPaint);
    // Outer white ring
    canvas.drawCircle(center, innerRadius, ringPaint);
    // Inner fill
    canvas.drawCircle(center, innerRadius - borderThickness * 2, fillPaint);

    final ui.Image image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.bytes(bytes);
  }

  /// Creates a set of standard spot marker icons used throughout the app.
  /// 
  /// Returns a map with keys: 'default', 'selected', 'highlighted', 'selectedHighlighted'
  static Future<Map<String, BitmapDescriptor>> createSpotMarkerIcons() async {
    return {
      'default': await createMarkerIcon(size: 22, fillColor: Colors.red),
      'selected': await createMarkerIcon(size: 22, fillColor: Color(0xFFFF8A80)),
      'highlighted': await createMarkerIcon(size: 22, fillColor: Colors.black),
      'selectedHighlighted': await createMarkerIcon(size: 22, fillColor: Colors.grey.shade400),
    };
  }

  /// Creates a user location marker icon.
  ///
  /// [size] - The size of the icon in pixels (default: 24)
  /// [fillColor] - The color of the inner fill circle (default: Colors.blue)
  static Future<BitmapDescriptor> createUserLocationIcon({
    double size = 24,
    Color fillColor = Colors.blue,
  }) async {
    return createMarkerIcon(size: size, fillColor: fillColor);
  }

  /// Event venue pin on Explore.
  static Future<BitmapDescriptor> loadEventVenueMapPin({
    double? logicalHeight,
  }) =>
      loadMapPinPng(
        mapPinEventAsset,
        fallbackFill: mapPinEventFallbackFill,
        logicalHeight: logicalHeight,
      );

  /// Selected event venue pin on Explore.
  static Future<BitmapDescriptor> loadEventVenueSelectedMapPin({
    double? logicalHeight,
  }) =>
      loadMapPinPng(
        mapPinEventSelectedAsset,
        fallbackFill: mapPinEventSelectedFallbackFill,
        logicalHeight: logicalHeight,
      );

  /// Spot with an upcoming event on Explore.
  static Future<BitmapDescriptor> loadSpotEventMapPin({
    double? logicalHeight,
  }) =>
      loadMapPinPng(
        mapPinSpotEventAsset,
        fallbackFill: mapPinEventFallbackFill,
        logicalHeight: logicalHeight,
      );

  /// Selected spot with an upcoming event on Explore.
  static Future<BitmapDescriptor> loadSpotEventSelectedMapPin({
    double? logicalHeight,
  }) =>
      loadMapPinPng(
        mapPinSpotEventSelectedAsset,
        fallbackFill: mapPinEventSelectedFallbackFill,
        logicalHeight: logicalHeight,
      );
}

