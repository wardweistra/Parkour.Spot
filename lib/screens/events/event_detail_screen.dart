import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import '../../l10n/app_localizations.dart';
import '../../models/parkour_event.dart';
import '../../models/spot.dart';
import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../services/spot_service.dart';
import '../../widgets/event_selection_dialog.dart';
import '../../widgets/page_scaffold.dart';

/// Event detail page; loads the document from Firestore by [eventId].
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  ParkourEvent? _event;
  bool _loading = true;
  bool _loadError = false;

  ParkourEvent? _originalEvent;
  bool _loadingOriginal = false;
  List<ParkourEvent> _duplicateEvents = const [];
  bool _loadingDuplicates = false;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  @override
  void didUpdateWidget(covariant EventDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      _loadEvent();
    }
  }

  Future<void> _loadEvent() async {
    setState(() {
      _loading = true;
      _loadError = false;
      _event = null;
      _originalEvent = null;
      _duplicateEvents = const [];
      _loadingOriginal = false;
      _loadingDuplicates = false;
    });

    final admin = context.read<AdminEventsService>();
    try {
      final e = await admin.getEventById(widget.eventId);
      if (!mounted) return;
      if (e == null) {
        setState(() {
          _loading = false;
          _event = null;
        });
        return;
      }
      setState(() {
        _event = e;
        _loading = false;
      });
      if (kIsWeb) {
        final l10n = AppLocalizations.of(context);
        final brand = l10n?.exploreMetaDefaultTitle ?? 'Parkour·Spot';
        web.document.title = '${e.title} - $brand';
      }
      _attachDuplicateContext(e);
    } catch (e, st) {
      debugPrint('EventDetailScreen._loadEvent: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  void _attachDuplicateContext(ParkourEvent e) {
    final dup = e.duplicateOf?.trim();
    if (dup != null && dup.isNotEmpty) {
      _loadOriginal(dup);
    } else if (e.id != null) {
      _loadDuplicates(e.id!);
    }
  }

  Future<void> _loadOriginal(String originalId) async {
    setState(() => _loadingOriginal = true);
    final admin = context.read<AdminEventsService>();
    try {
      final o = await admin.getEventById(originalId);
      if (!mounted) return;
      setState(() {
        _originalEvent = o;
        _loadingOriginal = false;
      });
    } catch (e, st) {
      debugPrint('EventDetailScreen._loadOriginal: $e\n$st');
      if (!mounted) return;
      setState(() => _loadingOriginal = false);
    }
  }

  Future<void> _loadDuplicates(String eventId) async {
    setState(() => _loadingDuplicates = true);
    final admin = context.read<AdminEventsService>();
    try {
      final list = await admin.getEventsDuplicating(eventId);
      if (!mounted) return;
      setState(() {
        _duplicateEvents = list;
        _loadingDuplicates = false;
      });
    } catch (e, st) {
      debugPrint('EventDetailScreen._loadDuplicates: $e\n$st');
      if (!mounted) return;
      setState(() => _loadingDuplicates = false);
    }
  }

  Future<void> _reloadAfterMutation() async {
    await _loadEvent();
  }

  Future<void> _onAdminMenu(
    BuildContext context,
    _EventAdminAction action,
    ParkourEvent event,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated || !auth.isAdmin) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventDetailMarkDuplicateAdminOnly)),
      );
      return;
    }
    final id = event.id;
    if (id == null) return;

    switch (action) {
      case _EventAdminAction.markDuplicate:
        final originalId = await showDialog<String>(
          context: context,
          builder: (c) => EventSelectionDialog(currentEventId: id),
        );
        if (!context.mounted || originalId == null) return;
        final admin = context.read<AdminEventsService>();
        final origEvent = await admin.getEventById(originalId);
        if (!context.mounted || origEvent == null) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n.spotDetailMenuMarkDuplicate),
            content: Text(
              l10n.eventDetailMarkDuplicateConfirmBody(origEvent.title),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.profileCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(l10n.spotDetailConfirm),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        final ok = await admin.markEventAsDuplicate(
          duplicateEventId: id,
          nativeOriginalEventId: originalId,
        );
        if (!context.mounted) return;
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.eventDetailMarkDuplicateSuccess)),
          );
          await _reloadAfterMutation();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                admin.error ?? l10n.eventDetailMarkDuplicateNotFoundOrInvalid,
              ),
            ),
          );
        }
        break;
      case _EventAdminAction.removeDuplicate:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n.spotDetailMenuRemoveDuplicateStatus),
            content: Text(l10n.eventDetailRemoveDuplicateConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.profileCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(l10n.spotDetailRemoveButton),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        final admin = context.read<AdminEventsService>();
        final ok = await admin.clearEventDuplicateStatus(id);
        if (!context.mounted) return;
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.eventDetailRemoveDuplicateSuccess)),
          );
          await _reloadAfterMutation();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                admin.error ??
                    l10n.eventDetailMarkDuplicateNotFoundOrInvalid,
              ),
            ),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading event',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Please try again later',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final event = _event;
    if (event == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_busy_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                'Event not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/explore'),
                child: const Text('Go to Explore'),
              ),
            ],
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final auth = context.watch<AuthService>();
    final isAdmin = auth.isAuthenticated && auth.isAdmin;
    final dupId = event.duplicateOf?.trim();
    final hasDupLink = dupId != null && dupId.isNotEmpty;
    final showDupSection =
        hasDupLink ||
        _loadingOriginal ||
        _originalEvent != null ||
        _loadingDuplicates ||
        _duplicateEvents.isNotEmpty;

    return PageScaffold(
      title: event.title,
      onBack: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/explore');
        }
      },
      actions: [
        if (isAdmin)
          PopupMenuButton<_EventAdminAction>(
            tooltip: 'Admin',
            onSelected: (action) => _onAdminMenu(context, action, event),
            itemBuilder: (ctx) {
              final isDup = hasDupLink;
              final theme = Theme.of(ctx);
              return [
                PopupMenuItem(
                  value: _EventAdminAction.markDuplicate,
                  enabled: !isDup,
                  child: Text(
                    l10n.spotDetailMenuMarkDuplicate,
                    style: TextStyle(
                      color: isDup ? theme.colorScheme.onSurface.withValues(alpha: 0.38) : null,
                    ),
                  ),
                ),
                if (isDup)
                  PopupMenuItem(
                    value: _EventAdminAction.removeDuplicate,
                    child: Text(l10n.spotDetailMenuRemoveDuplicateStatus),
                  ),
              ];
            },
            child: const Icon(Icons.more_vert),
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDupSection) ...[
            if (hasDupLink || _originalEvent != null || _loadingOriginal) ...[
              GestureDetector(
                onTap: _loadingOriginal
                    ? null
                    : () {
                        final targetId = _originalEvent?.id ?? dupId;
                        if (targetId != null && targetId.isNotEmpty) {
                          context.push('/event/$targetId');
                        }
                      },
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.copy_all,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(l10n.spotDetailDuplicateOf),
                  subtitle: _loadingOriginal
                      ? Text(l10n.spotDetailLoading)
                      : Text(
                          _originalEvent?.title ??
                              l10n.eventDetailOriginalEventFallback,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                  trailing: Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
            if (!hasDupLink && _originalEvent == null && !_loadingOriginal) ...[
              if (_loadingDuplicates)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.copy_all,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  title: Text(l10n.spotDetailAlsoBasedOn),
                  subtitle: Text(l10n.spotDetailLoading),
                )
              else if (_duplicateEvents.isNotEmpty) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    Icons.copy_all,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  title: Text(
                    l10n.spotDetailAlsoBasedOnCount(_duplicateEvents.length),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ..._duplicateEvents.map((dup) {
                  final id = dup.id;
                  return GestureDetector(
                    onTap: id == null || id.isEmpty
                        ? null
                        : () => context.push('/event/$id'),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 48),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          Icons.arrow_right,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        title: Text(
                          dup.title,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        subtitle: dup.eventSourceName?.trim().isNotEmpty == true
                            ? Text(
                                dup.eventSourceName!.trim(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withValues(alpha: 0.7),
                                ),
                              )
                            : null,
                        trailing: Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ],
            const SizedBox(height: 16),
          ],
          ..._buildEventMainContent(context, event),
        ],
      ),
    );
  }

  List<Widget> _buildEventMainContent(BuildContext context, ParkourEvent event) {
    final websiteUrl = event.websiteUrl?.trim();
    final hasWebsite = websiteUrl != null && websiteUrl.isNotEmpty;
    final hasLocation = event.latitude != null && event.longitude != null;
    final hasAddress = event.address?.trim().isNotEmpty == true;
    final sourceName = event.eventSourceName?.trim();
    final hasSource = sourceName != null && sourceName.isNotEmpty;

    return [
      if (event.description?.trim().isNotEmpty == true) ...[
        Text(
          event.description!,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          Chip(
            avatar: const Icon(Icons.schedule, size: 16),
            label: Text(_formatUtc(event.startAt)),
          ),
          if (event.endAt != null)
            Chip(
              avatar: const Icon(Icons.hourglass_bottom, size: 16),
              label: Text(_formatUtc(event.endAt!)),
            ),
          Chip(
            avatar: const Icon(Icons.place_outlined, size: 16),
            label: Text('${event.spotIds.length} linked spot(s)'),
          ),
          if (hasSource)
            Chip(
              avatar: const Icon(Icons.sync, size: 16),
              label: Text(sourceName),
            ),
        ],
      ),
      if (hasSource &&
          (event.externalSyncLastSeenAt != null ||
              event.externalSyncLastChangedAt != null)) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (event.externalSyncLastSeenAt != null)
              Chip(
                avatar: const Icon(Icons.update, size: 16),
                label: Text(
                  'Seen: ${_formatUtc(event.externalSyncLastSeenAt!)}',
                ),
              ),
            if (event.externalSyncLastChangedAt != null)
              Chip(
                avatar: const Icon(Icons.edit_calendar, size: 16),
                label: Text(
                  'Changed: ${_formatUtc(event.externalSyncLastChangedAt!)}',
                ),
              ),
          ],
        ),
      ],
      if (event.imageUrls.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Images', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: event.imageUrls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  event.imageUrls[index],
                  width: 280,
                  height: 190,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 280,
                    height: 190,
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
        const SizedBox(height: 16),
        Text('Website', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _openExternal(websiteUrl),
          child: Text(
            websiteUrl,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
      if (hasLocation || hasAddress) ...[
        const SizedBox(height: 16),
        Text('Location', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          hasAddress
              ? event.address!.trim()
              : '${event.latitude!.toStringAsFixed(5)}, ${event.longitude!.toStringAsFixed(5)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (hasLocation)
          TextButton.icon(
            onPressed: () => _openMap(event.latitude!, event.longitude!),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open in maps'),
          ),
      ],
      const SizedBox(height: 16),
      Text('Linked spots', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      _LinkedSpotsSection(spotIds: event.spotIds),
      const SizedBox(height: 8),
      SelectableText(
        'Event ID: ${event.id ?? '(pending)'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ];
  }

  String _formatUtc(DateTime value) {
    return '${DateFormat.yMMMd().add_Hm().format(value.toUtc())} UTC';
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMap(double lat, double lng) async {
    final mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
  }
}

enum _EventAdminAction { markDuplicate, removeDuplicate }

class _LinkedSpotsSection extends StatefulWidget {
  const _LinkedSpotsSection({required this.spotIds});

  final List<String> spotIds;

  @override
  State<_LinkedSpotsSection> createState() => _LinkedSpotsSectionState();
}

class _LinkedSpotsSectionState extends State<_LinkedSpotsSection> {
  Future<List<Spot>>? _spotsFuture;

  @override
  void initState() {
    super.initState();
    _spotsFuture = _loadSpots();
  }

  @override
  void didUpdateWidget(covariant _LinkedSpotsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spotIds.join(',') != widget.spotIds.join(',')) {
      _spotsFuture = _loadSpots();
    }
  }

  Future<List<Spot>> _loadSpots() async {
    final spotService = context.read<SpotService>();
    final spots = await Future.wait(
      widget.spotIds.map(spotService.getSpotById),
    );
    return spots.whereType<Spot>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Spot>>(
      future: _spotsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final spots = snapshot.data ?? const <Spot>[];
        if (spots.isEmpty) {
          return const Text('No linked spots found.');
        }
        return Column(
          children: spots
              .map(
                (spot) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(spot.name),
                    subtitle: Text(spot.address ?? spot.city ?? spot.id ?? ''),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: spot.id == null
                        ? null
                        : () => context.push('/spot/${spot.id}'),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
