import 'dart:async';

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
/// The first page loads a full past page near "now"; [onLoadMorePast] /
/// [onLoadMoreUpcoming] page the rest from the server.
///
/// Past pages prepend above "now" via a [CustomScrollView] center key so older
/// rows grow upward and the viewport does not drift when "Show earlier" loads.
class CommunityActivityStream extends StatefulWidget {
  const CommunityActivityStream({
    super.key,
    required this.feed,
    required this.onOpenSpot,
    required this.onOpenEvent,
    this.onOpenActor,
    this.onLoadMorePast,
    this.onLoadMoreUpcoming,
    this.loadingMorePast = false,
    this.loadingMoreUpcoming = false,
    this.now,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 16),
  });

  /// Single column; wider sheets centre the stream instead of stretching cards.
  static const double maxContentWidth = 720;

  /// Key on the floating control that scrolls back to the "now" divider.
  static const Key jumpToNowKey = ValueKey('community-stream-jump-to-now');

  final CommunityActivityFeed feed;
  final ValueChanged<CommunityActivityItem> onOpenSpot;
  final ValueChanged<EventMapPin> onOpenEvent;
  final ValueChanged<String>? onOpenActor;
  final VoidCallback? onLoadMorePast;
  final VoidCallback? onLoadMoreUpcoming;
  final bool loadingMorePast;
  final bool loadingMoreUpcoming;

  /// Injectable clock (tests); defaults to [DateTime.now].
  final DateTime? now;
  final EdgeInsets padding;

  @override
  State<CommunityActivityStream> createState() =>
      _CommunityActivityStreamState();
}

enum _JumpToNowDirection { up, down }

class _CommunityActivityStreamState extends State<CommunityActivityStream> {
  final ScrollController _scrollController = ScrollController();

  /// Marks the "now" divider as the scroll center so slivers above it (past
  /// activity) grow upward when earlier pages are prepended.
  final Key _nowCenterKey = const ValueKey('community-stream-now');

  /// Stable keys for mounted rows so we can pin screen Y across "Show earlier"
  /// inserts while child extents / images finish settling.
  final Map<String, GlobalKey> _entryKeys = {};

  /// Bounds of the scroll viewport for offscreen "now" detection.
  final GlobalKey _viewportKey = GlobalKey();

  String? _anchorId;
  double? _anchorScreenY;
  int _anchorFramesRemaining = 0;

  /// Enough frames for async card media / sliver extent correction without
  /// fighting a user who starts scrolling again.
  static const int _anchorCorrectionFrameBudget = 8;

  /// Edge inset before treating "now" as fully offscreen (avoids flicker).
  static const double _nowVisibilityMargin = 12;

  /// True after at least one open scroll that tried to center "now".
  bool _didApplyInitialScroll = false;

  /// Keep auto-centering "now" while the explore sheet expands (viewport
  /// grows). Cleared once the user scrolls or the open settle finishes.
  bool _autoCenterNow = true;

  /// Explore sheet open is ~300ms; wait a beat after the last size/extent
  /// change before stopping auto-center.
  static const Duration _autoCenterReleaseDelay = Duration(milliseconds: 400);

  Timer? _autoCenterReleaseTimer;

  /// False until initial layout + timeline jump have settled — avoids a false
  /// "jump down" while the explore sheet is still expanding.
  bool _nowVisibilityReady = false;

  Size? _lastViewportSize;

  /// Non-null when the inline "now" divider is outside the viewport.
  _JumpToNowDirection? _jumpToNowDirection;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scheduleNowVisibilityUpdate);
  }

  @override
  void dispose() {
    _autoCenterReleaseTimer?.cancel();
    _scrollController.removeListener(_scheduleNowVisibilityUpdate);
    _scrollController.dispose();
    super.dispose();
  }

  void _stopAutoCenterNow() {
    _autoCenterReleaseTimer?.cancel();
    _autoCenterReleaseTimer = null;
    _autoCenterNow = false;
  }

  /// Final mid-panel refine a moment after the last sheet/extent change.
  void _scheduleAutoCenterRelease() {
    _autoCenterReleaseTimer?.cancel();
    _autoCenterReleaseTimer = Timer(_autoCenterReleaseDelay, () {
      if (!mounted || !_autoCenterNow) return;
      _jumpNowToMidPanel();
      _autoCenterNow = false;
      _autoCenterReleaseTimer = null;
      _scheduleNowVisibilityUpdate();
    });
  }

  @override
  void didUpdateWidget(covariant CommunityActivityStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(widget.feed, oldWidget.feed)) return;

    // "Show earlier" prepends older past — pin the viewport, don't re-center.
    if (_isPastPageAppend(oldWidget.feed, widget.feed)) {
      _schedulePastInsertCorrection(oldWidget.feed);
      return;
    }
    // Further upcoming pages grow below "now"; leave scroll alone.
    if (_isUpcomingPageAppend(oldWidget.feed, widget.feed)) {
      return;
    }

    // Full reload (map move, retry, etc.): open again with "now" mid-panel.
    _didApplyInitialScroll = false;
    _autoCenterNow = true;
    _nowVisibilityReady = false;
    _clearAnchorCorrection();
    _scheduleAutoCenterRelease();
  }

  /// Older past page merged into the existing past half (upcoming unchanged).
  ///
  /// Uses set containment rather than list prefix so both server order
  /// (newer→older append) and UI/test prepends still count as paging.
  static bool _isPastPageAppend(
    CommunityActivityFeed previous,
    CommunityActivityFeed next,
  ) {
    if (next.loadedPastCount <= previous.loadedPastCount) return false;
    if (!_idsRetained(
      previous.past.map((e) => e.id),
      next.past.map((e) => e.id),
    )) {
      return false;
    }
    if (!_idsRetained(
      previous.pastEvents.map((e) => e.pin.eventId),
      next.pastEvents.map((e) => e.pin.eventId),
    )) {
      return false;
    }
    // Past paging leaves the upcoming half untouched.
    return _idsEqual(
          previous.upcoming.map((e) => e.id),
          next.upcoming.map((e) => e.id),
        ) &&
        _idsEqual(
          previous.events.map((e) => e.pin.eventId),
          next.events.map((e) => e.pin.eventId),
        );
  }

  /// Further-upcoming page merged into the existing upcoming half.
  static bool _isUpcomingPageAppend(
    CommunityActivityFeed previous,
    CommunityActivityFeed next,
  ) {
    final prevUpcoming = previous.upcoming.length + previous.events.length;
    final nextUpcoming = next.upcoming.length + next.events.length;
    if (nextUpcoming <= prevUpcoming) return false;
    if (!_idsEqual(
      previous.past.map((e) => e.id),
      next.past.map((e) => e.id),
    )) {
      return false;
    }
    if (!_idsEqual(
      previous.pastEvents.map((e) => e.pin.eventId),
      next.pastEvents.map((e) => e.pin.eventId),
    )) {
      return false;
    }
    return _idsRetained(
          previous.upcoming.map((e) => e.id),
          next.upcoming.map((e) => e.id),
        ) &&
        _idsRetained(
          previous.events.map((e) => e.pin.eventId),
          next.events.map((e) => e.pin.eventId),
        );
  }

  static bool _idsRetained(Iterable<String> previous, Iterable<String> next) {
    final nextSet = next.toSet();
    for (final id in previous) {
      if (!nextSet.contains(id)) return false;
    }
    return true;
  }

  static bool _idsEqual(Iterable<String> a, Iterable<String> b) {
    final aList = a.toList(growable: false);
    final bList = b.toList(growable: false);
    if (aList.length != bList.length) return false;
    for (var i = 0; i < aList.length; i++) {
      if (aList[i] != bList[i]) return false;
    }
    return true;
  }

  GlobalKey _keyFor(String id) => _entryKeys.putIfAbsent(id, GlobalKey.new);

  static String _activityAnchorId(CommunityActivityItem item) => 'a:${item.id}';

  static String _eventAnchorId(CommunityEventItem event) =>
      'e:${event.pin.eventId}';

  static String? _entryAnchorId(_StreamEntry entry) => switch (entry) {
    _PastEntry(:final item) => _activityAnchorId(item),
    _PastEventEntry(:final event) => _eventAnchorId(event),
    _PlanEntry(:final item) => _activityAnchorId(item),
    _EventEntry(:final event) => _eventAnchorId(event),
    _NowEntry() => 'now',
    _ => null,
  };

  double? _screenYForKey(GlobalKey? key) {
    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  /// Prefer an already-mounted past card; fall back to the "now" divider.
  ({String id, double screenY})? _pickInsertAnchor(CommunityActivityFeed oldFeed) {
    final priorIds = <String>[
      for (final item in oldFeed.past) _activityAnchorId(item),
      for (final event in oldFeed.pastEvents) _eventAnchorId(event),
      'now',
    ];
    String? bestId;
    double? bestY;
    for (final id in priorIds) {
      final y = _screenYForKey(_entryKeys[id]);
      if (y == null) continue;
      // Topmost visible prior row — the one the eye is least willing to lose.
      if (bestY == null || y < bestY) {
        bestY = y;
        bestId = id;
      }
    }
    if (bestId == null || bestY == null) return null;
    return (id: bestId, screenY: bestY);
  }

  void _clearAnchorCorrection() {
    _anchorId = null;
    _anchorScreenY = null;
    _anchorFramesRemaining = 0;
  }

  void _schedulePastInsertCorrection(CommunityActivityFeed oldFeed) {
    final anchor = _pickInsertAnchor(oldFeed);
    if (anchor == null) return;
    _anchorId = anchor.id;
    _anchorScreenY = anchor.screenY;
    _anchorFramesRemaining = _anchorCorrectionFrameBudget;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runPastInsertCorrection();
    });
  }

  void _runPastInsertCorrection() {
    if (!mounted || !_scrollController.hasClients) {
      _clearAnchorCorrection();
      return;
    }

    final anchorId = _anchorId;
    final targetY = _anchorScreenY;
    if (anchorId != null && targetY != null) {
      final currentY = _screenYForKey(_entryKeys[anchorId]);
      if (currentY != null) {
        final drift = currentY - targetY;
        if (drift.abs() > 0.5) {
          final position = _scrollController.position;
          _scrollController.jumpTo(
            (position.pixels + drift).clamp(
              position.minScrollExtent,
              position.maxScrollExtent,
            ),
          );
        }
      }
    }

    if (_anchorFramesRemaining > 1) {
      _anchorFramesRemaining--;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runPastInsertCorrection();
      });
      return;
    }
    _clearAnchorCorrection();
    _scheduleNowVisibilityUpdate();
  }

  /// Jump so the center-keyed "now" divider sits mid-viewport.
  void _jumpNowToMidPanel() {
    if (!_scrollController.hasClients) return;
    final target = _nowCenteredScrollOffset();
    if ((_scrollController.position.pixels - target).abs() > 0.5) {
      _scrollController.jumpTo(target);
    }
    final nowContext = _entryKeys['now']?.currentContext;
    if (nowContext != null && nowContext.mounted) {
      Scrollable.ensureVisible(
        nowContext,
        alignment: 0.5,
        duration: Duration.zero,
      );
    }
  }

  void _ensureInitialScrollToNow() {
    if (!_autoCenterNow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_autoCenterNow) return;
      if (!_scrollController.hasClients) {
        // Layout hasn't attached the position yet — try again next frame.
        _ensureInitialScrollToNow();
        return;
      }
      _jumpNowToMidPanel();
      final wasFirst = !_didApplyInitialScroll;
      _didApplyInitialScroll = true;
      _scheduleAutoCenterRelease();
      // Refine once extents / the "now" row are fully laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_autoCenterNow) return;
        _jumpNowToMidPanel();
        _scheduleAutoCenterRelease();
        if (wasFirst) {
          _beginNowVisibilitySettle();
        } else {
          _scheduleNowVisibilityUpdate();
        }
      });
    });
  }

  void _scheduleNowVisibilityUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateNowVisibility();
    });
  }

  /// Hide any premature jump pill, then re-measure after layout settles while
  /// the bottom sheet / scroll extents finish laying out.
  void _beginNowVisibilitySettle() {
    _nowVisibilityReady = false;
    if (_jumpToNowDirection != null && mounted) {
      setState(() => _jumpToNowDirection = null);
    }
    // Two nested post-frame callbacks: one after the timeline jump applies,
    // one after the sheet's size for that frame is committed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _nowVisibilityReady = true;
        _updateNowVisibility();
      });
    });
  }

  void _onViewportConstraints(BoxConstraints constraints) {
    if (!constraints.hasBoundedHeight || !constraints.hasBoundedWidth) return;
    final next = Size(constraints.maxWidth, constraints.maxHeight);
    if (_lastViewportSize == next) return;
    final previous = _lastViewportSize;
    _lastViewportSize = next;
    // Explore sheet open animates height; re-center so "now" stays mid-panel
    // instead of stuck near the top from the first (short) frame.
    if (_autoCenterNow && previous != null) {
      _ensureInitialScrollToNow();
      return;
    }
    // Sheet expand / rotate changes the clip without a scroll event.
    if (_didApplyInitialScroll) {
      _scheduleNowVisibilityUpdate();
    }
  }

  void _updateNowVisibility() {
    _JumpToNowDirection? next;

    if (_scrollController.hasClients) {
      final nowBox =
          _entryKeys['now']?.currentContext?.findRenderObject() as RenderBox?;
      final viewportBox =
          _viewportKey.currentContext?.findRenderObject() as RenderBox?;

      if (nowBox != null &&
          viewportBox != null &&
          nowBox.hasSize &&
          viewportBox.hasSize &&
          nowBox.attached &&
          viewportBox.attached) {
        // Prefer the scrollable's paint clip when available — matches what
        // the user can actually see inside the sheet.
        RenderBox boundsBox = viewportBox;
        final scrollContext =
            _scrollController.position.context.notificationContext;
        final scrollBox = scrollContext?.findRenderObject() as RenderBox?;
        if (scrollBox != null && scrollBox.hasSize && scrollBox.attached) {
          boundsBox = scrollBox;
        }

        final nowRect = nowBox.localToGlobal(Offset.zero) & nowBox.size;
        final viewRect = (boundsBox.localToGlobal(Offset.zero) & boundsBox.size)
            .deflate(_nowVisibilityMargin);

        if (nowRect.overlaps(viewRect)) {
          next = null;
        } else if (nowRect.bottom <= viewRect.top) {
          next = _JumpToNowDirection.up;
        } else {
          next = _JumpToNowDirection.down;
        }
      } else {
        // Far offscreen, "now" may not be laid out (outside cache extent).
        // With a center-keyed timeline, offset 0 is "now" at the leading edge.
        final pixels = _scrollController.position.pixels;
        if (pixels < -_nowVisibilityMargin) {
          next = _JumpToNowDirection.down;
        } else if (pixels > _nowVisibilityMargin) {
          next = _JumpToNowDirection.up;
        } else {
          next = null;
        }
      }
    }

    // Until settle completes, keep the floating control hidden even if a
    // mid-animation measurement thinks "now" is offscreen.
    if (!_nowVisibilityReady) {
      next = null;
    }

    if (next != _jumpToNowDirection) {
      setState(() => _jumpToNowDirection = next);
    }
  }

  /// Scroll offset that puts the center-keyed "now" near mid-viewport.
  double _nowCenteredScrollOffset() {
    final position = _scrollController.position;
    // Offset 0 pins "now" to the leading edge; shift by half the viewport so
    // it sits roughly in the middle.
    return (-position.viewportDimension / 2).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  Future<void> _animateScrollTo(double offset, {required bool reduceMotion}) async {
    if (reduceMotion) {
      _scrollController.jumpTo(offset);
      return;
    }
    await _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _scrollToNow() async {
    if (!_scrollController.hasClients) return;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 320);

    // If "now" is far offscreen it may not be laid out yet — nudge near the
    // center offset first so ensureVisible can run.
    var nowContext = _entryKeys['now']?.currentContext;
    if (nowContext == null) {
      await _animateScrollTo(
        _nowCenteredScrollOffset(),
        reduceMotion: reduceMotion,
      );
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      nowContext = _entryKeys['now']?.currentContext;
    }

    if (nowContext != null && nowContext.mounted) {
      await Scrollable.ensureVisible(
        nowContext,
        alignment: 0.5,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
    } else if (_scrollController.hasClients) {
      await _animateScrollTo(
        _nowCenteredScrollOffset(),
        reduceMotion: reduceMotion,
      );
    }
    if (mounted) _updateNowVisibility();
  }

  List<_StreamEntry> _pastNewestFirst() {
    return <_StreamEntry>[
      ...widget.feed.past.map(_PastEntry.new),
      ...widget.feed.pastEvents.map(_PastEventEntry.new),
    ]..sort((a, b) => b.sortTime.compareTo(a.sortTime));
  }

  List<_StreamEntry> _upcomingSoonestFirst() {
    return <_StreamEntry>[
      ...widget.feed.upcoming.map(_PlanEntry.new),
      ...widget.feed.events.map(_EventEntry.new),
    ]..sort((a, b) => a.sortTime.compareTo(b.sortTime));
  }

  Widget _padRow(Widget child, {required bool isLastInSection}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLastInSection ? 0 : 10),
      child: child,
    );
  }

  Widget _buildEntry(_StreamEntry entry, DateTime now) {
    final anchorId = _entryAnchorId(entry);
    final child = switch (entry) {
      _ShowEarlierEntry(:final remainingCount) => _ShowEarlierButton(
        remainingCount: remainingCount,
        loading: widget.loadingMorePast,
        onPressed: widget.loadingMorePast ? null : widget.onLoadMorePast,
      ),
      _PastHistoryLimitEntry() => const _PastHistoryLimitCaption(),
      _PastEntry(:final item) => CommunityActivityCard(
        item: item,
        now: now,
        onOpenSpot: () => widget.onOpenSpot(item),
        onOpenActor: _actorCallback(item),
      ),
      _PastEventEntry(:final event) => CommunityEventActivityCard(
        event: event,
        now: now,
        onTap: () => widget.onOpenEvent(event.pin),
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
      _ShowMoreUpcomingEntry(:final remainingCount) => _ShowMoreUpcomingButton(
        remainingCount: remainingCount,
        loading: widget.loadingMoreUpcoming,
        onPressed: widget.loadingMoreUpcoming
            ? null
            : widget.onLoadMoreUpcoming,
      ),
    };
    if (anchorId == null) return child;
    // GlobalKey keeps list identity stable and supplies screen-Y for
    // post-insert drift correction while extents settle.
    return KeyedSubtree(key: _keyFor(anchorId), child: child);
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.now ?? DateTime.now().toUtc();
    final padding = widget.padding;
    final pastNewestFirst = _pastNewestFirst();
    final upcoming = _upcomingSoonestFirst();

    final remainingPast = widget.feed.hasMorePast
        ? (widget.feed.pastTotal > widget.feed.loadedPastCount
              ? widget.feed.pastTotal - widget.feed.loadedPastCount
              : null)
        : null;
    final remainingUpcoming = widget.feed.hasMoreUpcoming
        ? (widget.feed.upcomingTotal > widget.feed.loadedUpcomingCount
              ? widget.feed.upcomingTotal - widget.feed.loadedUpcomingCount
              : null)
        : null;
    final showEarlier =
        widget.feed.hasMorePast && widget.onLoadMorePast != null;
    final showPastLimit =
        !widget.feed.hasMorePast && widget.feed.loadedPastCount > 0;
    final showMoreUpcoming =
        widget.feed.hasMoreUpcoming && widget.onLoadMoreUpcoming != null;

    _ensureInitialScrollToNow();

    // Before [center], the first sliver is at the top of the timeline. Past is
    // still newest-first so growth from "Show earlier" expands away from "now"
    // and the viewport stays put.
    final jumpDirection = _jumpToNowDirection;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: CommunityActivityStream.maxContentWidth,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            _onViewportConstraints(constraints);
            return Stack(
              key: _viewportKey,
              children: [
                NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification is UserScrollNotification) {
                      // Hand off: stop auto-centering once the user scrolls.
                      if (_autoCenterNow) {
                        _stopAutoCenterNow();
                      }
                      if (_anchorFramesRemaining > 0) {
                        // Don't fight the user if they scroll during extent settling.
                        _clearAnchorCorrection();
                      }
                    }
                    // Metrics fire on sheet resize / extent settle — re-center
                    // while still auto-centering so image loads don't leave
                    // "now" pinned to the leading edge.
                    if (_autoCenterNow &&
                        notification is ScrollMetricsNotification &&
                        _didApplyInitialScroll &&
                        _scrollController.hasClients) {
                      final drift =
                          (_scrollController.position.pixels -
                                  _nowCenteredScrollOffset())
                              .abs();
                      if (drift > 8) {
                        _ensureInitialScrollToNow();
                      }
                    }
                    // Metrics fire on sheet resize; updates/ends on user scroll.
                    if (notification is ScrollMetricsNotification ||
                        notification is ScrollEndNotification ||
                        notification is ScrollUpdateNotification) {
                      _scheduleNowVisibilityUpdate();
                    }
                    return false;
                  },
                  child: _CenteredTimelineScrollView(
                controller: _scrollController,
                centerKey: _nowCenterKey,
                slivers: [
                  if (showEarlier || showPastLimit)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        padding.left,
                        padding.top,
                        padding.right,
                        10,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _buildEntry(
                          showEarlier
                              ? _ShowEarlierEntry(remainingPast)
                              : const _PastHistoryLimitEntry(),
                          now,
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.only(top: padding.top),
                      sliver: const SliverToBoxAdapter(
                        child: SizedBox.shrink(),
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      padding.left,
                      0,
                      padding.right,
                      0,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final entry = pastNewestFirst[index];
                          return _padRow(
                            _buildEntry(entry, now),
                            isLastInSection: false,
                          );
                        },
                        childCount: pastNewestFirst.length,
                      ),
                    ),
                  ),
                  KeyedSubtree(
                    key: _nowCenterKey,
                    child: SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        padding.left,
                        0,
                        padding.right,
                        10,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _buildEntry(const _NowEntry(), now),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      padding.left,
                      0,
                      padding.right,
                      showMoreUpcoming ? 0 : padding.bottom,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final entry = upcoming[index];
                          final isLast =
                              index == upcoming.length - 1 && !showMoreUpcoming;
                          return _padRow(
                            _buildEntry(entry, now),
                            isLastInSection: isLast,
                          );
                        },
                        childCount: upcoming.length,
                      ),
                    ),
                  ),
                  if (showMoreUpcoming)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        padding.left,
                        10,
                        padding.right,
                        padding.bottom,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _buildEntry(
                          _ShowMoreUpcomingEntry(remainingUpcoming),
                          now,
                        ),
                      ),
                    ),
                ],
              ),
            ),
                if (jumpDirection != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: jumpDirection == _JumpToNowDirection.up ? 8 : null,
                    bottom: jumpDirection == _JumpToNowDirection.down
                        ? 8
                        : null,
                    child: Center(
                      child: _JumpToNowPill(
                        direction: jumpDirection,
                        onPressed: _scrollToNow,
                      ),
                    ),
                  ),
              ],
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

/// Local wrapper so DevTools can confirm the center-keyed timeline is mounted.
class _CenteredTimelineScrollView extends StatelessWidget {
  const _CenteredTimelineScrollView({
    required this.controller,
    required this.centerKey,
    required this.slivers,
  });

  final ScrollController controller;
  final Key centerKey;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      center: centerKey,
      slivers: slivers,
    );
  }
}

sealed class _StreamEntry {
  const _StreamEntry();

  /// Sort key for past (occurred) and upcoming (start) ordering.
  DateTime get sortTime => DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

class _ShowEarlierEntry extends _StreamEntry {
  const _ShowEarlierEntry(this.remainingCount);
  final int? remainingCount;
}

class _PastHistoryLimitEntry extends _StreamEntry {
  const _PastHistoryLimitEntry();
}

class _ShowMoreUpcomingEntry extends _StreamEntry {
  const _ShowMoreUpcomingEntry(this.remainingCount);
  final int? remainingCount;
}

class _PastEntry extends _StreamEntry {
  const _PastEntry(this.item);
  final CommunityActivityItem item;

  @override
  DateTime get sortTime => item.occurredAt;
}

class _PastEventEntry extends _StreamEntry {
  const _PastEventEntry(this.event);
  final CommunityEventItem event;

  @override
  DateTime get sortTime => event.occurredAt;
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
    required this.remainingCount,
    required this.loading,
    required this.onPressed,
  });

  final int? remainingCount;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = remainingCount != null && remainingCount! > 0
        ? l10n.communityStreamShowEarlier(remainingCount!)
        : l10n.communityStreamShowEarlierGeneric;
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.history, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _ShowMoreUpcomingButton extends StatelessWidget {
  const _ShowMoreUpcomingButton({
    required this.remainingCount,
    required this.loading,
    required this.onPressed,
  });

  final int? remainingCount;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = remainingCount != null && remainingCount! > 0
        ? l10n.communityStreamShowMoreUpcoming(remainingCount!)
        : l10n.communityStreamShowMoreUpcomingGeneric;
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.expand_more, size: 18),
        label: Text(label),
      ),
    );
  }
}

/// Quiet terminus when the past half has no older pages left.
class _PastHistoryLimitCaption extends StatelessWidget {
  const _PastHistoryLimitCaption();

  /// Matches server `PAST_ACTIVITY_RETENTION_MS` (90 days).
  static const int retentionDays = 90;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        l10n.communityStreamPastHistoryLimit(retentionDays),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Timeline marker between what already happened and what is planned.
class CommunityNowDivider extends StatelessWidget {
  const CommunityNowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final line = Expanded(
      child: Divider(color: colorScheme.primary.withValues(alpha: 0.6)),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          line,
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: _NowPill(),
          ),
          line,
        ],
      ),
    );
  }
}

/// Shared filled "now" chip used by the inline divider and the jump control.
class _NowPill extends StatelessWidget {
  const _NowPill({this.leading, this.trailing});

  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: colorScheme.onPrimary,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 4)],
          Text(l10n.communityStreamNowDivider, style: labelStyle),
          if (trailing != null) ...[const SizedBox(width: 4), trailing!],
        ],
      ),
    );
  }
}

/// Floating control that scrolls the timeline back to the "now" divider.
class _JumpToNowPill extends StatelessWidget {
  const _JumpToNowPill({required this.direction, required this.onPressed});

  final _JumpToNowDirection direction;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final arrow = Icon(
      direction == _JumpToNowDirection.up
          ? Icons.keyboard_arrow_up
          : Icons.keyboard_arrow_down,
      size: 18,
      color: colorScheme.onPrimary,
    );
    return Semantics(
      button: true,
      label: l10n.communityStreamJumpToNow,
      child: Material(
        key: CommunityActivityStream.jumpToNowKey,
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: _NowPill(
            // Arrow points the way back to "now".
            leading: direction == _JumpToNowDirection.up ? arrow : null,
            trailing: direction == _JumpToNowDirection.down ? arrow : null,
          ),
        ),
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
    // Past events use [CommunityEventActivityCard], not this card.
    CommunityActivityKind.eventEnded => Icons.event,
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
    CommunityActivityKind.eventEnded => actor,
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
      case CommunityActivityKind.eventEnded:
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
    final isPast = event.isPast;
    final headline = isPast
        ? l10n.communityStreamEventPast
        : _isHappeningNow
        ? l10n.communityStreamEventHappeningNow
        : l10n.communityStreamEventUpcoming;
    final goingLabel = isPast
        ? l10n.communityStreamEventAttended(event.goingCount)
        : l10n.communityStreamEventGoing(event.goingCount);
    final interestedLabel = isPast
        ? l10n.communityStreamEventWereInterested(event.interestedCount)
        : l10n.communityStreamEventInterested(event.interestedCount);

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
                    if (event.goingCount > 0 || event.interestedCount > 0) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (event.goingCount > 0)
                            _CountChip(
                              icon: Icons.check_circle_outline,
                              label: goingLabel,
                              emphasized: true,
                            ),
                          if (event.interestedCount > 0)
                            _CountChip(
                              icon: Icons.star_outline,
                              label: interestedLabel,
                            ),
                        ],
                      ),
                    ],
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
