import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/event_interest.dart';
import '../../models/parkour_event.dart';
import '../../services/auth_service.dart';
import '../../services/event_interest_service.dart';
import '../../services/user_calendar_feed_service.dart';
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
  bool _calendarBusy = false;
  final UserCalendarFeedService _calendarFeedService =
      UserCalendarFeedService();

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
      var events = await service.getEventsByIds(
        interests.map((interest) => interest.eventId),
      );
      final nativeIds = missingNativeEventIds(events);
      if (nativeIds.isNotEmpty) {
        final natives = await service.getEventsByIds(nativeIds);
        events = {...events, ...natives};
      }
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

  Future<void> _copyCalendarLink() async {
    if (_calendarBusy) return;
    setState(() => _calendarBusy = true);
    try {
      final url = await _calendarFeedService.getOrCreateFeedUrl();
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.myEventsCalendarCopied)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.myEventsCalendarFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _calendarBusy = false);
    }
  }

  Future<void> _openCalendarSubscribe() async {
    if (_calendarBusy) return;
    setState(() => _calendarBusy = true);
    try {
      final url = await _calendarFeedService.getOrCreateFeedUrl();
      final webcal = UserCalendarFeedService.toWebcalUrl(url);
      final uri = Uri.parse(webcal);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        await Clipboard.setData(ClipboardData(text: url));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_l10n.myEventsCalendarCopied)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.myEventsCalendarFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _calendarBusy = false);
    }
  }

  Future<void> _confirmRegenerateCalendarLink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10n.myEventsCalendarRegenerateTitle),
          content: Text(
            l10n.myEventsCalendarRegenerateBody,
            style: TextStyle(color: scheme.error),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.profileCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.myEventsCalendarRegenerateConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    if (_calendarBusy) return;
    setState(() => _calendarBusy = true);
    try {
      final url = await _calendarFeedService.regenerateFeedUrl();
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.myEventsCalendarCopied)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.myEventsCalendarFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _calendarBusy = false);
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
    final isEmpty = upcoming.isEmpty && past.isEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _calendarSection(),
        if (isEmpty) ...[
          const SizedBox(height: 24),
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
          const SizedBox(height: 16),
        ] else ...[
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
      ],
    );
  }

  Widget _calendarSection() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _l10n.myEventsCalendarTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _l10n.myEventsCalendarDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _calendarBusy ? null : _copyCalendarLink,
                icon: _calendarBusy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.link),
                label: Text(_l10n.myEventsCalendarCopyLink),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  TextButton(
                    onPressed: _calendarBusy ? null : _openCalendarSubscribe,
                    child: Text(_l10n.myEventsCalendarOpenSubscribe),
                  ),
                  TextButton(
                    onPressed: _calendarBusy
                        ? null
                        : _confirmRegenerateCalendarLink,
                    child: Text(_l10n.myEventsCalendarRegenerate),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
        isPast: isParkourEventPast(entry.event),
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
    required this.isPast,
    required this.onTap,
  });

  final ParkourEvent event;
  final EventInterestStatus status;
  final bool isPast;
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
        ? (isPast ? l10n.eventInterestAttended : l10n.eventInterestGoing)
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
