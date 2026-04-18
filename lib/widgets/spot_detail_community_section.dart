import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/spot_detail_ui.dart';
import '../l10n/app_localizations.dart';
import '../models/spot_check_in.dart';
import '../services/auth_service.dart';
import '../services/spot_check_in_service.dart';
import 'spot_check_in_presence.dart';

/// Spot detail: compact community strip — tight when empty (usual case), slightly
/// richer when people are checked in (social proof).
class SpotDetailCommunitySection extends StatefulWidget {
  const SpotDetailCommunitySection({
    super.key,
    required this.spotId,
    required this.onNewCheckIn,
    required this.onEditCheckIn,
    required this.onLoginRequired,
  });

  final String spotId;
  final Future<void> Function() onNewCheckIn;
  final Future<void> Function(SpotCheckIn existing) onEditCheckIn;
  final VoidCallback onLoginRequired;

  @override
  State<SpotDetailCommunitySection> createState() =>
      _SpotDetailCommunitySectionState();
}

class _SpotDetailCommunitySectionState extends State<SpotDetailCommunitySection> {
  static const double _avatarRadius = 20;
  static const double _avatarOverlap = _avatarRadius * (23.0 / 20.0);

  Stream<List<SpotCheckIn>>? _publicStream;
  Stream<SpotCheckIn?>? _myStream;
  String? _lastUid;
  String? _cachedSpotId;

  @override
  void didUpdateWidget(covariant SpotDetailCommunitySection oldWidget) {
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

  String _plainTooltipFor(CheckInAvatarEntry entry) {
    final l10n = AppLocalizations.of(context)!;
    final c = entry.checkIn;
    final until = DateFormat('h:mm a').format(c.expectedEndAt.toLocal());
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

  Widget _stackedAvatar(
    BuildContext context,
    ThemeData theme,
    CheckInAvatarEntry entry,
    double radius,
  ) {
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

  Widget _planningControl({
    required ThemeData theme,
    required AppLocalizations l10n,
    required bool compact,
  }) {
    final tip = l10n.spotDetailCommunityPlanningVisitTooltip;
    if (compact) {
      return Tooltip(
        message: tip,
        child: IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          onPressed: null,
          icon: Icon(
            Icons.event_available_outlined,
            size: 22,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      );
    }
    return Tooltip(
      message: tip,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
        ),
        child: Text(l10n.spotDetailCommunityPlanningVisitButton),
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
      if (m != null) {
        widget.onEditCheckIn(m);
      } else {
        widget.onNewCheckIn();
      }
    }

    if (!authenticated) {
      return SizedBox(
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
      );
    }

    final checkedIn = mine != null;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: onCheckInPressed,
        icon: Icon(
          checkedIn ? Icons.edit_location_alt_outlined : Icons.place_outlined,
          size: 18,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final auth = Provider.of<AuthService>(context);

    Widget body;
    if (auth.isLoading || _publicStream == null || _myStream == null) {
      body = SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: cs.primary,
            ),
          ),
        ),
      );
    } else {
      body = StreamBuilder<List<SpotCheckIn>>(
        stream: _publicStream,
        builder: (context, publicSnap) {
          return StreamBuilder<SpotCheckIn?>(
            stream: _myStream,
            builder: (context, mySnap) {
              final entries =
                  buildCheckInAvatarEntries(publicSnap.data ?? [], mySnap.data);
              final hasPeople = entries.isNotEmpty;
              final mine = mySnap.data;

              final presenceBlock = hasPeople
                  ? Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () =>
                            showCheckInsListDialog(context, theme, widget.spotId),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              _avatarStackRow(context, theme, entries),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.spotDetailCommunityViewAll,
                                  style: theme.textTheme.labelLarge?.copyWith(
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
                    )
                  : Text.rich(
                      TextSpan(
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.3,
                          color: cs.onSurface.withValues(alpha: 0.75),
                        ),
                        children: [
                          TextSpan(
                            text: l10n.spotDetailPresenceHereNow,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: ' · ${l10n.spotDetailCommunityNobodyHereShort}',
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    );

              return LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth > 520;
                  final planning = _planningControl(
                    theme: theme,
                    l10n: l10n,
                    compact: !hasPeople,
                  );

                  final checkIn = _checkInButton(
                    l10n: l10n,
                    authenticated: auth.isAuthenticated,
                    mine: mine,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
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
                                if (hasPeople) ...[
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
                          if (!hasPeople) planning,
                        ],
                      ),
                      const SizedBox(height: 8),
                      presenceBlock,
                      const SizedBox(height: 10),
                      if (wide && hasPeople)
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
                        if (hasPeople) ...[
                          const SizedBox(height: 8),
                          planning,
                        ],
                      ],
                    ],
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
