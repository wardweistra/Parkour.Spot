import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/parkour_event.dart';
import '../../models/spot.dart';
import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/spot_service.dart';
import '../../utils/image_preparation.dart';
import '../../widgets/spot_selection_dialog.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  late final AuthService _authService;
  bool _scheduledInitialFetch = false;

  @override
  void initState() {
    super.initState();
    _authService = context.read<AuthService>();
    _authService.addListener(_tryFetchForAdmin);
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFetchForAdmin());
  }

  @override
  void dispose() {
    _authService.removeListener(_tryFetchForAdmin);
    super.dispose();
  }

  void _tryFetchForAdmin() {
    if (!mounted) return;
    if (!_authService.isAdmin || !_authService.isProfileReady) return;
    if (_scheduledInitialFetch) return;

    final service = context.read<AdminEventsService>();
    if (service.events.isNotEmpty || service.isLoading) return;

    _scheduledInitialFetch = true;
    service.fetchEvents();
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateEventDialog(
        onCreate:
            ({
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
            }) async {
              final authService = context.read<AuthService>();
              final createdBy = authService.currentUser?.uid ?? 'unknown';
              return context.read<AdminEventsService>().createEvent(
                title: title,
                description: description,
                imageUrls: imageUrls,
                websiteUrl: websiteUrl,
                startAt: startAt,
                endAt: endAt,
                latitude: latitude,
                longitude: longitude,
                address: address,
                spotIds: spotIds,
                createdBy: createdBy,
              );
            },
      ),
    );

    if (!mounted || created == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(created ? 'Event created' : 'Failed to create event'),
        backgroundColor: created ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Events')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/admin');
            }
          },
        ),
        actions: [
          Consumer<AdminEventsService>(
            builder: (context, service, _) {
              return IconButton(
                tooltip: 'Refresh',
                icon: service.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: service.isLoading
                    ? null
                    : () => service.fetchEvents(forceRefresh: true),
              );
            },
          ),
          IconButton(
            tooltip: 'Add event',
            icon: const Icon(Icons.add),
            onPressed: _openCreateDialog,
          ),
        ],
      ),
      body: Consumer<AdminEventsService>(
        builder: (context, service, _) {
          if (service.isLoading && service.events.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.error != null && service.events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(service.error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => service.fetchEvents(forceRefresh: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (service.events.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => service.fetchEvents(forceRefresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 140),
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_busy_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text('No events yet'),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final showLoadMore = service.hasMore;
          final itemCount = service.events.length + (showLoadMore ? 1 : 0);

          return RefreshIndicator(
            onRefresh: () => service.fetchEvents(forceRefresh: true),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index >= service.events.length) {
                  return _EventsLoadMoreFooter(service: service);
                }
                return _EventCard(event: service.events[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final ParkourEvent event;

  @override
  Widget build(BuildContext context) {
    final startLabel = _formatUtc(event.startAt);
    final endLabel = event.endAt == null ? null : _formatUtc(event.endAt!);
    final websiteUrl = event.websiteUrl?.trim();
    final hasWebsite = websiteUrl != null && websiteUrl.isNotEmpty;
    final hasLocation = event.latitude != null && event.longitude != null;
    final openEventPage = event.id == null
        ? null
        : () => context.push('/event/${event.id}');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: openEventPage,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (event.id != null)
                    IconButton(
                      onPressed: openEventPage,
                      tooltip: 'Open event page',
                      icon: const Icon(Icons.open_in_new),
                    ),
                ],
              ),
              if (event.description != null &&
                  event.description!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(event.description!),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 16),
                    label: Text(startLabel),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  if (endLabel != null)
                    Chip(
                      avatar: const Icon(Icons.hourglass_bottom, size: 16),
                      label: Text(endLabel),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  Chip(
                    avatar: const Icon(Icons.place_outlined, size: 16),
                    label: Text('${event.spotIds.length} linked spot(s)'),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SelectableText(
                'Spot IDs: ${event.spotIds.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (event.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: event.imageUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          event.imageUrls[index],
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 72,
                            height: 72,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (hasWebsite) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _openWebsite(websiteUrl),
                  child: Text(
                    websiteUrl,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
              if (hasLocation) ...[
                const SizedBox(height: 10),
                Text(
                  event.address?.trim().isNotEmpty == true
                      ? event.address!
                      : '${event.latitude!.toStringAsFixed(5)}, ${event.longitude!.toStringAsFixed(5)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatUtc(DateTime value) {
    return '${DateFormat.yMMMd().add_Hm().format(value.toUtc())} UTC';
  }

  Future<void> _openWebsite(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _EventsLoadMoreFooter extends StatelessWidget {
  const _EventsLoadMoreFooter({required this.service});

  final AdminEventsService service;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: service.isLoadingMore
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton.icon(
                onPressed: () => service.loadMore(),
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
      ),
    );
  }
}

class _CreateEventDialog extends StatefulWidget {
  const _CreateEventDialog({required this.onCreate});

  final Future<bool> Function({
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
  })
  onCreate;

  @override
  State<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends State<_CreateEventDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _newImageUrlController = TextEditingController();

  DateTime _startAt = DateTime.now().toUtc().add(const Duration(hours: 1));
  DateTime? _endAt;
  bool _isSubmitting = false;
  bool _isGeocoding = false;
  String? _formError;
  final List<Spot> _linkedSpots = <Spot>[];
  final List<Uint8List> _selectedImageBytes = <Uint8List>[];
  final List<String> _imageUrls = <String>[];

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
    setState(() {
      _endAt = value.toUtc();
    });
  }

  Future<void> _addLinkedSpot() async {
    final selectedSpotId = await showDialog<String>(
      context: context,
      builder: (_) => const SpotSelectionDialog(allowExternalSources: true),
    );
    if (selectedSpotId == null || !mounted) return;
    if (_linkedSpots.any((spot) => spot.id == selectedSpotId)) return;

    final spotService = context.read<SpotService>();
    final spot = await spotService.getSpotById(selectedSpotId);
    if (!mounted) return;
    if (spot == null || spot.id == null) {
      setState(() {
        _formError = 'Could not load the selected spot';
      });
      return;
    }

    setState(() {
      _linkedSpots.add(spot);
      _formError = null;
    });
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (pickedFiles.isEmpty) return;

      var addedCount = 0;
      for (final pickedFile in pickedFiles) {
        final bytes = await pickedFile.readAsBytes();
        final prepared = await prepareImageForUpload(bytes);
        _selectedImageBytes.add(prepared.bytes);
        addedCount++;
      }

      if (!mounted || addedCount == 0) return;
      setState(() {
        _formError = null;
      });
    } on ImagePreparationException catch (e) {
      setState(() {
        _formError = e.message;
      });
    } catch (e) {
      setState(() {
        _formError = 'Failed to pick images: $e';
      });
    }
  }

  void _removeSelectedImageAt(int index) {
    setState(() {
      _selectedImageBytes.removeAt(index);
    });
  }

  void _addImageUrl() {
    final value = _newImageUrlController.text.trim();
    if (value.isEmpty) return;
    final uri = Uri.tryParse(value);
    final valid =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (!valid) {
      setState(() {
        _formError = 'Image URL must be a valid http(s) link';
      });
      return;
    }
    if (_imageUrls.contains(value)) {
      _newImageUrlController.clear();
      return;
    }
    setState(() {
      _imageUrls.add(value);
      _newImageUrlController.clear();
      _formError = null;
    });
  }

  void _removeImageUrlAt(int index) {
    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  Future<bool> _tryGeocodeCoordinatesIfNeeded({bool force = false}) async {
    final latRaw = _latitudeController.text.trim();
    final lngRaw = _longitudeController.text.trim();
    final hasLatitudeText = latRaw.isNotEmpty;
    final hasLongitudeText = lngRaw.isNotEmpty;
    final hasAddress = _addressController.text.trim().isNotEmpty;

    if (!hasLatitudeText && !hasLongitudeText) {
      return true;
    }
    if (hasLatitudeText != hasLongitudeText) {
      setState(() {
        _formError = 'Both latitude and longitude are required';
      });
      return false;
    }
    final latitude = double.tryParse(latRaw);
    final longitude = double.tryParse(lngRaw);
    if (latitude == null || longitude == null) {
      setState(() {
        _formError = 'Latitude and longitude must be valid numbers';
      });
      return false;
    }
    if (latitude < -90 || latitude > 90) {
      setState(() {
        _formError = 'Latitude must be between -90 and 90';
      });
      return false;
    }
    if (longitude < -180 || longitude > 180) {
      setState(() {
        _formError = 'Longitude must be between -180 and 180';
      });
      return false;
    }
    if (hasAddress && !force) {
      return true;
    }

    setState(() {
      _isGeocoding = true;
      _formError = null;
    });
    try {
      final geocoding = context.read<GeocodingService>();
      final details = await geocoding.geocodeCoordinatesDetails(
        latitude,
        longitude,
      );
      final resolvedAddress = details['address']?.trim();
      if (!mounted) return false;
      if (resolvedAddress == null || resolvedAddress.isEmpty) {
        setState(() {
          _formError = 'Unable to geocode these coordinates';
        });
        return false;
      }
      _addressController.text = resolvedAddress;
      setState(() {
        _formError = null;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _formError = 'Failed to geocode coordinates: $e';
      });
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    final eventsService = context.read<AdminEventsService>();
    if (!_formKey.currentState!.validate()) return;
    if (_linkedSpots.isEmpty) {
      setState(() {
        _formError = 'Link at least one spot to the event';
      });
      return;
    }
    if (_endAt != null && _endAt!.isBefore(_startAt)) {
      setState(() {
        _formError = 'End time cannot be before start time';
      });
      return;
    }

    final geocoded = await _tryGeocodeCoordinatesIfNeeded();
    if (!geocoded) return;

    List<String> uploadedImageUrls = <String>[];

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    try {
      if (_selectedImageBytes.isNotEmpty) {
        uploadedImageUrls = await eventsService.uploadEventImages(
          _selectedImageBytes,
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

    final success = await widget.onCreate(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      imageUrls: [..._imageUrls, ...uploadedImageUrls],
      websiteUrl: _websiteController.text.trim(),
      startAt: _startAt,
      endAt: _endAt,
      latitude: double.tryParse(_latitudeController.text.trim()),
      longitude: double.tryParse(_longitudeController.text.trim()),
      address: _addressController.text.trim(),
      spotIds: _linkedSpots.map((spot) => spot.id!).toList(),
    );
    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });
    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _formError = eventsService.error ?? 'Create failed';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Event'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    return null;
                  },
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
                    hintText: 'https://example.com/event',
                  ),
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return null;
                    final uri = Uri.tryParse(trimmed);
                    final valid =
                        uri != null &&
                        (uri.scheme == 'http' || uri.scheme == 'https') &&
                        uri.host.isNotEmpty;
                    if (!valid) return 'Enter a valid http(s) URL';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Event images',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _isSubmitting ? null : _pickImagesFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Upload image(s)'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _newImageUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Add image URL',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.url,
                        onFieldSubmitted: (_) => _addImageUrl(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isSubmitting ? null : _addImageUrl,
                      icon: const Icon(Icons.add_link),
                      tooltip: 'Add image URL',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_selectedImageBytes.isNotEmpty)
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImageBytes.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _selectedImageBytes[index],
                                width: 84,
                                height: 84,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: InkWell(
                                onTap: _isSubmitting
                                    ? null
                                    : () => _removeSelectedImageAt(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                if (_imageUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _imageUrls
                        .asMap()
                        .entries
                        .map(
                          (entry) => Chip(
                            label: Text('URL ${entry.key + 1}'),
                            onDeleted: _isSubmitting
                                ? null
                                : () => _removeImageUrlAt(entry.key),
                          ),
                        )
                        .toList(),
                  ),
                ],
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
                      label: const Text('Geocode'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address (auto-filled from coordinates)',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _DateField(
                  label: 'Start (UTC)',
                  value: _startAt,
                  onPick: _pickStartAt,
                ),
                const SizedBox(height: 8),
                _DateField(
                  label: 'End (UTC, optional)',
                  value: _endAt,
                  onPick: _pickEndAt,
                  onClear: _endAt == null
                      ? null
                      : () {
                          setState(() {
                            _endAt = null;
                          });
                        },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Linked spots',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
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
                  Text(
                    'No spots selected yet',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
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
                                : () {
                                    setState(() {
                                      _linkedSpots.removeWhere(
                                        (s) => s.id == spot.id,
                                      );
                                    });
                                  },
                          ),
                        )
                        .toList(),
                  ),
                if (_formError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _formError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
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

    final initialTime = TimeOfDay.fromDateTime(initial.toLocal());
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
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

class _DateField extends StatelessWidget {
  const _DateField({
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
        Expanded(
          child: Text(
            '$label: $display',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.edit_calendar),
          label: const Text('Pick'),
        ),
        if (onClear != null)
          IconButton(
            onPressed: onClear,
            tooltip: 'Clear',
            icon: const Icon(Icons.clear),
          ),
      ],
    );
  }
}
