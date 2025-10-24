import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Mixin that provides map recentering functionality for spot screens
mixin MapRecenteringMixin<T extends StatefulWidget> on State<T> {
  GoogleMapController? _mapController;

  /// Gets the current map controller
  GoogleMapController? get mapController => _mapController;

  /// Sets the map controller when the map is created
  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Centers the map on the given location with zoom level 16
  void centerMapOnLocation(LatLng location) {
    if (_mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(location, 16));
    }
  }

  /// Centers the map on the given location with a small delay to ensure controller is ready
  void centerMapOnLocationWithDelay(LatLng location) {
    Future.delayed(const Duration(milliseconds: 100), () {
      centerMapOnLocation(location);
    });
  }

  /// Centers the map after the widget is built (useful for initial centering)
  void centerMapAfterBuild(LatLng location) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      centerMapOnLocationWithDelay(location);
    });
  }
}
