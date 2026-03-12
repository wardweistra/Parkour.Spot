import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for Jumpflix integration: fetching video-spot links and triggering imports.
class JumpflixService extends ChangeNotifier {
  static const String _collection = 'spotJumpflixVideos';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Returns Jumpflix video IDs linked to the given spot, or null if none.
  Future<List<int>?> getJumpflixIdsForSpot(String spotId) async {
    final doc = await _firestore.collection(_collection).doc(spotId).get();
    if (!doc.exists || doc.data() == null) return null;
    final ids = doc.data()!['jumpflixIds'];
    if (ids == null || ids is! List) return null;
    return ids
        .map((e) => e is int ? e : (e is num ? e.toInt() : null))
        .whereType<int>()
        .toList();
  }

  /// Triggers the Jumpflix import (admin only). Returns stats on success.
  /// Throws on failure.
  Future<Map<String, dynamic>> runJumpflixImport() async {
    final callable = _functions.httpsCallable(
      'runJumpflixImport',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
    );
    final result = await callable.call();
    final data = result.data as Map<String, dynamic>?;
    if (data == null || data['success'] != true) {
      throw Exception(
        data?['error'] ?? 'Jumpflix import failed',
      );
    }
    return {
      'spotsUpdated': data['spotsUpdated'] as int? ?? 0,
      'spotsRemoved': data['spotsRemoved'] as int? ?? 0,
      'jumpflixVideoCount': data['jumpflixVideoCount'] as int? ?? 0,
    };
  }
}
