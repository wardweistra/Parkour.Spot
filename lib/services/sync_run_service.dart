import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/sync_run.dart';

/// Fetches durable sync-run reports (admin-only Firestore reads).
class SyncRunService {
  SyncRunService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<SyncRun?> fetchById(String runId) async {
    final trimmed = runId.trim();
    if (trimmed.isEmpty) return null;
    try {
      final snap = await _firestore.collection('syncRuns').doc(trimmed).get();
      if (!snap.exists) return null;
      return SyncRun.fromFirestore(snap);
    } catch (e) {
      debugPrint('SyncRunService.fetchById error: $e');
      rethrow;
    }
  }
}
