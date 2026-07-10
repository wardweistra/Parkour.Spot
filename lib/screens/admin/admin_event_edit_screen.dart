import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/parkour_event.dart';
import '../../models/spot.dart';
import '../../models/spot_list.dart';
import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/search_state_service.dart';
import '../../services/spot_list_service.dart';
import '../../services/spot_service.dart';
import '../../utils/browser_timezone_utils.dart';
import '../../utils/event_location_utils.dart';
import '../../utils/event_schedule_utils.dart';
import '../../utils/image_preparation.dart';
import '../../utils/image_picker_utils.dart';
import '../../utils/location_permission_utils.dart';
import '../../utils/map_recentering_mixin.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_config.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_screen.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/spot_form/image_section.dart';
import '../../widgets/spot_form/location_section.dart';
import '../../widgets/spot_list_selection_dialog.dart';

class AdminEventEditScreen extends StatefulWidget {
  const AdminEventEditScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<AdminEventEditScreen> createState() => _AdminEventEditScreenState();
}

class _AdminEventEditScreenState extends State<AdminEventEditScreen>
    with MapRecenteringMixin {
  static const String _localTimeZoneValue = '__local__';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _locationAddressController =
      TextEditingController();
  final TextEditingController _scheduleDisplayController =
      TextEditingController();

  ParkourEvent? _event;
  DateTime _startAt = DateTime.now().toUtc();
  DateTime? _endAt;
  bool _isDateOnly = false;
  String _selectedTimeZone = _localTimeZoneValue;
  late final List<String> _timeZoneOptions;
  late final String _browserTimeZone;
  bool _timeZoneManuallySet = false;
  int _timeZoneLookupGeneration = 0;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isGeocoding = false;
  bool _isGettingLocation = false;
  bool _isSatelliteView = false;
  bool _isLocationPermissionDenied = false;
  bool _isSchedulePickerOpen = false;
  bool _scheduleDisplayInitialized = false;
  String? _formError;
  String? _currentCity;
  String? _currentCountryCode;
  String? _resolvedAddressInput;
  LatLng? _pickedLocation;
  Position? _currentPosition;
  late LatLng _mapFallbackCenter;
  final List<Spot> _linkedSpots = <Spot>[];
  final List<SpotList> _linkedLists = <SpotList>[];
  List<Spot> _linkedListSpots = <Spot>[];
  final List<Uint8List?> _selectedImageBytes = <Uint8List?>[];
  final List<String> _existingImageUrls = <String>[];
  SearchStateService? _searchStateServiceRef;

  @override
  void initState() {
    super.initState();
    _browserTimeZone = detectIanaTimeZone();
    _mapFallbackCenter = const LatLng(
      AppConfig.defaultMapCenterLat,
      AppConfig.defaultMapCenterLng,
    );
    _timeZoneOptions = <String>[
      _localTimeZoneValue,
      ...EventScheduleUtils.availableTimeZoneIds(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchStateServiceRef = Provider.of<SearchStateService>(
        context,
        listen: false,
      );
      _searchStateServiceRef!.addListener(_onSearchStateChanged);
      setState(() => _isSatelliteView = _searchStateServiceRef!.isSatellite);
      _loadEvent();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_scheduleDisplayInitialized && !_isLoading) {
      _scheduleDisplayInitialized = true;
      _syncScheduleDisplayControllers();
    }
    _recenterMapForDisplay();
  }

  @override
  void dispose() {
    _searchStateServiceRef?.removeListener(_onSearchStateChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _locationAddressController.dispose();
    _scheduleDisplayController.dispose();
    super.dispose();
  }

  void _onSearchStateChanged() {
    if (!mounted) return;
    final searchState = _searchStateServiceRef;
    if (searchState == null) return;
    setState(() => _isSatelliteView = searchState.isSatellite);
  }

  LatLng get _displayLocationForMap {
    if (_pickedLocation != null) return _pickedLocation!;
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    return _mapFallbackCenter;
  }

  List<Spot> get _mapDisplaySpots {
    final seen = <String>{};
    final spots = <Spot>[];

    void addSpot(Spot spot) {
      final key = spot.id ?? '${spot.name}_${spot.latitude}_${spot.longitude}';
      if (seen.add(key)) spots.add(spot);
    }

    for (final spot in _linkedSpots) {
      addSpot(spot);
    }
    for (final spot in _linkedListSpots) {
      addSpot(spot);
    }
    return spots;
  }

  List<LatLng> _mapMarkerLocations() {
    final locations = <LatLng>[];
    if (_pickedLocation != null) {
      locations.add(_pickedLocation!);
    }
    for (final spot in _mapDisplaySpots) {
      if (spotHasCoordinates(spot)) {
        locations.add(LatLng(spot.latitude, spot.longitude));
      }
    }
    if (locations.isNotEmpty) return locations;

    if (_currentPosition != null) {
      return [
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      ];
    }
    return [_mapFallbackCenter];
  }

  void _recenterMapForDisplay() {
    recenterMapForLocationsAfterBuild(_mapMarkerLocations());
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

    final listSpots = await _loadSpotsForLists(lists);

    if (!mounted) return;
    final address = event.address?.trim();
    setState(() {
      _event = event;
      _titleController.text = event.title;
      _descriptionController.text = event.description ?? '';
      _websiteController.text = event.websiteUrl ?? '';
      _locationAddressController.text = address ?? '';
      _resolvedAddressInput = address?.isNotEmpty == true ? address : null;
      if (event.latitude != null && event.longitude != null) {
        _pickedLocation = LatLng(event.latitude!, event.longitude!);
      }
      _currentCity = event.city;
      _currentCountryCode = event.countryCode;
      _startAt = event.startAt.toUtc();
      _endAt = event.endAt?.toUtc();
      _isDateOnly = event.isDateOnly;
      _selectedTimeZone = _selectionForTimeZone(event.timeZone);
      _linkedSpots
        ..clear()
        ..addAll(spots);
      _linkedLists
        ..clear()
        ..addAll(lists);
      _linkedListSpots = listSpots;
      _existingImageUrls
        ..clear()
        ..addAll(event.imageUrls);
      _isLoading = false;
    });
    _syncScheduleDisplayControllers();
    _scheduleDisplayInitialized = true;
    _recenterMapForDisplay();
  }

  Future<List<Spot>> _loadSpotsForLists(List<SpotList> lists) async {
    if (lists.isEmpty) return const [];
    final spotService = context.read<SpotService>();
    final loaded = <Spot>[];
    final seen = <String>{};
    for (final list in lists) {
      for (final spotId in list.effectiveSpotIds) {
        if (!seen.add(spotId)) continue;
        final spot = await spotService.getSpotById(spotId);
        if (spot != null) loaded.add(spot);
        if (!mounted) return loaded;
      }
    }
    return loaded;
  }

  Future<void> _reloadLinkedListSpots() async {
    final spots = await _loadSpotsForLists(_linkedLists);
    if (!mounted) return;
    setState(() => _linkedListSpots = spots);
    _recenterMapForDisplay();
    _syncTimeZoneFromLocation();
  }

  String _selectionForTimeZone(String? timeZone) {
    final normalized = EventScheduleUtils.normalizeTimeZone(timeZone);
    return normalized ?? _localTimeZoneValue;
  }

  String? get _effectiveTimeZone {
    if (_selectedTimeZone == _localTimeZoneValue) return null;
    return EventScheduleUtils.normalizeTimeZone(_selectedTimeZone);
  }

  DateTime _displayInSelectedTimeZone(DateTime value) {
    return EventScheduleUtils.toDisplayDateTime(
      value,
      timeZone: _effectiveTimeZone,
    );
  }

  String _timeZoneLabel(String value) {
    if (value == _localTimeZoneValue) {
      return 'Viewer local timezone (legacy)';
    }
    return EventScheduleUtils.formatTimeZoneLabel(
      value,
      referenceUtc: _startAt,
    );
  }

  String _timeZoneShortLabel(String value) {
    if (value == _localTimeZoneValue) {
      return 'Local (legacy)';
    }
    return EventScheduleUtils.formatTimeZoneShortLabel(
      value,
      referenceUtc: _startAt,
    );
  }

  void _syncScheduleDisplayControllers() {
    _scheduleDisplayController.text = EventScheduleUtils.formatSummaryLine(
      context,
      startAt: _startAt,
      endAt: _endAt,
      isDateOnly: _isDateOnly,
      timeZone: _effectiveTimeZone,
    );
  }

  Future<void> _withSchedulePickerLock(Future<void> Function() fn) async {
    _isSchedulePickerOpen = true;
    try {
      await fn();
    } finally {
      _isSchedulePickerOpen = false;
    }
  }

  DateTime _endAfterStartUtc({required DateTime startAtUtc}) {
    if (_isDateOnly) {
      final startLocal = _displayInSelectedTimeZone(startAtUtc);
      final nextLocalDate = DateTime(
        startLocal.year,
        startLocal.month,
        startLocal.day,
      ).add(const Duration(days: 1));
      return EventScheduleUtils.dateEndToUtc(
        nextLocalDate,
        timeZone: _effectiveTimeZone,
      );
    }

    return startAtUtc.add(const Duration(hours: 1));
  }

  InputDecoration _outlineFieldDecoration(
    ThemeData theme, {
    required String labelText,
    String? hintText,
  }) {
    final scheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(12);
    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      border: border(scheme.outline),
      enabledBorder: border(scheme.outline.withValues(alpha: 0.5)),
      focusedBorder: border(scheme.primary, width: 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, width: 2),
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
      hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
    );
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    DateTime? minUtc,
    String? dateHelpText,
    String? timeHelpText,
    String? dateCancelText,
    String? timeCancelText,
  }) async {
    final displayInitial = _displayInSelectedTimeZone(initial);
    final displayMin = minUtc == null ? null : _displayInSelectedTimeZone(minUtc);
    final pickedDate = await showDatePicker(
      context: context,
      helpText: dateHelpText,
      cancelText: dateCancelText,
      initialDate: displayInitial,
      firstDate: displayMin != null
          ? DateTime(displayMin.year, displayMin.month, displayMin.day)
          : DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      helpText: timeHelpText,
      cancelText: timeCancelText,
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
      timeZone: _effectiveTimeZone,
    );
  }

  Future<DateTime?> _pickStartSchedule(AppLocalizations l10n) async {
    if (_isDateOnly) {
      final initialDate = _displayInSelectedTimeZone(_startAt);
      final pickedDate = await showDatePicker(
        context: context,
        helpText: l10n.addEventSchedulePickStartDate,
        initialDate: DateTime(
          initialDate.year,
          initialDate.month,
          initialDate.day,
        ),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
      if (pickedDate == null || !mounted) return null;
      return EventScheduleUtils.dateStartToUtc(
        pickedDate,
        timeZone: _effectiveTimeZone,
      );
    }

    return _pickDateTime(
      initial: _startAt,
      dateHelpText: l10n.addEventSchedulePickStartDate,
      timeHelpText: l10n.addEventSchedulePickStartTime,
    );
  }

  Future<({DateTime? value, bool cancelled})> _pickEndSchedule(
    AppLocalizations l10n, {
    required DateTime startAtUtc,
    DateTime? initialEndUtc,
  }) async {
    final initialEnd =
        initialEndUtc ?? _endAfterStartUtc(startAtUtc: startAtUtc);

    if (_isDateOnly) {
      final initialDate = _displayInSelectedTimeZone(initialEnd);
      final minDate = _displayInSelectedTimeZone(startAtUtc);
      final pickedDate = await showDatePicker(
        context: context,
        helpText: l10n.addEventSchedulePickEndDateOptional,
        cancelText: l10n.addEventScheduleSkipEnd,
        initialDate: DateTime(
          initialDate.year,
          initialDate.month,
          initialDate.day,
        ),
        firstDate: DateTime(
          minDate.year,
          minDate.month,
          minDate.day,
        ),
        lastDate: DateTime(2100),
      );
      if (pickedDate == null || !mounted) {
        return (value: null, cancelled: true);
      }
      return (
        value: EventScheduleUtils.dateEndToUtc(
          pickedDate,
          timeZone: _effectiveTimeZone,
        ),
        cancelled: false,
      );
    }

    final picked = await _pickDateTime(
      initial: initialEnd,
      minUtc: startAtUtc,
      dateHelpText: l10n.addEventSchedulePickEndDateOptional,
      timeHelpText: l10n.addEventSchedulePickEndTimeOptional,
      dateCancelText: l10n.addEventScheduleSkipEnd,
      timeCancelText: l10n.addEventScheduleSkipEnd,
    );
    if (picked == null || !mounted) {
      return (value: null, cancelled: true);
    }

    final clamped = picked.isBefore(startAtUtc)
        ? _endAfterStartUtc(startAtUtc: startAtUtc)
        : picked;
    return (value: clamped, cancelled: false);
  }

  Future<void> _pickScheduleFromStart() async {
    await _withSchedulePickerLock(() async {
      final l10n = AppLocalizations.of(context)!;
      final newStart = await _pickStartSchedule(l10n);
      if (newStart == null || !mounted) return;

      final preservedEnd =
          _endAt != null && !_endAt!.isBefore(newStart) ? _endAt : null;
      final endResult = await _pickEndSchedule(
        l10n,
        startAtUtc: newStart,
        initialEndUtc: preservedEnd,
      );
      if (!mounted) return;

      setState(() {
        _startAt = newStart;
        _endAt = endResult.cancelled ? null : endResult.value;
        _syncScheduleDisplayControllers();
        _formError = null;
      });
    });
  }

  Future<void> _getCurrentLocation({bool setAsPickedPin = true}) async {
    if (_isSchedulePickerOpen) return;
    setState(() => _isGettingLocation = true);

    final permission = await LocationPermissionUtils.checkAndRequestPermission(
      context: context,
      showErrorMessages: setAsPickedPin,
    );
    final isPermissionGranted = LocationPermissionUtils.isPermissionGranted(
      permission,
    );

    if (mounted) {
      setState(() => _isLocationPermissionDenied = !isPermissionGranted);
    }

    if (!isPermissionGranted) {
      if (mounted) setState(() => _isGettingLocation = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = position;
        if (setAsPickedPin) {
          _pickedLocation = latLng;
        }
        _isLocationPermissionDenied = false;
      });
      _recenterMapForDisplay();
      if (setAsPickedPin) {
        _syncTimeZoneFromLocation();
      }
      await _geocodeLocation(latLng);
    } catch (_) {
      // Best-effort current location lookup.
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _geocodeLocation(LatLng location) async {
    if (!mounted) return;
    setState(() => _isGeocoding = true);
    try {
      final result = await context
          .read<GeocodingService>()
          .geocodeCoordinatesDetails(location.latitude, location.longitude);
      if (!mounted) return;
      setState(() {
        _currentCity = result['city'];
        _currentCountryCode = result['countryCode'];
        final address = result['address']?.trim();
        if (address != null && address.isNotEmpty) {
          _locationAddressController.text = address;
          _resolvedAddressInput = address;
        }
      });
    } catch (_) {
      // Best-effort reverse geocoding.
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<void> _syncTimeZoneFromLocation() async {
    if (!mounted ||
        _timeZoneManuallySet ||
        _selectedTimeZone == _localTimeZoneValue) {
      return;
    }

    final generation = ++_timeZoneLookupGeneration;
    final coordinates = resolveEventTimezoneCoordinates(
      pickedLocation: _pickedLocation,
      linkedSpots: _linkedSpots,
      linkedSpotListSpots: _linkedListSpots,
    );

    if (coordinates == null) {
      if (!mounted || generation != _timeZoneLookupGeneration) return;
      setState(() {
        _selectedTimeZone = _browserTimeZone;
        _syncScheduleDisplayControllers();
      });
      return;
    }

    try {
      final geocodingService = context.read<GeocodingService>();
      final rawTimeZone = await geocodingService.lookupTimeZone(
        coordinates.latitude,
        coordinates.longitude,
      );
      final normalized = EventScheduleUtils.normalizeTimeZone(rawTimeZone);
      if (!mounted || generation != _timeZoneLookupGeneration) return;
      if (normalized == null) return;
      setState(() {
        _selectedTimeZone = normalized;
        if (!_timeZoneOptions.contains(normalized)) {
          _timeZoneOptions.insert(1, normalized);
        }
        _syncScheduleDisplayControllers();
      });
    } catch (_) {
      // Best-effort timezone lookup.
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
    setState(() {
      _linkedSpots.add(spot);
      _formError = null;
    });
    _recenterMapForDisplay();
    _syncTimeZoneFromLocation();
  }

  Future<void> _pickLocationOnMap() async {
    if (_isSchedulePickerOpen) return;
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
      _currentPosition = null;
      _currentCity = null;
      _currentCountryCode = null;
      _resolvedAddressInput = null;
      _locationAddressController.clear();
      _formError = null;
    });
    _recenterMapForDisplay();
    await _geocodeLocation(latLng);
    _syncTimeZoneFromLocation();
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
      setState(() => _formError = l10n.addEventAddressRequiredToResolve);
      return false;
    }

    setState(() {
      _isGeocoding = true;
      _formError = null;
    });
    try {
      final geocodingService = context.read<GeocodingService>();
      final result = await geocodingService.reverseGeocodeAddress(typedAddress);
      if (!mounted) return false;
      final latitude = result?['latitude'] as double?;
      final longitude = result?['longitude'] as double?;
      if (latitude == null || longitude == null) {
        setState(() => _formError = l10n.addEventAddressNotFound);
        return false;
      }
      final formattedAddress = (result?['address'] as String?)?.trim();
      final acceptedAddress = typedAddress.isNotEmpty
          ? typedAddress
          : (formattedAddress?.isNotEmpty == true ? formattedAddress! : '');
      setState(() {
        _pickedLocation = LatLng(latitude, longitude);
        _locationAddressController.text = acceptedAddress;
        _resolvedAddressInput = acceptedAddress;
        _currentCity = result?['city'] as String?;
        _currentCountryCode = result?['countryCode'] as String?;
        _currentPosition = null;
      });
      _recenterMapForDisplay();
      _syncTimeZoneFromLocation();
      return true;
    } catch (_) {
      if (mounted) setState(() => _formError = l10n.addEventAddressNotFound);
      return false;
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _clearLocation() {
    setState(() {
      _pickedLocation = null;
      _currentPosition = null;
      _currentCity = null;
      _currentCountryCode = null;
      _resolvedAddressInput = null;
      _locationAddressController.clear();
      _formError = null;
    });
    _recenterMapForDisplay();
    _syncTimeZoneFromLocation();
  }

  Widget _buildLocationAddressSuffixIcon({
    required AppLocalizations l10n,
    required bool fieldsEnabled,
    required bool hasSelectedPin,
  }) {
    if (_isGeocoding) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final needsResolve = _typedAddressNeedsResolution();
    final showSearch = needsResolve || !hasSelectedPin;
    final showClear = hasSelectedPin;

    Widget searchButton() => IconButton(
      icon: const Icon(Icons.search),
      tooltip: l10n.addEventUseAddressButton,
      onPressed: fieldsEnabled ? _resolveTypedAddress : null,
    );

    Widget clearButton() => IconButton(
      icon: const Icon(Icons.clear),
      tooltip: l10n.addEventClearLocationTooltip,
      onPressed: fieldsEnabled ? _clearLocation : null,
    );

    if (showSearch && showClear) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [searchButton(), clearButton()],
      );
    }
    if (showSearch) return searchButton();
    return clearButton();
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
    await _reloadLinkedListSpots();
  }

  Future<void> _pickFromGallery() async {
    try {
      final pickedFiles = await pickImagesFromGallery();
      if (pickedFiles.isEmpty) return;

      for (final pickedFile in pickedFiles) {
        try {
          final bytes = await pickedFile.readAsBytes();
          final prepared = await preparePickedImageBytes(bytes);
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
      final pickedFile = await pickImage(source: ImageSource.camera);
      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final prepared = await preparePickedImageBytes(bytes);
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

  Future<bool> _backfillCityCountryFromCoordinates() async {
    final location = _pickedLocation;
    if (location == null) return true;

    final hasCity = _currentCity?.trim().isNotEmpty == true;
    final hasCountryCode = _currentCountryCode?.trim().isNotEmpty == true;
    if (hasCity && hasCountryCode) return true;

    setState(() {
      _isGeocoding = true;
      _formError = null;
    });
    try {
      final details = await context
          .read<GeocodingService>()
          .geocodeCoordinatesDetails(location.latitude, location.longitude);
      if (!mounted) return false;

      final resolvedCity = details['city']?.trim();
      final resolvedCountryCode = details['countryCode']?.trim().toUpperCase();
      setState(() {
        if (resolvedCity?.isNotEmpty == true && !hasCity) {
          _currentCity = resolvedCity;
        }
        if (resolvedCountryCode?.isNotEmpty == true && !hasCountryCode) {
          _currentCountryCode = resolvedCountryCode;
        }
      });
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

  bool _hasLinkedSpotLocation() =>
      _linkedSpots.isNotEmpty || _linkedLists.isNotEmpty;

  Future<void> _applyCityCountryFromFirstLinkedSpotIfNeeded() async {
    if (eventHasDirectLocation(
      latitude: _pickedLocation?.latitude,
      longitude: _pickedLocation?.longitude,
      address: _locationAddressController.text,
    )) {
      return;
    }
    if (_linkedSpots.isEmpty && _linkedLists.isEmpty) return;

    var linkedSpotListSpots = _linkedListSpots;
    if (_linkedSpots.isEmpty &&
        linkedSpotListSpots.isEmpty &&
        _linkedLists.isNotEmpty) {
      final spotIds = _linkedLists.first.effectiveSpotIds;
      if (spotIds.isEmpty) return;
      final spot = await context.read<SpotService>().getSpotById(spotIds.first);
      if (!mounted) return;
      if (spot != null) linkedSpotListSpots = [spot];
    }

    final resolved = resolveEventCityCountryFromLinkedSpots(
      latitude: _pickedLocation?.latitude,
      longitude: _pickedLocation?.longitude,
      address: _locationAddressController.text,
      city: _currentCity,
      countryCode: _currentCountryCode,
      linkedSpots: _linkedSpots,
      linkedSpotListSpots: linkedSpotListSpots,
    );
    if (resolved.city == null && resolved.countryCode == null) return;

    setState(() {
      if (resolved.city != null) _currentCity = resolved.city;
      if (resolved.countryCode != null) {
        _currentCountryCode = resolved.countryCode;
      }
    });
  }

  String? _effectiveAddressForSubmission() {
    final trimmed = _locationAddressController.text.trim();
    if (trimmed.isNotEmpty) return trimmed;
    if (_pickedLocation == null) return null;
    final l10n = AppLocalizations.of(context)!;
    return l10n.addEventApproxCoordinates(
      _pickedLocation!.latitude.toStringAsFixed(5),
      _pickedLocation!.longitude.toStringAsFixed(5),
    );
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    if (!_canEditLoadedEvent(auth)) return;

    final eventsService = context.read<AdminEventsService>();
    if (!_formKey.currentState!.validate()) return;

    if (_typedAddressNeedsResolution() && !await _resolveTypedAddress()) {
      return;
    }
    if (!mounted) return;

    if (_pickedLocation != null && !await _backfillCityCountryFromCoordinates()) {
      return;
    }
    if (!mounted) return;

    final timeZone = _effectiveTimeZone;
    DateTime normalizedStartAt = _startAt;
    DateTime? normalizedEndAt = _endAt;
    if (_isDateOnly) {
      final startDate = _displayInSelectedTimeZone(_startAt);
      normalizedStartAt = EventScheduleUtils.dateStartToUtc(
        startDate,
        timeZone: timeZone,
      );
      final endDate = _displayInSelectedTimeZone(_endAt ?? _startAt);
      normalizedEndAt = EventScheduleUtils.dateEndToUtc(
        endDate,
        timeZone: timeZone,
      );
    }
    if (normalizedEndAt != null &&
        normalizedEndAt.isBefore(normalizedStartAt)) {
      setState(() => _formError = l10n.addEventEndBeforeStart);
      return;
    }

    await _applyCityCountryFromFirstLinkedSpotIfNeeded();
    if (!mounted) return;

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
      startAt: normalizedStartAt,
      endAt: normalizedEndAt,
      isDateOnly: _isDateOnly,
      timeZone: timeZone,
      latitude: _pickedLocation?.latitude,
      longitude: _pickedLocation?.longitude,
      address: _effectiveAddressForSubmission(),
      city: _currentCity,
      countryCode: _currentCountryCode,
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

  Widget _buildEventBasicsSection(
    AppLocalizations l10n,
    bool fieldsEnabled,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _titleController,
              labelText: l10n.addEventTitleLabel,
              prefixIcon: Icons.event_outlined,
              textCapitalization: TextCapitalization.words,
              enabled: fieldsEnabled,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return l10n.addEventTitleRequired;
                if (trimmed.length > 200) return l10n.addEventTitleTooLong;
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _descriptionController,
              labelText: l10n.addEventDescriptionLabel,
              prefixIcon: Icons.description_outlined,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              enabled: fieldsEnabled,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length > 2000) {
                  return l10n.addEventDescriptionTooLong;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _websiteController,
              labelText: l10n.addEventWebsiteLabel,
              hintText: l10n.addEventWebsiteHint,
              prefixIcon: Icons.link,
              keyboardType: TextInputType.url,
              enabled: fieldsEnabled,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhereSection(AppLocalizations l10n, ThemeData theme) {
    final fieldsEnabled = !_isSubmitting && !_isGeocoding;
    final hasSelectedPin = _pickedLocation != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.addEventWhereSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.addEventLocationSectionHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_hasLinkedSpotLocation()) ...[
              const SizedBox(height: 8),
              Text(
                'This event is linked to a spot or list. Clear the event '
                'location so the map only shows linked pins.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: _isSubmitting ? null : _linkSpotsOnMap,
                  icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                  label: Text(l10n.addEventLinkSpotButton),
                ),
                TextButton.icon(
                  onPressed: _isSubmitting ? null : _addLinkedList,
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: Text(l10n.adminEventAddSpotList),
                ),
              ],
            ),
            if (_linkedSpots.isNotEmpty || _linkedLists.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ..._linkedSpots.map(
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
                          : () {
                              setState(
                                () => _linkedSpots.removeWhere(
                                  (s) => s.id == spot.id,
                                ),
                              );
                              _recenterMapForDisplay();
                              _syncTimeZoneFromLocation();
                            },
                    ),
                  ),
                  ..._linkedLists.map(
                    (list) => Chip(
                      avatar: const Icon(Icons.list_alt_outlined, size: 18),
                      label: Text(
                        l10n.addEventLinkedSpotListLabel(
                          list.name.isNotEmpty ? list.name : (list.id ?? ''),
                        ),
                      ),
                      onDeleted: _isSubmitting
                          ? null
                          : () async {
                              setState(
                                () => _linkedLists.removeWhere(
                                  (l) => l.id == list.id,
                                ),
                              );
                              await _reloadLinkedListSpots();
                            },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SpotLocationSection(
              embedded: true,
              showRequiredIndicator: false,
              showSelectedPin: hasSelectedPin,
              showLocationDetails: false,
              mapHeroTagPrefix: 'adminEventEdit',
              linkedSpots: _mapDisplaySpots,
              currentLocation: _displayLocationForMap,
              address: null,
              countryCode: null,
              isGettingLocation: _isGettingLocation,
              isGeocoding: false,
              isSatelliteView: _isSatelliteView,
              isLocationPermissionDenied: _isLocationPermissionDenied,
              onRefreshLocation: () => _getCurrentLocation(setAsPickedPin: true),
              onPickOnMap: _pickLocationOnMap,
              onToggleSatellite: (value) {
                if (_isSchedulePickerOpen) return;
                setState(() => _isSatelliteView = value);
                final searchState = Provider.of<SearchStateService>(
                  context,
                  listen: false,
                );
                searchState.setSatellite(value);
              },
              onMapCreated: onMapCreated,
            ),
            if (!hasSelectedPin) ...[
              const SizedBox(height: 8),
              Text(
                l10n.addEventLocationNotSet,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            CustomTextField(
              controller: _locationAddressController,
              labelText: l10n.addEventAddressLabel,
              hintText: l10n.addEventAddressHint,
              prefixIcon: Icons.place_outlined,
              keyboardType: TextInputType.streetAddress,
              textInputAction: TextInputAction.search,
              enabled: fieldsEnabled,
              onChanged: (value) {
                setState(() {
                  if (value.trim().isEmpty) {
                    _resolvedAddressInput = null;
                  }
                  _formError = null;
                });
              },
              onFieldSubmitted: (_) {
                if (fieldsEnabled) _resolveTypedAddress();
              },
              suffixIconWidget: _buildLocationAddressSuffixIcon(
                l10n: l10n,
                fieldsEnabled: fieldsEnabled,
                hasSelectedPin: hasSelectedPin,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhenSection(AppLocalizations l10n, ThemeData theme) {
    final fieldsEnabled = !_isSubmitting;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.addEventWhenSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDateOnly,
              title: Text(l10n.addEventAllDay),
              onChanged: fieldsEnabled
                  ? (value) {
                      setState(() {
                        _isDateOnly = value;
                        _syncScheduleDisplayControllers();
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _scheduleDisplayController,
              labelText: l10n.addEventScheduleLabel,
              prefixIcon: Icons.date_range_outlined,
              readOnly: true,
              enabled: fieldsEnabled,
              onTap: fieldsEnabled ? _pickScheduleFromStart : null,
              suffixIcon: _endAt == null ? Icons.edit_calendar : null,
              suffixIconWidget: _endAt == null
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          tooltip: l10n.addEventClearEndTooltip,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          onPressed: fieldsEnabled
                              ? () => setState(() {
                                  _endAt = null;
                                  _syncScheduleDisplayControllers();
                                })
                              : null,
                        ),
                        const Icon(Icons.edit_calendar),
                        const SizedBox(width: 8),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedTimeZone,
              decoration: _outlineFieldDecoration(
                theme,
                labelText: l10n.addEventTimezoneLabel,
              ),
              selectedItemBuilder: (context) {
                return _timeZoneOptions
                    .map(
                      (value) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _timeZoneShortLabel(value),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList();
              },
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
              onChanged: fieldsEnabled
                  ? (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedTimeZone = value;
                        _timeZoneManuallySet = true;
                        _syncScheduleDisplayControllers();
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm(AppLocalizations l10n, AuthService auth) {
    final theme = Theme.of(context);
    final fieldsEnabled = !_isSubmitting;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_event!.isNativeEvent && auth.isAdmin) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sync,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.adminEventExternalSyncWarningTitle,
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.adminEventExternalSyncWarningBody,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildEventBasicsSection(l10n, fieldsEnabled),
          const SizedBox(height: 16),
          _buildWhereSection(l10n, theme),
          const SizedBox(height: 16),
          _buildWhenSection(l10n, theme),
          const SizedBox(height: 16),
          SpotImageSection(
            selectedImageBytes: _selectedImageBytes,
            existingImageUrls: _existingImageUrls,
            sectionTitle: l10n.addEventPhotosSectionTitle,
            showRequiredIndicator: false,
            onPickFromGallery: _pickFromGallery,
            onTakePhoto: _takePhoto,
            onRemoveSelectedAt: _removeSelectedImageAt,
            onRemoveExistingAt: _removeExistingImageAt,
            onReorderExisting: _reorderExistingImage,
            onReorderSelected: _reorderSelectedImage,
          ),
          if (_formError != null) ...[
            const SizedBox(height: 16),
            Text(
              _formError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          CustomButton(
            onPressed: _isSubmitting ? null : _save,
            text: _isSubmitting ? l10n.addEventSubmitting : l10n.adminEventEditSave,
            isLoading: _isSubmitting,
            icon: Icons.save_outlined,
            width: double.infinity,
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
      return PageScaffold(
        title: l10n.adminEventEditTitle,
        body: const Center(
          child: Text('Moderator or administrator access required'),
        ),
      );
    }

    final isModeratorOnly = auth.isModerator && !auth.isAdmin;
    final isExternalBlocked =
        !_isLoading &&
        _event != null &&
        !_event!.isNativeEvent &&
        isModeratorOnly;

    if (_isLoading) {
      return PageScaffold(
        title: l10n.adminEventEditTitle,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_event == null) {
      return PageScaffold(
        title: l10n.adminEventEditTitle,
        body: Center(child: Text(_formError ?? 'Event not found')),
      );
    }

    if (isExternalBlocked) {
      return PageScaffold(
        title: l10n.adminEventEditTitle,
        body: _buildExternalSourceBlockedBody(l10n),
      );
    }

    return PageScaffold(
      title: l10n.adminEventEditTitle,
      body: _buildEditForm(l10n, auth),
    );
  }
}
