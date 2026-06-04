import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import '../../models/spot.dart';
import '../../services/auth_service.dart';
import '../../services/event_report_service.dart';
import '../../services/geocoding_service.dart';
import '../../utils/browser_timezone_utils.dart';
import '../../utils/event_schedule_utils.dart';
import '../../utils/image_preparation.dart';
import '../../utils/marker_icon_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_config.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_screen.dart';
import '../../widgets/location_info_box.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/spot_form/image_section.dart';

class AddEventReportScreen extends StatefulWidget {
  const AddEventReportScreen({
    super.key,
    this.initialLocation,
    this.initialSpotId,
    this.initialSpotName,
    this.initialSpotListId,
    this.initialSpotListName,
  });

  final LatLng? initialLocation;
  final String? initialSpotId;
  final String? initialSpotName;
  final String? initialSpotListId;
  final String? initialSpotListName;

  @override
  State<AddEventReportScreen> createState() => _AddEventReportScreenState();
}

class _AddEventReportScreenState extends State<AddEventReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  final _locationAddressController = TextEditingController();

  bool _isSubmitting = false;
  bool _isDateOnly = false;
  DateTime _startAt = DateTime.now().toUtc().add(const Duration(hours: 1));
  DateTime? _endAt;
  late String _selectedTimeZone;
  late final List<String> _timeZoneOptions;

  LatLng? _pickedLocation;
  String? _address;
  String? _city;
  String? _countryCode;
  bool _isGeocoding = false;
  String? _resolvedAddressInput;
  BitmapDescriptor? _locationPinIcon;

  List<Spot> _linkedSpots = [];
  String? _linkedSpotListId;
  String? _linkedSpotListName;

  final List<Uint8List?> _selectedImageBytes = [];

  @override
  void initState() {
    super.initState();
    _selectedTimeZone = detectIanaTimeZone();
    _timeZoneOptions = EventScheduleUtils.availableTimeZoneIds();
    _pickedLocation = widget.initialLocation;
    if (widget.initialSpotId != null) {
      _linkedSpots = [
        Spot(
          id: widget.initialSpotId,
          name: widget.initialSpotName ?? widget.initialSpotId!,
          description: '',
          latitude: widget.initialLocation?.latitude ?? 0,
          longitude: widget.initialLocation?.longitude ?? 0,
        ),
      ];
    }
    _linkedSpotListId = widget.initialSpotListId;
    _linkedSpotListName = widget.initialSpotListName;
    _loadLocationPinIcon();
    if (_pickedLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _geocodeLocation(_pickedLocation!);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _locationAddressController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationPinIcon() async {
    final icon = await MarkerIconUtils.loadNormalSelectedMapPin();
    if (mounted) setState(() => _locationPinIcon = icon);
  }

  DateTime _displayInSelectedTimeZone(DateTime value) {
    return EventScheduleUtils.toDisplayDateTime(
      value,
      timeZone: _selectedTimeZone,
    );
  }

  String _timeZoneLabel(String value) {
    return EventScheduleUtils.formatTimeZoneLabel(
      value,
      referenceUtc: _startAt,
    );
  }

  Future<void> _geocodeLocation(LatLng location) async {
    if (!mounted) return;
    setState(() => _isGeocoding = true);
    try {
      final geocodingService = context.read<GeocodingService>();
      final result = await geocodingService.geocodeCoordinatesDetails(
        location.latitude,
        location.longitude,
      );
      if (!mounted) return;
      setState(() {
        _address = result['address'];
        _city = result['city'];
        _countryCode = result['countryCode'];
        final address = _address?.trim();
        if (address != null && address.isNotEmpty) {
          _locationAddressController.text = address;
          _resolvedAddressInput = address;
        }
      });
    } catch (_) {
      // Best-effort reverse geocoding.
    } finally {
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  Future<void> _linkSpotsOnMap() async {
    final result = await ExploreEntityPickerScreen.show(
      context,
      config: ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.spotsOnly,
        initialCenter: _pickedLocation,
      ),
    );
    if (result == null || !mounted) return;
    final spot = result.spot;
    if (spot == null) return;
    if (_linkedSpots.any((s) => s.id == spot.id)) return;
    setState(() => _linkedSpots.add(spot));
  }

  Future<void> _pickLocationOnMap() async {
    final result = await ExploreEntityPickerScreen.show(
      context,
      config: ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.locationOnly,
        initialLocation: _pickedLocation,
        usageTip: LocationPickerUsageTip.addEvent,
      ),
    );
    final latLng = result?.location;
    if (latLng == null || !mounted) return;
    setState(() {
      _pickedLocation = latLng;
    });
    await _geocodeLocation(latLng);
  }

  bool _typedAddressNeedsResolution() {
    final typed = _locationAddressController.text.trim();
    if (typed.isEmpty) return false;
    return typed != _resolvedAddressInput || _pickedLocation == null;
  }

  Future<bool> _resolveTypedAddress() async {
    final l10n = AppLocalizations.of(context)!;
    final typedAddress = _locationAddressController.text.trim();
    if (typedAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addEventAddressRequiredToResolve)),
      );
      return false;
    }

    setState(() => _isGeocoding = true);
    try {
      final geocodingService = context.read<GeocodingService>();
      final coords = await geocodingService.reverseGeocodeAddress(typedAddress);
      if (!mounted) return false;
      if (coords == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.addEventAddressNotFound)));
        return false;
      }
      final latitude = coords['latitude'];
      final longitude = coords['longitude'];
      if (latitude == null || longitude == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.addEventAddressNotFound)));
        return false;
      }

      final details = await geocodingService.geocodeCoordinatesDetails(
        latitude,
        longitude,
      );
      if (!mounted) return false;

      final resolvedAddress = details['address']?.trim();
      final acceptedAddress = resolvedAddress?.isNotEmpty == true
          ? resolvedAddress!
          : typedAddress;
      setState(() {
        _pickedLocation = LatLng(latitude, longitude);
        _address = acceptedAddress;
        _city = details['city'];
        _countryCode = details['countryCode'];
        _locationAddressController.text = acceptedAddress;
        _resolvedAddressInput = acceptedAddress;
      });
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.addEventAddressNotFound)));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _clearLocation() {
    setState(() {
      _pickedLocation = null;
      _address = null;
      _city = null;
      _countryCode = null;
      _resolvedAddressInput = null;
      _locationAddressController.clear();
    });
  }

  Future<void> _pickStartDateTime() async {
    if (_isDateOnly) {
      final initialDate = _displayInSelectedTimeZone(_startAt);
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime(
          initialDate.year,
          initialDate.month,
          initialDate.day,
        ),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );
      if (pickedDate == null || !mounted) return;
      final value = EventScheduleUtils.dateStartToUtc(
        pickedDate,
        timeZone: _selectedTimeZone,
      );
      setState(() {
        _startAt = value;
        if (_endAt != null && _endAt!.isBefore(_startAt)) {
          _endAt = _startAt;
        }
      });
      return;
    }

    final value = await _pickDateTime(initial: _startAt);
    if (value == null || !mounted) return;
    setState(() {
      _startAt = value;
      if (_endAt != null && _endAt!.isBefore(_startAt)) {
        _endAt = _startAt.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEndDateTime() async {
    if (_isDateOnly) {
      final initialDateTime = _displayInSelectedTimeZone(_endAt ?? _startAt);
      final pickedDate = await showDatePicker(
        context: context,
        initialDate: DateTime(
          initialDateTime.year,
          initialDateTime.month,
          initialDateTime.day,
        ),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );
      if (pickedDate == null || !mounted) return;
      setState(() {
        _endAt = EventScheduleUtils.dateEndToUtc(
          pickedDate,
          timeZone: _selectedTimeZone,
        );
      });
      return;
    }

    final value = await _pickDateTime(initial: _endAt ?? _startAt);
    if (value == null || !mounted) return;
    setState(() {
      _endAt = value;
    });
  }

  Future<DateTime?> _pickDateTime({required DateTime initial}) async {
    final displayInitial = _displayInSelectedTimeZone(initial);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: displayInitial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate == null || !mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(displayInitial),
    );
    if (pickedTime == null || !mounted) return null;

    return EventScheduleUtils.localDateTimeToUtc(
      DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
      timeZone: _selectedTimeZone,
    );
  }

  bool _hasValidWebsiteUrl() {
    final raw = _websiteController.text.trim();
    if (raw.isEmpty) return true;
    final uri = Uri.tryParse(raw);
    return uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https');
  }

  String _formatDateTime(DateTime value) {
    return EventScheduleUtils.formatSummaryLine(
      context,
      startAt: value,
      isDateOnly: _isDateOnly,
      timeZone: _selectedTimeZone,
    );
  }

  String? _effectiveAddressForSubmission() {
    final trimmed = _address?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (_pickedLocation == null) return null;
    final l10n = AppLocalizations.of(context)!;
    return l10n.addEventApproxCoordinates(
      _pickedLocation!.latitude.toStringAsFixed(5),
      _pickedLocation!.longitude.toStringAsFixed(5),
    );
  }

  Future<void> _pickImagesFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        var added = 0;
        for (final pickedFile in pickedFiles) {
          try {
            final bytes = await pickedFile.readAsBytes();
            final prepared = await prepareImageForUpload(bytes);
            _selectedImageBytes.add(prepared.bytes);
            added++;
          } on ImagePreparationException catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.message), backgroundColor: Colors.red),
              );
            }
          }
        }
        if (added > 0 && mounted) setState(() {});
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ImagePreparationException
                  ? e.message
                  : l10n.addSpotPickImagesFailed,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
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

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final prepared = await prepareImageForUpload(bytes);
        setState(() => _selectedImageBytes.add(prepared.bytes));
      }
    } on ImagePreparationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.addSpotTakePhotoFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      if (index < _selectedImageBytes.length) {
        _selectedImageBytes.removeAt(index);
      }
    });
  }

  void _reorderSelectedImage(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _selectedImageBytes.removeAt(oldIndex);
      _selectedImageBytes.insert(newIndex, item);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    if (!_hasValidWebsiteUrl()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addEventWebsiteInvalid)));
      return;
    }

    var normalizedStartAt = _startAt;
    var normalizedEndAt = _endAt;
    if (_isDateOnly) {
      final startDate = _displayInSelectedTimeZone(_startAt);
      normalizedStartAt = EventScheduleUtils.dateStartToUtc(
        startDate,
        timeZone: _selectedTimeZone,
      );
      final endDate = _displayInSelectedTimeZone(_endAt ?? _startAt);
      normalizedEndAt = EventScheduleUtils.dateEndToUtc(
        endDate,
        timeZone: _selectedTimeZone,
      );
    }

    if (normalizedEndAt != null &&
        normalizedEndAt.isBefore(normalizedStartAt)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addEventEndBeforeStart)));
      return;
    }

    if (_typedAddressNeedsResolution() && !await _resolveTypedAddress()) {
      return;
    }
    if (!mounted) return;

    final hasLinkedSpot = _linkedSpots.isNotEmpty;
    final hasLinkedList = _linkedSpotListId != null;
    final hasLocation = _pickedLocation != null;
    if (!hasLinkedSpot && !hasLinkedList && !hasLocation) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addEventNeedLocationOrLink)));
      return;
    }

    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null) {
      context.go('/login?redirectTo=${Uri.encodeComponent('/events/add')}');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final eventReportService = context.read<EventReportService>();
      List<String> suggestedPhotoUrls = const <String>[];
      final imageBytes = _selectedImageBytes.whereType<Uint8List>().toList(
        growable: false,
      );

      if (imageBytes.isNotEmpty) {
        if (imageBytes.length > EventReportService.maxSuggestedPhotos) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.addEventMaxPhotos(EventReportService.maxSuggestedPhotos),
              ),
            ),
          );
          return;
        }
        try {
          suggestedPhotoUrls = await eventReportService
              .uploadSuggestedEventPhotos(imageBytes);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e is ImagePreparationException
                    ? e.message
                    : l10n.addEventUploadPhotosFailed,
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      final success = await eventReportService.submitEventReport(
        title: _titleController.text,
        description: _descriptionController.text,
        websiteUrl: _websiteController.text.trim().isEmpty
            ? null
            : _websiteController.text.trim(),
        startAt: normalizedStartAt,
        endAt: normalizedEndAt,
        isDateOnly: _isDateOnly,
        timeZone: _selectedTimeZone,
        latitude: _pickedLocation?.latitude,
        longitude: _pickedLocation?.longitude,
        address: _effectiveAddressForSubmission(),
        city: _city,
        countryCode: _countryCode,
        spotIds: _linkedSpots
            .map((spot) => spot.id)
            .whereType<String>()
            .toList(),
        spotListIds: _linkedSpotListId == null
            ? const <String>[]
            : <String>[_linkedSpotListId!],
        linkedSpotName: _linkedSpots.isEmpty
            ? null
            : _linkedSpots.map((spot) => spot.name).join(', '),
        linkedSpotListName: _linkedSpotListName,
        reporterUserId: user.uid,
        reporterName:
            authService.userProfile?.displayName ??
            user.displayName ??
            user.email,
        reporterEmail: user.email,
        suggestedPhotoUrls: suggestedPhotoUrls,
      );

      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.addEventSubmitFailed)));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.addEventSubmitSuccess),
          backgroundColor: Colors.green,
        ),
      );

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop(true);
      } else {
        context.go('/explore?tab=add');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildLocationSection(AppLocalizations l10n, ThemeData theme) {
    final pickedLocation = _pickedLocation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.addEventLocationSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.addEventLocationSectionHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationAddressController,
              decoration: InputDecoration(
                labelText: l10n.addEventAddressLabel,
                hintText: l10n.addEventAddressHint,
                border: const OutlineInputBorder(),
                suffixIcon: _locationAddressController.text.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.addEventClearAddressTooltip,
                        onPressed: _isSubmitting || _isGeocoding
                            ? null
                            : () {
                                setState(() {
                                  _locationAddressController.clear();
                                  _address = null;
                                  _resolvedAddressInput = null;
                                });
                              },
                        icon: const Icon(Icons.clear),
                      ),
              ),
              enabled: !_isSubmitting && !_isGeocoding,
              keyboardType: TextInputType.streetAddress,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {
                  if (value.trim().isEmpty) {
                    _address = null;
                    _resolvedAddressInput = null;
                  }
                });
              },
              onFieldSubmitted: (_) {
                if (!_isSubmitting && !_isGeocoding) _resolveTypedAddress();
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmitting || _isGeocoding
                      ? null
                      : _resolveTypedAddress,
                  icon: _isGeocoding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(l10n.addEventUseAddressButton),
                ),
                FilledButton.icon(
                  onPressed: _isSubmitting || _isGeocoding
                      ? null
                      : _pickLocationOnMap,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: Text(l10n.addEventPickLocationButton),
                ),
                if (pickedLocation != null)
                  TextButton.icon(
                    onPressed: _isSubmitting || _isGeocoding
                        ? null
                        : _clearLocation,
                    icon: const Icon(Icons.clear),
                    label: Text(l10n.addEventClearLocationTooltip),
                  ),
              ],
            ),
            if (pickedLocation == null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l10n.addEventLocationNotSet)),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              _buildLocationPreviewMap(pickedLocation, l10n, theme),
              const SizedBox(height: 16),
              LocationInfoBox(
                latitude: pickedLocation.latitude,
                longitude: pickedLocation.longitude,
                address: _address,
                countryCode: _countryCode,
                isGeocoding: _isGeocoding,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPreviewMap(
    LatLng location,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            key: ValueKey(
              'event_location_${location.latitude}_${location.longitude}',
            ),
            initialCameraPosition: CameraPosition(target: location, zoom: 16),
            markers: {
              Marker(
                markerId: const MarkerId('selected_event_location'),
                position: location,
                icon: _locationPinIcon ?? BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 1.0),
                infoWindow: InfoWindow.noText,
              ),
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
            mapToolbarEnabled: false,
            liteModeEnabled: kIsWeb,
            compassEnabled: false,
            zoomGesturesEnabled: false,
            scrollGesturesEnabled: false,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
            onTap: (_) => _pickLocationOnMap(),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: PointerInterceptor(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      l10n.addSpotPickLocationHint,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return PageScaffold(
      title: l10n.addEventTitle,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  l10n.addEventModerationNotice,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.addEventTitleLabel,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return l10n.addEventTitleRequired;
                if (trimmed.length > 200) return l10n.addEventTitleTooLong;
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.addEventDescriptionLabel,
                border: const OutlineInputBorder(),
              ),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length > 2000) {
                  return l10n.addEventDescriptionTooLong;
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _websiteController,
              decoration: InputDecoration(
                labelText: l10n.addEventWebsiteLabel,
                hintText: l10n.addEventWebsiteHint,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            SpotImageSection(
              selectedImageBytes: _selectedImageBytes,
              existingImageUrls: const <String>[],
              onPickFromGallery: _pickImagesFromGallery,
              onTakePhoto: _takePhoto,
              onRemoveSelectedAt: _removeImageAt,
              onRemoveExistingAt: (_) {},
              onReorderSelected: _reorderSelectedImage,
              sectionTitle: l10n.addEventPhotosSectionTitle,
              showRequiredIndicator: false,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _isDateOnly,
              title: Text(l10n.addEventAllDay),
              onChanged: (value) {
                setState(() {
                  _isDateOnly = value;
                });
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedTimeZone,
              decoration: InputDecoration(
                labelText: l10n.addEventTimezoneLabel,
                border: const OutlineInputBorder(),
              ),
              items: _timeZoneOptions
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        _timeZoneLabel(value),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _selectedTimeZone = value);
                    },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.addEventStartLabel),
              subtitle: Text(_formatDateTime(_startAt)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickStartDateTime,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.addEventEndLabel),
              subtitle: Text(
                _endAt == null
                    ? l10n.addEventEndNotSet
                    : _formatDateTime(_endAt!),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_endAt != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.addEventClearEndTooltip,
                      onPressed: () => setState(() => _endAt = null),
                    ),
                  const Icon(Icons.edit_calendar),
                ],
              ),
              onTap: _pickEndDateTime,
            ),
            const Divider(height: 24),
            Text(
              l10n.addEventLinkingSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _linkSpotsOnMap,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: Text(l10n.addEventLinkSpotButton),
                ),
              ],
            ),
            if (_linkedSpots.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _linkedSpots
                    .map(
                      (spot) => Chip(
                        avatar: const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                        ),
                        label: Text(
                          l10n.addEventLinkedSpotLabel(
                            spot.name.isNotEmpty ? spot.name : (spot.id ?? ''),
                          ),
                        ),
                        onDeleted: _isSubmitting
                            ? null
                            : () => setState(
                                () => _linkedSpots.removeWhere(
                                  (s) => s.id == spot.id,
                                ),
                              ),
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_linkedSpotListId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  avatar: const Icon(Icons.list_alt_outlined, size: 18),
                  label: Text(
                    l10n.addEventLinkedSpotListLabel(
                      _linkedSpotListName?.isNotEmpty == true
                          ? _linkedSpotListName!
                          : _linkedSpotListId!,
                    ),
                  ),
                  onDeleted: () {
                    setState(() {
                      _linkedSpotListId = null;
                      _linkedSpotListName = null;
                    });
                  },
                ),
              ),
            const SizedBox(height: 12),
            _buildLocationSection(l10n, theme),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _isSubmitting
                    ? l10n.addEventSubmitting
                    : l10n.addEventSubmitButton,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
