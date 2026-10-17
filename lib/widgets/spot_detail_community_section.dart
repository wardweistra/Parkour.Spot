import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/spot_detail_ui.dart';
import '../l10n/app_localizations.dart';
import '../models/spot_check_in.dart';
import '../models/spot_training_plan.dart';
import '../services/auth_service.dart';
import '../services/spot_check_in_service.dart';
import '../services/spot_training_plan_service.dart';
import '../utils/community_activity_time_formatting.dart';
import 'spot_check_in_presence.dart';
import 'spot_detail_community_activity_dialog.dart';
import 'training_plan_presence.dart';

/// Spot detail: compact community strip — tight when empty (usual case), slightly
/// richer when people are checked in (social proof).
class SpotDetailCommunitySection extends StatefulWidget {
  const SpotDetailCommunitySection({
    super.key,
    required this.spotId,
    this.spotDisplayName,
    this.countryCode,
    this.city,
    required this.onNewCheckIn,
    required this.onEditCheckIn,
    required this.onNewTrainingPlan,
    required this.onEditTrainingPlan,
    required this.onJoinTrainingPlan,
    required this.onLoginRequired,
  });

  final String spotId;
  /// For share links in the Community dialog (SEO path when set).
  final String? spotDisplayName;
  final String? countryCode;
  final String? city;
  final Future<void> Function() onNewCheckIn;
  final Future<void> Function(SpotCheckIn existing) onEditCheckIn;
  final Future<void> Function() onNewTrainingPlan;
  final Future<void> Function(SpotTrainingPlan existing) onEditTrainingPlan;
  final Future<void> Function(SpotTrainingPlan sourcePlan) onJoinTrainingPlan;
  final VoidCallback onLoginRequired;

  @override
  State<SpotDetailCommunitySection> createState() =>
      _SpotDetailCommunitySectionState();
}

class _SpotDetailCommunitySectionState extends State<SpotDetailCommunitySection> {
  static const double _avatarRadius = 20;
  static const double _avatarOverlap = _avatarRadius * (23.0 / 20.0);
  /// Distinct from [null] uid so signed-out users still refresh `_myStream` after spot changes.
  static const Object _uidUnset = Object();

  Stream<List<SpotCheckIn>>? _publicStream;
  Stream<SpotCheckIn?>? _myStream;
  Stream<List<SpotTrainingPlan>>? _publicPlansStream;
  Stream<SpotTrainingPlan?>? _myPlanStream;
  Object? _lastUid = _uidUnset;
  String? _cachedSpotId;

  /// True while a check-in or planning flow runs (lookups before its dialog
  /// opens, then the dialog itself). Shows progress and blocks double taps.
  bool _checkInBusy = false;
  bool _planBusy = false;

  Future<void> _runCheckInFlow(Future<void> Function() flow) async {
    if (_checkInBusy) return;
    setState(() => _checkInBusy = true);
    try {
      await flow();
    } finally {
      if (mounted) setState(() => _checkInBusy = false);
    }
  }

  Future<void> _runPlanFlow(Future<void> Function() flow) async {
    if (_planBusy) return;
    setState(() => _planBusy = true);
    try {
      await flow();
    } finally {
      if (mounted) setState(() => _planBusy = false);
    }
  }

  static Widget _buttonIcon(IconData icon, {required bool busy}) {
    if (!busy) return Icon(icon, size: 18);
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }

  @override
  void didUpdateWidget(covariant SpotDetailCommunitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spotId != widget.spotId) {
      _cachedSpotId = null;
      _publicStream = null;
      _publicPlansStream = null;
      _lastUid = _uidUnset;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final svc = Provider.of<SpotCheckInService>(context, listen: false);
    final planSvc = Provider.of<SpotTrainingPlanService>(context, listen: false);
    final auth = Provider.of<AuthService>(context);
    final uid = auth.currentUser?.uid;
    if (_cachedSpotId != widget.spotId) {
      _cachedSpotId = widget.spotId;
      _publicStream = svc.watchPublicCheckIns(widget.spotId);
      _publicPlansStream = planSvc.watchPublicPlansForSpot(widget.spotId);
      _lastUid = _uidUnset;
    }
    if (uid != _lastUid) {
      _lastUid = uid;
      _myStream = uid == null
          ? Stream.value(null)
          : svc.watchMyCheckIn(widget.spotId);
      _myPlanStream = uid == null
          ? Stream.value(null)
          : planSvc.watchMyPlanForSpot(widget.spotId);
    }
  }

  String _plainTooltipFor(CheckInAvatarEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    final c = entry.checkIn;
    final until = communityFriendlyCheckInUntil(c.expectedEndAt, l10n);
    final comment = c.comment?.trim();
    if (entry.showPrivateBadge) {
      final head = l10n.spotCheckInTooltipPrivate(until);
      if (comment != null && comment.isNotEmpty) {
        return '$head\n$comment';
      }
      return head;
    }
    final name = c.displayName?.trim();
    final who = (name != null && name.isNotEmpty)
        ? name
        : l10n.spotCheckInUnnamedPerson;
    final head = l10n.spotCheckInTooltipPublic(who, until);
    if (comment != null && comment.isNotEmpty) {
      return '$head\n$comment';
    }
    return head;
  }

  static const double _kPresenceRingWidth = 2;

  Widget _stackedAvatar(
    BuildContext context,
    ThemeData theme,
    CheckInAvatarEntry entry,
    double radius,
  ) {
    final cs = theme.colorScheme;
    final c = entry.checkIn;
    final innerR = math.max(4.0, radius - _kPresenceRingWidth);
    final avatar = CircleAvatar(
      radius: innerR,
      backgroundColor: cs.surfaceContainerHighest,
      backgroundImage: c.photoURL != null ? NetworkImage(c.photoURL!) : null,
      child: c.photoURL == null
          ? Text(
              (c.displayName?.isNotEmpty == true ? c.displayName![0] : '?')
                  .toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: math.max(11, innerR * 0.85),
              ),
            )
          : null,
    );

    /// Primary ring = “here now” (live check-in).
    final ringed = CircleAvatar(
      radius: radius,
      backgroundColor: cs.primary,
      child: avatar,
    );

    Widget target;
    if (entry.showPrivateBadge) {
      target = SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ringed,
            Positioned(
              right: -1,
              bottom: -1,
              child: Material(
                color: cs.surface,
                elevation: 1,
                shape: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.lock_outline,
                    size: radius * 0.65,
                    color: cs.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      target = ringed;
    }

    return Tooltip(
      message: _plainTooltipFor(entry),
      child: target,
    );
  }

  Widget _avatarStackRow(
    BuildContext context,
    ThemeData theme,
    List<CheckInAvatarEntry> entries,
  ) {
    const maxShown = 6;
    final shown = entries.take(maxShown).toList();
    final extra = entries.length - shown.length;
    final extraStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: shown.isEmpty ? 0 : (shown.length - 1) * _avatarOverlap + _avatarRadius * 2,
          height: _avatarRadius * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * _avatarOverlap,
                  child: _stackedAvatar(
                    context,
                    theme,
                    shown[i],
                    _avatarRadius,
                  ),
                ),
            ],
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 6),
          Text('+$extra', style: extraStyle),
        ],
      ],
    );
  }

  String _trainingTooltipFor(TrainingPlanAvatarEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    final p = entry.plan;
    final now = DateTime.now();
    final inActiveWindow = now.toUtc().isAfter(p.plannedStartAt.toUtc()) &&
        p.plannedEndAt.toUtc().isAfter(now.toUtc());

    final String head;
    if (inActiveWindow) {
      final untilTime = communityFriendlyCheckInUntil(p.plannedEndAt, l10n);
      if (entry.showPrivateBadge) {
        head = l10n.spotTrainingPlanTooltipPrivateUntil(untilTime);
      } else {
        final name = p.displayName?.trim();
        final who = (name != null && name.isNotEmpty)
            ? name
            : l10n.spotCheckInUnnamedPerson;
        head = l10n.spotTrainingPlanTooltipPublicUntil(who, untilTime);
      }
    } else {
      final timeRange = communityFriendlyPlannedTrainingStart(
        p.plannedStartAt,
        l10n,
      );
      if (entry.showPrivateBadge) {
        head = l10n.spotTrainingPlanTooltipPrivate(timeRange);
      } else {
        final name = p.displayName?.trim();
        final who = (name != null && name.isNotEmpty)
            ? name
            : l10n.spotCheckInUnnamedPerson;
        head = l10n.spotTrainingPlanTooltipPublic(who, timeRange);
      }
    }

    final comment = p.comment?.trim();
    if (comment != null && comment.isNotEmpty) {
      return '$head\n$comment';
    }
    return head;
  }

  Widget _stackedAvatarTraining(
    BuildContext context,
    ThemeData theme,
    TrainingPlanAvatarEntry entry,
    double radius,
  ) {
    final cs = theme.colorScheme;
    final planAccent = cs.secondary;
    final p = entry.plan;
    final innerR = math.max(4.0, radius - _kPresenceRingWidth);
    final avatar = CircleAvatar(
      radius: innerR,
      backgroundColor: cs.surfaceContainerHighest,
      backgroundImage: p.photoURL != null ? NetworkImage(p.photoURL!) : null,
      child: p.photoURL == null
          ? Text(
              (p.displayName?.isNotEmpty == true ? p.displayName![0] : '?')
                  .toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: math.max(11, innerR * 0.85),
              ),
            )
          : null,
    );

    /// Secondary-colored ring = “planning ahead” (not live yet).
    final ringed = CircleAvatar(
      radius: radius,
      backgroundColor: planAccent,
      child: avatar,
    );

    Widget target;
    if (entry.showPrivateBadge) {
      target = SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ringed,
            Positioned(
              right: -1,
              bottom: -1,
              child: Material(
                color: cs.surface,
                elevation: 1,
                shape: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.lock_outline,
                    size: radius * 0.65,
                    color: planAccent,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      target = ringed;
    }

    return Tooltip(
      message: _trainingTooltipFor(entry),
      child: target,
    );
  }

  Widget _avatarStackRowTraining(
    BuildContext context,
    ThemeData theme,
    List<TrainingPlanAvatarEntry> entries,
  ) {
    const maxShown = 6;
    final shown = entries.take(maxShown).toList();
    final extra = entries.length - shown.length;
    final extraStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: shown.isEmpty ? 0 : (shown.length - 1) * _avatarOverlap + _avatarRadius * 2,
          height: _avatarRadius * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * _avatarOverlap,
                  child: _stackedAvatarTraining(
                    context,
                    theme,
                    shown[i],
                    _avatarRadius,
                  ),
                ),
            ],
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 6),
          Text('+$extra', style: extraStyle),
        ],
      ],
    );
  }

  Widget _planningControl({
    required ThemeData theme,
    required AppLocalizations l10n,
    required bool authenticated,
    required SpotTrainingPlan? myPlan,
  }) {
    final tip = l10n.spotDetailCommunityPlanningVisitTooltip;
    void onPressed() {
      if (!authenticated) {
        widget.onLoginRequired();
        return;
      }
      final m = myPlan;
      _runPlanFlow(
        m != null
            ? () => widget.onEditTrainingPlan(m)
            : widget.onNewTrainingPlan,
      );
    }

    final label = !authenticated
        ? l10n.spotDetailCommunitySignInToPlanButton
        : (myPlan != null
            ? l10n.spotDetailCommunityEditTrainingPlanButton
            : l10n.spotDetailCommunityPlanningVisitButton);

    final IconData planIcon;
    if (!authenticated) {
      planIcon = Icons.event_available_outlined;
    } else if (myPlan != null) {
      planIcon = Icons.edit_calendar_outlined;
    } else {
      planIcon = Icons.event_available_outlined;
    }

    return Tooltip(
      message: tip,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _planBusy ? null : onPressed,
          icon: _buttonIcon(planIcon, busy: _planBusy),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _checkInButton({
    required AppLocalizations l10n,
    required bool authenticated,
    required SpotCheckIn? mine,
  }) {
    void onCheckInPressed() {
      final m = mine;
      _runCheckInFlow(
        m != null ? () => widget.onEditCheckIn(m) : widget.onNewCheckIn,
      );
    }

    if (!authenticated) {
      return Tooltip(
        message: l10n.spotDetailCommunitySignInToCheckInButtonTooltip,
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: widget.onLoginRequired,
            icon: const Icon(Icons.place_outlined, size: 18),
            label: Text(l10n.spotDetailCommunitySignInToCheckInButton),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),
      );
    }

    final checkedIn = mine != null;
    return Tooltip(
      message: checkedIn
          ? l10n.spotDetailCommunityEditCheckInButtonTooltip
          : l10n.spotDetailCommunityCheckInButtonTooltip,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: _checkInBusy ? null : onCheckInPressed,
          icon: _buttonIcon(
            checkedIn ? Icons.edit_location_alt_outlined : Icons.place_outlined,
            busy: _checkInBusy,
          ),
          label: Text(
            checkedIn
                ? l10n.spotDetailCommunityEditCheckInButton
                : l10n.spotDetailCommunityCheckInButton,
          ),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required ThemeData theme,
    required ColorScheme cs,
    required AppLocalizations l10n,
    required bool showSubtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.groups_2_outlined,
          size: 20,
          color: cs.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.spotDetailCommunitySectionTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (showSubtitle) ...[
                const SizedBox(height: 2),
                Text(
                  l10n.spotDetailCommunitySectionSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.68),
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Placeholder for the presence / empty-status row (same approach as
  /// Notifications: soft bars and circles, no spinner-only empty panel).
  Widget _socialStripSkeleton(ColorScheme cs) {
    final placeholder = cs.surfaceContainerHighest.withValues(alpha: 0.85);
    const skeletonCount = 3;
    final stackWidth =
        (skeletonCount - 1) * _avatarOverlap + _avatarRadius * 2;

    Widget circle() => Container(
          width: _avatarRadius * 2,
          height: _avatarRadius * 2,
          decoration: BoxDecoration(
            color: placeholder,
            shape: BoxShape.circle,
          ),
        );

    return SizedBox(
      height: _avatarRadius * 2,
      child: Row(
        children: [
          SizedBox(
            width: stackWidth,
            height: _avatarRadius * 2,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < skeletonCount; i++)
                  Positioned(
                    left: i * _avatarOverlap,
                    child: circle(),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 12,
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 96),
                decoration: BoxDecoration(
                  color: placeholder,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButtonSkeleton(ColorScheme cs) {
    final placeholder = cs.surfaceContainerHighest.withValues(alpha: 0.85);
    return Container(
      height: 40,
      width: double.infinity,
      decoration: BoxDecoration(
        color: placeholder,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _panelColumn({
    required ThemeData theme,
    required ColorScheme cs,
    required AppLocalizations l10n,
    required bool showSubtitle,
    required Widget socialStrip,
    required Widget checkIn,
    required Widget planning,
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 520;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader(
              theme: theme,
              cs: cs,
              l10n: l10n,
              showSubtitle: showSubtitle,
            ),
            const SizedBox(height: 8),
            socialStrip,
            const SizedBox(height: 10),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: checkIn),
                  const SizedBox(width: 10),
                  Expanded(child: planning),
                ],
              )
            else ...[
              checkIn,
              const SizedBox(height: 8),
              planning,
            ],
          ],
        );
      },
    );
  }

  /// Header + skeleton presence row + real actions when auth is known, or
  /// skeleton actions while auth itself is still resolving.
  Widget _loadingPanel({
    required ThemeData theme,
    required ColorScheme cs,
    required AppLocalizations l10n,
    required AuthService auth,
  }) {
    final social = _socialStripSkeleton(cs);
    if (auth.isLoading) {
      return _panelColumn(
        theme: theme,
        cs: cs,
        l10n: l10n,
        showSubtitle: false,
        socialStrip: social,
        checkIn: _actionButtonSkeleton(cs),
        planning: _actionButtonSkeleton(cs),
      );
    }
    return _panelColumn(
      theme: theme,
      cs: cs,
      l10n: l10n,
      showSubtitle: false,
      socialStrip: social,
      checkIn: _checkInButton(
        l10n: l10n,
        authenticated: auth.isAuthenticated,
        mine: null,
      ),
      planning: _planningControl(
        theme: theme,
        l10n: l10n,
        authenticated: auth.isAuthenticated,
        myPlan: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final auth = Provider.of<AuthService>(context);

    Widget body;
    if (auth.isLoading ||
        _publicStream == null ||
        _myStream == null ||
        _publicPlansStream == null ||
        _myPlanStream == null) {
      body = _loadingPanel(
        theme: theme,
        cs: cs,
        l10n: l10n,
        auth: auth,
      );
    } else {
      body = StreamBuilder<List<SpotCheckIn>>(
        stream: _publicStream,
        builder: (context, publicSnap) {
          return StreamBuilder<SpotCheckIn?>(
            stream: _myStream,
            builder: (context, mySnap) {
              return StreamBuilder<List<SpotTrainingPlan>>(
                stream: _publicPlansStream,
                builder: (context, plansPublicSnap) {
                  return StreamBuilder<SpotTrainingPlan?>(
                    stream: _myPlanStream,
                    builder: (context, myPlanSnap) {
                      // Until every stream has emitted, avoid flashing empty
                      // presence then jumping to avatars (moves the buttons).
                      final anyWaiting = [
                        publicSnap,
                        mySnap,
                        plansPublicSnap,
                        myPlanSnap,
                      ].any(
                        (snap) =>
                            snap.connectionState == ConnectionState.waiting,
                      );
                      if (anyWaiting) {
                        return _loadingPanel(
                          theme: theme,
                          cs: cs,
                          l10n: l10n,
                          auth: auth,
                        );
                      }

                      final entries = buildCheckInAvatarEntries(
                        publicSnap.data ?? [],
                        mySnap.data,
                      );
                      final hasPeople = entries.isNotEmpty;
                      final mine = mySnap.data;

                      final planningEntries = buildTrainingPlanAvatarEntries(
                        plansPublicSnap.data ?? [],
                        myPlanSnap.data,
                      );
                      final hasPlanningPresence = planningEntries.isNotEmpty;
                      final myPlan = myPlanSnap.data;

                      final unifiedSocialStrip =
                          !hasPeople && !hasPlanningPresence
                              ? Text(
                                  l10n.spotDetailCommunityNobodySocialShort,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    height: 1.3,
                                    color: cs.onSurface.withValues(alpha: 0.75),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => showSpotCommunityActivityDialog(
                                      context,
                                      theme,
                                      widget.spotId,
                                      spotDisplayName: widget.spotDisplayName,
                                      countryCode: widget.countryCode,
                                      city: widget.city,
                                      onJoinTrainingPlan:
                                          widget.onJoinTrainingPlan,
                                      onLoginRequired: widget.onLoginRequired,
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        children: [
                                          if (hasPeople) ...[
                                            Tooltip(
                                              message:
                                                  l10n.spotDetailPresenceHereNow,
                                              child: Icon(
                                                Icons.place_outlined,
                                                size: 17,
                                                color: cs.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            _avatarStackRow(
                                              context,
                                              theme,
                                              entries,
                                            ),
                                          ],
                                          if (hasPeople &&
                                              hasPlanningPresence)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                              ),
                                              child: Text(
                                                '·',
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  color: cs.onSurface
                                                      .withValues(alpha: 0.35),
                                                  height: 1,
                                                ),
                                              ),
                                            ),
                                          if (hasPlanningPresence) ...[
                                            Tooltip(
                                              message: l10n
                                                  .spotDetailCommunityPlanningToTrain,
                                              child: Icon(
                                                Icons.event_available_outlined,
                                                size: 17,
                                                color: cs.secondary,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            _avatarStackRowTraining(
                                              context,
                                              theme,
                                              planningEntries,
                                            ),
                                          ],
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              l10n.spotDetailCommunityViewAll,
                                              style: theme.textTheme.labelLarge
                                                  ?.copyWith(
                                                color: cs.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            size: 20,
                                            color: cs.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );

                      return _panelColumn(
                        theme: theme,
                        cs: cs,
                        l10n: l10n,
                        showSubtitle: hasPeople || hasPlanningPresence,
                        socialStrip: unifiedSocialStrip,
                        checkIn: _checkInButton(
                          l10n: l10n,
                          authenticated: auth.isAuthenticated,
                          mine: mine,
                        ),
                        planning: _planningControl(
                          theme: theme,
                          l10n: l10n,
                          authenticated: auth.isAuthenticated,
                          myPlan: myPlan,
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
          border: SpotDetailUi.outlineBorder(cs),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: body,
        ),
      ),
    );
  }
}
