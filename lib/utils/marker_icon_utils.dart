import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Utility class for creating custom map marker icons
class MarkerIconUtils {
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
}

