import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/parkour_event.dart';
import '../../models/spot.dart';
import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../services/spot_service.dart';
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
              required DateTime startAt,
              DateTime? endAt,
              required List<String> spotIds,
            }) async {
              final authService = context.read<AuthService>();
              final createdBy = authService.currentUser?.uid ?? 'unknown';
              return context.read<AdminEventsService>().createEvent(
                title: title,
                description: description,
                startAt: startAt,
                endAt: endAt,
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.title, style: Theme.of(context).textTheme.titleMedium),
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
            const SizedBox(height: 8),
            SelectableText(
              'Spot IDs: ${event.spotIds.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _formatUtc(DateTime value) {
    return '${DateFormat.yMMMd().add_Hm().format(value.toUtc())} UTC';
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
    required DateTime startAt,
    DateTime? endAt,
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

  DateTime _startAt = DateTime.now().toUtc().add(const Duration(hours: 1));
  DateTime? _endAt;
  bool _isSubmitting = false;
  String? _formError;
  final List<Spot> _linkedSpots = <Spot>[];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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

  Future<void> _submit() async {
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

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    final success = await widget.onCreate(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      startAt: _startAt,
      endAt: _endAt,
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
      _formError = context.read<AdminEventsService>().error ?? 'Create failed';
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
