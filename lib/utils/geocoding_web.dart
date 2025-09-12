// Web implementation that calls window.geocodePlace defined in web/index.html
import 'dart:async';
import 'dart:js_util' as js_util;
import 'dart:html' as html;
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<LatLng?> geocodePlace(String query) async {
  try {
    final dynamic promise = js_util.callMethod(html.window, 'geocodePlace', [query]);
    final dynamic result = await js_util.promiseToFuture(promise);
    if (result == null) return null;
    final num? lat = js_util.getProperty(result, 'lat');
    final num? lng = js_util.getProperty(result, 'lng');
    if (lat == null || lng == null) return null;
    return LatLng(lat.toDouble(), lng.toDouble());
  } catch (_) {
    return null;
  }
}

