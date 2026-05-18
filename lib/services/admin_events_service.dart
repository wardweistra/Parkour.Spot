import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/parkour_event.dart';
import '../utils/image_preparation.dart';

class AdminEventsService extends ChangeNotifier {
  AdminEventsService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  final List<ParkourEvent> _events = <ParkourEvent>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastEventDocument;
  bool _hasMore = true;

  static const int _defaultPageSize = 30;
  static const int maxSpotListIds = 10;

  List<ParkourEvent> get events => List<ParkourEvent>.unmodifiable(_events);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> fetchEvents({
    bool forceRefresh = false,
    int pageSize = _defaultPageSize,
  }) async {
    if (_isLoading && !forceRefresh) return;

    _isLoading = true;
    _isLoadingMore = false;
    _error = null;
    if (forceRefresh) {
      _events.clear();
      _lastEventDocument = null;
      _hasMore = true;
    }
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('events')
          .orderBy('startAt', descending: true)
          .limit(pageSize)
          .get();
      _applyPage(snapshot, pageSize, replaceExisting: true);
    } catch (e, st) {
      _error = 'Failed to load events';
      debugPrint('AdminEventsService.fetchEvents error: $e\n$st');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore({int pageSize = _defaultPageSize}) async {
    if (!_hasMore ||
        _isLoading ||
        _isLoadingMore ||
        _lastEventDocument == null) {
      return;
    }

    _isLoadingMore = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore
          .collection('events')
          .orderBy('startAt', descending: true)
          .startAfterDocument(_lastEventDocument!)
          .limit(pageSize)
          .get();
      _applyPage(snapshot, pageSize, replaceExisting: false);
    } catch (e, st) {
      _error = 'Failed to load more events';
      debugPrint('AdminEventsService.loadMore error: $e\n$st');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<bool> createEvent({
    required String title,
    String? description,
    List<String>? imageUrls,
    String? websiteUrl,
    required DateTime startAt,
    DateTime? endAt,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? countryCode,
    required List<String> spotIds,
    List<String> spotListIds = const <String>[],
    required String createdBy,
  }) async {
    final normalized = _normalizeEventInput(
      title: title,
      description: description,
      imageUrls: imageUrls,
      websiteUrl: websiteUrl,
      address: address,
      spotIds: spotIds,
      spotListIds: spotListIds,
      startAt: startAt,
      endAt: endAt,
      latitude: latitude,
      longitude: longitude,
      city: city,
      countryCode: countryCode,
    );
    if (normalized.error != null) {
      _error = normalized.error;
      notifyListeners();
      return false;
    }

    final listError = await validateSpotListIdsForLinking(
      normalized.spotListIds,
    );
    if (listError != null) {
      _error = listError;
      notifyListeners();
      return false;
    }

    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now().toUtc();
      final event = ParkourEvent(
        title: normalized.title,
        description: normalized.description,
        imageUrls: normalized.imageUrls,
        websiteUrl: normalized.websiteUrl,
        startAt: normalized.startAt,
        endAt: normalized.endAt,
        latitude: normalized.latitude,
        longitude: normalized.longitude,
        address: normalized.address,
        city: normalized.city,
        countryCode: normalized.countryCode,
        spotIds: normalized.spotIds,
        spotListIds: normalized.spotListIds,
        createdBy: createdBy,
        createdAt: now,
        updatedAt: now,
      );
      final ref = await _firestore
          .collection('events')
          .add(event.toFirestore());
      _events.insert(0, event.copyWith(id: ref.id));
      _events.sort((a, b) => b.startAt.compareTo(a.startAt));
      notifyListeners();
      return true;
    } catch (e, st) {
      _error = 'Failed to create event';
      debugPrint('AdminEventsService.createEvent error: $e\n$st');
      notifyListeners();
      return false;
    }
  }

  /// Creates a native parkour.spot event by copying data from an external/imported event.
  /// Returns the new document id, or null on failure.
  Future<String?> createNativeEventFromExisting(
    ParkourEvent sourceEvent,
    String createdBy,
  ) async {
    if (sourceEvent.isNativeEvent) {
      _error = 'Source event is already a native parkour.spot event';
      notifyListeners();
      return null;
    }

    final normalized = _normalizeEventInput(
      title: sourceEvent.title,
      description: sourceEvent.description,
      imageUrls: sourceEvent.imageUrls,
      websiteUrl: sourceEvent.websiteUrl,
      address: sourceEvent.address,
      spotIds: sourceEvent.spotIds,
      spotListIds: sourceEvent.spotListIds,
      startAt: sourceEvent.startAt,
      endAt: sourceEvent.endAt,
      latitude: sourceEvent.latitude,
      longitude: sourceEvent.longitude,
      city: sourceEvent.city,
      countryCode: sourceEvent.countryCode,
    );
    if (normalized.error != null) {
      _error = normalized.error;
      notifyListeners();
      return null;
    }

    final listError = await validateSpotListIdsForLinking(
      normalized.spotListIds,
    );
    if (listError != null) {
      _error = listError;
      notifyListeners();
      return null;
    }

    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now().toUtc();
      final nativeEvent = ParkourEvent(
        title: normalized.title,
        description: normalized.description,
        imageUrls: normalized.imageUrls,
        websiteUrl: normalized.websiteUrl,
        startAt: normalized.startAt,
        endAt: normalized.endAt,
        latitude: normalized.latitude,
        longitude: normalized.longitude,
        address: normalized.address,
        city: normalized.city,
        countryCode: normalized.countryCode,
        spotIds: normalized.spotIds,
        spotListIds: normalized.spotListIds,
        createdBy: createdBy,
        createdAt: now,
        updatedAt: now,
        duplicateOf: null,
        createdFromCreateNative: true,
      );
      final ref = await _firestore
          .collection('events')
          .add(nativeEvent.toFirestore());
      notifyListeners();
      return ref.id;
    } catch (e, st) {
      _error = 'Failed to create native event';
      debugPrint(
        'AdminEventsService.createNativeEventFromExisting error: $e\n$st',
      );
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateEvent({
    required String eventId,
    required String title,
    String? description,
    List<String>? imageUrls,
    String? websiteUrl,
    required DateTime startAt,
    DateTime? endAt,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? countryCode,
    required List<String> spotIds,
    List<String> spotListIds = const <String>[],
  }) async {
    final trimmedId = eventId.trim();
    if (trimmedId.isEmpty) {
      _error = 'Invalid event id';
      notifyListeners();
      return false;
    }

    final existingSnap = await _firestore
        .collection('events')
        .doc(trimmedId)
        .get();
    if (!existingSnap.exists) {
      _error = 'Event not found';
      notifyListeners();
      return false;
    }
    final existing = ParkourEvent.fromFirestore(existingSnap);

    final normalized = _normalizeEventInput(
      title: title,
      description: description,
      imageUrls: imageUrls,
      websiteUrl: websiteUrl,
      address: address,
      spotIds: spotIds,
      spotListIds: spotListIds,
      startAt: startAt,
      endAt: endAt,
      latitude: latitude,
      longitude: longitude,
      city: city,
      countryCode: countryCode,
    );
    if (normalized.error != null) {
      _error = normalized.error;
      notifyListeners();
      return false;
    }

    final listError = await validateSpotListIdsForLinking(
      normalized.spotListIds,
    );
    if (listError != null) {
      _error = listError;
      notifyListeners();
      return false;
    }

    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now().toUtc();
      final updated = existing.copyWith(
        title: normalized.title,
        description: normalized.description,
        imageUrls: normalized.imageUrls,
        websiteUrl: normalized.websiteUrl,
        startAt: normalized.startAt,
        endAt: normalized.endAt,
        latitude: normalized.latitude,
        longitude: normalized.longitude,
        address: normalized.address,
        city: normalized.city,
        countryCode: normalized.countryCode,
        spotIds: normalized.spotIds,
        spotListIds: normalized.spotListIds,
        updatedAt: now,
      );
      await _firestore
          .collection('events')
          .doc(trimmedId)
          .update(updated.toFirestore());

      final index = _events.indexWhere((e) => e.id == trimmedId);
      if (index >= 0) {
        _events[index] = updated.copyWith(id: trimmedId);
        _events.sort((a, b) => b.startAt.compareTo(a.startAt));
      }
      notifyListeners();
      return true;
    } catch (e, st) {
      _error = 'Failed to update event';
      debugPrint('AdminEventsService.updateEvent error: $e\n$st');
      notifyListeners();
      return false;
    }
  }

  /// Returns an error message when any list is missing or not linkable (public/unlisted).
  Future<String?> validateSpotListIdsForLinking(List<String> listIds) async {
    for (final listId in listIds) {
      final doc = await _firestore.collection('spotLists').doc(listId).get();
      if (!doc.exists) {
        return 'Spot list not found: $listId';
      }
      final data = doc.data();
      final visibility = data?['visibility'] as String?;
      if (visibility == 'private') {
        return 'Private spot lists cannot be linked to events';
      }
    }
    return null;
  }

  Future<List<String>> uploadEventImages(List<Uint8List> imageBytesList) async {
    final callable = _functions.httpsCallable('uploadEventImage');
    final imageUrls = <String>[];
    for (var index = 0; index < imageBytesList.length; index++) {
      final prepared = await prepareImageForUpload(imageBytesList[index]);
      final result = await callable.call<Map<String, dynamic>>({
        'imageData': base64Encode(prepared.bytes),
        'contentType': prepared.contentType,
        'index': index,
      });
      final data = result.data;
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Upload failed');
      }
      final url = data['imageUrl'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception('Upload returned no image URL');
      }
      imageUrls.add(url);
    }
    return imageUrls;
  }

  Future<ParkourEvent?> getEventById(String eventId) async {
    try {
      final doc = await _firestore.collection('events').doc(eventId).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return ParkourEvent.fromFirestore(doc);
    } catch (e, st) {
      debugPrint('AdminEventsService.getEventById error: $e\n$st');
      return null;
    }
  }

  Future<ParkourEvent?> getNextUpcomingEventForSpot(String spotId) async {
    try {
      final now = DateTime.now().toUtc();
      final snapshot = await _firestore
          .collection('events')
          .where('spotIds', arrayContains: spotId)
          .limit(100)
          .get();
      final events = <ParkourEvent>[];
      for (final doc in snapshot.docs) {
        try {
          final event = ParkourEvent.fromFirestore(doc);
          if (event.duplicateOf != null &&
              event.duplicateOf!.trim().isNotEmpty) {
            continue;
          }
          if (event.startAt.toUtc().isAfter(now)) {
            events.add(event);
          }
        } catch (e) {
          debugPrint(
            'AdminEventsService.getNextUpcomingEventForSpot skipping malformed event ${doc.id}: $e',
          );
        }
      }
      events.sort((a, b) => a.startAt.compareTo(b.startAt));
      if (events.isEmpty) return null;
      return events.first;
    } catch (e, st) {
      debugPrint(
        'AdminEventsService.getNextUpcomingEventForSpot error: $e\n$st',
      );
      return null;
    }
  }

  void _applyPage(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    int pageSize, {
    required bool replaceExisting,
  }) {
    final docs = snapshot.docs;
    if (replaceExisting) {
      _events.clear();
    }
    for (final doc in docs) {
      _events.add(ParkourEvent.fromFirestore(doc));
    }
    if (replaceExisting) {
      _lastEventDocument = docs.isNotEmpty ? docs.last : null;
      _hasMore = docs.length >= pageSize;
      return;
    }
    if (docs.isEmpty) {
      _hasMore = false;
      return;
    }
    _lastEventDocument = docs.last;
    _hasMore = docs.length >= pageSize;
  }

  ({
    String? error,
    String title,
    String? description,
    List<String> imageUrls,
    String? websiteUrl,
    DateTime startAt,
    DateTime? endAt,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? countryCode,
    List<String> spotIds,
    List<String> spotListIds,
  })
  _normalizeEventInput({
    required String title,
    String? description,
    List<String>? imageUrls,
    String? websiteUrl,
    required DateTime startAt,
    DateTime? endAt,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? countryCode,
    required List<String> spotIds,
    required List<String> spotListIds,
  }) {
    final normalizedImageUrls = (imageUrls ?? const <String>[])
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    final normalizedWebsiteUrl = websiteUrl?.trim();
    final normalizedAddress = address?.trim();
    final normalizedCity = city?.trim();
    final normalizedCountryCode = countryCode?.trim().toUpperCase();
    final normalizedSpotIds = spotIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final normalizedSpotListIds = spotListIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (title.trim().isEmpty) {
      return (
        error: 'Title is required',
        title: '',
        description: null,
        imageUrls: const <String>[],
        websiteUrl: null,
        startAt: startAt.toUtc(),
        endAt: null,
        latitude: null,
        longitude: null,
        address: null,
        city: null,
        countryCode: null,
        spotIds: const <String>[],
        spotListIds: const <String>[],
      );
    }
    if (normalizedSpotListIds.length > maxSpotListIds) {
      return (
        error: 'At most $maxSpotListIds spot lists can be linked',
        title: '',
        description: null,
        imageUrls: const <String>[],
        websiteUrl: null,
        startAt: startAt.toUtc(),
        endAt: null,
        latitude: null,
        longitude: null,
        address: null,
        city: null,
        countryCode: null,
        spotIds: const <String>[],
        spotListIds: const <String>[],
      );
    }
    if (normalizedWebsiteUrl != null &&
        normalizedWebsiteUrl.isNotEmpty &&
        !_isValidHttpUrl(normalizedWebsiteUrl)) {
      return (
        error: 'Website URL must be a valid http(s) link',
        title: '',
        description: null,
        imageUrls: const <String>[],
        websiteUrl: null,
        startAt: startAt.toUtc(),
        endAt: null,
        latitude: null,
        longitude: null,
        address: null,
        city: null,
        countryCode: null,
        spotIds: const <String>[],
        spotListIds: const <String>[],
      );
    }
    final hasLatitude = latitude != null;
    final hasLongitude = longitude != null;
    if (hasLatitude != hasLongitude) {
      return (
        error: 'Both latitude and longitude are required for event location',
        title: '',
        description: null,
        imageUrls: const <String>[],
        websiteUrl: null,
        startAt: startAt.toUtc(),
        endAt: null,
        latitude: null,
        longitude: null,
        address: null,
        city: null,
        countryCode: null,
        spotIds: const <String>[],
        spotListIds: const <String>[],
      );
    }
    if (latitude != null && (latitude < -90 || latitude > 90)) {
      return (
        error: 'Latitude must be between -90 and 90',
        title: '',
        description: null,
        imageUrls: const <String>[],
        websiteUrl: null,
        startAt: startAt.toUtc(),
        endAt: null,
        latitude: null,
        longitude: null,
        address: null,
        city: null,
        countryCode: null,
        spotIds: const <String>[],
        spotListIds: const <String>[],
      );
    }
    if (longitude != null && (longitude < -180 || longitude > 180)) {
      return (
        error: 'Longitude must be between -180 and 180',
        title: '',
        description: null,
        imageUrls: const <String>[],
        websiteUrl: null,
        startAt: startAt.toUtc(),
        endAt: null,
        latitude: null,
        longitude: null,
        address: null,
        city: null,
        countryCode: null,
        spotIds: const <String>[],
        spotListIds: const <String>[],
      );
    }
    if (latitude != null &&
        (normalizedAddress == null || normalizedAddress.isEmpty)) {
      return (
        error: 'Address is required when coordinates are provided',
        title: '',
        description: null,
        imageUrls: const <String>[],
        websiteUrl: null,
        startAt: startAt.toUtc(),
        endAt: null,
        latitude: null,
        longitude: null,
        address: null,
        city: null,
        countryCode: null,
        spotIds: const <String>[],
        spotListIds: const <String>[],
      );
    }
    if (endAt != null && endAt.isBefore(startAt)) {
      return (
        error: 'End time cannot be before start time',
        title: '',
        description: null,
        imageUrls: const <String>[],
        websiteUrl: null,
        startAt: startAt.toUtc(),
        endAt: null,
        latitude: null,
        longitude: null,
        address: null,
        city: null,
        countryCode: null,
        spotIds: const <String>[],
        spotListIds: const <String>[],
      );
    }

    return (
      error: null,
      title: title.trim(),
      description: description?.trim().isEmpty == true
          ? null
          : description?.trim(),
      imageUrls: normalizedImageUrls,
      websiteUrl: normalizedWebsiteUrl?.isEmpty == true
          ? null
          : normalizedWebsiteUrl,
      startAt: startAt.toUtc(),
      endAt: endAt?.toUtc(),
      latitude: latitude,
      longitude: longitude,
      address: normalizedAddress?.isEmpty == true ? null : normalizedAddress,
      city: normalizedCity?.isEmpty == true ? null : normalizedCity,
      countryCode: normalizedCountryCode?.isEmpty == true
          ? null
          : normalizedCountryCode,
      spotIds: normalizedSpotIds,
      spotListIds: normalizedSpotListIds,
    );
  }

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  /// Events that point to [eventId] as their canonical native original.
  Future<List<ParkourEvent>> getEventsDuplicating(String eventId) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .where('duplicateOf', isEqualTo: eventId)
          .get();
      return snapshot.docs.map(ParkourEvent.fromFirestore).toList();
    } catch (e, st) {
      debugPrint('AdminEventsService.getEventsDuplicating error: $e\n$st');
      return const <ParkourEvent>[];
    }
  }

  /// Recent events that can serve as a duplicate target: native, not a duplicate.
  Future<List<ParkourEvent>> fetchNativeOriginalEventCandidates({
    required String excludeEventId,
    int limit = 40,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('events')
          .orderBy('startAt', descending: true)
          .limit(limit * 3)
          .get();
      final out = <ParkourEvent>[];
      for (final doc in snapshot.docs) {
        if (doc.id == excludeEventId) continue;
        final event = ParkourEvent.fromFirestore(doc);
        if (!event.isNativeEvent) continue;
        final dup = event.duplicateOf?.trim();
        if (dup != null && dup.isNotEmpty) continue;
        out.add(event);
        if (out.length >= limit) break;
      }
      return out;
    } catch (e, st) {
      debugPrint(
        'AdminEventsService.fetchNativeOriginalEventCandidates error: $e\n$st',
      );
      return const <ParkourEvent>[];
    }
  }

  /// Validates and sets [duplicateEventId].duplicateOf to [nativeOriginalEventId].
  Future<bool> markEventAsDuplicate({
    required String duplicateEventId,
    required String nativeOriginalEventId,
  }) async {
    _error = null;
    notifyListeners();

    final trimmedOriginal = nativeOriginalEventId.trim();
    final trimmedDup = duplicateEventId.trim();
    if (trimmedOriginal.isEmpty || trimmedDup.isEmpty) {
      _error = 'Invalid event id';
      notifyListeners();
      return false;
    }
    if (trimmedOriginal == trimmedDup) {
      _error = 'An event cannot be a duplicate of itself';
      notifyListeners();
      return false;
    }

    try {
      final originalSnap = await _firestore
          .collection('events')
          .doc(trimmedOriginal)
          .get();
      if (!originalSnap.exists) {
        _error = 'Original event not found';
        notifyListeners();
        return false;
      }
      final original = ParkourEvent.fromFirestore(originalSnap);
      if (!original.isNativeEvent) {
        _error =
            'The original must be a native parkour.spot event, not from an external source';
        notifyListeners();
        return false;
      }
      final origDup = original.duplicateOf?.trim();
      if (origDup != null && origDup.isNotEmpty) {
        _error =
            'Cannot point to an event that is already marked as a duplicate';
        notifyListeners();
        return false;
      }

      final dupSnap = await _firestore
          .collection('events')
          .doc(trimmedDup)
          .get();
      if (!dupSnap.exists) {
        _error = 'Event to mark as duplicate was not found';
        notifyListeners();
        return false;
      }
      final duplicate = ParkourEvent.fromFirestore(dupSnap);
      final existingDup = duplicate.duplicateOf?.trim();
      if (existingDup != null && existingDup.isNotEmpty) {
        _error = 'This event is already marked as a duplicate';
        notifyListeners();
        return false;
      }

      final dependents = await getEventsDuplicating(trimmedDup);
      if (dependents.isNotEmpty) {
        _error =
            'Cannot mark this event as a duplicate because other events are already marked as duplicates of it';
        notifyListeners();
        return false;
      }

      final dupData = dupSnap.data();
      final spotIdsLen = dupData?['spotIds'] is List
          ? (dupData!['spotIds'] as List).length
          : -1;
      debugPrint(
        'AdminEventsService.markEventAsDuplicate: uid=${FirebaseAuth.instance.currentUser?.uid} '
        'dup=$trimmedDup original=$trimmedOriginal '
        'spotIdsLen=$spotIdsLen createdBy=${dupData?['createdBy']} '
        'eventSourceId=${dupData?['eventSourceId']}',
      );

      await _firestore.collection('events').doc(trimmedDup).update({
        'duplicateOf': trimmedOriginal,
        'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      });
      notifyListeners();
      return true;
    } catch (e, st) {
      _error = 'Failed to mark event as duplicate';
      debugPrint('AdminEventsService.markEventAsDuplicate error: $e\n$st');
      if (e is FirebaseException && e.code == 'permission-denied') {
        debugPrint(
          'AdminEventsService.markEventAsDuplicate: permission-denied '
          '(deploy firestore.rules; external events may have had empty spotIds until rules fix; '
          'admin must be token.admin or users/{uid}.isAdmin).',
        );
      }
      notifyListeners();
      return false;
    }
  }

  /// Materializes [eventMapPins] for all events or a single event (admin callable).
  Future<Map<String, dynamic>?> backfillEventMapPins({String? eventId}) async {
    _error = null;
    try {
      final callable = _functions.httpsCallable(
        'backfillEventMapPins',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      final result = await callable.call({
        if (eventId != null && eventId.trim().isNotEmpty)
          'eventId': eventId.trim(),
      });
      final data = result.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e, st) {
      _error = 'Failed to backfill event map pins: $e';
      debugPrint('AdminEventsService.backfillEventMapPins error: $e\n$st');
      notifyListeners();
      return null;
    }
  }

  Future<bool> clearEventDuplicateStatus(String eventId) async {
    _error = null;
    notifyListeners();
    final id = eventId.trim();
    if (id.isEmpty) {
      _error = 'Invalid event id';
      notifyListeners();
      return false;
    }
    try {
      await _firestore.collection('events').doc(id).update({
        'duplicateOf': FieldValue.delete(),
        'updatedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      });
      notifyListeners();
      return true;
    } catch (e, st) {
      _error = 'Failed to remove duplicate status';
      debugPrint('AdminEventsService.clearEventDuplicateStatus error: $e\n$st');
      notifyListeners();
      return false;
    }
  }
}
