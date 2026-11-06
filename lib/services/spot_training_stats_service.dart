import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/spot_training_stats.dart';

/// Reads public `spotTrainingStats/{spotId}` aggregates (Cloud Functions write).
class SpotTrainingStatsService {
  SpotTrainingStatsService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  String? _error;
  String? get error => _error;

  DocumentReference<Map<String, dynamic>> _statsRef(String spotId) {
    return _firestore.collection('spotTrainingStats').doc(spotId);
  }

  /// Live stats for [spotId]. Missing docs emit [SpotTrainingStats.empty].
  Stream<SpotTrainingStats> watchStats(String spotId) {
    final trimmed = spotId.trim();
    if (trimmed.isEmpty) {
      return Stream<SpotTrainingStats>.value(SpotTrainingStats.empty);
    }
    return _statsRef(trimmed).snapshots().map(SpotTrainingStats.fromFirestore);
  }

  /// Admin: rebuild 90-day check-in volume + public recent trainers for all spots.
  Future<Map<String, dynamic>?> recomputeAllSpotTrainingStats() async {
    _error = null;
    try {
      final callable = _functions.httpsCallable(
        'recomputeAllSpotTrainingStats',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      final result = await callable.call();
      final data = result.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e, st) {
      _error = 'Failed to recompute spot training stats: $e';
      debugPrint(
        'SpotTrainingStatsService.recomputeAllSpotTrainingStats error: $e\n$st',
      );
      return null;
    }
  }
}
