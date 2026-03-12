import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Video details from Jumpflix (stored in Firestore jumpflixVideos collection).
class JumpflixVideo {
  const JumpflixVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    this.thumbnailUrl,
  });

  final int id;
  final String title;
  final String description;
  final String url;
  final String? thumbnailUrl;

  factory JumpflixVideo.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return JumpflixVideo(
      id: int.tryParse(doc.id) ?? 0,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      url: d['url'] as String? ?? '',
      thumbnailUrl: d['thumbnailUrl'] as String?,
    );
  }
}

/// Service for Jumpflix integration: fetching video-spot links and triggering imports.
class JumpflixService extends ChangeNotifier {
  static const String _spotCollection = 'spotJumpflixVideos';
  static const String _videosCollection = 'jumpflixVideos';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  /// Returns Jumpflix video IDs linked to the given spot, or null if none.
  Future<List<int>?> getJumpflixIdsForSpot(String spotId) async {
    final doc = await _firestore.collection(_spotCollection).doc(spotId).get();
    if (!doc.exists || doc.data() == null) return null;
    final ids = doc.data()!['jumpflixIds'];
    if (ids == null || ids is! List) return null;
    return ids
        .map((e) => e is int ? e : (e is num ? e.toInt() : null))
        .whereType<int>()
        .toList();
  }

  /// Returns details for a single Jumpflix video, or null if not found.
  Future<JumpflixVideo?> getJumpflixVideo(int jumpflixId) async {
    final doc = await _firestore
        .collection(_videosCollection)
        .doc(jumpflixId.toString())
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return JumpflixVideo.fromFirestore(doc);
  }

  /// Returns details for all Jumpflix videos linked to the given spot.
  Future<List<JumpflixVideo>> getJumpflixVideosForSpot(String spotId) async {
    final ids = await getJumpflixIdsForSpot(spotId);
    if (ids == null || ids.isEmpty) return [];
    final videos = <JumpflixVideo>[];
    for (final id in ids) {
      final v = await getJumpflixVideo(id);
      if (v != null) videos.add(v);
    }
    return videos;
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
      'videosStored': data['videosStored'] as int? ?? 0,
    };
  }
}
