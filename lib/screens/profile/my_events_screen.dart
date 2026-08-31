import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/event_interest.dart';
import '../../models/parkour_event.dart';
import '../../services/auth_service.dart';
import '../../services/event_interest_service.dart';
import '../../utils/event_interest_utils.dart';
import '../../utils/event_schedule_utils.dart';
import '../../widgets/page_scaffold.dart';

/// Events the signed-in user marked Going or Interested.
class MyEventsScreen extends StatefulWidget {
  const MyEventsScreen({super.key});

  @override
  State<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends State<MyEventsScreen> {
  bool _loading = true;
  String? _error;
  MyEventsPartition _partition = const MyEventsPartition(
    upcoming: [],
    past: [],
  );

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      setState(() {
        _loading = false;
        _error = null;
        _partition = const MyEventsPartition(upcoming: [], past: []);
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final service = context.read<EventInterestService>();
      final interests = await service.getMyInterests();
      final events = await service.getEventsByIds(
        interests.map((interest) => interest.eventId),
      );
      if (!mounted) return;
      setState(() {
        _partition = partitionMyEvents(interests, events);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated) {
          return PageScaffold(
            title: _l10n.myEventsTitle,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_outlined, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _l10n.myEventsSignInPrompt,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(
                      '/login?redirectTo=${Uri.encodeComponent('/profile/events')}',
                    ),
                    child: Text(_l10n.profileSignInButton),
                  ),
                ],
              ),
            ),
          );
        }

        return PageScaffold(
          title: _l10n.myEventsTitle,
          scrollable: false,
          body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 48),
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            _l10n.myEventsLoadFailed,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.tonal(
              onPressed: _load,
              child: Text(_l10n.profileRetry),
            ),
          ),
        ],
      );
    }

    final upcoming = _partition.upcoming;
    final past = _partition.past;
    if (upcoming.isEmpty && past.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 32),
        children: [
          Icon(
            Icons.event_outlined,
            size: 56,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          const SizedBox(height: 16),
          Text(
            _l10n.myEventsEmptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _l10n.myEventsEmptyDescription,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (upcoming.isNotEmpty) ...[
          _sectionTitle(_l10n.myEventsUpcomingTitle),
          ...upcoming.map(_eventTile),
        ],
        if (past.isNotEmpty) ...[
          _sectionTitle(_l10n.myEventsPastTitle),
          ...past.map(_eventTile),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _eventTile(MyEventEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _MyEventTile(
        event: entry.event,
        status: entry.interest.status,
        onTap: () {
          final id = entry.event.id;
          if (id == null || id.isEmpty) return;
          context.push('/event/$id');
        },
      ),
    );
  }
}

class _MyEventTile extends StatelessWidget {
  const _MyEventTile({
    required this.event,
    required this.status,
    required this.onTap,
  });

  final ParkourEvent event;
  final EventInterestStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final when = EventScheduleUtils.formatSummaryLine(
      context,
      startAt: event.startAt,
      endAt: event.endAt,
      isDateOnly: event.isDateOnly,
      timeZone: event.timeZone,
    );
    final statusLabel = status == EventInterestStatus.going
        ? l10n.eventInterestGoing
        : l10n.eventInterestInterested;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      when,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text(statusLabel),
                avatar: Icon(
                  status == EventInterestStatus.going
                      ? Icons.check_circle
                      : Icons.star,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
