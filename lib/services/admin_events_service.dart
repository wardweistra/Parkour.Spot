import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/parkour_event.dart';
import '../utils/image_preparation.dart';

class AdminEventsService extends ChangeNotifier {
  AdminEventsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final List<ParkourEvent> _events = <ParkourEvent>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  QueryDocumentSnapshot<Map<String, dynamic>>? _lastEventDocument;
  bool _hasMore = true;

  static const int _defaultPageSize = 30;

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
    required List<String> spotIds,
    required String createdBy,
  }) async {
    final normalizedImageUrls = (imageUrls ?? const <String>[])
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toSet()
        .toList();
    final normalizedWebsiteUrl = websiteUrl?.trim();
    final normalizedAddress = address?.trim();
    final normalizedSpotIds = spotIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (title.trim().isEmpty || normalizedSpotIds.isEmpty) {
      _error = 'Title and at least one linked spot are required';
      notifyListeners();
      return false;
    }
    if (normalizedWebsiteUrl != null &&
        normalizedWebsiteUrl.isNotEmpty &&
        !_isValidHttpUrl(normalizedWebsiteUrl)) {
      _error = 'Website URL must be a valid http(s) link';
      notifyListeners();
      return false;
    }
    final hasLatitude = latitude != null;
    final hasLongitude = longitude != null;
    if (hasLatitude != hasLongitude) {
      _error = 'Both latitude and longitude are required for event location';
      notifyListeners();
      return false;
    }
    if (latitude != null && (latitude < -90 || latitude > 90)) {
      _error = 'Latitude must be between -90 and 90';
      notifyListeners();
      return false;
    }
    if (longitude != null && (longitude < -180 || longitude > 180)) {
      _error = 'Longitude must be between -180 and 180';
      notifyListeners();
      return false;
    }
    if (latitude != null &&
        (normalizedAddress == null || normalizedAddress.isEmpty)) {
      _error = 'Address is required when coordinates are provided';
      notifyListeners();
      return false;
    }
    if (endAt != null && endAt.isBefore(startAt)) {
      _error = 'End time cannot be before start time';
      notifyListeners();
      return false;
    }

    _error = null;
    notifyListeners();

    try {
      final now = DateTime.now().toUtc();
      final event = ParkourEvent(
        title: title.trim(),
        description: description?.trim().isEmpty == true ? null : description,
        imageUrls: normalizedImageUrls,
        websiteUrl: normalizedWebsiteUrl?.isEmpty == true
            ? null
            : normalizedWebsiteUrl,
        startAt: startAt.toUtc(),
        endAt: endAt?.toUtc(),
        latitude: latitude,
        longitude: longitude,
        address: normalizedAddress?.isEmpty == true ? null : normalizedAddress,
        spotIds: normalizedSpotIds,
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

  Future<List<String>> uploadEventImages(List<Uint8List> imageBytesList) async {
    final List<String> imageUrls = [];
    for (var index = 0; index < imageBytesList.length; index++) {
      final prepared = await prepareImageForUpload(imageBytesList[index]);
      final ext = _extensionForContentType(prepared.contentType);
      final fileName =
          'events/${DateTime.now().millisecondsSinceEpoch}_event_image_$index$ext';
      final ref = _storage.ref().child(fileName);
      final snapshot = await ref.putData(
        prepared.bytes,
        SettableMetadata(contentType: prepared.contentType),
      );
      imageUrls.add(await snapshot.ref.getDownloadURL());
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

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return false;
    return uri.scheme == 'http' || uri.scheme == 'https';
  }

  String _extensionForContentType(String contentType) {
    switch (contentType) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/gif':
        return '.gif';
      case 'image/webp':
        return '.webp';
      default:
        return '.jpg';
    }
  }
}
