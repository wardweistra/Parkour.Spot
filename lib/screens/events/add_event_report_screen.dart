import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/event_report_service.dart';
import '../../services/geocoding_service.dart';
import '../spots/location_picker_screen.dart';

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

  bool _isSubmitting = false;
  bool _isDateOnly = false;
  DateTime _startAt = DateTime.now().toUtc().add(const Duration(hours: 1));
  DateTime? _endAt;

  LatLng? _pickedLocation;
  String? _address;
  String? _city;
  String? _countryCode;
  bool _isGeocoding = false;

  String? _linkedSpotId;
  String? _linkedSpotName;
  String? _linkedSpotListId;
  String? _linkedSpotListName;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
    _linkedSpotId = widget.initialSpotId;
    _linkedSpotName = widget.initialSpotName;
    _linkedSpotListId = widget.initialSpotListId;
    _linkedSpotListName = widget.initialSpotListName;
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
    super.dispose();
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
      });
    } catch (_) {
      // Best-effort reverse geocoding.
    } finally {
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  Future<void> _pickLocationOnMap() async {
    final picked = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: _pickedLocation,
          showUsageTip: true,
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _pickedLocation = picked;
    });
    await _geocodeLocation(picked);
  }

  Future<void> _pickStartDateTime() async {
    final localStart = _startAt.toLocal();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: localStart,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate == null || !mounted) return;

    if (_isDateOnly) {
      final newStart = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      ).toUtc();
      setState(() {
        _startAt = newStart;
        if (_endAt != null && _endAt!.isBefore(_startAt)) {
          _endAt = _startAt;
        }
      });
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(localStart),
    );
    if (pickedTime == null || !mounted) return;

    final localDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final utcDateTime = localDateTime.toUtc();
    setState(() {
      _startAt = utcDateTime;
      if (_endAt != null && _endAt!.isBefore(_startAt)) {
        _endAt = _startAt.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEndDateTime() async {
    final localInitial = (_endAt ?? _startAt).toLocal();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: localInitial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate == null || !mounted) return;

    if (_isDateOnly) {
      final endDay = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        23,
        59,
        59,
      ).toUtc();
      setState(() {
        _endAt = endDay;
      });
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(localInitial),
    );
    if (pickedTime == null || !mounted) return;
    final localDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      _endAt = localDateTime.toUtc();
    });
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
    final local = value.toLocal();
    final date = MaterialLocalizations.of(context).formatMediumDate(local);
    if (_isDateOnly) return date;
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date · $time';
  }

  String? _effectiveAddressForSubmission() {
    final trimmed = _address?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (_pickedLocation == null) return null;
    return 'Approx. ${_pickedLocation!.latitude.toStringAsFixed(5)}, ${_pickedLocation!.longitude.toStringAsFixed(5)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasValidWebsiteUrl()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Website URL must be a valid http(s) URL.'),
        ),
      );
      return;
    }
    if (_endAt != null && _endAt!.isBefore(_startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time cannot be before start time.')),
      );
      return;
    }

    final hasLinkedSpot = _linkedSpotId != null;
    final hasLinkedList = _linkedSpotListId != null;
    final hasLocation = _pickedLocation != null;
    if (!hasLinkedSpot && !hasLinkedList && !hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Add a map location, link a spot, or link a spot list before submitting.',
          ),
        ),
      );
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
      final success = await context
          .read<EventReportService>()
          .submitEventReport(
            title: _titleController.text,
            description: _descriptionController.text,
            websiteUrl: _websiteController.text.trim().isEmpty
                ? null
                : _websiteController.text.trim(),
            startAt: _startAt,
            endAt: _endAt,
            isDateOnly: _isDateOnly,
            latitude: _pickedLocation?.latitude,
            longitude: _pickedLocation?.longitude,
            address: _effectiveAddressForSubmission(),
            city: _city,
            countryCode: _countryCode,
            spotIds: _linkedSpotId == null
                ? const <String>[]
                : <String>[_linkedSpotId!],
            spotListIds: _linkedSpotListId == null
                ? const <String>[]
                : <String>[_linkedSpotListId!],
            linkedSpotName: _linkedSpotName,
            linkedSpotListName: _linkedSpotListName,
            reporterUserId: user.uid,
            reporterName:
                authService.userProfile?.displayName ??
                user.displayName ??
                user.email,
            reporterEmail: user.email,
          );

      if (!mounted) return;
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not submit event proposal.')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Event submitted to the moderator queue.'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Add event')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Event proposals are reviewed by moderators before they become public.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Event title',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return 'Title is required.';
                if (trimmed.length > 200) return 'Title is too long.';
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
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length > 2000) {
                  return 'Description is too long.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _websiteController,
              decoration: const InputDecoration(
                labelText: 'Website URL (optional)',
                hintText: 'https://example.com',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _isDateOnly,
              title: const Text('All-day event'),
              onChanged: (value) {
                setState(() {
                  _isDateOnly = value;
                });
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start'),
              subtitle: Text(_formatDateTime(_startAt)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickStartDateTime,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End (optional)'),
              subtitle: Text(
                _endAt == null ? 'Not set' : _formatDateTime(_endAt!),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_endAt != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear end',
                      onPressed: () => setState(() => _endAt = null),
                    ),
                  const Icon(Icons.edit_calendar),
                ],
              ),
              onTap: _pickEndDateTime,
            ),
            const Divider(height: 24),
            Text('Linking', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_linkedSpotId != null)
              Chip(
                avatar: const Icon(Icons.location_on_outlined, size: 18),
                label: Text(
                  _linkedSpotName?.isNotEmpty == true
                      ? 'Spot: ${_linkedSpotName!}'
                      : 'Spot: $_linkedSpotId',
                ),
                onDeleted: () {
                  setState(() {
                    _linkedSpotId = null;
                    _linkedSpotName = null;
                  });
                },
              ),
            if (_linkedSpotListId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Chip(
                  avatar: const Icon(Icons.list_alt_outlined, size: 18),
                  label: Text(
                    _linkedSpotListName?.isNotEmpty == true
                        ? 'Spot list: ${_linkedSpotListName!}'
                        : 'Spot list: $_linkedSpotListId',
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
            Card(
              child: ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(
                  _pickedLocation == null
                      ? 'Location not set'
                      : '${_pickedLocation!.latitude.toStringAsFixed(5)}, ${_pickedLocation!.longitude.toStringAsFixed(5)}',
                ),
                subtitle: Text(
                  _isGeocoding
                      ? 'Loading address...'
                      : (_address?.isNotEmpty ?? false)
                      ? _address!
                      : 'Pick a location on the map (optional when linked spot/list exists).',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    if (_pickedLocation != null)
                      IconButton(
                        tooltip: 'Clear location',
                        onPressed: () {
                          setState(() {
                            _pickedLocation = null;
                            _address = null;
                            _city = null;
                            _countryCode = null;
                          });
                        },
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: 'Pick location',
                      onPressed: _pickLocationOnMap,
                      icon: const Icon(Icons.edit_location_alt_outlined),
                    ),
                  ],
                ),
              ),
            ),
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
                _isSubmitting ? 'Submitting...' : 'Submit for review',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
