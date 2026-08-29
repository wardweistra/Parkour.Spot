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
    return collection.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map(LocationOfInterest.fromFirestore)
          .toList();
      items.sort(LocationOfInterest.compareForDisplay);
      return List<LocationOfInterest>.unmodifiable(items);
    });
  }

  Future<bool> upsertLastKnownLocation({
    required double latitude,
    required double longitude,
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
      // Omit alertRadiusKm and enabled so GPS refresh keeps a custom radius
      // and a muted bell. First create writes enabled: true (query requires it).
      final ref = collection.doc('lastKnown');
      final existing = await ref.get();
      final data = <String, dynamic>{
        'userId': uid,
        'latitude': latitude,
        'longitude': longitude,
        'kind': LocationOfInterestKind.lastKnown.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!existing.exists) {
        data['enabled'] = true;
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await ref.set(data, SetOptions(merge: true));
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
    int alertRadiusKm = LocationOfInterest.defaultAlertRadiusKm,
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
        'alertRadiusKm': LocationOfInterest.normalizeAlertRadiusKm(
          alertRadiusKm,
        ),
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
    int alertRadiusKm = LocationOfInterest.defaultAlertRadiusKm,
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
        'alertRadiusKm': LocationOfInterest.normalizeAlertRadiusKm(
          alertRadiusKm,
        ),
        'label': normalizedLabel,
        'address': trimmed == null || trimmed.isEmpty
            ? FieldValue.delete()
            : trimmed,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<bool> setLastKnownAlertRadius(int alertRadiusKm) async {
    return _runWrite(() async {
      final collection = _locationsCollection;
      if (collection == null) {
        throw StateError('Not authenticated');
      }
      await collection.doc('lastKnown').update({
        'alertRadiusKm': LocationOfInterest.normalizeAlertRadiusKm(
          alertRadiusKm,
        ),
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
      await collection.doc(id).update({'enabled': enabled});
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
