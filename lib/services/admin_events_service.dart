import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/parkour_event.dart';
import '../utils/event_date_window.dart';
import '../utils/event_linked_spot_loader.dart';
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
  static const String eventSourceFilterAll = '__all__';
  static const String eventSourceFilterNative = '__native__';
  static const int _maxNativeFilterBatches = 15;

  String _eventSourceFilter = eventSourceFilterAll;
  bool _upcomingOnly = true;
  bool _excludeDuplicates = true;
  bool _withoutLocationOnly = false;

  List<ParkourEvent> get events => List<ParkourEvent>.unmodifiable(_events);
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String get eventSourceFilter => _eventSourceFilter;
  bool get upcomingOnly => _upcomingOnly;
  bool get excludeDuplicates => _excludeDuplicates;
  bool get withoutLocationOnly => _withoutLocationOnly;
  bool get hasEventSourceFilter =>
      _eventSourceFilter != eventSourceFilterAll;
  bool get hasActiveListFilters =>
      hasEventSourceFilter ||
      !_upcomingOnly ||
      !_excludeDuplicates ||
      _withoutLocationOnly;

  void setEventSourceFilter(String filter) {
    if (_eventSourceFilter == filter) return;
    _eventSourceFilter = filter;
    notifyListeners();
  }

  /// Returns true when any filter value changed.
  bool updateListFilters({
    String? eventSourceFilter,
    bool? upcomingOnly,
    bool? excludeDuplicates,
    bool? withoutLocationOnly,
  }) {
    var changed = false;
    if (eventSourceFilter != null && _eventSourceFilter != eventSourceFilter) {
      _eventSourceFilter = eventSourceFilter;
      changed = true;
    }
    if (upcomingOnly != null && _upcomingOnly != upcomingOnly) {
      _upcomingOnly = upcomingOnly;
      changed = true;
    }
    if (excludeDuplicates != null && _excludeDuplicates != excludeDuplicates) {
      _excludeDuplicates = excludeDuplicates;
      changed = true;
    }
    if (withoutLocationOnly != null &&
        _withoutLocationOnly != withoutLocationOnly) {
      _withoutLocationOnly = withoutLocationOnly;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

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
      if (_usesClientSidePaging) {
        await _fetchUntilPageFull(
          replaceExisting: true,
          pageSize: pageSize,
        );
      } else {
        final snapshot = await _buildEventsQuery().limit(pageSize).get();
        _applyPage(snapshot, pageSize, replaceExisting: true);
      }
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
      if (_usesClientSidePaging) {
        await _fetchUntilPageFull(
          replaceExisting: false,
          pageSize: pageSize,
        );
      } else {
        final snapshot = await _buildEventsQuery()
            .startAfterDocument(_lastEventDocument!)
            .limit(pageSize)
            .get();
        _applyPage(snapshot, pageSize, replaceExisting: false);
      }
    } catch (e, st) {
      _error = 'Failed to load more events';
      debugPrint('AdminEventsService.loadMore error: $e\n$st');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
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
      isDateOnly: sourceEvent.isDateOnly,
      timeZone: sourceEvent.timeZone,
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
        isDateOnly: normalized.isDateOnly,
        timeZone: normalized.timeZone,
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
    bool isDateOnly = false,
    String? timeZone,
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
      isDateOnly: isDateOnly,
      timeZone: timeZone,
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
      final resolvedCityCountry = await resolveEventCityCountryFromFirestore(
        firestore: _firestore,
        latitude: normalized.latitude,
        longitude: normalized.longitude,
        address: normalized.address,
        city: normalized.city,
        countryCode: normalized.countryCode,
        spotIds: normalized.spotIds,
        spotListIds: normalized.spotListIds,
      );

      final now = DateTime.now().toUtc();
      final updated = existing.copyWith(
        title: normalized.title,
        description: normalized.description,
        imageUrls: normalized.imageUrls,
        websiteUrl: normalized.websiteUrl,
        startAt: normalized.startAt,
        endAt: normalized.endAt,
        isDateOnly: normalized.isDateOnly,
        timeZone: normalized.timeZone,
        latitude: normalized.latitude,
        longitude: normalized.longitude,
        address: normalized.address,
        city: resolvedCityCountry.city,
        countryCode: resolvedCityCountry.countryCode,
        spotIds: normalized.spotIds,
        spotListIds: normalized.spotListIds,
        updatedAt: now,
      );
      final updateData = updated.toFirestore();
      updateData['isDateOnly'] = updated.isDateOnly;
      final trimmedTimeZone = updated.timeZone?.trim();
      if (trimmedTimeZone == null || trimmedTimeZone.isEmpty) {
        updateData['timeZone'] = FieldValue.delete();
      } else {
        updateData['timeZone'] = trimmedTimeZone;
      }
      _applyFieldDeletesForClearedEventLocation(updateData, updated);
      await _firestore.collection('events').doc(trimmedId).update(updateData);

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

  Future<List<Map<String, dynamic>>> searchEventsByTitle({
    required String query,
    int limit = 6,
  }) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return <Map<String, dynamic>>[];

    try {
      final callable = _functions.httpsCallable('searchEventsByTitle');
      final result = await callable.call<Map<String, dynamic>>({
        'query': trimmedQuery,
        'limit': limit,
      });
      final data = result.data;
      if (data['success'] != true) {
        return <Map<String, dynamic>>[];
      }
      final items = data['events'] as List<dynamic>? ?? <dynamic>[];
      return items
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => <String, dynamic>{
              'id': item['id'] as String?,
              'title': item['title'] as String? ?? '',
              'city': item['city'] as String?,
              'countryCode': item['countryCode'] as String?,
              'startAt': item['startAt'] as String?,
            },
          )
          .where(
            (event) =>
                (event['id'] as String?)?.isNotEmpty == true &&
                (event['title'] as String).trim().isNotEmpty,
          )
          .toList();
    } catch (e, st) {
      debugPrint('AdminEventsService.searchEventsByTitle error: $e\n$st');
      return <Map<String, dynamic>>[];
    }
  }

  Future<ParkourEvent?> getNextUpcomingEventForSpot(String spotId) async {
    return _getNextUpcomingEvent(
      field: 'spotIds',
      id: spotId,
      logLabel: 'getNextUpcomingEventForSpot',
    );
  }

  Future<ParkourEvent?> getNextUpcomingEventForSpotList(
    String spotListId,
  ) async {
    return _getNextUpcomingEvent(
      field: 'spotListIds',
      id: spotListId,
      logLabel: 'getNextUpcomingEventForSpotList',
    );
  }

  Future<ParkourEvent?> _getNextUpcomingEvent({
    required String field,
    required String id,
    required String logLabel,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final snapshot = await _firestore
          .collection('events')
          .where(field, arrayContains: id)
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
            'AdminEventsService.$logLabel skipping malformed event ${doc.id}: $e',
          );
        }
      }
      events.sort((a, b) => a.startAt.compareTo(b.startAt));
      if (events.isEmpty) return null;
      return events.first;
    } catch (e, st) {
      debugPrint('AdminEventsService.$logLabel error: $e\n$st');
      return null;
    }
  }

  Query<Map<String, dynamic>> _buildEventsQuery() {
    Query<Map<String, dynamic>> query = _firestore.collection('events');
    if (_isExternalSourceFilter) {
      query = query.where('eventSourceId', isEqualTo: _eventSourceFilter);
    }
    return query.orderBy('startAt', descending: true);
  }

  bool get _isExternalSourceFilter =>
      _eventSourceFilter != eventSourceFilterAll &&
      _eventSourceFilter != eventSourceFilterNative;

  bool get _usesClientSidePaging =>
      _eventSourceFilter == eventSourceFilterNative ||
      _upcomingOnly ||
      _excludeDuplicates ||
      _withoutLocationOnly;

  bool _matchesEventSourceFilter(ParkourEvent event) {
    switch (_eventSourceFilter) {
      case eventSourceFilterAll:
        return true;
      case eventSourceFilterNative:
        return event.isNativeEvent;
      default:
        return event.eventSourceId == _eventSourceFilter;
    }
  }

  bool _isUpcoming(ParkourEvent event, DateTime now) {
    final utcNow = now.toUtc();
    if (event.endAt != null) {
      return !event.endAt!.toUtc().isBefore(utcNow);
    }
    return !event.startAt.toUtc().isBefore(utcNow);
  }

  bool _isDuplicate(ParkourEvent event) {
    final duplicateOf = event.duplicateOf?.trim();
    return duplicateOf != null && duplicateOf.isNotEmpty;
  }

  bool _hasLocation(ParkourEvent event) {
    if (event.latitude != null && event.longitude != null) return true;
    if (event.spotIds.isNotEmpty) return true;
    if (event.spotListIds.isNotEmpty) return true;
    return false;
  }

  bool _matchesEventFilters(ParkourEvent event) {
    if (!_matchesEventSourceFilter(event)) return false;
    if (_upcomingOnly && !_isUpcoming(event, DateTime.now())) return false;
    if (_excludeDuplicates && _isDuplicate(event)) return false;
    if (_withoutLocationOnly && _hasLocation(event)) return false;
    return true;
  }

  Future<void> _fetchUntilPageFull({
    required bool replaceExisting,
    required int pageSize,
  }) async {
    if (replaceExisting) {
      _events.clear();
      _lastEventDocument = null;
      _hasMore = true;
    }

    final targetCount = replaceExisting
        ? pageSize
        : _events.length + pageSize;
    var batches = 0;

    while (_hasMore && _events.length < targetCount) {
      if (batches >= _maxNativeFilterBatches) {
        break;
      }
      batches++;

      Query<Map<String, dynamic>> query = _buildEventsQuery();
      if (_lastEventDocument != null) {
        query = query.startAfterDocument(_lastEventDocument!);
      }

      final snapshot = await query.limit(pageSize).get();
      final docs = snapshot.docs;
      if (docs.isEmpty) {
        _hasMore = false;
        break;
      }

      for (final doc in docs) {
        final event = ParkourEvent.fromFirestore(doc);
        if (_matchesEventFilters(event)) {
          _events.add(event);
        }
      }

      _lastEventDocument = docs.last;
      _hasMore = docs.length >= pageSize;
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
      final event = ParkourEvent.fromFirestore(doc);
      if (_matchesEventFilters(event)) {
        _events.add(event);
      }
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
    bool isDateOnly,
    String? timeZone,
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
    bool isDateOnly = false,
    String? timeZone,
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
    final normalizedTimeZone = timeZone?.trim();
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

    ({
      String? error,
      String title,
      String? description,
      List<String> imageUrls,
      String? websiteUrl,
      DateTime startAt,
      DateTime? endAt,
      bool isDateOnly,
      String? timeZone,
      double? latitude,
      double? longitude,
      String? address,
      String? city,
      String? countryCode,
      List<String> spotIds,
      List<String> spotListIds,
    })
    invalidResult(String errorMessage) {
      return (
        error: errorMessage,
        title: '',
        description: null,
        imageUrls: const <String>[],
        websiteUrl: null,
        startAt: startAt.toUtc(),
        endAt: null,
        isDateOnly: false,
        timeZone: null,
        latitude: null,
        longitude: null,
        address: null,
        city: null,
        countryCode: null,
        spotIds: const <String>[],
        spotListIds: const <String>[],
      );
    }

    if (title.trim().isEmpty) {
      return invalidResult('Title is required');
    }
    if (normalizedSpotListIds.length > maxSpotListIds) {
      return invalidResult('At most $maxSpotListIds spot lists can be linked');
    }
    if (normalizedWebsiteUrl != null &&
        normalizedWebsiteUrl.isNotEmpty &&
        !_isValidHttpUrl(normalizedWebsiteUrl)) {
      return invalidResult('Website URL must be a valid http(s) link');
    }
    final hasLatitude = latitude != null;
    final hasLongitude = longitude != null;
    if (hasLatitude != hasLongitude) {
      return invalidResult(
        'Both latitude and longitude are required for event location',
      );
    }
    if (latitude != null && (latitude < -90 || latitude > 90)) {
      return invalidResult('Latitude must be between -90 and 90');
    }
    if (longitude != null && (longitude < -180 || longitude > 180)) {
      return invalidResult('Longitude must be between -180 and 180');
    }
    final hasLinkedSpotLocation =
        normalizedSpotIds.isNotEmpty || normalizedSpotListIds.isNotEmpty;
    if (latitude != null &&
        (normalizedAddress == null || normalizedAddress.isEmpty) &&
        !hasLinkedSpotLocation) {
      return invalidResult('Address is required when coordinates are provided');
    }
    if (endAt != null && endAt.isBefore(startAt)) {
      return invalidResult('End time cannot be before start time');
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
      isDateOnly: isDateOnly,
      timeZone: normalizedTimeZone?.isEmpty == true ? null : normalizedTimeZone,
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

  /// [toFirestore] omits null location fields; Firestore [update] would keep old values.
  void _applyFieldDeletesForClearedEventLocation(
    Map<String, dynamic> updateData,
    ParkourEvent updated,
  ) {
    if (updated.latitude == null) {
      updateData['latitude'] = FieldValue.delete();
    }
    if (updated.longitude == null) {
      updateData['longitude'] = FieldValue.delete();
    }
    if (updated.address == null) {
      updateData['address'] = FieldValue.delete();
    }
    if (updated.city == null) {
      updateData['city'] = FieldValue.delete();
    }
    if (updated.countryCode == null) {
      updateData['countryCode'] = FieldValue.delete();
    }
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

  /// Native, non-duplicate events that can serve as a duplicate target.
  ///
  /// When [aroundStartAt] is set, results are limited to events whose dates
  /// overlap a padded window around the reference event (see [EventDateWindow]).
  Future<List<ParkourEvent>> fetchNativeOriginalEventCandidates({
    required String excludeEventId,
    DateTime? aroundStartAt,
    DateTime? aroundEndAt,
    int limit = 40,
  }) async {
    try {
      final dateWindow = aroundStartAt == null
          ? null
          : EventDateWindow.aroundEvent(
              startAt: aroundStartAt,
              endAt: aroundEndAt,
            );

      Query<Map<String, dynamic>> query = _firestore.collection('events');
      if (dateWindow != null) {
        query = query
            .where(
              'startAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(dateWindow.start),
            )
            .where(
              'startAt',
              isLessThanOrEqualTo: Timestamp.fromDate(dateWindow.end),
            )
            .orderBy('startAt');
      } else {
        query = query.orderBy('startAt', descending: true);
      }

      final snapshot = await query.limit(limit * 3).get();
      final out = <ParkourEvent>[];
      for (final doc in snapshot.docs) {
        if (doc.id == excludeEventId) continue;
        final event = ParkourEvent.fromFirestore(doc);
        if (!event.isNativeEvent) continue;
        final dup = event.duplicateOf?.trim();
        if (dup != null && dup.isNotEmpty) continue;
        if (dateWindow != null && !dateWindow.overlapsParkourEvent(event)) {
          continue;
        }
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

  /// Populates [eventSearchTerms] for all events (Explore autocomplete).
  Future<Map<String, dynamic>?> backfillEventSearchTerms({bool purge = false}) async {
    _error = null;
    try {
      final callable = _functions.httpsCallable(
        'backfillEventSearchTerms',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      final result = await callable.call({'purge': purge});
      final data = result.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return null;
    } catch (e, st) {
      _error = 'Failed to backfill event search terms: $e';
      debugPrint('AdminEventsService.backfillEventSearchTerms error: $e\n$st');
      notifyListeners();
      return null;
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
