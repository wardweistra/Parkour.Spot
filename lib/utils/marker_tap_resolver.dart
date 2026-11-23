import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Picks the marker the user most plausibly aimed at on native Android.
///
/// The Android Maps SDK hit-tests markers against an enlarged rectangle around
/// each icon and lets the top-most (southern, in our draw order) one win. In a
/// cluster, a tap slightly below/left of the intended pin head therefore often
/// lands on a neighbour. Web markers are DOM elements and are hit-tested
/// precisely, so this resolver is a no-op there.
///
/// Usage: call [recordPointerDown] from a translucent [Listener] over the map,
/// then pass every marker tap through [resolve] before acting on it.
class MarkerTapResolver {
  MarkerTapResolver({
    required this.pinHeightDp,
    this.maxPointerAge = const Duration(milliseconds: 1500),
  });

  /// Rendered pin height in logical pixels (anchor at bottom-centre).
  final double pinHeightDp;

  final Duration maxPointerAge;

  /// The round head of our teardrop pins is centred at 36% of the height.
  static const double _headCentreFromTop = 57.5 / 160;

  /// Max distance between tapped marker and a candidate to bother projecting,
  /// in logical pixels. Larger than any plausible SDK hit-box overlap.
  static const double _candidateRadiusDp = 120;

  static bool get isNeeded =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Offset? _lastDown;
  DateTime? _lastDownAt;

  /// [localPosition] is the pointer position relative to the map widget.
  void recordPointerDown(Offset localPosition) {
    _lastDown = localPosition;
    _lastDownAt = DateTime.now();
  }

  double get _headAboveTipDp => pinHeightDp * (1 - _headCentreFromTop);

  /// Returns the id of the marker whose pin head is closest to the last
  /// pointer-down, choosing among [positions] near [tappedId]. Falls back to
  /// [tappedId] when there is no recent pointer or projection fails.
  Future<String> resolve({
    required String tappedId,
    required Map<String, LatLng> positions,
    required GoogleMapController controller,
    required double devicePixelRatio,
  }) async {
    final down = _lastDown;
    final downAt = _lastDownAt;
    final tappedPos = positions[tappedId];
    if (!isNeeded ||
        down == null ||
        downAt == null ||
        tappedPos == null ||
        DateTime.now().difference(downAt) > maxPointerAge) {
      return tappedId;
    }
    try {
      final zoom = await controller.getZoomLevel();
      final metersPerDp =
          156543.03392 *
          math.cos(tappedPos.latitude * math.pi / 180) /
          math.pow(2, zoom);
      final maxMeters = _candidateRadiusDp * metersPerDp;

      String best = tappedId;
      double bestDist = double.infinity;
      for (final entry in positions.entries) {
        if (entry.key != tappedId &&
            _approxMeters(tappedPos, entry.value) > maxMeters) {
          continue;
        }
        // Android returns physical pixels relative to the map view.
        final sc = await controller.getScreenCoordinate(entry.value);
        final head = Offset(
          sc.x / devicePixelRatio,
          sc.y / devicePixelRatio - _headAboveTipDp,
        );
        final d = (head - down).distance;
        if (d < bestDist) {
          bestDist = d;
          best = entry.key;
        }
      }
      return best;
    } catch (e) {
      debugPrint('MarkerTapResolver: falling back to tapped marker: $e');
      return tappedId;
    }
  }

  static double _approxMeters(LatLng a, LatLng b) {
    const r = 6371000.0;
    final lat = (a.latitude + b.latitude) / 2 * math.pi / 180;
    final dx = (b.longitude - a.longitude) * math.pi / 180 * math.cos(lat);
    final dy = (b.latitude - a.latitude) * math.pi / 180;
    return r * math.sqrt(dx * dx + dy * dy);
  }
}
