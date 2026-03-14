import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/spot_list.dart';
import '../services/auth_service.dart';
import '../services/feature_access_service.dart';

class SpotListService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService;
  final FeatureAccessService _featureAccessService;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  SpotListService(this._authService, this._featureAccessService);

  /// Check if the current user has access to spot lists feature
  bool _hasFeatureAccess() {
    return _featureAccessService.hasFeatureAccess('spotLists');
  }

  /// Check if the current user is authenticated
  bool _isAuthenticated() {
    return _authService.isAuthenticated;
  }

  /// Get the current user ID
  String? _getCurrentUserId() {
    return _authService.currentUser?.uid;
  }

  /// Create a new spot list
  Future<String?> createSpotList(
    String name, {
    String? description,
    SpotListVisibility visibility = SpotListVisibility.unlisted,
  }) async {
    if (!_isAuthenticated()) {
      _error = 'You must be signed in to create a list';
      notifyListeners();
      return null;
    }

    if (!_hasFeatureAccess()) {
      _error = 'You do not have access to create spot lists';
      notifyListeners();
      return null;
    }

    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'User ID not found';
      notifyListeners();
      return null;
    }

    if (name.trim().isEmpty) {
      _error = 'List name cannot be empty';
      notifyListeners();
      return null;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final now = DateTime.now();
      final sectionId = const Uuid().v4();
      final spotList = SpotList(
        name: name.trim(),
        description: description?.trim(),
        spotIds: [],
        sections: [SpotListSection(id: sectionId, entries: [])],
        visibility: visibility,
        createdBy: userId,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _firestore
          .collection('spotLists')
          .add(spotList.toFirestore());

      _isLoading = false;
      notifyListeners();
      return docRef.id;
    } catch (e) {
      _error = 'Failed to create list: $e';
      debugPrint('Error creating spot list: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Get all spot lists for the current user (requires feature access for management)
  /// Note: This method does not update loading state or notify listeners
  /// as it's typically called from FutureBuilder which manages its own loading state
  Future<List<SpotList>> getUserSpotLists() async {
    if (!_isAuthenticated()) {
      return [];
    }

    if (!_hasFeatureAccess()) {
      return [];
    }

    final userId = _getCurrentUserId();
    if (userId == null) {
      return [];
    }

    try {
      final querySnapshot = await _firestore
          .collection('spotLists')
          .where('createdBy', isEqualTo: userId)
          .orderBy('updatedAt', descending: true)
          .get();

      final lists = querySnapshot.docs
          .map((doc) => SpotList.fromFirestore(doc))
          .toList();

      return lists;
    } catch (e) {
      debugPrint('Error loading user spot lists: $e');
      return [];
    }
  }

  /// Get spot lists for a specific user.
  /// - Owners see all their lists.
  /// - Other users only see public lists.
  /// Note: This method does not update loading state or notify listeners
  Future<List<SpotList>> getSpotListsByUser(String userId) async {
    try {
      final currentUserId = _getCurrentUserId();
      late final QuerySnapshot<Map<String, dynamic>> querySnapshot;

      if (currentUserId == userId) {
        querySnapshot = await _firestore
            .collection('spotLists')
            .where('createdBy', isEqualTo: userId)
            .orderBy('updatedAt', descending: true)
            .get();
      } else {
        querySnapshot = await _firestore
            .collection('spotLists')
            .where('createdBy', isEqualTo: userId)
            .where(
              'visibility',
              isEqualTo: SpotListVisibility.public.firestoreValue,
            )
            .orderBy('updatedAt', descending: true)
            .get();
      }

      final lists = querySnapshot.docs
          .map((doc) => SpotList.fromFirestore(doc))
          .toList();

      return lists;
    } catch (e) {
      debugPrint('Error loading spot lists for user: $e');
      return [];
    }
  }

  /// Get a specific spot list by ID (visibility-aware access)
  Future<SpotList?> getSpotListById(String listId) async {
    try {
      final doc = await _firestore.collection('spotLists').doc(listId).get();
      if (doc.exists) {
        final list = SpotList.fromFirestore(doc);
        final currentUserId = _getCurrentUserId();
        final canView = list.visibility != SpotListVisibility.private ||
            list.createdBy == currentUserId;
        return canView ? list : null;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting spot list: $e');
      return null;
    }
  }

  /// Update spot list metadata (name, description, visibility)
  Future<bool> updateSpotList(
    String listId, {
    String? name,
    String? description,
    SpotListVisibility? visibility,
  }) async {
    if (!_isAuthenticated()) {
      _error = 'You must be signed in to update a list';
      notifyListeners();
      return false;
    }

    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'User ID not found';
      notifyListeners();
      return false;
    }

    // Verify ownership
    final list = await getSpotListById(listId);
    if (list == null || list.createdBy != userId) {
      _error = 'You do not have permission to update this list';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (name != null) {
        if (name.trim().isEmpty) {
          _error = 'List name cannot be empty';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        updates['name'] = name.trim();
      }

      if (description != null) {
        updates['description'] = description.trim().isEmpty
            ? FieldValue.delete()
            : description.trim();
      }

      if (visibility != null) {
        updates['visibility'] = visibility.firestoreValue;
      }

      await _firestore.collection('spotLists').doc(listId).update(updates);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update list: $e';
      debugPrint('Error updating spot list: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Add a spot to a list. For lists with sections, adds to the first section.
  Future<bool> addSpotToList(String listId, String spotId) async {
    if (!_isAuthenticated()) {
      _error = 'You must be signed in to add spots to a list';
      notifyListeners();
      return false;
    }

    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'User ID not found';
      notifyListeners();
      return false;
    }

    final list = await getSpotListById(listId);
    if (list == null || list.createdBy != userId) {
      _error = 'You do not have permission to modify this list';
      notifyListeners();
      return false;
    }

    if (list.hasAdvancedOrganization && list.sections != null && list.sections!.isNotEmpty) {
      return addSpotToSection(listId, list.sections!.first.id, spotId);
    }

    if (list.spotIds.contains(spotId)) {
      _error = 'Spot is already in this list';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('spotLists').doc(listId).update({
        'spotIds': FieldValue.arrayUnion([spotId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to add spot to list: $e';
      debugPrint('Error adding spot to list: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Remove a spot from a list. For advanced lists, removes all occurrences across sections.
  Future<bool> removeSpotFromList(String listId, String spotId) async {
    if (!_isAuthenticated()) {
      _error = 'You must be signed in to remove spots from a list';
      notifyListeners();
      return false;
    }

    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'User ID not found';
      notifyListeners();
      return false;
    }

    final list = await getSpotListById(listId);
    if (list == null || list.createdBy != userId) {
      _error = 'You do not have permission to modify this list';
      notifyListeners();
      return false;
    }

    if (list.hasAdvancedOrganization && list.sections != null) {
      final sections = <SpotListSection>[];
      for (final section in list.sections!) {
        final remainingEntries =
            section.entries.where((e) => e.spotId != spotId).toList();
        if (remainingEntries.isNotEmpty) {
          sections.add(section.copyWith(entries: remainingEntries));
        }
      }
      return updateSpotListOrganization(listId, sections);
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('spotLists').doc(listId).update({
        'spotIds': FieldValue.arrayRemove([spotId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to remove spot from list: $e';
      debugPrint('Error removing spot from list: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update section organization. Persists sections and
  /// derived spotIds for backward compatibility.
  Future<bool> updateSpotListOrganization(
    String listId,
    List<SpotListSection> sections,
  ) async {
    if (!_isAuthenticated()) {
      _error = 'You must be signed in to update list organization';
      notifyListeners();
      return false;
    }

    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'User ID not found';
      notifyListeners();
      return false;
    }

    final list = await getSpotListById(listId);
    if (list == null || list.createdBy != userId) {
      _error = 'You do not have permission to modify this list';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final effectiveSpotIds = _deriveSpotIdsFromSections(sections);

      if (sections.isEmpty) {
        // Convert back to simple mode with no spots
        await _firestore.collection('spotLists').doc(listId).update({
          'sections': FieldValue.delete(),
          'spotIds': <String>[],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _firestore.collection('spotLists').doc(listId).update({
          'sections': sections.map((s) => s.toMap()).toList(),
          'spotIds': effectiveSpotIds,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to update list organization: $e';
      debugPrint('Error updating list organization: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  List<String> _deriveSpotIdsFromSections(List<SpotListSection> sections) {
    final seen = <String>{};
    final result = <String>[];
    for (final section in sections) {
      for (final entry in section.entries) {
        if (entry.spotId.isNotEmpty && !seen.contains(entry.spotId)) {
          seen.add(entry.spotId);
          result.add(entry.spotId);
        }
      }
    }
    return result;
  }

  /// Add a spot to a specific section (advanced lists only).
  Future<bool> addSpotToSection(
    String listId,
    String sectionId,
    String spotId, {
    String? note,
  }) async {
    if (!_isAuthenticated()) {
      _error = 'You must be signed in to add spots to a list';
      notifyListeners();
      return false;
    }

    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'User ID not found';
      notifyListeners();
      return false;
    }

    final list = await getSpotListById(listId);
    if (list == null || list.createdBy != userId) {
      _error = 'You do not have permission to modify this list';
      notifyListeners();
      return false;
    }

    if (!list.hasAdvancedOrganization || list.sections == null) {
      _error = 'This list does not use advanced organization';
      notifyListeners();
      return false;
    }

    final sections = List<SpotListSection>.from(list.sections!);
    final sectionIndex = sections.indexWhere((s) => s.id == sectionId);
    if (sectionIndex < 0) {
      _error = 'Section not found';
      notifyListeners();
      return false;
    }

    final section = sections[sectionIndex];
    final newEntries = List<SpotListEntry>.from(section.entries)
      ..add(SpotListEntry(spotId: spotId, note: note?.trim().isEmpty == true ? null : note));
    sections[sectionIndex] = section.copyWith(entries: newEntries);

    return updateSpotListOrganization(listId, sections);
  }

  /// Remove an entry at a specific index from a section.
  Future<bool> removeEntryAt(
    String listId,
    String sectionId,
    int entryIndex,
  ) async {
    if (!_isAuthenticated()) {
      _error = 'You must be signed in to modify this list';
      notifyListeners();
      return false;
    }

    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'User ID not found';
      notifyListeners();
      return false;
    }

    final list = await getSpotListById(listId);
    if (list == null || list.createdBy != userId) {
      _error = 'You do not have permission to modify this list';
      notifyListeners();
      return false;
    }

    if (!list.hasAdvancedOrganization || list.sections == null) {
      _error = 'This list does not use advanced organization';
      notifyListeners();
      return false;
    }

    final sections = List<SpotListSection>.from(list.sections!);
    final sectionIndex = sections.indexWhere((s) => s.id == sectionId);
    if (sectionIndex < 0) {
      _error = 'Section not found';
      notifyListeners();
      return false;
    }

    final section = sections[sectionIndex];
    if (entryIndex < 0 || entryIndex >= section.entries.length) {
      _error = 'Invalid entry index';
      notifyListeners();
      return false;
    }

    final newEntries = List<SpotListEntry>.from(section.entries)..removeAt(entryIndex);
    sections[sectionIndex] = section.copyWith(entries: newEntries);

    // Remove section if empty (allows list to become empty, converting to simple mode)
    if (newEntries.isEmpty) {
      sections.removeAt(sectionIndex);
    }

    return updateSpotListOrganization(listId, sections);
  }

  /// Reorder spots in a list (legacy flat lists only; section-based lists use Organize screen)
  Future<bool> reorderSpotsInList(String listId, List<String> newSpotIds) async {
    if (!_isAuthenticated()) {
      _error = 'You must be signed in to reorder spots in a list';
      notifyListeners();
      return false;
    }

    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'User ID not found';
      notifyListeners();
      return false;
    }

    final list = await getSpotListById(listId);
    if (list == null || list.createdBy != userId) {
      _error = 'You do not have permission to modify this list';
      notifyListeners();
      return false;
    }

    if (list.hasAdvancedOrganization) {
      _error = 'Use Organize List to reorder spots';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('spotLists').doc(listId).update({
        'spotIds': newSpotIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to reorder spots: $e';
      debugPrint('Error reordering spots in list: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete a spot list
  Future<bool> deleteSpotList(String listId) async {
    if (!_isAuthenticated()) {
      _error = 'You must be signed in to delete a list';
      notifyListeners();
      return false;
    }

    final userId = _getCurrentUserId();
    if (userId == null) {
      _error = 'User ID not found';
      notifyListeners();
      return false;
    }

    // Verify ownership
    final list = await getSpotListById(listId);
    if (list == null || list.createdBy != userId) {
      _error = 'You do not have permission to delete this list';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestore.collection('spotLists').doc(listId).delete();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to delete list: $e';
      debugPrint('Error deleting spot list: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

