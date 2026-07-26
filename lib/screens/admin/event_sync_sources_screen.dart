import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../services/event_sync_source_service.dart';
import '../../utils/event_schedule_utils.dart';

const TextStyle _kEventSyncChipLabelText = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.normal,
);

class EventSyncSourcesScreen extends StatefulWidget {
  const EventSyncSourcesScreen({super.key});

  @override
  State<EventSyncSourcesScreen> createState() => _EventSyncSourcesScreenState();
}

class _EventSyncSourcesScreenState extends State<EventSyncSourcesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<EventSyncSourceService>();
      if (service.sources.isEmpty && !service.isLoading) {
        service.fetchSources(includeInactive: true);
      }
    });
  }

  Future<void> _openEditDialog({EventSyncSource? source}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => EventSyncSourceEditDialog(source: source),
    );
    if (saved == true && mounted) {
      await context.read<EventSyncSourceService>().fetchSources(
        includeInactive: true,
      );
    }
  }

  Future<void> _runSyncForSource(EventSyncSource source) async {
    final service = context.read<EventSyncSourceService>();
    final result = await service.syncSource(source.id);
    if (!mounted) return;
    if (result != null) {
      final stats = result['stats'] as Map<dynamic, dynamic>?;
      final created = (stats?['created'] ?? 0).toString();
      final changed = (stats?['changed'] ?? 0).toString();
      final unchanged = (stats?['unchanged'] ?? 0).toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            '${source.name} synced. Created: $created, Changed: $changed, Unchanged: $unchanged',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(service.error ?? 'Failed to sync ${source.name}'),
        ),
      );
    }
  }

  Future<void> _runSyncAll() async {
    final service = context.read<EventSyncSourceService>();
    final result = await service.syncAllSources();
    if (!mounted) return;
    if (result != null) {
      final stats = result['totalStats'] as Map<dynamic, dynamic>?;
      final created = (stats?['created'] ?? 0).toString();
      final changed = (stats?['changed'] ?? 0).toString();
      final unchanged = (stats?['unchanged'] ?? 0).toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Event source sync complete. Created: $created, Changed: $changed, Unchanged: $unchanged',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(service.error ?? 'Failed to sync all event sources'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event Sync Sources')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Sync Sources'),
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
          Consumer<EventSyncSourceService>(
            builder: (context, service, _) {
              return IconButton(
                tooltip: 'Sync all active sources',
                icon: service.isSyncingAll
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                onPressed: service.isSyncingAll ? null : _runSyncAll,
              );
            },
          ),
          IconButton(
            tooltip: 'Add event source',
            icon: const Icon(Icons.add),
            onPressed: () => _openEditDialog(),
          ),
        ],
      ),
      body: Consumer<EventSyncSourceService>(
        builder: (context, service, _) {
          if (service.isLoading && service.sources.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (service.error != null && service.sources.isEmpty) {
            return Center(child: Text(service.error!));
          }

          if (service.sources.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => service.fetchSources(includeInactive: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 160),
                    child: Center(
                      child: Text('No event sources configured yet'),
                    ),
                  ),
                ],
              ),
            );
          }

          final sortedSources = [...service.sources]
            ..sort((a, b) => a.name.compareTo(b.name));
          return RefreshIndicator(
            onRefresh: () => service.fetchSources(includeInactive: true),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sortedSources.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final source = sortedSources[index];
                final isSyncing = service.syncingSources.contains(source.id);
                return Card(
                  child: ListTile(
                    title: Text(source.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (source.description?.trim().isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(source.description!.trim()),
                          ),
                        if (source.defaultTimeZone?.trim().isNotEmpty == true)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Default timezone: ${source.defaultTimeZone}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        SelectableText(
                          source.icsUrl,
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (source.publicUrl?.trim().isNotEmpty == true)
                          InkWell(
                            onTap: () async {
                              final uri = Uri.tryParse(
                                source.publicUrl!.trim(),
                              );
                              if (uri == null) return;
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(
                                  uri,
                                  mode: LaunchMode.externalApplication,
                                );
                              }
                            },
                            child: Text(
                              source.publicUrl!.trim(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Chip(
                              label: Text(
                                source.isWixPublishedCalendar
                                    ? 'Wix calendar'
                                    : 'ICS',
                              ),
                            ),
                            Chip(
                              label: Text(
                                source.isActive ? 'Active' : 'Inactive',
                              ),
                            ),
                            if (source.lastSyncAt != null)
                              Chip(
                                label: Text('Last sync: ${source.lastSyncAt}'),
                              ),
                            if (source.autoSyncEnabled == true)
                              Chip(
                                backgroundColor: Colors.green.shade100,
                                label: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.schedule, size: 16),
                                    SizedBox(width: 4),
                                    Text('Auto-Sync ON'),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        if (source.autoSyncEnabled == true &&
                            source.syncSchedule != null &&
                            source.syncSchedule!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Chip(
                            backgroundColor: Colors.blue.shade50,
                            label: Text(
                              'Schedule: ${source.syncSchedule}',
                              style: _kEventSyncChipLabelText,
                            ),
                          ),
                        ],
                        if (source.lastSyncStats != null)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _StatChip(
                                label: 'Created',
                                value: source.lastSyncStats!['created'],
                                color: Colors.green.shade100,
                              ),
                              _StatChip(
                                label: 'Changed',
                                value: source.lastSyncStats!['changed'],
                                color: Colors.blue.shade100,
                              ),
                              _StatChip(
                                label: 'Unchanged',
                                value: source.lastSyncStats!['unchanged'],
                                color: Colors.grey.shade200,
                              ),
                            ],
                          ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (source.isActive)
                          IconButton(
                            tooltip: 'Sync source',
                            icon: isSyncing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sync),
                            onPressed: isSyncing
                                ? null
                                : () => _runSyncForSource(source),
                          ),
                        PopupMenuButton<String>(
                          onSelected: (action) async {
                            switch (action) {
                              case 'edit':
                                await _openEditDialog(source: source);
                                return;
                              case 'toggleActive':
                                await context
                                    .read<EventSyncSourceService>()
                                    .updateSource(
                                      sourceId: source.id,
                                      isActive: !source.isActive,
                                    );
                                return;
                              case 'delete':
                                final eventSourceService = context
                                    .read<EventSyncSourceService>();
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: const Text('Delete event source'),
                                    content: Text('Delete "${source.name}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && mounted) {
                                  await eventSourceService.deleteSource(
                                    source.id,
                                  );
                                }
                                return;
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: 'toggleActive',
                              child: Text(
                                source.isActive ? 'Deactivate' : 'Activate',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class EventSyncSourceEditDialog extends StatefulWidget {
  final EventSyncSource? source;

  const EventSyncSourceEditDialog({super.key, this.source});

  @override
  State<EventSyncSourceEditDialog> createState() =>
      _EventSyncSourceEditDialogState();
}

class _EventSyncSourceEditDialogState extends State<EventSyncSourceEditDialog> {
  static const String _noDefaultTimeZoneValue = '';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _icsUrlCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _publicUrlCtrl;
  late final TextEditingController _syncScheduleCtrl;
  late final List<String> _defaultTimeZoneOptions;
  late String _selectedDefaultTimeZone;
  late String _sourceType;
  late bool _isActive;
  late bool _autoSyncEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    EventScheduleUtils.ensureTimeZonesInitialized();
    const commonTimeZones = <String>[
      'America/New_York',
      'America/Los_Angeles',
      'America/Chicago',
      'Europe/London',
    ];
    _defaultTimeZoneOptions = <String>[
      _noDefaultTimeZoneValue,
      ...commonTimeZones,
      ...EventScheduleUtils.availableTimeZoneIds().where(
        (timeZone) => !commonTimeZones.contains(timeZone),
      ),
    ];
    _nameCtrl = TextEditingController(text: widget.source?.name ?? '');
    _icsUrlCtrl = TextEditingController(text: widget.source?.icsUrl ?? '');
    _descriptionCtrl = TextEditingController(
      text: widget.source?.description ?? '',
    );
    _publicUrlCtrl = TextEditingController(
      text: widget.source?.publicUrl ?? '',
    );
    _syncScheduleCtrl = TextEditingController(
      text: widget.source?.syncSchedule ?? '',
    );
    _selectedDefaultTimeZone =
        EventScheduleUtils.normalizeTimeZone(widget.source?.defaultTimeZone) ??
        _noDefaultTimeZoneValue;
    _sourceType =
        widget.source?.sourceType ?? EventSyncSource.sourceTypeIcs;
    _isActive = widget.source?.isActive ?? true;
    _autoSyncEnabled = widget.source?.autoSyncEnabled ?? false;
  }

  bool get _isWixSourceType =>
      _sourceType == EventSyncSource.sourceTypeWixPublishedCalendar;

  String get _feedUrlLabel =>
      _isWixSourceType ? 'Published calendar URL' : 'ICS URL';

  String get _feedUrlHelperText => _isWixSourceType
      ? 'Full BoomTech/Wix published_calendar URL including the instance token'
      : 'Google Calendar public .ics URL';

  String get _defaultTimeZoneHelperText => _isWixSourceType
      ? 'Fallback when the published calendar has no time_zone. '
            'Re-sync after changing this.'
      : 'Used when the ICS feed has no calendar timezone. '
            'Re-sync after changing this.';

  String _defaultTimeZoneLabel(String value) {
    if (value == _noDefaultTimeZoneValue) {
      return 'None (UTC for all-day events)';
    }
    return EventScheduleUtils.formatTimeZoneLabel(value);
  }

  String? get _effectiveDefaultTimeZone {
    if (_selectedDefaultTimeZone == _noDefaultTimeZoneValue) return null;
    return EventScheduleUtils.normalizeTimeZone(_selectedDefaultTimeZone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _icsUrlCtrl.dispose();
    _descriptionCtrl.dispose();
    _publicUrlCtrl.dispose();
    _syncScheduleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.source == null ? 'Add Event Source' : 'Edit Event Source',
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _sourceType,
                  decoration: const InputDecoration(labelText: 'Source type'),
                  items: const [
                    DropdownMenuItem(
                      value: EventSyncSource.sourceTypeIcs,
                      child: Text('ICS feed'),
                    ),
                    DropdownMenuItem(
                      value: EventSyncSource.sourceTypeWixPublishedCalendar,
                      child: Text('Wix published calendar'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sourceType = value);
                  },
                ),
                TextFormField(
                  controller: _icsUrlCtrl,
                  decoration: InputDecoration(
                    labelText: _feedUrlLabel,
                    helperText: _feedUrlHelperText,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Required';
                    final uri = Uri.tryParse(trimmed);
                    if (uri == null || uri.host.isEmpty) return 'Invalid URL';
                    if (uri.scheme != 'http' && uri.scheme != 'https') {
                      return 'URL must start with http or https';
                    }
                    if (_isWixSourceType &&
                        !uri.path.contains('/api/published_calendar')) {
                      return 'URL must include /api/published_calendar';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                  maxLines: 3,
                ),
                TextFormField(
                  controller: _publicUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Public URL (optional)',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedDefaultTimeZone,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Default timezone for all-day events',
                    helperText: _defaultTimeZoneHelperText,
                  ),
                  items: _defaultTimeZoneOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            _defaultTimeZoneLabel(value),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _selectedDefaultTimeZone = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
                const Divider(),
                const Text(
                  'Auto-Sync Configuration',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable Auto-Sync'),
                  subtitle: const Text(
                    'Automatically sync this event source according to the schedule below',
                  ),
                  value: _autoSyncEnabled,
                  onChanged: (value) =>
                      setState(() => _autoSyncEnabled = value),
                ),
                TextFormField(
                  controller: _syncScheduleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sync Schedule (Cron)',
                    helperText:
                        'Cron expression (e.g., "0 */6 * * *" every 6 hours in UTC). Leave empty to disable schedule.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  final service = context.read<EventSyncSourceService>();
                  final navigator = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _isSaving = true);
                  final trimmedDescription = _descriptionCtrl.text.trim();
                  final trimmedPublicUrl = _publicUrlCtrl.text.trim();
                  final selectedDefaultTimeZone = _effectiveDefaultTimeZone;
                  final previousDefaultTimeZone =
                      EventScheduleUtils.normalizeTimeZone(
                        widget.source?.defaultTimeZone,
                      );

                  bool ok;
                  if (widget.source == null) {
                    ok = await service.createSource(
                      name: _nameCtrl.text.trim(),
                      icsUrl: _icsUrlCtrl.text.trim(),
                      sourceType: _sourceType,
                      description: trimmedDescription.isEmpty
                          ? null
                          : trimmedDescription,
                      publicUrl: trimmedPublicUrl.isEmpty
                          ? null
                          : trimmedPublicUrl,
                      isActive: _isActive,
                      syncSchedule: _syncScheduleCtrl.text.trim().isEmpty
                          ? null
                          : _syncScheduleCtrl.text.trim(),
                      autoSyncEnabled: _autoSyncEnabled,
                      defaultTimeZone: selectedDefaultTimeZone,
                    );
                  } else {
                    final defaultTimeZoneChanged =
                        selectedDefaultTimeZone != previousDefaultTimeZone;
                    ok = await service.updateSource(
                      sourceId: widget.source!.id,
                      name: _nameCtrl.text.trim(),
                      icsUrl: _icsUrlCtrl.text.trim(),
                      sourceType: _sourceType,
                      description: trimmedDescription,
                      publicUrl: trimmedPublicUrl,
                      isActive: _isActive,
                      syncSchedule: _syncScheduleCtrl.text.trim(),
                      autoSyncEnabled: _autoSyncEnabled,
                      defaultTimeZone: defaultTimeZoneChanged
                          ? selectedDefaultTimeZone
                          : null,
                      clearDefaultTimeZone: defaultTimeZoneChanged &&
                          selectedDefaultTimeZone == null,
                    );
                  }

                  if (!mounted) return;
                  setState(() => _isSaving = false);
                  messenger.showSnackBar(
                    SnackBar(content: Text(ok ? 'Saved' : 'Failed to save')),
                  );
                  if (ok) {
                    navigator.pop(true);
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final dynamic value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final number = value is num ? value.toInt() : 0;
    return Chip(backgroundColor: color, label: Text('$label: $number'));
  }
}
