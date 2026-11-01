import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/community_activity.dart';
import '../models/event_map_pin.dart';
import '../utils/community_activity_time_formatting.dart';
import '../utils/event_schedule_utils.dart';
import 'resized_spot_image.dart';

/// Explore "Community" stream for one map viewport, laid out as a timeline:
/// recent activity (oldest at the top, newest just above "now"), a "now"
/// divider, then training plans and events ordered soonest first.
///
/// Only the most recent [recentPastPreviewCount] past items are shown by
/// default so "now" stays near the top; older history expands on request.
class CommunityActivityStream extends StatefulWidget {
  const CommunityActivityStream({
    super.key,
    required this.feed,
    required this.onOpenSpot,
    required this.onOpenEvent,
    this.onOpenActor,
    this.now,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  static const int recentPastPreviewCount = 3;

  /// Single column; wider sheets centre the stream instead of stretching cards.
  static const double maxContentWidth = 720;

  final CommunityActivityFeed feed;
  final ValueChanged<CommunityActivityItem> onOpenSpot;
  final ValueChanged<EventMapPin> onOpenEvent;
  final ValueChanged<String>? onOpenActor;

  /// Injectable clock (tests); defaults to [DateTime.now].
  final DateTime? now;
  final EdgeInsets padding;

  @override
  State<CommunityActivityStream> createState() =>
      _CommunityActivityStreamState();
}

class _CommunityActivityStreamState extends State<CommunityActivityStream> {
  bool _showAllPast = false;

  @override
  void didUpdateWidget(covariant CommunityActivityStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.feed, widget.feed)) {
      _showAllPast = false;
    }
  }

  List<_StreamEntry> _buildEntries() {
    final feed = widget.feed;
    final entries = <_StreamEntry>[];

    final past = feed.past;
    final previewCount = CommunityActivityStream.recentPastPreviewCount;
    final hiddenCount = _showAllPast || past.length <= previewCount
        ? 0
        : past.length - previewCount;
    if (hiddenCount > 0) {
      entries.add(_ShowEarlierEntry(hiddenCount));
    }
    // `past` is newest first; the timeline reads oldest → newest → now.
    final shownPast = past.take(past.length - hiddenCount).toList().reversed;
    entries.addAll(shownPast.map(_PastEntry.new));

    entries.add(const _NowEntry());

    final upcoming = <_StreamEntry>[
      ...feed.upcoming.map(_PlanEntry.new),
      ...feed.events.map(_EventEntry.new),
    ]..sort((a, b) => a.sortTime.compareTo(b.sortTime));
    entries.addAll(upcoming);

    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _buildEntries();
    final now = widget.now ?? DateTime.now().toUtc();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: CommunityActivityStream.maxContentWidth,
        ),
        child: ListView.builder(
          padding: widget.padding,
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final child = switch (entry) {
              _ShowEarlierEntry(:final hiddenCount) => _ShowEarlierButton(
                hiddenCount: hiddenCount,
                onPressed: () => setState(() => _showAllPast = true),
              ),
              _PastEntry(:final item) => CommunityActivityCard(
                item: item,
                now: now,
                onOpenSpot: () => widget.onOpenSpot(item),
                onOpenActor: _actorCallback(item),
              ),
              _NowEntry() => const CommunityNowDivider(),
              _PlanEntry(:final item) => CommunityActivityCard(
                item: item,
                now: now,
                onOpenSpot: () => widget.onOpenSpot(item),
                onOpenActor: _actorCallback(item),
              ),
              _EventEntry(:final event) => CommunityEventActivityCard(
                event: event,
                now: now,
                onTap: () => widget.onOpenEvent(event.pin),
              ),
            };
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == entries.length - 1 ? 0 : 10,
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }

  VoidCallback? _actorCallback(CommunityActivityItem item) {
    final onOpenActor = widget.onOpenActor;
    final userId = item.actorUserId;
    if (onOpenActor == null || userId == null || userId.isEmpty) return null;
    return () => onOpenActor(userId);
  }
}

sealed class _StreamEntry {
  const _StreamEntry();

  /// Only meaningful for upcoming entries (plans and events).
  DateTime get sortTime => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

class _ShowEarlierEntry extends _StreamEntry {
  const _ShowEarlierEntry(this.hiddenCount);
  final int hiddenCount;
}

class _PastEntry extends _StreamEntry {
  const _PastEntry(this.item);
  final CommunityActivityItem item;
}

class _NowEntry extends _StreamEntry {
  const _NowEntry();
}

class _PlanEntry extends _StreamEntry {
  const _PlanEntry(this.item);
  final CommunityActivityItem item;

  @override
  DateTime get sortTime => item.startAt ?? item.occurredAt;
}

class _EventEntry extends _StreamEntry {
  const _EventEntry(this.event);
  final CommunityEventItem event;

  @override
  DateTime get sortTime => event.pin.startAt;
}

class _ShowEarlierButton extends StatelessWidget {
  const _ShowEarlierButton({
    required this.hiddenCount,
    required this.onPressed,
  });

  final int hiddenCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.history, size: 18),
        label: Text(l10n.communityStreamShowEarlier(hiddenCount)),
      ),
    );
  }
}

/// Timeline marker between what already happened and what is planned.
class CommunityNowDivider extends StatelessWidget {
  const CommunityNowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final line = Expanded(
      child: Divider(color: colorScheme.primary.withValues(alpha: 0.6)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          line,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.communityStreamNowDivider,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          line,
        ],
      ),
    );
  }
}

/// One spot-anchored activity: new spot, new photos, check-in or training plan.
class CommunityActivityCard extends StatelessWidget {
  const CommunityActivityCard({
    super.key,
    required this.item,
    required this.now,
    this.onOpenSpot,
    this.onOpenActor,
  });

  final CommunityActivityItem item;
  final DateTime now;
  final VoidCallback? onOpenSpot;
  final VoidCallback? onOpenActor;

  static const double _avatarRadius = 20;
  static const double _thumbSize = 72;

  IconData get _kindIcon => switch (item.kind) {
    CommunityActivityKind.spotAdded => Icons.add_location_alt_outlined,
    CommunityActivityKind.spotPhotoAdded => Icons.add_a_photo_outlined,
    CommunityActivityKind.spotCheckIn => Icons.where_to_vote_outlined,
    CommunityActivityKind.spotTrainingPlan => Icons.fitness_center,
  };

  String _sentence(AppLocalizations l10n, String actor) => switch (item.kind) {
    CommunityActivityKind.spotAdded => l10n.communityStreamSpotAdded(actor),
    CommunityActivityKind.spotPhotoAdded => l10n.communityStreamPhotoAdded(
      actor,
      item.photoCount ?? (item.imageUrls.isEmpty ? 1 : item.imageUrls.length),
    ),
    CommunityActivityKind.spotCheckIn => l10n.communityStreamCheckedIn(actor),
    CommunityActivityKind.spotTrainingPlan =>
      l10n.communityStreamPlanningToTrain(actor),
  };

  /// Trailing time for past kinds; training plans show their window inline.
  String? _trailingTime(AppLocalizations l10n) {
    if (item.kind == CommunityActivityKind.spotTrainingPlan) return null;
    return communityStreamRelativeTime(item.occurredAt, l10n, now: now);
  }

  String? _scheduleLine(AppLocalizations l10n) {
    switch (item.kind) {
      case CommunityActivityKind.spotTrainingPlan:
        final start = item.startAt;
        final end = item.endAt;
        if (start != null && end != null) {
          return communityFriendlyTrainingWindow(start, end, l10n, now: now);
        }
        if (start != null) {
          return communityFriendlyPlannedTrainingStart(start, l10n, now: now);
        }
        return null;
      case CommunityActivityKind.spotCheckIn:
        final end = item.endAt;
        if (end != null && item.isActiveAt(now)) {
          return l10n.communityStreamCheckedInUntil(
            communityFriendlyCheckInUntil(end, l10n, now: now),
          );
        }
        return null;
      case CommunityActivityKind.spotAdded:
      case CommunityActivityKind.spotPhotoAdded:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = colorScheme.onSurface.withValues(alpha: 0.65);

    final rawName = item.actorDisplayName?.trim() ?? '';
    final actor = rawName.isEmpty
        ? l10n.communityStreamAnonymousActor
        : rawName;
    final sentence = _sentence(l10n, actor);
    final spotName = (item.spotName?.trim().isNotEmpty ?? false)
        ? item.spotName!.trim()
        : l10n.communityStreamSpotFallback;
    final city = item.city?.trim() ?? '';
    final spotLine = city.isEmpty ? spotName : '$spotName · $city';
    final trailingTime = _trailingTime(l10n);
    final scheduleLine = _scheduleLine(l10n);
    final comment = item.comment?.trim() ?? '';
    final images = item.imageUrls.take(3).toList();

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onOpenSpot,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ActorAvatar(
                    photoURL: item.actorPhotoURL,
                    name: actor,
                    badgeIcon: _kindIcon,
                    radius: _avatarRadius,
                    onTap: onOpenActor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HighlightedSentence(
                          sentence: sentence,
                          highlight: actor,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 14,
                              color: mutedColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                spotLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: mutedColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (scheduleLine != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 14,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  scheduleLine,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (comment.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '“$comment”',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: mutedColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingTime != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      trailingTime,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: mutedColor,
                      ),
                    ),
                  ],
                ],
              ),
              if (images.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: _avatarRadius * 2 + 12),
                  child: SizedBox(
                    height: _thumbSize,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: images.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ResizedSpotImage(
                          imageUrl: images[index],
                          width: _thumbSize,
                          height: _thumbSize,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// An upcoming or in-progress event with its public Going / Interested totals.
class CommunityEventActivityCard extends StatelessWidget {
  const CommunityEventActivityCard({
    super.key,
    required this.event,
    required this.now,
    this.onTap,
  });

  final CommunityEventItem event;
  final DateTime now;
  final VoidCallback? onTap;

  static const double _thumbSize = 64;

  bool get _isHappeningNow {
    final pin = event.pin;
    if (now.isBefore(pin.startAt)) return false;
    final end = pin.endAt;
    if (end != null) return !now.isAfter(end);
    return now.difference(pin.startAt) < const Duration(days: 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mutedColor = colorScheme.onSurface.withValues(alpha: 0.65);
    final pin = event.pin;
    final whenLine = EventScheduleUtils.formatSummaryLine(
      context,
      startAt: pin.startAt,
      endAt: pin.endAt,
      isDateOnly: pin.isDateOnly,
      timeZone: pin.timeZone,
      now: now,
    );
    final city = pin.city?.trim() ?? '';
    final headline = _isHappeningNow
        ? l10n.communityStreamEventHappeningNow
        : l10n.communityStreamEventUpcoming;

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: _thumbSize,
                  height: _thumbSize,
                  child: pin.imageUrls.isNotEmpty
                      ? ResizedSpotImage(
                          imageUrl: pin.imageUrls.first,
                          width: _thumbSize,
                          height: _thumbSize,
                          fit: BoxFit.cover,
                        )
                      : ColoredBox(
                          color: colorScheme.primaryContainer,
                          child: Icon(
                            Icons.event,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pin.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: mutedColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            whenLine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: mutedColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: mutedColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: mutedColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _CountChip(
                          icon: Icons.check_circle_outline,
                          label: l10n.communityStreamEventGoing(
                            event.goingCount,
                          ),
                          emphasized: event.goingCount > 0,
                        ),
                        if (event.interestedCount > 0)
                          _CountChip(
                            icon: Icons.star_outline,
                            label: l10n.communityStreamEventInterested(
                              event.interestedCount,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = emphasized
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.65);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _ActorAvatar extends StatelessWidget {
  const _ActorAvatar({
    required this.photoURL,
    required this.name,
    required this.badgeIcon,
    required this.radius,
    this.onTap,
  });

  final String? photoURL;
  final String name;
  final IconData badgeIcon;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasPhoto = photoURL != null && photoURL!.isNotEmpty;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: colorScheme.surfaceContainerHighest,
      backgroundImage: hasPhoto ? NetworkImage(photoURL!) : null,
      child: hasPhoto
          ? null
          : Text(
              name.characters.first.toUpperCase(),
              style: theme.textTheme.titleSmall,
            ),
    );

    final badged = SizedBox(
      width: radius * 2 + 4,
      height: radius * 2 + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: colorScheme.primary,
              shape: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  badgeIcon,
                  size: radius * 0.6,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return badged;
    return Semantics(
      button: true,
      label: name,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: badged,
      ),
    );
  }
}

/// Renders [sentence] with the first occurrence of [highlight] in bold.
class _HighlightedSentence extends StatelessWidget {
  const _HighlightedSentence({
    required this.sentence,
    required this.highlight,
    this.style,
  });

  final String sentence;
  final String highlight;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final index = highlight.isEmpty ? -1 : sentence.indexOf(highlight);
    if (index < 0) {
      return Text(sentence, style: style);
    }
    final bold =
        style?.copyWith(fontWeight: FontWeight.w700) ??
        const TextStyle(fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          if (index > 0) TextSpan(text: sentence.substring(0, index)),
          TextSpan(text: highlight, style: bold),
          TextSpan(text: sentence.substring(index + highlight.length)),
        ],
      ),
    );
  }
}
