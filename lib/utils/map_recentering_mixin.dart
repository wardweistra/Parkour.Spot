import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Mixin that provides map recentering functionality for spot screens
mixin MapRecenteringMixin<T extends StatefulWidget> on State<T> {
  GoogleMapController? _mapController;
  LatLng? _pendingCenter;
  int _centerGeneration = 0;

  /// Gets the current map controller
  GoogleMapController? get mapController => _mapController;

  /// Sets the map controller when the map is created
  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    final pending = _pendingCenter;
    if (pending != null) {
      _pendingCenter = null;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(pending, 16),
      );
    }
    onMapControllerReady();
  }

  /// Called after [onMapCreated] once [mapController] is available.
  void onMapControllerReady() {}

  /// Centers the map on the given location with zoom level 16.
  ///
  /// If the controller is not ready yet, the location is queued and applied
  /// when [onMapCreated] runs. Newer center requests invalidate older delayed
  /// ones so a late automatic GPS fix is not overwritten by an earlier default
  /// recenter.
  void centerMapOnLocation(LatLng location) {
    _requestCenter(location, delay: Duration.zero);
  }

  /// Centers the map on the given location with a small delay to ensure controller is ready
  void centerMapOnLocationWithDelay(LatLng location) {
    _requestCenter(location, delay: const Duration(milliseconds: 100));
  }

  /// Centers the map after the widget is built (useful for initial centering)
  void centerMapAfterBuild(LatLng location) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      centerMapOnLocationWithDelay(location);
    });
  }

  void _requestCenter(LatLng location, {required Duration delay}) {
    final generation = ++_centerGeneration;
    if (delay == Duration.zero) {
      _applyCenterIfCurrent(location, generation);
      return;
    }
    Future.delayed(delay, () {
      _applyCenterIfCurrent(location, generation);
    });
  }

  void _applyCenterIfCurrent(LatLng location, int generation) {
    if (!mounted || generation != _centerGeneration) return;
    if (_mapController != null) {
      _pendingCenter = null;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(location, 16),
      );
    } else {
      _pendingCenter = location;
    }
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
