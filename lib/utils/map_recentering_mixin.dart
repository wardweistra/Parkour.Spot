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
    onMapControllerReady();
  }

  /// Called after [onMapCreated] once [mapController] is available.
  void onMapControllerReady() {}

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

  /// Fits the map camera to show all [locations] with padding.
  void fitMapToLocations(List<LatLng> locations) {
    if (_mapController == null || locations.isEmpty) return;

    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final location in locations) {
      if (location.latitude < minLat) minLat = location.latitude;
      if (location.latitude > maxLat) maxLat = location.latitude;
      if (location.longitude < minLng) minLng = location.longitude;
      if (location.longitude > maxLng) maxLng = location.longitude;
    }

    final latMargin = (maxLat - minLat) * 0.05;
    final lngMargin = (maxLng - minLng) * 0.05;

    if (latMargin == 0) {
      minLat -= 0.01;
      maxLat += 0.01;
    } else {
      minLat -= latMargin;
      maxLat += latMargin;
    }

    if (lngMargin == 0) {
      minLng -= 0.01;
      maxLng += 0.01;
    } else {
      minLng -= lngMargin;
      maxLng += lngMargin;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  void fitMapToLocationsWithDelay(List<LatLng> locations) {
    Future.delayed(const Duration(milliseconds: 100), () {
      fitMapToLocations(locations);
    });
  }

  /// Centers on one point or fits bounds when multiple markers should be visible.
  void recenterMapForLocations(List<LatLng> locations) {
    if (locations.isEmpty) return;
    if (locations.length == 1) {
      centerMapOnLocationWithDelay(locations.first);
      return;
    }
    fitMapToLocationsWithDelay(locations);
  }

  void recenterMapForLocationsAfterBuild(List<LatLng> locations) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      recenterMapForLocations(locations);
    });
  }
}
