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
class EventInterestPanel extends StatelessWidget {
  const EventInterestPanel({
    super.key,
    required this.selected,
    required this.goingCount,
    required this.interestedCount,
    required this.isBusy,
    required this.onGoingPressed,
    required this.onInterestedPressed,
  });

  final EventInterestStatus? selected;
  final int goingCount;
  final int interestedCount;
  final bool isBusy;
  final VoidCallback onGoingPressed;
  final VoidCallback onInterestedPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                    label: l10n.eventInterestGoingLabel(goingCount),
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
                    label: l10n.eventInterestInterestedLabel(interestedCount),
                    selected: selected == EventInterestStatus.interested,
                    enabled: !isBusy,
                    onPressed: onInterestedPressed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.eventInterestDisclaimer,
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
class EventInterestSection extends StatefulWidget {
  const EventInterestSection({super.key, required this.event});

  final ParkourEvent event;

  @override
  State<EventInterestSection> createState() => _EventInterestSectionState();
}

class _EventInterestSectionState extends State<EventInterestSection> {
  EventInterestStatus? _optimisticStatus;
  EventInterestStats? _optimisticStats;
  EventInterestStats? _statsBeforeWrite;
  bool _isBusy = false;

  String? get _eventId {
    final id = widget.event.id?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
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
    final eventId = _eventId;
    if (eventId == null) return;

    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      context.go('/login?redirectTo=${Uri.encodeComponent('/event/$eventId')}');
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
      eventId: eventId,
      status: next,
      eventStartAt: widget.event.startAt,
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
    final eventId = _eventId;
    if (eventId == null) return const SizedBox.shrink();

    final service = context.read<EventInterestService>();
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final interestStream = auth.isAuthenticated
            ? service.watchUserInterest(eventId)
            : Stream<EventInterest?>.value(null);
        return StreamBuilder<EventInterestStats>(
          stream: service.watchStats(eventId),
          builder: (context, statsSnap) {
            final liveStats = statsSnap.data ?? EventInterestStats.empty;
            return StreamBuilder<EventInterest?>(
              stream: interestStream,
              builder: (context, interestSnap) {
                final liveStatus = interestSnap.data?.status;
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
