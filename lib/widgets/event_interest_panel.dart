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
              const SizedBox(height: 12),
              _EventInterestPeopleStrip(
                people: people,
                totalCount: _totalCount,
                onPressed: onPeoplePressed,
              ),
            ],
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

class _EventInterestPeopleStrip extends StatelessWidget {
  const _EventInterestPeopleStrip({
    required this.people,
    required this.totalCount,
    this.onPressed,
  });

  final List<EventInterestPerson> people;
  final int totalCount;
  final VoidCallback? onPressed;

  static const int _maxStack = 4;
  static const double _stackRadius = 10;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final stackEntries = people
        .map(
          (person) => StackedUserAvatarEntry(
            userId: person.userId,
            displayName: person.displayName,
            photoURL: person.photoURL,
          ),
        )
        .toList(growable: false);

    final Widget avatars;
    if (stackEntries.isNotEmpty) {
      avatars = StackedUserAvatars(
        entries: stackEntries,
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              avatars,
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.eventInterestPeopleViewAll,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
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
}) {
  final hostContext = context;
  final theme = Theme.of(context);
  final l10n = AppLocalizations.of(context)!;
  final title = isPast
      ? l10n.eventInterestPeopleTitlePast
      : l10n.eventInterestPeopleTitle;

  showDialog<void>(
    context: context,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.55;
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        title: Row(
          children: [
            Icon(
              Icons.groups_2_outlined,
              color: theme.colorScheme.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: math.min(420, maxH),
          child: people.isEmpty
              ? Center(
                  child: Text(
                    l10n.eventInterestPeopleEmpty,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: people.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final person = people[index];
                    return _EventInterestPersonTile(
                      person: person,
                      isPast: isPast,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        navigateToUserProfileForCheckIn(
                          hostContext,
                          person.userId,
                        );
                      },
                    );
                  },
                ),
        ),
      );
    },
  );
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
    final photo = person.photoURL?.trim();
    final initial = label.isNotEmpty ? label[0].toUpperCase() : '?';
    final statusLabel = person.status == EventInterestStatus.going
        ? (isPast ? l10n.eventInterestAttended : l10n.eventInterestGoing)
        : l10n.eventInterestInterested;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: cs.surfaceContainerHighest,
                  backgroundImage: (photo != null && photo.isNotEmpty)
                      ? NetworkImage(photo)
                      : null,
                  child: (photo == null || photo.isEmpty)
                      ? Text(
                          initial,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
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
                final peopleLoaded = peopleSnap.connectionState ==
                        ConnectionState.active ||
                    peopleSnap.hasData;
                final livePeople = peopleSnap.data ?? const <EventInterestPerson>[];
                return StreamBuilder<EventInterestStatus?>(
                  stream: interestStream,
                  builder: (context, interestSnap) {
                    final liveStatus = interestSnap.data;
                    final useOptimistic =
                        _isBusy || _statsStillAtBaseline(liveStats);
                    final status = useOptimistic
                        ? _optimisticStatus
                        : liveStatus;
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
