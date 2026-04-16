import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/location_of_interest.dart';
import 'auth_service.dart';

class UserLocationsOfInterestService extends ChangeNotifier {
  UserLocationsOfInterestService(this._authService);

  final AuthService _authService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _error;
  bool _isLoading = false;
  DateTime? _lastKnownUpsertAttemptAt;

  String? get error => _error;
  bool get isLoading => _isLoading;

  String? get _uid => _authService.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _locationsCollection {
    final uid = _uid;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('locationsOfInterest');
  }

  Stream<List<LocationOfInterest>> watchLocations() {
    final collection = _locationsCollection;
    if (collection == null) {
      return Stream<List<LocationOfInterest>>.value(const []);
    }
    return collection.orderBy('updatedAt', descending: true).snapshots().map((
      snapshot,
    ) {
      final items = snapshot.docs
          .map(LocationOfInterest.fromFirestore)
          .toList(growable: false);
      items.sort((a, b) {
        if (a.kind != b.kind) {
          if (a.kind == LocationOfInterestKind.lastKnown) return -1;
          if (b.kind == LocationOfInterestKind.lastKnown) return 1;
        }
        final aAt = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bAt.compareTo(aAt);
      });
      return items;
    });
  }

  Future<bool> upsertLastKnownLocation({
    required double latitude,
    required double longitude,
    bool enabled = true,
    Duration minUpdateInterval = const Duration(minutes: 15),
  }) async {
    final lastAttempt = _lastKnownUpsertAttemptAt;
    if (lastAttempt != null &&
        DateTime.now().difference(lastAttempt) < minUpdateInterval) {
      return true;
    }
    return _runWrite(() async {
      final uid = _uid;
      final collection = _locationsCollection;
      if (uid == null || collection == null) {
        throw StateError('Not authenticated');
      }
      _validateCoordinates(latitude, longitude);
      await collection.doc('lastKnown').set({
        'userId': uid,
        'latitude': latitude,
        'longitude': longitude,
        'kind': LocationOfInterestKind.lastKnown.name,
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _lastKnownUpsertAttemptAt = DateTime.now();
    });
  }

  Future<bool> setLastKnownEnabled(bool enabled) async {
    return _runWrite(() async {
      final collection = _locationsCollection;
      if (collection == null) {
        throw StateError('Not authenticated');
      }
      if (!enabled) {
        try {
          await collection.doc('lastKnown').delete();
        } on FirebaseException catch (e) {
          if (e.code != 'not-found') {
            rethrow;
          }
        }
        return;
      }
      try {
        await collection.doc('lastKnown').update({
          'enabled': enabled,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e) {
        if (e.code != 'not-found') {
          rethrow;
        }
      }
    });
  }

  Future<bool> addSavedLocation({
    required String label,
    required double latitude,
    required double longitude,
    bool enabled = true,
    String? address,
  }) async {
    return _runWrite(() async {
      final uid = _uid;
      final collection = _locationsCollection;
      if (uid == null || collection == null) {
        throw StateError('Not authenticated');
      }
      _validateCoordinates(latitude, longitude);
      final normalizedLabel = _normalizeLabel(label);
      final trimmedAddress = address?.trim();
      await collection.add({
        'userId': uid,
        'latitude': latitude,
        'longitude': longitude,
        'kind': LocationOfInterestKind.saved.name,
        'enabled': enabled,
        'label': normalizedLabel,
        if (trimmedAddress != null && trimmedAddress.isNotEmpty)
          'address': trimmedAddress,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<bool> updateSavedLocation({
    required String id,
    required String label,
    required double latitude,
    required double longitude,
    required bool enabled,
    String? address,
  }) async {
    return _runWrite(() async {
      final uid = _uid;
      final collection = _locationsCollection;
      if (uid == null || collection == null) {
        throw StateError('Not authenticated');
      }
      _validateCoordinates(latitude, longitude);
      final normalizedLabel = _normalizeLabel(label);
      final trimmed = address?.trim();
      await collection.doc(id).update({
        'userId': uid,
        'latitude': latitude,
        'longitude': longitude,
        'kind': LocationOfInterestKind.saved.name,
        'enabled': enabled,
        'label': normalizedLabel,
        'address': trimmed == null || trimmed.isEmpty
            ? FieldValue.delete()
            : trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<bool> setLocationEnabled({
    required String id,
    required bool enabled,
  }) async {
    return _runWrite(() async {
      final collection = _locationsCollection;
      if (collection == null) {
        throw StateError('Not authenticated');
      }
      await collection.doc(id).update({
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<bool> deleteSavedLocation(String id) async {
    if (id == 'lastKnown') return false;
    return _runWrite(() async {
      final collection = _locationsCollection;
      if (collection == null) {
        throw StateError('Not authenticated');
      }
      await collection.doc(id).delete();
    });
  }

  Future<bool> _runWrite(Future<void> Function() operation) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      await operation();
      return true;
    } catch (e) {
      _error = 'Failed to update locations of interest: $e';
      debugPrint(_error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _validateCoordinates(double latitude, double longitude) {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(
        latitude,
        'latitude',
        'Must be a finite value between -90 and 90',
      );
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Must be a finite value between -180 and 180',
      );
    }
  }

  String _normalizeLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(label, 'label', 'Label must not be empty');
    }
    if (trimmed.length > 80) {
      throw ArgumentError.value(
        label,
        'label',
        'Label must be 80 characters or fewer',
      );
    }
    return trimmed;
  }
}
