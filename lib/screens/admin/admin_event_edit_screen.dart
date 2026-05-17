import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/parkour_event.dart';
import '../../models/spot.dart';
import '../../models/spot_list.dart';
import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/spot_list_service.dart';
import '../../services/spot_service.dart';
import '../../utils/image_preparation.dart';
import '../../widgets/spot_form/image_section.dart';
import '../../widgets/spot_list_selection_dialog.dart';
import '../../widgets/spot_selection_dialog.dart';

class AdminEventEditScreen extends StatefulWidget {
  const AdminEventEditScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<AdminEventEditScreen> createState() => _AdminEventEditScreenState();
}

class _AdminEventEditScreenState extends State<AdminEventEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _newImageUrlController = TextEditingController();

  ParkourEvent? _event;
  DateTime _startAt = DateTime.now().toUtc();
  DateTime? _endAt;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isGeocoding = false;
  String? _formError;
  final List<Spot> _linkedSpots = <Spot>[];
  final List<SpotList> _linkedLists = <SpotList>[];
  final List<Uint8List?> _selectedImageBytes = <Uint8List?>[];
  final List<String> _existingImageUrls = <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEvent());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _addressController.dispose();
    _newImageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadEvent() async {
    final admin = context.read<AdminEventsService>();
    final spotService = context.read<SpotService>();
    final spotListService = context.read<SpotListService>();

    final event = await admin.getEventById(widget.eventId);
    if (!mounted) return;
    if (event == null) {
      setState(() {
        _isLoading = false;
        _formError = 'Event not found';
      });
      return;
    }

    final spots = <Spot>[];
    for (final spotId in event.spotIds) {
      final spot = await spotService.getSpotById(spotId);
      if (spot != null) spots.add(spot);
    }

    final lists = <SpotList>[];
    for (final listId in event.spotListIds) {
      final list = await spotListService.getSpotListById(listId);
      if (list != null) lists.add(list);
    }

    if (!mounted) return;
    setState(() {
      _event = event;
      _titleController.text = event.title;
      _descriptionController.text = event.description ?? '';
      _websiteController.text = event.websiteUrl ?? '';
      if (event.latitude != null) {
        _latitudeController.text = event.latitude.toString();
      }
      if (event.longitude != null) {
        _longitudeController.text = event.longitude.toString();
      }
      _addressController.text = event.address ?? '';
      _startAt = event.startAt.toUtc();
      _endAt = event.endAt?.toUtc();
      _linkedSpots
        ..clear()
        ..addAll(spots);
      _linkedLists
        ..clear()
        ..addAll(lists);
      _existingImageUrls
        ..clear()
        ..addAll(event.imageUrls);
      _isLoading = false;
    });
  }

  Future<void> _pickStartAt() async {
    final value = await _pickDateTime(context, initial: _startAt);
    if (value == null) return;
    setState(() {
      _startAt = value.toUtc();
      if (_endAt != null && _endAt!.isBefore(_startAt)) {
        _endAt = null;
      }
    });
  }

  Future<void> _pickEndAt() async {
    final initial = _endAt ?? _startAt.add(const Duration(hours: 2));
    final value = await _pickDateTime(context, initial: initial);
    if (value == null) return;
    setState(() => _endAt = value.toUtc());
  }

  Future<void> _addLinkedSpot() async {
    final selectedSpotId = await showDialog<String>(
      context: context,
      builder: (_) => const SpotSelectionDialog(allowExternalSources: true),
    );
    if (selectedSpotId == null || !mounted) return;
    if (_linkedSpots.any((spot) => spot.id == selectedSpotId)) return;

    final spot = await context.read<SpotService>().getSpotById(selectedSpotId);
    if (!mounted) return;
    if (spot == null || spot.id == null) {
      setState(() => _formError = 'Could not load the selected spot');
      return;
    }
    setState(() {
      _linkedSpots.add(spot);
      _formError = null;
    });
  }

  Future<void> _addLinkedList() async {
    final l10n = AppLocalizations.of(context)!;
    final selectedListId = await showDialog<String>(
      context: context,
      builder: (_) => const SpotListSelectionDialog(),
    );
    if (selectedListId == null || !mounted) return;
    if (_linkedLists.any((list) => list.id == selectedListId)) return;

    final list = await context.read<SpotListService>().getSpotListById(
      selectedListId,
    );
    if (!mounted) return;
    if (list == null || list.id == null) {
      setState(() => _formError = l10n.adminSpotListSelectionLoadFailed);
      return;
    }
    setState(() {
      _linkedLists.add(list);
      _formError = null;
    });
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (pickedFiles.isEmpty) return;

      for (final pickedFile in pickedFiles) {
        try {
          final bytes = await pickedFile.readAsBytes();
          final prepared = await prepareImageForUpload(bytes);
          if (mounted) {
            setState(() => _selectedImageBytes.add(prepared.bytes));
          }
        } on ImagePreparationException catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message), backgroundColor: Colors.red),
            );
          }
        }
      }
      if (!mounted) return;
      setState(() => _formError = null);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ImagePreparationException
                ? e.message
                : 'Failed to pick images. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final prepared = await prepareImageForUpload(bytes);
      if (!mounted) return;
      setState(() {
        _selectedImageBytes.add(prepared.bytes);
        _formError = null;
      });
    } on ImagePreparationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to take photo. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeSelectedImageAt(int index) {
    setState(() {
      if (index < _selectedImageBytes.length) {
        _selectedImageBytes[index] = null;
      }
    });
  }

  void _removeExistingImageAt(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  void _reorderExistingImage(int oldIndex, int newIndex) {
    setState(() {
      final imageUrl = _existingImageUrls.removeAt(oldIndex);
      _existingImageUrls.insert(newIndex, imageUrl);
    });
  }

  void _reorderSelectedImage(int oldIndex, int newIndex) {
    setState(() {
      final imageBytes = _selectedImageBytes.removeAt(oldIndex);
      _selectedImageBytes.insert(newIndex, imageBytes);
    });
  }

  Future<bool> _tryReverseGeocodeAddressIfNeeded({bool force = false}) async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return true;

    final latRaw = _latitudeController.text.trim();
    final lngRaw = _longitudeController.text.trim();
    final hasLatitudeText = latRaw.isNotEmpty;
    final hasLongitudeText = lngRaw.isNotEmpty;

    if (hasLatitudeText && hasLongitudeText && !force) return true;
    if (hasLatitudeText != hasLongitudeText) {
      setState(() => _formError = 'Both latitude and longitude are required');
      return false;
    }

    setState(() {
      _isGeocoding = true;
      _formError = null;
    });
    try {
      final geocoding = context.read<GeocodingService>();
      final coords = await geocoding.reverseGeocodeAddress(address);
      if (!mounted) return false;
      if (coords == null) {
        setState(() {
          _formError =
              geocoding.error ?? 'Unable to locate coordinates for this address';
        });
        return false;
      }
      final latitude = coords['latitude'];
      final longitude = coords['longitude'];
      if (latitude == null || longitude == null) {
        setState(() => _formError = 'Unable to locate coordinates for this address');
        return false;
      }
      _latitudeController.text = latitude.toString();
      _longitudeController.text = longitude.toString();
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _formError = 'Failed to locate address: $e');
      return false;
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<bool> _tryGeocodeCoordinatesIfNeeded({bool force = false}) async {
    final latRaw = _latitudeController.text.trim();
    final lngRaw = _longitudeController.text.trim();
    final hasLatitudeText = latRaw.isNotEmpty;
    final hasLongitudeText = lngRaw.isNotEmpty;
    final hasAddress = _addressController.text.trim().isNotEmpty;

    if (!hasLatitudeText && !hasLongitudeText) return true;
    if (hasLatitudeText != hasLongitudeText) {
      setState(() => _formError = 'Both latitude and longitude are required');
      return false;
    }
    final latitude = double.tryParse(latRaw);
    final longitude = double.tryParse(lngRaw);
    if (latitude == null || longitude == null) {
      setState(() => _formError = 'Latitude and longitude must be valid numbers');
      return false;
    }
    if (hasAddress && !force) return true;

    setState(() {
      _isGeocoding = true;
      _formError = null;
    });
    try {
      final details = await context.read<GeocodingService>().geocodeCoordinatesDetails(
        latitude,
        longitude,
      );
      final resolvedAddress = details['address']?.trim();
      if (!mounted) return false;
      if (resolvedAddress == null || resolvedAddress.isEmpty) {
        setState(() => _formError = 'Unable to geocode these coordinates');
        return false;
      }
      _addressController.text = resolvedAddress;
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() => _formError = 'Failed to geocode coordinates: $e');
      return false;
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  bool _canEditLoadedEvent(AuthService auth) {
    final event = _event;
    if (event == null) return false;
    if (auth.isAdmin) return true;
    return auth.isModerator && event.isNativeEvent;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    if (!_canEditLoadedEvent(auth)) return;

    final eventsService = context.read<AdminEventsService>();
    if (!_formKey.currentState!.validate()) return;
    if (_endAt != null && _endAt!.isBefore(_startAt)) {
      setState(() => _formError = 'End time cannot be before start time');
      return;
    }
    if (!await _tryReverseGeocodeAddressIfNeeded()) return;
    if (!await _tryGeocodeCoordinatesIfNeeded()) return;

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    final validNewImageBytes = _selectedImageBytes
        .where((bytes) => bytes != null)
        .cast<Uint8List>()
        .toList();

    List<String> uploadedImageUrls = <String>[];
    try {
      if (validNewImageBytes.isNotEmpty) {
        uploadedImageUrls = await eventsService.uploadEventImages(
          validNewImageBytes,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _formError = 'Failed to upload images: $e';
      });
      return;
    }

    final success = await eventsService.updateEvent(
      eventId: widget.eventId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      imageUrls: [..._existingImageUrls, ...uploadedImageUrls],
      websiteUrl: _websiteController.text.trim(),
      startAt: _startAt,
      endAt: _endAt,
      latitude: double.tryParse(_latitudeController.text.trim()),
      longitude: double.tryParse(_longitudeController.text.trim()),
      address: _addressController.text.trim(),
      spotIds: _linkedSpots.map((s) => s.id!).toList(),
      spotListIds: _linkedLists.map((l) => l.id!).toList(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.adminEventEditSave),
          backgroundColor: Colors.green,
        ),
      );
      context.pop(true);
      return;
    }
    setState(() => _formError = eventsService.error ?? 'Update failed');
  }

  Widget _buildExternalSourceBlockedBody(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.adminEventExternalSyncWarningTitle,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.eventDetailExternalSourceCannotEdit,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_event?.eventSourceName?.trim().isNotEmpty == true)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.source,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.eventDetailSourceLabel,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            _event!.eventSourceName!.trim(),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go back'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.select<AuthService, AuthService>((s) => s);
    final isStaff = auth.isModerator || auth.isAdmin;
    if (!isStaff) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.adminEventEditTitle)),
        body: const Center(child: Text('Moderator or administrator access required')),
      );
    }

    final isModeratorOnly = auth.isModerator && !auth.isAdmin;
    final isExternalBlocked =
        !_isLoading && _event != null && !_event!.isNativeEvent && isModeratorOnly;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminEventEditTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _event == null
          ? Center(child: Text(_formError ?? 'Event not found'))
          : isExternalBlocked
          ? _buildExternalSourceBlockedBody(l10n)
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!_event!.isNativeEvent && auth.isAdmin) ...[
                    MaterialBanner(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .tertiaryContainer
                          .withValues(alpha: 0.5),
                      leading: const Icon(Icons.sync),
                      content: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.adminEventExternalSyncWarningTitle,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(l10n.adminEventExternalSyncWarningBody),
                        ],
                      ),
                      actions: const [SizedBox.shrink()],
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      border: OutlineInputBorder(),
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _websiteController,
                    decoration: const InputDecoration(
                      labelText: 'Website URL (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Event location',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latitudeController,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _longitudeController,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: (_isSubmitting || _isGeocoding)
                            ? null
                            : () => _tryGeocodeCoordinatesIfNeeded(force: true),
                        icon: _isGeocoding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.pin_drop_outlined),
                        label: const Text('To address'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                          ),
                          minLines: 2,
                          maxLines: 3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: (_isSubmitting || _isGeocoding)
                            ? null
                            : () => _tryReverseGeocodeAddressIfNeeded(force: true),
                        icon: _isGeocoding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.location_searching_outlined),
                        label: const Text('To coords'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SpotImageSection(
                    selectedImageBytes: _selectedImageBytes,
                    existingImageUrls: _existingImageUrls,
                    sectionTitle: 'Images (optional)',
                    showRequiredIndicator: false,
                    onPickFromGallery: _pickFromGallery,
                    onTakePhoto: _takePhoto,
                    onRemoveSelectedAt: _removeSelectedImageAt,
                    onRemoveExistingAt: _removeExistingImageAt,
                    onReorderExisting: _reorderExistingImage,
                    onReorderSelected: _reorderSelectedImage,
                  ),
                  const SizedBox(height: 16),
                  _buildLinkedSpotsSection(l10n),
                  const SizedBox(height: 16),
                  _buildLinkedListsSection(l10n),
                  const SizedBox(height: 16),
                  _AdminEventDateField(
                    label: 'Start (UTC)',
                    value: _startAt,
                    onPick: _pickStartAt,
                  ),
                  const SizedBox(height: 8),
                  _AdminEventDateField(
                    label: 'End (UTC, optional)',
                    value: _endAt,
                    onPick: _pickEndAt,
                    onClear: _endAt == null ? null : () => setState(() => _endAt = null),
                  ),
                  if (_formError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _formError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _save,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.adminEventEditSave),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildLinkedSpotsSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Linked spots', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _addLinkedSpot,
              icon: const Icon(Icons.add),
              label: const Text('Add spot'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_linkedSpots.isEmpty)
          Text('No spots selected', style: Theme.of(context).textTheme.bodySmall)
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _linkedSpots
                .map(
                  (spot) => Chip(
                    label: Text('${spot.name} (${spot.id})'),
                    onDeleted: _isSubmitting
                        ? null
                        : () => setState(
                            () => _linkedSpots.removeWhere((s) => s.id == spot.id),
                          ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildLinkedListsSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.adminEventLinkedSpotListsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _addLinkedList,
              icon: const Icon(Icons.add),
              label: Text(l10n.adminEventAddSpotList),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_linkedLists.isEmpty)
          Text(
            l10n.adminEventNoLinkedSpotLists,
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _linkedLists
                .map(
                  (list) => Chip(
                    label: Text('${list.name} (${list.visibility.label})'),
                    onDeleted: _isSubmitting
                        ? null
                        : () => setState(
                            () => _linkedLists.removeWhere((l) => l.id == list.id),
                          ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context, {
    required DateTime initial,
  }) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial.toLocal(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (selectedDate == null || !context.mounted) return null;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial.toLocal()),
    );
    if (selectedTime == null) return null;

    return DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    ).toUtc();
  }
}

class _AdminEventDateField extends StatelessWidget {
  const _AdminEventDateField({
    required this.label,
    required this.value,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? 'Not set'
        : '${DateFormat.yMMMd().add_Hm().format(value!.toUtc())} UTC';

    return Row(
      children: [
        Expanded(child: Text('$label: $display')),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.edit_calendar),
          label: const Text('Pick'),
        ),
        if (onClear != null)
          IconButton(onPressed: onClear, icon: const Icon(Icons.clear)),
      ],
    );
  }
}
