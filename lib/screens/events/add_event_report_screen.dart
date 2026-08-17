import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/spot.dart';
import '../../services/auth_service.dart';
import '../../services/event_report_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/search_state_service.dart';
import '../../services/spot_list_service.dart';
import '../../services/spot_service.dart';
import '../../utils/browser_timezone_utils.dart';
import '../../utils/event_location_utils.dart';
import '../../utils/event_schedule_utils.dart';
import '../../utils/image_preparation.dart';
import '../../utils/image_picker_utils.dart';
import '../../utils/ui_yield.dart';
import '../../utils/location_permission_utils.dart';
import '../../utils/map_recentering_mixin.dart';
import '../../utils/pointer_interceptor_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_config.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_screen.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/spot_form/image_section.dart';
import '../../widgets/spot_form/location_section.dart';

class AddEventReportScreen extends StatefulWidget {
  const AddEventReportScreen({
    super.key,
    this.initialLocation,
    this.initialLinkedSpot,
    this.initialSpotId,
    this.initialSpotName,
    this.initialSpotListId,
    this.initialSpotListName,
    this.initialSpotListSpots,
  });

  final LatLng? initialLocation;
  final Spot? initialLinkedSpot;
  final String? initialSpotId;
  final String? initialSpotName;
  final String? initialSpotListId;
  final String? initialSpotListName;
  final List<Spot>? initialSpotListSpots;

  @override
  State<AddEventReportScreen> createState() => _AddEventReportScreenState();
}

class _AddEventReportScreenState extends State<AddEventReportScreen>
    with MapRecenteringMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  final _locationAddressController = TextEditingController();
  final _scheduleDisplayController = TextEditingController();

  bool _isSubmitting = false;
  bool _isDateOnly = true;
  // Used to prevent click-through interactions on the embedded Google Map while
  // the schedule pickers (date/time) are open.
  bool _isSchedulePickerOpen = false;
  DateTime _startAt = DateTime.now().toUtc().add(const Duration(hours: 1));
  DateTime? _endAt;
  late String _selectedTimeZone;
  late final String _browserTimeZone;
  late final List<String> _timeZoneOptions;
  bool _timeZoneManuallySet = false;
  int _timeZoneLookupGeneration = 0;

  LatLng? _pickedLocation;

  /// Last-known GPS. Kept after a pin/spots are chosen so clearing where
  /// can recenter like the first open of Add event.
  Position? _currentPosition;
  late LatLng _mapFallbackCenter;
  String? _address;
  String? _city;
  String? _countryCode;
  bool _isGeocoding = false;
  bool _isGettingLocation = false;
  bool _isSatelliteView = false;
  bool _isLocationPermissionDenied = false;
  String? _resolvedAddressInput;
  SearchStateService? _searchStateServiceRef;
  AuthService? _authServiceRef;

  List<Spot> _linkedSpots = [];
  List<Spot> _linkedSpotListSpots = [];
  String? _linkedSpotListId;
  String? _linkedSpotListName;

  final List<PreparedImage?> _selectedImages = [];
  bool _isPreparingImages = false;
  bool _isUploadingImages = false;
  String? _imageProcessingMessage;
  bool _scheduleDisplayInitialized = false;

  LatLng? get _gpsLatLng {
    final position = _currentPosition;
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  bool get _hasSelectedWhere =>
      _pickedLocation != null ||
      _linkedSpots.isNotEmpty ||
      _linkedSpotListId != null;

  LatLng get _displayLocationForMap {
    return _pickedLocation ?? _gpsLatLng ?? _mapFallbackCenter;
  }

  bool _spotHasCoordinates(Spot spot) => spotHasCoordinates(spot);

  List<Spot> _readSpotList(List<Spot> Function() read) {
    try {
      return List<Spot>.from(read());
    } catch (_) {
      return const [];
    }
  }

  List<Spot> get _mapDisplaySpots {
    final seen = <String>{};
    final spots = <Spot>[];

    void addSpot(Spot spot) {
      final key = spot.id ?? '${spot.name}_${spot.latitude}_${spot.longitude}';
      if (seen.add(key)) spots.add(spot);
    }

    for (final spot in _readSpotList(() => _linkedSpots)) {
      addSpot(spot);
    }
    for (final spot in _readSpotList(() => _linkedSpotListSpots)) {
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
      if (_spotHasCoordinates(spot)) {
        locations.add(LatLng(spot.latitude, spot.longitude));
      }
    }
    if (locations.isNotEmpty) return locations;
    return [_gpsLatLng ?? _mapFallbackCenter];
  }

  void _recenterMapForDisplay() {
    recenterMapForLocationsAfterBuild(_mapMarkerLocations());
  }

  @override
  void onMapControllerReady() {
    recenterMapForLocations(_mapMarkerLocations());
  }

  @override
  void initState() {
    super.initState();
    _browserTimeZone = detectIanaTimeZone();
    _selectedTimeZone = _browserTimeZone;
    _timeZoneOptions = EventScheduleUtils.availableTimeZoneIds();
    _pickedLocation = widget.initialLocation;
    if (widget.initialLinkedSpot != null) {
      _linkedSpots = [widget.initialLinkedSpot!];
    } else if (widget.initialSpotId != null) {
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
    if (widget.initialSpotListSpots != null &&
        widget.initialSpotListSpots!.isNotEmpty) {
      _linkedSpotListSpots = List<Spot>.from(widget.initialSpotListSpots!);
    }
    final collapsed = collapseEventWhere(
      pin: _pickedLocation,
      spots: _linkedSpots,
      spotListIds: [
        if (_linkedSpotListId != null && _linkedSpotListId!.trim().isNotEmpty)
          _linkedSpotListId!,
      ],
    );
    _pickedLocation = collapsed.pin;
    _linkedSpots = List<Spot>.from(collapsed.spots);
    if (collapsed.kind != EventWhereKind.list) {
      _linkedSpotListId = null;
      _linkedSpotListName = null;
      _linkedSpotListSpots = [];
    }
    _mapFallbackCenter = const LatLng(
      AppConfig.defaultMapCenterLat,
      AppConfig.defaultMapCenterLng,
    );
    final whereSpots = _mapDisplaySpots.where(_spotHasCoordinates);
    if (whereSpots.isNotEmpty) {
      _mapFallbackCenter = LatLng(
        whereSpots.first.latitude,
        whereSpots.first.longitude,
      );
    }
    if (_pickedLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _geocodeLocation(_pickedLocation!);
      });
    } else if (_mapDisplaySpots.isEmpty && _linkedSpotListId == null) {
      _getCurrentLocation(setAsPickedPin: false);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchStateServiceRef = Provider.of<SearchStateService>(
        context,
        listen: false,
      );
      _searchStateServiceRef!.addListener(_onSearchStateChanged);
      setState(() => _isSatelliteView = _searchStateServiceRef!.isSatellite);

      _authServiceRef = Provider.of<AuthService>(context, listen: false);
      _authServiceRef!.addListener(_onAuthChanged);
    });
    _titleController.addListener(_onFormFieldChanged);
    _websiteController.addListener(_onFormFieldChanged);
    _locationAddressController.addListener(_onFormFieldChanged);
    if (_linkedSpotListId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_linkedSpotListSpots.isNotEmpty) {
          _recenterMapForDisplay();
          _syncTimeZoneFromLocation();
        } else {
          _loadLinkedSpotListSpots();
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTimeZoneFromLocation();
    });
  }

  void _onAuthChanged() {
    if (!mounted ||
        _linkedSpotListId == null ||
        _linkedSpotListSpots.isNotEmpty) {
      return;
    }
    final authService = _authServiceRef;
    if (authService == null || !authService.isAuthenticated) return;
    _loadLinkedSpotListSpots();
  }

  Future<void> _loadLinkedSpotListSpots() async {
    final listId = _linkedSpotListId;
    if (listId == null) {
      if (_linkedSpotListSpots.isNotEmpty && mounted) {
        setState(() => _linkedSpotListSpots = []);
        _recenterMapForDisplay();
        _syncTimeZoneFromLocation();
      }
      return;
    }

    if (_linkedSpotListSpots.isNotEmpty) {
      _recenterMapForDisplay();
      return;
    }

    try {
      final spotListService = context.read<SpotListService>();
      final spotService = context.read<SpotService>();
      final list = await spotListService.getSpotListById(listId);
      if (!mounted || _linkedSpotListId != listId) return;

      final spotIds = list?.effectiveSpotIds ?? const <String>[];
      if (spotIds.isEmpty) {
        setState(() => _linkedSpotListSpots = []);
        _recenterMapForDisplay();
        _syncTimeZoneFromLocation();
        return;
      }

      final loadedSpots = <Spot>[];
      for (final spotId in spotIds) {
        final spot = await spotService.getSpotById(spotId);
        if (spot != null) loadedSpots.add(spot);
        if (!mounted || _linkedSpotListId != listId) return;
      }

      setState(() => _linkedSpotListSpots = loadedSpots);
      _recenterMapForDisplay();
      _syncTimeZoneFromLocation();
    } catch (e) {
      debugPrint('Failed to load linked spot list spots: $e');
      if (!mounted || _linkedSpotListId != listId) return;
      setState(() => _linkedSpotListSpots = []);
      _syncTimeZoneFromLocation();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_scheduleDisplayInitialized) {
      _scheduleDisplayInitialized = true;
      _syncScheduleDisplayControllers();
    }
    _recenterMapForDisplay();
  }

  @override
  void dispose() {
    _titleController.removeListener(_onFormFieldChanged);
    _websiteController.removeListener(_onFormFieldChanged);
    _locationAddressController.removeListener(_onFormFieldChanged);
    _searchStateServiceRef?.removeListener(_onSearchStateChanged);
    _authServiceRef?.removeListener(_onAuthChanged);
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

  void _syncScheduleDisplayControllers() {
    _scheduleDisplayController.text = EventScheduleUtils.formatSummaryLine(
      context,
      startAt: _startAt,
      endAt: _endAt,
      isDateOnly: _isDateOnly,
      timeZone: _selectedTimeZone,
    );
  }

  Future<void> _withSchedulePickerLock(Future<void> Function() fn) async {
    setState(() => _isSchedulePickerOpen = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _isSchedulePickerOpen = false);
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
        timeZone: _selectedTimeZone,
      );
    }

    return startAtUtc.add(const Duration(hours: 1));
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
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
        builder: interceptingPickerBuilder,
      );
      if (pickedDate == null || !mounted) return null;
      return EventScheduleUtils.dateStartToUtc(
        pickedDate,
        timeZone: _selectedTimeZone,
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
        firstDate: DateTime(minDate.year, minDate.month, minDate.day),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
        builder: interceptingPickerBuilder,
      );
      if (pickedDate == null || !mounted) {
        return (value: null, cancelled: true);
      }
      return (
        value: EventScheduleUtils.dateEndToUtc(
          pickedDate,
          timeZone: _selectedTimeZone,
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

      final preservedEnd = _endAt != null && !_endAt!.isBefore(newStart)
          ? _endAt
          : null;
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
      });
    });
  }

  void _onFormFieldChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasTitle => _titleController.text.trim().isNotEmpty;

  bool get _hasLocationOrLink =>
      _linkedSpots.isNotEmpty ||
      _linkedSpotListId != null ||
      _pickedLocation != null;

  bool get _canSubmit =>
      !_isSubmitting &&
      !_isPreparingImages &&
      !_isUploadingImages &&
      _hasLocationOrLink &&
      !_typedAddressNeedsResolution() &&
      _hasTitle &&
      _hasValidWebsiteUrl();

  String? _submitBlockReason(AppLocalizations l10n) {
    if (_isPreparingImages || _isUploadingImages) {
      return l10n.publicProfileProcessingImage;
    }
    if (!_hasLocationOrLink) return l10n.addEventNeedLocationOrLink;
    if (_typedAddressNeedsResolution()) return l10n.addEventAddressNeedsResolve;
    if (!_hasTitle) return l10n.addEventTitleRequired;
    if (!_hasValidWebsiteUrl()) return l10n.addEventWebsiteInvalid;
    return null;
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
        _mapFallbackCenter = latLng;
        if (setAsPickedPin) {
          _applyPinType(latLng, notify: false);
        }
        _isLocationPermissionDenied = false;
      });
      _recenterMapForDisplay();
      if (setAsPickedPin) {
        _syncTimeZoneFromLocation();
      }
      await _geocodeLocation(latLng, bindToForm: setAsPickedPin);
    } catch (e) {
      if (mounted && setAsPickedPin) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.exploreLocationError('$e'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
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

  String _timeZoneShortLabel(String value) {
    return EventScheduleUtils.formatTimeZoneShortLabel(
      value,
      referenceUtc: _startAt,
    );
  }

  Future<void> _geocodeLocation(
    LatLng location, {
    bool bindToForm = true,
  }) async {
    if (!mounted) return;
    if (!bindToForm) return;
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
        } else {
          _locationAddressController.clear();
          _resolvedAddressInput = null;
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

  Future<void> _syncTimeZoneFromLocation() async {
    if (!mounted || _timeZoneManuallySet) return;

    final generation = ++_timeZoneLookupGeneration;
    final coordinates = resolveEventTimezoneCoordinates(
      pickedLocation: _pickedLocation,
      linkedSpots: _linkedSpots,
      linkedSpotListSpots: _linkedSpotListSpots,
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
          _timeZoneOptions.insert(0, normalized);
        }
        _syncScheduleDisplayControllers();
      });
    } catch (_) {
      // Best-effort timezone lookup.
    }
  }

  void _showWhereReplacedSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _clearPinFields({required bool notify}) {
    _pickedLocation = null;
    _address = null;
    _city = null;
    _countryCode = null;
    _resolvedAddressInput = null;
    _locationAddressController.clear();
    if (notify) setState(() {});
  }

  void _clearSpotFields() {
    _linkedSpots = [];
  }

  void _clearListFields() {
    _linkedSpotListId = null;
    _linkedSpotListName = null;
    _linkedSpotListSpots = [];
  }

  void _applyPinType(LatLng latLng, {bool notify = true}) {
    final replacedListName = _linkedSpotListId == null
        ? null
        : _linkedSpotListName?.trim();
    final replacedSpots = _linkedSpots.isNotEmpty;
    _pickedLocation = latLng;
    _clearSpotFields();
    _clearListFields();
    if (notify) {
      setState(() {});
      final l10n = AppLocalizations.of(context)!;
      if (replacedListName != null && replacedListName.isNotEmpty) {
        _showWhereReplacedSnack(
          l10n.addEventWhereReplacedListWithLocation(replacedListName),
        );
      } else if (replacedSpots) {
        _showWhereReplacedSnack(l10n.addEventWhereReplacedSpots);
      }
    }
  }

  void _applySpotsType(List<Spot> spots) {
    final replacedListName = _linkedSpotListId == null
        ? null
        : _linkedSpotListName?.trim();
    final replacedPin = _pickedLocation != null;
    _linkedSpots = List<Spot>.from(spots);
    _clearListFields();
    _clearPinFields(notify: false);
    setState(() {});
    final l10n = AppLocalizations.of(context)!;
    if (replacedListName != null && replacedListName.isNotEmpty) {
      _showWhereReplacedSnack(
        l10n.addEventWhereReplacedListWithSpots(replacedListName),
      );
    } else if (replacedPin) {
      _showWhereReplacedSnack(l10n.addEventWhereReplacedLocation);
    }
  }

  Future<void> _ensureGpsForEmptyWhere() async {
    if (_hasSelectedWhere) return;
    if (_currentPosition != null || _isLocationPermissionDenied) return;
    await _getCurrentLocation(setAsPickedPin: false);
  }

  void _restoreEmptyWhereMapCenter() {
    _recenterMapForDisplay();
    _syncTimeZoneFromLocation();
    _ensureGpsForEmptyWhere();
  }

  Future<void> _openEventWherePicker() async {
    if (_isSchedulePickerOpen) return;
    await _ensureGpsForEmptyWhere();
    if (!mounted) return;
    final listFit = _linkedSpotListId == null
        ? const <LatLng>[]
        : _mapDisplaySpots
              .where(spotHasCoordinates)
              .map((spot) => LatLng(spot.latitude, spot.longitude))
              .toList(growable: false);
    final result = await ExploreEntityPickerScreen.show(
      context,
      config: ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.eventWhere,
        initialLocation: _pickedLocation,
        initialSpots: List<Spot>.from(_linkedSpots),
        initialCenter: resolveEventWherePickerCenter(
          pin: _pickedLocation,
          gps: _gpsLatLng,
        ),
        cameraFitLocations: listFit,
        linkedSpotListName: _linkedSpotListId == null
            ? null
            : _linkedSpotListName,
        usageTip: LocationPickerUsageTip.addEvent,
      ),
    );
    if (result == null || !mounted) return;
    if (result.spots.isNotEmpty) {
      _applySpotsType(result.spots);
      _recenterMapForDisplay();
      _syncTimeZoneFromLocation();
      return;
    }
    final latLng = result.location;
    if (latLng == null) return;
    _applyPinType(latLng);
    _recenterMapForDisplay();
    await _geocodeLocation(latLng);
    _syncTimeZoneFromLocation();
  }

  bool _typedAddressNeedsResolution() {
    if (_linkedSpots.isNotEmpty || _linkedSpotListId != null) {
      return false;
    }
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
      final result = await geocodingService.reverseGeocodeAddress(typedAddress);
      if (!mounted) return false;
      if (result == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.addEventAddressNotFound)));
        return false;
      }
      final latitude = result['latitude'] as double?;
      final longitude = result['longitude'] as double?;
      if (latitude == null || longitude == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.addEventAddressNotFound)));
        return false;
      }

      final formattedAddress = (result['address'] as String?)?.trim();
      final acceptedAddress = typedAddress.isNotEmpty
          ? typedAddress
          : (formattedAddress?.isNotEmpty == true ? formattedAddress! : '');
      setState(() {
        _applyPinType(LatLng(latitude, longitude), notify: false);
        _pickedLocation = LatLng(latitude, longitude);
        _address = acceptedAddress;
        _city = result['city'] as String?;
        _countryCode = result['countryCode'] as String?;
        _locationAddressController.text = acceptedAddress;
        _resolvedAddressInput = acceptedAddress;
      });
      _recenterMapForDisplay();
      _syncTimeZoneFromLocation();
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
    _restoreEmptyWhereMapCenter();
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

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    DateTime? minUtc,
    String? dateHelpText,
    String? timeHelpText,
    String? dateCancelText,
    String? timeCancelText,
  }) async {
    final displayInitial = _displayInSelectedTimeZone(initial);
    final displayMin = minUtc == null
        ? null
        : _displayInSelectedTimeZone(minUtc);
    final pickedDate = await showDatePicker(
      context: context,
      helpText: dateHelpText,
      cancelText: dateCancelText,
      initialDate: displayInitial,
      firstDate: displayMin != null
          ? DateTime(displayMin.year, displayMin.month, displayMin.day)
          : DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: interceptingPickerBuilder,
    );
    if (pickedDate == null || !mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      helpText: timeHelpText,
      cancelText: timeCancelText,
      initialTime: TimeOfDay.fromDateTime(displayInitial),
      builder: interceptingPickerBuilder,
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
    final l10n = AppLocalizations.of(context)!;

    List<XFile> pickedFiles;
    try {
      pickedFiles = await pickImagesFromGallery();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.addSpotPickImagesFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted || pickedFiles.isEmpty) return;

    setState(() {
      _isPreparingImages = true;
      _imageProcessingMessage = l10n.publicProfileProcessingImage;
    });
    await yieldToUi();

    try {
      final preparedImages = await preparePickedFiles(
        pickedFiles,
        onProgress: ({required current, required total, required phase}) {
          if (!mounted) return;
          setState(() {
            _imageProcessingMessage =
                '${l10n.publicProfileProcessingImage} ${imagePickProgressLabel(current, total)}';
          });
        },
      );

      if (!mounted) return;

      if (preparedImages.isNotEmpty) {
        setState(() {
          for (final prepared in preparedImages) {
            _selectedImages.add(prepared);
          }
        });
      }
    } on ImagePreparationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
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
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingImages = false;
          _imageProcessingMessage = null;
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    final l10n = AppLocalizations.of(context)!;

    final pickedFile = await pickImage(source: ImageSource.camera);
    if (!mounted || pickedFile == null) return;

    setState(() {
      _isPreparingImages = true;
      _imageProcessingMessage = l10n.publicProfileProcessingImage;
    });
    await yieldToUi();

    try {
      final preparedImages = await preparePickedFiles([
        pickedFile,
      ], maxImages: 1);
      if (preparedImages.isNotEmpty && mounted) {
        setState(() => _selectedImages.add(preparedImages.first));
      }
    } on ImagePreparationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.addSpotTakePhotoFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingImages = false;
          _imageProcessingMessage = null;
        });
      }
    }
  }

  void _removeImageAt(int index) {
    setState(() {
      if (index < _selectedImages.length) {
        _selectedImages.removeAt(index);
      }
    });
  }

  void _reorderSelectedImage(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _selectedImages.removeAt(oldIndex);
      _selectedImages.insert(newIndex, item);
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;

    if (_isPreparingImages || _isUploadingImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.publicProfileProcessingImage)),
      );
      return;
    }

    if (!_hasLocationOrLink) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addEventNeedLocationOrLink)));
      return;
    }

    if (_typedAddressNeedsResolution() && !await _resolveTypedAddress()) {
      return;
    }
    if (!mounted) return;

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

    if (!_formKey.currentState!.validate()) return;

    if (!_hasValidWebsiteUrl()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.addEventWebsiteInvalid)));
      return;
    }

    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    if (user == null) {
      context.go('/login?redirectTo=${Uri.encodeComponent('/events/add')}');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isUploadingImages = true;
      _imageProcessingMessage = l10n.publicProfileUploading;
    });
    await yieldToUi();
    try {
      final eventReportService = context.read<EventReportService>();
      List<String> suggestedPhotoUrls = const <String>[];
      final preparedPhotos = _selectedImages.whereType<PreparedImage>().toList(
        growable: false,
      );

      if (preparedPhotos.isNotEmpty) {
        if (preparedPhotos.length > EventReportService.maxSuggestedPhotos) {
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
          suggestedPhotoUrls = await eventReportService.uploadSuggestedEventPhotos(
            preparedPhotos,
            onProgress: (current, total) {
              if (!mounted) return;
              setState(() {
                _imageProcessingMessage =
                    '${l10n.publicProfileUploading} ${imagePickProgressLabel(current, total)}';
              });
            },
          );
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

      final collapsed = collapseEventWhere(
        pin: _pickedLocation,
        spots: _linkedSpots,
        spotListIds: [
          if (_linkedSpotListId != null && _linkedSpotListId!.trim().isNotEmpty)
            _linkedSpotListId!,
        ],
      );
      final isPin = collapsed.kind == EventWhereKind.pin;
      final isSpots = collapsed.kind == EventWhereKind.spots;
      final isList = collapsed.kind == EventWhereKind.list;
      final pin = collapsed.pin;
      final resolvedCityCountry = resolveEventCityCountryFromLinkedSpots(
        latitude: isPin ? pin?.latitude : null,
        longitude: isPin ? pin?.longitude : null,
        address: isPin ? _effectiveAddressForSubmission() : null,
        city: isPin ? _city : null,
        countryCode: isPin ? _countryCode : null,
        linkedSpots: collapsed.spots,
        linkedSpotListSpots: isList ? _linkedSpotListSpots : const <Spot>[],
      );

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
        latitude: isPin ? pin?.latitude : null,
        longitude: isPin ? pin?.longitude : null,
        address: isPin ? _effectiveAddressForSubmission() : null,
        city: resolvedCityCountry.city,
        countryCode: resolvedCityCountry.countryCode,
        spotIds: isSpots
            ? collapsed.spots
                  .map((spot) => spot.id)
                  .whereType<String>()
                  .toList()
            : const <String>[],
        spotListIds: isList ? collapsed.spotListIds : const <String>[],
        linkedSpotName: isSpots && collapsed.spots.isNotEmpty
            ? collapsed.spots.map((spot) => spot.name).join(', ')
            : null,
        linkedSpotListName: isList ? _linkedSpotListName : null,
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
        setState(() {
          _isSubmitting = false;
          _isUploadingImages = false;
          _imageProcessingMessage = null;
        });
      }
    }
  }

  List<Uint8List?> get _selectedImageBytes =>
      _selectedImages.map((image) => image?.bytes).toList();

  Widget _buildWhereSection(AppLocalizations l10n, ThemeData theme) {
    final fieldsEnabled = !_isSubmitting && !_isGeocoding;
    final hasSelectedPin = _pickedLocation != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SpotLocationSection(
              embedded: true,
              sectionTitle: l10n.addEventWhereSectionTitle,
              showSelectedPin: hasSelectedPin,
              showLocationDetails: false,
              mapHeroTagPrefix: 'addEvent',
              linkedSpots: _mapDisplaySpots,
              currentLocation: _displayLocationForMap,
              address: null,
              countryCode: null,
              isGettingLocation: _isGettingLocation,
              isGeocoding: false,
              isSatelliteView: _isSatelliteView,
              isLocationPermissionDenied: _isLocationPermissionDenied,
              blockMapPointers: _isSchedulePickerOpen,
              pickOnMapHint: l10n.addEventChooseOnMapHint,
              onRefreshLocation: () =>
                  _getCurrentLocation(setAsPickedPin: true),
              onPickOnMap: _openEventWherePicker,
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
            if (!hasSelectedPin &&
                _linkedSpots.isEmpty &&
                _linkedSpotListId == null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.addEventLocationNotSet,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else if (hasSelectedPin) ...[
              const SizedBox(height: 8),
              Text(
                l10n.addEventExactLocationSet,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ..._linkedSpots.map(
                    (spot) => Chip(
                      avatar: const Icon(Icons.location_on_outlined, size: 18),
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
                              _restoreEmptyWhereMapCenter();
                            },
                    ),
                  ),
                  if (_linkedSpotListId != null)
                    Chip(
                      avatar: const Icon(Icons.list_alt_outlined, size: 18),
                      label: Text(
                        l10n.addEventLinkedSpotListLabel(
                          _linkedSpotListName?.isNotEmpty == true
                              ? _linkedSpotListName!
                              : _linkedSpotListId!,
                        ),
                      ),
                      onDeleted: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _linkedSpotListId = null;
                                _linkedSpotListName = null;
                                _linkedSpotListSpots = [];
                              });
                              _restoreEmptyWhereMapCenter();
                            },
                    ),
                ],
              ),
            ],
            if (hasSelectedPin) ...[
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
                      _address = null;
                      _resolvedAddressInput = null;
                    }
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
          ],
        ),
      ),
    );
  }

  Widget _buildEventBasicsSection(AppLocalizations l10n, bool fieldsEnabled) {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final submitBlockReason = _submitBlockReason(l10n);
    final fieldsEnabled = !_isSubmitting;

    return PageScaffold(
      title: l10n.addEventTitle,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildWhereSection(l10n, theme),
            const SizedBox(height: 16),
            _buildEventBasicsSection(l10n, fieldsEnabled),
            const SizedBox(height: 16),
            _buildWhenSection(l10n, theme),
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
              isProcessingImages: _isPreparingImages || _isUploadingImages,
              processingMessage: _imageProcessingMessage,
            ),
            const SizedBox(height: 24),
            if (submitBlockReason != null) ...[
              Text(
                submitBlockReason,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
            ],
            CustomButton(
              onPressed: _canSubmit ? _submit : null,
              text: _isSubmitting
                  ? l10n.addEventSubmitting
                  : l10n.addEventSubmitButton,
              isLoading: _isSubmitting,
              icon: Icons.send_outlined,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}
