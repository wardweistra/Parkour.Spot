import 'dart:math' as math;

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
import 'spot_check_in_presence.dart' show navigateToUserProfileForCheckIn;
import 'stacked_user_avatars.dart';

/// Going / Interested buttons, public totals, and people roster for an event.
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
    this.people = const [],
    this.peopleLoaded = true,
    this.isPast = false,
    this.onPeoplePressed,
  });

  final EventInterestStatus? selected;
  final int goingCount;
  final int interestedCount;
  final bool isBusy;
  final VoidCallback onGoingPressed;
  final VoidCallback onInterestedPressed;
  final List<EventInterestPerson> people;
  final bool peopleLoaded;
  final bool isPast;
  final VoidCallback? onPeoplePressed;

  int get _totalCount => goingCount + interestedCount;

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
            if (people.isNotEmpty || (!peopleLoaded && _totalCount > 0)) ...[
              const SizedBox(height: 14),
              _EventInterestPeopleStrip(
                people: people,
                totalCount: math.max(_totalCount, people.length),
                isPast: isPast,
                onPressed: onPeoplePressed,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              disclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventInterestPeopleStrip extends StatelessWidget {
  const _EventInterestPeopleStrip({
    required this.people,
    required this.totalCount,
    required this.isPast,
    this.onPressed,
  });

  final List<EventInterestPerson> people;
  final int totalCount;
  final bool isPast;
  final VoidCallback? onPressed;

  static const int _maxStack = 5;
  static const double _stackRadius = 14;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final countForCopy = people.isNotEmpty ? people.length : totalCount;
    final label = isPast
        ? l10n.eventInterestPeopleStripLabelPast(countForCopy)
        : l10n.eventInterestPeopleStripLabel(countForCopy);

    final Widget avatars;
    if (people.isNotEmpty) {
      avatars = _EventInterestCrewStack(
        people: people,
        maxShown: _maxStack,
        radius: _stackRadius,
      );
    } else {
      avatars = StackedUserAvatarsSkeleton(
        count: math.min(totalCount, _maxStack),
        radius: _stackRadius,
      );
    }

    return Material(
      color: colors.primaryContainer.withValues(alpha: 0.28),
      borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.22),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
            child: Row(
              children: [
                avatars,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlapping crew faces with status rings (primary = Going, secondary =
/// Interested), matching the community presence language.
class _EventInterestCrewStack extends StatelessWidget {
  const _EventInterestCrewStack({
    required this.people,
    this.maxShown = 5,
    this.radius = 14,
  });

  final List<EventInterestPerson> people;
  final int maxShown;
  final double radius;

  static const double _overlapFactor = 1.35;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty || maxShown <= 0) return const SizedBox.shrink();

    final shown = people.take(maxShown).toList(growable: false);
    final extra = people.length - shown.length;
    final overlap = radius * _overlapFactor;
    final stackWidth =
        shown.isEmpty ? 0.0 : (shown.length - 1) * overlap + radius * 2;
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stackWidth,
          height: radius * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * overlap,
                  child: _EventInterestRingAvatar(
                    person: shown[i],
                    radius: radius,
                  ),
                ),
            ],
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 6),
          Text(
            '+$extra',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _EventInterestRingAvatar extends StatelessWidget {
  const _EventInterestRingAvatar({
    required this.person,
    required this.radius,
  });

  final EventInterestPerson person;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final going = person.status == EventInterestStatus.going;
    final ringColor = going ? cs.primary : cs.secondary;
    final photo = person.photoURL?.trim();
    final name = person.displayName?.trim();
    final initial = (name != null && name.isNotEmpty)
        ? name[0].toUpperCase()
        : '?';
    final innerRadius = radius - 2.2;

    return Tooltip(
      message: name ?? '',
      child: CircleAvatar(
        radius: radius,
        backgroundColor: ringColor,
        child: CircleAvatar(
          radius: innerRadius,
          backgroundColor: cs.surfaceContainerHighest,
          backgroundImage: (photo != null && photo.isNotEmpty)
              ? NetworkImage(photo)
              : null,
          child: (photo == null || photo.isEmpty)
              ? Text(
                  initial,
                  style: TextStyle(
                    fontSize: innerRadius * 0.9,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                )
              : null,
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

void showEventInterestPeopleDialog(
  BuildContext context, {
  required List<EventInterestPerson> people,
  required bool isPast,
  int? goingCount,
  int? interestedCount,
}) {
  final hostContext = context;
  final theme = Theme.of(context);
  final l10n = AppLocalizations.of(context)!;
  final cs = theme.colorScheme;
  final title = isPast
      ? l10n.eventInterestPeopleTitlePast
      : l10n.eventInterestPeopleTitle;
  final going = goingCount ??
      people.where((p) => p.status == EventInterestStatus.going).length;
  final interested = interestedCount ??
      people.where((p) => p.status == EventInterestStatus.interested).length;
  final subtitle = isPast
      ? l10n.eventInterestPeopleSubtitlePast(going, interested)
      : l10n.eventInterestPeopleSubtitle(going, interested);

  showDialog<void>(
    context: context,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.58;
      return AlertDialog(
        backgroundColor: cs.surface,
        surfaceTintColor: cs.primaryContainer.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.groups_2_rounded,
                color: cs.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  if (people.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: math.min(440, maxH),
          child: people.isEmpty
              ? Center(
                  child: Text(
                    l10n.eventInterestPeopleEmpty,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                )
              : _EventInterestRosterList(
                  people: people,
                  isPast: isPast,
                  onPersonTap: (person) {
                    Navigator.of(ctx).pop();
                    navigateToUserProfileForCheckIn(
                      hostContext,
                      person.userId,
                    );
                  },
                ),
        ),
      );
    },
  );
}

class _EventInterestRosterList extends StatefulWidget {
  const _EventInterestRosterList({
    required this.people,
    required this.isPast,
    required this.onPersonTap,
  });

  final List<EventInterestPerson> people;
  final bool isPast;
  final ValueChanged<EventInterestPerson> onPersonTap;

  @override
  State<_EventInterestRosterList> createState() =>
      _EventInterestRosterListState();
}

class _EventInterestRosterListState extends State<_EventInterestRosterList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    final reduceMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      itemCount: widget.people.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final person = widget.people[index];
        final tile = _EventInterestPersonTile(
          person: person,
          isPast: widget.isPast,
          onTap: () => widget.onPersonTap(person),
        );
        if (reduceMotion || _controller.value >= 1) return tile;

        final start = (index * 0.07).clamp(0.0, 0.55);
        final end = (start + 0.35).clamp(0.0, 1.0);
        final animation = CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation),
            child: tile,
          ),
        );
      },
    );
  }
}

class _EventInterestStatusBadge extends StatelessWidget {
  const _EventInterestStatusBadge({
    required this.status,
    required this.isPast,
  });

  final EventInterestStatus status;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final going = status == EventInterestStatus.going;
    final label = going
        ? (isPast ? l10n.eventInterestAttended : l10n.eventInterestGoing)
        : l10n.eventInterestInterested;
    final icon = going
        ? (isPast ? Icons.how_to_reg_rounded : Icons.check_circle_rounded)
        : Icons.star_rounded;
    final background = going
        ? cs.primaryContainer.withValues(alpha: 0.85)
        : cs.surfaceContainerHighest.withValues(alpha: 0.9);
    final foreground = going ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    final iconColor = going ? cs.primary : cs.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: going
            ? null
            : Border.all(color: cs.outline.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventInterestPersonTile extends StatelessWidget {
  const _EventInterestPersonTile({
    required this.person,
    required this.isPast,
    required this.onTap,
  });

  final EventInterestPerson person;
  final bool isPast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final name = person.displayName?.trim();
    final label = (name != null && name.isNotEmpty)
        ? name
        : l10n.spotTrainingPlanUnnamedPerson;

    return Material(
      color: cs.surfaceContainerLow.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                _EventInterestRingAvatar(person: person, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _EventInterestStatusBadge(
                  status: person.status,
                  isPast: isPast,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loads the signed-in user's RSVP, public totals, and people roster for [event].
///
/// RSVPs are stored on the listing being viewed. Public totals and people use
/// the native event when this listing is a duplicate. Selected status is
/// Going-wins across the duplicate cluster.
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
  List<EventInterestPerson>? _optimisticPeople;
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
    List<EventInterestPerson> people,
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

    final userId = auth.currentUser?.uid;
    if (userId == null || userId.isEmpty) return;

    final service = context.read<EventInterestService>();
    final next = nextEventInterestStatus(current, tapped);
    final optimisticStats = eventInterestStatsAfterChange(
      stats: stats,
      from: current,
      to: next,
    );
    final profile = auth.userProfile;
    final photoURL = (profile != null && profile.isPublicProfile)
        ? profile.photoURL
        : null;
    final optimisticPeople = eventInterestPeopleAfterChange(
      people: people,
      userId: userId,
      to: next,
      displayName: profile?.displayName,
      photoURL: photoURL,
    );

    setState(() {
      _isBusy = true;
      _optimisticStatus = next;
      _optimisticStats = optimisticStats;
      _statsBeforeWrite = stats;
      _optimisticPeople = optimisticPeople;
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
        _optimisticPeople = null;
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
    final isPast = isParkourEventPast(widget.event);
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        final interestStream = auth.isAuthenticated
            ? service.watchClusterInterest(_clusterIds)
            : Stream<EventInterestStatus?>.value(null);
        return StreamBuilder<EventInterestStats>(
          stream: service.watchStats(statsEventId),
          builder: (context, statsSnap) {
            final liveStats = statsSnap.data ?? EventInterestStats.empty;
            return StreamBuilder<List<EventInterestPerson>>(
              stream: service.watchPeople(statsEventId),
              builder: (context, peopleSnap) {
                final peopleLoaded =
                    peopleSnap.connectionState == ConnectionState.active ||
                    peopleSnap.hasData;
                final livePeople =
                    peopleSnap.data ?? const <EventInterestPerson>[];
                return StreamBuilder<EventInterestStatus?>(
                  stream: interestStream,
                  builder: (context, interestSnap) {
                    final liveStatus = interestSnap.data;
                    final useOptimistic =
                        _isBusy || _statsStillAtBaseline(liveStats);
                    final status =
                        useOptimistic ? _optimisticStatus : liveStatus;
                    final stats = useOptimistic
                        ? (_optimisticStats ?? liveStats)
                        : liveStats;
                    final people = useOptimistic
                        ? (_optimisticPeople ?? livePeople)
                        : livePeople;
                    if (!useOptimistic && _optimisticPeople != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        if (_optimisticPeople == null) return;
                        setState(() => _optimisticPeople = null);
                      });
                    }
                    return EventInterestPanel(
                      selected: status,
                      goingCount: stats.goingCount,
                      interestedCount: stats.interestedCount,
                      isBusy: _isBusy,
                      isPast: isPast,
                      people: people,
                      peopleLoaded: peopleLoaded,
                      onGoingPressed: () => _onSelect(
                        EventInterestStatus.going,
                        status,
                        stats,
                        people,
                      ),
                      onInterestedPressed: () => _onSelect(
                        EventInterestStatus.interested,
                        status,
                        stats,
                        people,
                      ),
                      onPeoplePressed: () => showEventInterestPeopleDialog(
                        context,
                        people: people,
                        isPast: isPast,
                        goingCount: stats.goingCount,
                        interestedCount: stats.interestedCount,
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
