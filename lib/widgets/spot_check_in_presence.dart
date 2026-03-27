import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../models/spot_check_in.dart';
import '../services/auth_service.dart';
import '../services/spot_check_in_service.dart';
import '../services/user_profile_service.dart';
import 'spot_check_in_dialog.dart';

/// Where [SpotCheckInPresenceStrip] is shown: detail header (tappable) vs spot card
/// (tap passes through to the card; tooltips on hover).
enum SpotCheckInPresenceVariant { detail, spotCard }

/// Spot detail action row uses 44×44 circles; avatars use [_kSpotDetailAvatarRadius].
const double _kSpotDetailActionButtonSize = 44;
const double _kSpotDetailAvatarRadius = 20;

/// Public + optional private self with lock badge (for dialogs and tooltips).
class CheckInAvatarEntry {
  const CheckInAvatarEntry(this.checkIn, {this.showPrivateBadge = false});

  final SpotCheckIn checkIn;
  final bool showPrivateBadge;
}

/// Public check-ins first; if you’re checked in privately and not in the public list, add your avatar with a badge.
List<CheckInAvatarEntry> buildCheckInAvatarEntries(
  List<SpotCheckIn> public,
  SpotCheckIn? mine,
) {
  final entries = public
      .map((c) => CheckInAvatarEntry(c, showPrivateBadge: false))
      .toList();
  if (mine != null && mine.isPrivate) {
    final alreadyInPublic = public.any((p) => p.userId == mine.userId);
    if (!alreadyInPublic) {
      entries.add(CheckInAvatarEntry(mine, showPrivateBadge: true));
    }
  }
  return entries;
}

/// Rebuilds whenever public or “my” check-in streams emit (e.g. after an edit).
Stream<List<CheckInAvatarEntry>> watchCheckInAvatarEntriesForSpot(
  SpotCheckInService svc,
  String spotId,
) {
  return Stream<List<CheckInAvatarEntry>>.multi((controller) {
    List<SpotCheckIn> latestPublic = [];
    SpotCheckIn? latestMine;

    void emit() {
      controller.add(buildCheckInAvatarEntries(latestPublic, latestMine));
    }

    late final StreamSubscription<List<SpotCheckIn>> sub1;
    late final StreamSubscription<SpotCheckIn?> sub2;
    sub1 = svc.watchPublicCheckIns(spotId).listen(
      (p) {
        latestPublic = p;
        emit();
      },
      onError: controller.addError,
    );
    sub2 = svc.watchMyCheckIn(spotId).listen(
      (m) {
        latestMine = m;
        emit();
      },
      onError: controller.addError,
    );

    controller.onCancel = () {
      sub1.cancel();
      sub2.cancel();
    };
  });
}

/// Lazy-attaches Firestore streams only when this widget is on-screen (or briefly was).
class SpotCheckInPresenceLazy extends StatefulWidget {
  const SpotCheckInPresenceLazy({
    super.key,
    required this.spotId,
    this.variant = SpotCheckInPresenceVariant.spotCard,
  });

  final String spotId;
  final SpotCheckInPresenceVariant variant;

  @override
  State<SpotCheckInPresenceLazy> createState() =>
      _SpotCheckInPresenceLazyState();
}

class _SpotCheckInPresenceLazyState extends State<SpotCheckInPresenceLazy> {
  bool _attach = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('spot-checkin-vis-${widget.spotId}'),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final visible = info.visibleFraction > 0;
        if (visible && !_attach) {
          setState(() => _attach = true);
        } else if (!visible && _attach) {
          setState(() => _attach = false);
        }
      },
      child: _attach
          ? SpotCheckInPresenceStrip(
              spotId: widget.spotId,
              variant: widget.variant,
            )
          : const SizedBox(width: 1, height: 1),
    );
  }
}

/// Avatar stack for “who’s here now” (public check-ins within their expected end time + private self).
class SpotCheckInPresenceStrip extends StatefulWidget {
  const SpotCheckInPresenceStrip({
    super.key,
    required this.spotId,
    this.variant = SpotCheckInPresenceVariant.detail,
    /// Shown below the avatar stack on [SpotCheckInPresenceVariant.detail] when non-null.
    this.detailLeadingLabel,
  });

  final String spotId;
  final SpotCheckInPresenceVariant variant;
  final String? detailLeadingLabel;

  @override
  State<SpotCheckInPresenceStrip> createState() =>
      _SpotCheckInPresenceStripState();
}

class _SpotCheckInPresenceStripState extends State<SpotCheckInPresenceStrip> {
  Stream<List<SpotCheckIn>>? _publicStream;
  Stream<SpotCheckIn?>? _myStream;
  String? _lastUid;
  String? _cachedSpotId;

  @override
  void didUpdateWidget(covariant SpotCheckInPresenceStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spotId != widget.spotId) {
      _cachedSpotId = null;
      _publicStream = null;
      _lastUid = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final svc = Provider.of<SpotCheckInService>(context, listen: false);
    final auth = Provider.of<AuthService>(context);
    final uid = auth.currentUser?.uid;
    if (_cachedSpotId != widget.spotId) {
      _cachedSpotId = widget.spotId;
      _publicStream = svc.watchPublicCheckIns(widget.spotId);
      _lastUid = null;
    }
    if (uid != _lastUid) {
      _lastUid = uid;
      _myStream = uid == null
          ? Stream.value(null)
          : svc.watchMyCheckIn(widget.spotId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = Provider.of<AuthService>(context);
    if (auth.isLoading || _publicStream == null || _myStream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<SpotCheckIn>>(
      stream: _publicStream,
      builder: (context, publicSnap) {
        final public = publicSnap.data ?? [];
        return StreamBuilder<SpotCheckIn?>(
          stream: _myStream,
          builder: (context, mySnap) {
            final mine = mySnap.data;
            final entries = buildCheckInAvatarEntries(public, mine);

            if (entries.isEmpty) {
              return const SizedBox.shrink();
            }

            final stack = _buildAvatarStack(context, theme, entries);

            if (widget.variant == SpotCheckInPresenceVariant.spotCard) {
              return stack;
            }

            final label = widget.detailLeadingLabel;
            final labelStyle = theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w500,
            );
            final avatarTopInset =
                _kSpotDetailActionButtonSize / 2 - _kSpotDetailAvatarRadius;
            final detailColumnChildren = <Widget>[
              Padding(
                padding: EdgeInsets.only(top: avatarTopInset),
                child: stack,
              ),
              if (label != null) ...[
                const SizedBox(height: 4),
                Text(
                  label,
                  style: labelStyle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      showCheckInsListDialog(context, theme, widget.spotId),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: detailColumnChildren,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvatarStack(
    BuildContext context,
    ThemeData theme,
    List<CheckInAvatarEntry> entries,
  ) {
    const maxShown = 6;
    final isCard = widget.variant == SpotCheckInPresenceVariant.spotCard;
    // Detail page: slightly under 44×44 action buttons; spot cards: compact on imagery.
    final double radius = isCard ? 14.0 : _kSpotDetailAvatarRadius;
    final double overlap =
        isCard ? 16.0 : _kSpotDetailAvatarRadius * (23.0 / 20.0);
    final shown = entries.take(maxShown).toList();
    final extra = entries.length - shown.length;
    final extraStyle = isCard
        ? theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            shadows: const [Shadow(blurRadius: 6, color: Colors.black54)],
          )
        : theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: shown.isEmpty ? 0 : (shown.length - 1) * overlap + radius * 2,
          height: radius * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(
                  left: i * overlap,
                  child: _stackedAvatar(
                    context,
                    theme,
                    shown[i],
                    radius,
                    passThroughTap: isCard,
                  ),
                ),
            ],
          ),
        ),
        if (extra > 0) ...[
          const SizedBox(width: 6),
          IgnorePointer(
            ignoring: isCard,
            child: Text('+$extra', style: extraStyle),
          ),
        ],
      ],
    );
  }

  Widget _stackedAvatar(
    BuildContext context,
    ThemeData theme,
    CheckInAvatarEntry entry,
    double radius, {
    required bool passThroughTap,
  }) {
    final c = entry.checkIn;
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      backgroundImage: c.photoURL != null ? NetworkImage(c.photoURL!) : null,
      child: c.photoURL == null
          ? Text(
              (c.displayName?.isNotEmpty == true ? c.displayName![0] : '?')
                  .toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: math.max(11, radius * 0.85),
              ),
            )
          : null,
    );

    final richMessage = entry.showPrivateBadge
        ? _privateCheckInTooltipSpan(context, theme, c)
        : _publicCheckInTooltipSpan(context, theme, c);

    Widget target;
    if (entry.showPrivateBadge) {
      target = SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            avatar,
            Positioned(
              right: -1,
              bottom: -1,
              child: Material(
                color: theme.colorScheme.surface,
                elevation: 1,
                shape: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.lock_outline,
                    size: radius * 0.65,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      target = avatar;
    }

    if (widget.variant == SpotCheckInPresenceVariant.spotCard) {
      target = _spotCardAvatarGlow(target, radius);
    }

    if (!passThroughTap) {
      return Tooltip(
        richMessage: richMessage,
        textStyle: _tooltipBaseTextStyle(context, theme),
        child: target,
      );
    }

    return Tooltip(
      richMessage: richMessage,
      textStyle: _tooltipBaseTextStyle(context, theme),
      child: IgnorePointer(ignoring: true, child: target),
    );
  }

  /// Soft white halo so avatars read on busy spot photos (Explore cards only).
  Widget _spotCardAvatarGlow(Widget child, double radius) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.88),
            blurRadius: 10,
            spreadRadius: 0.5,
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.45),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
      child: child,
    );
  }

  /// Matches [Tooltip] / [TooltipTheme]: inverse surface uses [ColorScheme.onInverseSurface].
  TextStyle _tooltipBaseTextStyle(BuildContext context, ThemeData theme) {
    final fromTheme = TooltipTheme.of(context).textStyle;
    if (fromTheme != null && fromTheme.color != null) {
      return fromTheme;
    }
    final cs = theme.colorScheme;
    return theme.textTheme.bodySmall?.copyWith(
          color: cs.onInverseSurface,
          height: 1.35,
        ) ??
        TextStyle(color: cs.onInverseSurface, fontSize: 13, height: 1.35);
  }

  TextStyle _tooltipCommentItalicStyle(BuildContext context, ThemeData theme) {
    final base = _tooltipBaseTextStyle(context, theme);
    final c = base.color ?? theme.colorScheme.onInverseSurface;
    return base.copyWith(
      fontStyle: FontStyle.italic,
      color: c.withValues(alpha: 0.92),
    );
  }

  TextSpan _publicCheckInTooltipSpan(
    BuildContext context,
    ThemeData theme,
    SpotCheckIn c,
  ) {
    final name = c.displayName?.trim();
    final who = (name != null && name.isNotEmpty) ? name : 'This person';
    final comment = c.comment?.trim();
    final until = DateFormat('h:mm a').format(c.expectedEndAt.toLocal());
    final headline = '$who is here now at this spot (until $until)';
    final baseStyle = _tooltipBaseTextStyle(context, theme);
    return _checkInTooltipSpanWithOptionalComment(
      context,
      theme,
      headline,
      headlineStyle: baseStyle,
      comment: comment,
    );
  }

  TextSpan _privateCheckInTooltipSpan(
    BuildContext context,
    ThemeData theme,
    SpotCheckIn mine,
  ) {
    final comment = mine.comment?.trim();
    final until = DateFormat('h:mm a').format(mine.expectedEndAt.toLocal());
    final headline =
        "You're here now at this spot until $until — only you can see this check-in";
    final baseStyle = _tooltipBaseTextStyle(context, theme);
    return _checkInTooltipSpanWithOptionalComment(
      context,
      theme,
      headline,
      headlineStyle: baseStyle,
      comment: comment,
    );
  }

  TextSpan _checkInTooltipSpanWithOptionalComment(
    BuildContext context,
    ThemeData theme,
    String headline, {
    required TextStyle headlineStyle,
    String? comment,
  }) {
    if (comment == null || comment.isEmpty) {
      return TextSpan(text: headline, style: headlineStyle);
    }
    return TextSpan(
      children: [
        TextSpan(text: headline, style: headlineStyle),
        TextSpan(
          text: '\n\n💬 $comment',
          style: _tooltipCommentItalicStyle(context, theme),
        ),
      ],
    );
  }
}

Future<void> navigateToUserProfileForCheckIn(
  BuildContext context,
  String userId,
) async {
  try {
    final userProfileService = Provider.of<UserProfileService>(
      context,
      listen: false,
    );
    final user = await userProfileService.getUserProfile(userId);
    final identifier = user?.username?.isNotEmpty == true
        ? user!.username!
        : userId;
    if (context.mounted) {
      context.push('/user/$identifier');
    }
  } catch (_) {
    if (context.mounted) {
      context.push('/user/$userId');
    }
  }
}

void showCheckInsListDialog(
  BuildContext context,
  ThemeData theme,
  String spotId,
) {
  final svc = Provider.of<SpotCheckInService>(context, listen: false);
  final entriesStream = watchCheckInAvatarEntriesForSpot(svc, spotId);

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
              Icons.place_outlined,
              color: theme.colorScheme.primary,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Here now',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: math.min(420, maxH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'These are the people training at this spot now.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<List<CheckInAvatarEntry>>(
                  stream: entriesStream,
                  builder: (dialogContext, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Could not load check-ins',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final sorted = List<CheckInAvatarEntry>.from(snap.data!)
                      ..sort(
                        (a, b) => b.checkIn.checkedInAt.compareTo(
                          a.checkIn.checkedInAt,
                        ),
                      );
                    if (sorted.isEmpty) {
                      return Center(
                        child: Text(
                          'No one here now',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: sorted.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (dialogContext, i) {
                        return CheckInUserCard(
                          key: ValueKey(sorted[i].checkIn.id),
                          entry: sorted[i],
                          hostContext: context,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

/// Comment block for check-in lists (matches “Here now” dialog and My check-ins).
class CheckInCommentBlock extends StatelessWidget {
  const CheckInCommentBlock({super.key, required this.comment});

  final String comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '💬 $comment',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurface.withValues(
            alpha: 0.8,
          ),
        ),
      ),
    );
  }
}

/// Single check-in row in the list dialog (spot-style note + avatar, inspired by [SpotCard] custom notes).
class CheckInUserCard extends StatelessWidget {
  const CheckInUserCard({
    super.key,
    required this.entry,
    required this.hostContext,
  });

  final CheckInAvatarEntry entry;
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = entry.checkIn;
    final uid = Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    final isMine = uid != null && uid == c.userId;
    final name = c.displayName?.trim();
    final title = (name != null && name.isNotEmpty) ? name : 'Someone here';
    final untilStr = DateFormat('h:mm a').format(c.expectedEndAt.toLocal());
    final comment = c.comment?.trim();

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final uid = c.userId;
          Navigator.of(context).pop();
          await navigateToUserProfileForCheckIn(hostContext, uid);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckInDialogAvatar(entry: entry),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isMine)
                          IconButton(
                            tooltip: 'Edit check-in',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: () async {
                              final svc = Provider.of<SpotCheckInService>(
                                context,
                                listen: false,
                              );
                              final stillHereEligible =
                                  await svc.stillHereEligibleForUser(c);
                              if (!context.mounted) return;
                              final result = await showSpotCheckInDialog(
                                context,
                                existingCheckIn: c,
                                stillHereEligible: stillHereEligible,
                              );
                              if (result == null || !context.mounted) return;
                              if (result is SpotCheckInDialogDeleted) {
                                final ok = await svc.deleteCheckIn(c.id);
                                if (!context.mounted) return;
                                if (ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Check-in removed'),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        svc.error ?? 'Could not delete check-in',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }
                              if (result is! SpotCheckInDialogSaved) return;
                              final ok = await svc.updateCheckIn(
                                c.id,
                                checkedInAt: result.checkedInAt!,
                                isPrivate: result.isPrivate,
                                expectedEndAt: result.expectedEndAt,
                                comment: result.comment,
                              );
                              if (!context.mounted) return;
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Check-in updated'),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      svc.error ?? 'Could not update check-in',
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        if (entry.showPrivateBadge) ...[
                          Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Only you',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Until $untilStr',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    if (comment != null && comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      CheckInCommentBlock(comment: comment),
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

class CheckInDialogAvatar extends StatelessWidget {
  const CheckInDialogAvatar({super.key, required this.entry});

  final CheckInAvatarEntry entry;

  static const double _radius = 28;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = entry.checkIn;
    final avatar = CircleAvatar(
      radius: _radius,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      backgroundImage: c.photoURL != null ? NetworkImage(c.photoURL!) : null,
      child: c.photoURL == null
          ? Text(
              (c.displayName?.isNotEmpty == true ? c.displayName![0] : '?')
                  .toUpperCase(),
              style: theme.textTheme.titleSmall,
            )
          : null,
    );

    if (!entry.showPrivateBadge) {
      return avatar;
    }

    return SizedBox(
      width: _radius * 2,
      height: _radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: theme.colorScheme.surface,
              elevation: 1,
              shape: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(
                  Icons.lock_outline,
                  size: _radius * 0.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
