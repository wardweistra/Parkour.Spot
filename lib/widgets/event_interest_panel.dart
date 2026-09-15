import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/spot_detail_ui.dart';
import '../l10n/app_localizations.dart';
import '../models/event_interest.dart';
import '../models/parkour_event.dart';
import '../services/auth_service.dart';
import '../services/event_interest_service.dart';
import '../services/snackbar_service.dart';
import '../utils/event_interest_utils.dart';

/// Going / Interested buttons and public totals for an event.
/// Past events use Attended / Interested labels.
class EventInterestPanel extends StatelessWidget {
  const EventInterestPanel({
    super.key,
    required this.selected,
    required this.goingCount,
    required this.interestedCount,
    required this.isBusy,
    required this.onGoingPressed,
    required this.onInterestedPressed,
    this.isPast = false,
  });

  final EventInterestStatus? selected;
  final int goingCount;
  final int interestedCount;
  final bool isBusy;
  final VoidCallback onGoingPressed;
  final VoidCallback onInterestedPressed;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final goingLabel = isPast
        ? l10n.eventInterestAttendedLabel(goingCount)
        : l10n.eventInterestGoingLabel(goingCount);
    final interestedLabel = l10n.eventInterestInterestedLabel(interestedCount);
    final disclaimer = isPast
        ? l10n.eventInterestDisclaimerPast
        : l10n.eventInterestDisclaimer;

    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: SpotDetailUi.detailCardPadding,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
          border: SpotDetailUi.outlineBorder(colors),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _InterestChoiceButton(
                    icon: Icons.check_circle_outline,
                    selectedIcon: Icons.check_circle,
                    label: goingLabel,
                    selected: selected == EventInterestStatus.going,
                    enabled: !isBusy,
                    onPressed: onGoingPressed,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InterestChoiceButton(
                    icon: Icons.star_outline,
                    selectedIcon: Icons.star,
                    label: interestedLabel,
                    selected: selected == EventInterestStatus.interested,
                    enabled: !isBusy,
                    onPressed: onInterestedPressed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              disclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestChoiceButton extends StatelessWidget {
  const _InterestChoiceButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    final background = selected
        ? colors.primaryContainer
        : colors.surfaceContainerHighest.withValues(alpha: 0.45);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
              border: selected
                  ? Border.all(color: colors.primary.withValues(alpha: 0.55))
                  : SpotDetailUi.outlineBorder(colors),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 20,
                  color: selected
                      ? colors.primary
                      : foreground.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loads the signed-in user's RSVP and public totals for [event].
///
/// RSVPs are stored on the listing being viewed. Public totals use the native
/// event when this listing is a duplicate. Selected status is Going-wins
/// across the duplicate cluster.
class EventInterestSection extends StatefulWidget {
  const EventInterestSection({
    super.key,
    required this.event,
    this.clusterEventIds,
  });

  final ParkourEvent event;
  final Set<String>? clusterEventIds;

  @override
  State<EventInterestSection> createState() => _EventInterestSectionState();
}

class _EventInterestSectionState extends State<EventInterestSection> {
  EventInterestStatus? _optimisticStatus;
  EventInterestStats? _optimisticStats;
  EventInterestStats? _statsBeforeWrite;
  bool _isBusy = false;
  late Set<String> _clusterIds;
  bool _clusterLoadStarted = false;

  String? get _listingEventId => eventInterestWriteEventId(widget.event);

  /// Duplicate listings display Going / Interested totals for the native event.
  String? get _statsEventId => canonicalEventInterestEventId(widget.event);

  Set<String> _clusterIdsFromWidget() {
    return eventInterestClusterIds(
      event: widget.event,
      extraIds: widget.clusterEventIds ?? const <String>{},
    );
  }

  @override
  void initState() {
    super.initState();
    _clusterIds = _clusterIdsFromWidget();
  }

  @override
  void didUpdateWidget(EventInterestSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id) {
      _clusterIds = _clusterIdsFromWidget();
      _expandCluster();
      return;
    }
    final next = _clusterIdsFromWidget();
    if (next.difference(_clusterIds).isNotEmpty) {
      _clusterIds = {..._clusterIds, ...next};
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_clusterLoadStarted) return;
    _clusterLoadStarted = true;
    _expandCluster();
  }

  Future<void> _expandCluster() async {
    final service = context.read<EventInterestService>();
    final ids = await service.getInterestClusterIds(widget.event);
    if (!mounted) return;
    if (ids.difference(_clusterIds).isEmpty) return;
    setState(() => _clusterIds = {..._clusterIds, ...ids});
  }

  bool _statsStillAtBaseline(EventInterestStats liveStats) {
    final baseline = _statsBeforeWrite;
    if (baseline == null || _optimisticStats == null) return false;
    return liveStats.goingCount == baseline.goingCount &&
        liveStats.interestedCount == baseline.interestedCount;
  }

  Future<void> _onSelect(
    EventInterestStatus tapped,
    EventInterestStatus? current,
    EventInterestStats stats,
  ) async {
    final listingEventId = _listingEventId;
    if (listingEventId == null) return;

    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      context.go(
        '/login?redirectTo=${Uri.encodeComponent('/event/$listingEventId')}',
      );
      return;
    }

    final service = context.read<EventInterestService>();
    final next = nextEventInterestStatus(current, tapped);
    final optimisticStats = eventInterestStatsAfterChange(
      stats: stats,
      from: current,
      to: next,
    );

    setState(() {
      _isBusy = true;
      _optimisticStatus = next;
      _optimisticStats = optimisticStats;
      _statsBeforeWrite = stats;
    });

    final ok = await service.setInterest(
      eventId: listingEventId,
      status: next,
      eventStartAt: widget.event.startAt,
      clusterEventIds: _clusterIds,
    );
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      if (!ok) {
        _optimisticStatus = null;
        _optimisticStats = null;
        _statsBeforeWrite = null;
      }
    });
    if (!ok) {
      final l10n = AppLocalizations.of(context)!;
      SnackbarService.showError(l10n.eventInterestUpdateFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingEventId = _listingEventId;
    final statsEventId = _statsEventId ?? listingEventId;
    if (listingEventId == null || statsEventId == null) {
      return const SizedBox.shrink();
    }

    final service = context.read<EventInterestService>();
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final interestStream = auth.isAuthenticated
            ? service.watchClusterInterest(_clusterIds)
            : Stream<EventInterestStatus?>.value(null);
        return StreamBuilder<EventInterestStats>(
          stream: service.watchStats(statsEventId),
          builder: (context, statsSnap) {
            final liveStats = statsSnap.data ?? EventInterestStats.empty;
            return StreamBuilder<EventInterestStatus?>(
              stream: interestStream,
              builder: (context, interestSnap) {
                final liveStatus = interestSnap.data;
                final useOptimistic =
                    _isBusy || _statsStillAtBaseline(liveStats);
                final status = useOptimistic ? _optimisticStatus : liveStatus;
                final stats = useOptimistic
                    ? (_optimisticStats ?? liveStats)
                    : liveStats;
                return EventInterestPanel(
                  selected: status,
                  goingCount: stats.goingCount,
                  interestedCount: stats.interestedCount,
                  isBusy: _isBusy,
                  isPast: isParkourEventPast(widget.event),
                  onGoingPressed: () =>
                      _onSelect(EventInterestStatus.going, status, stats),
                  onInterestedPressed: () =>
                      _onSelect(EventInterestStatus.interested, status, stats),
                );
              },
            );
          },
        );
      },
    );
  }
}
