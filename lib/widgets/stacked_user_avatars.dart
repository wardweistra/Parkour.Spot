import 'package:flutter/material.dart';

/// Compact overlapping circle avatars for presence / who-rated chips.
class StackedUserAvatars extends StatelessWidget {
  const StackedUserAvatars({
    super.key,
    required this.entries,
    this.maxShown = 4,
    this.radius = 12,
    this.overlapFactor = 1.15,
  });

  final List<StackedUserAvatarEntry> entries;
  final int maxShown;
  final double radius;

  /// Horizontal step between avatar centers as a multiple of [radius].
  final double overlapFactor;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty || maxShown <= 0) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final shown = entries.take(maxShown).toList(growable: false);
    final overlap = radius * overlapFactor;

    return SizedBox(
      width: shown.isEmpty ? 0 : (shown.length - 1) * overlap + radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * overlap,
              child: _StackedAvatarCircle(
                entry: shown[i],
                radius: radius,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Soft overlapping circles while real avatars load (same approach as the
/// Community presence strip skeleton).
class StackedUserAvatarsSkeleton extends StatelessWidget {
  const StackedUserAvatarsSkeleton({
    super.key,
    this.count = 3,
    this.radius = 12,
    this.overlapFactor = 1.15,
  });

  final int count;
  final double radius;
  final double overlapFactor;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final placeholder = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.85);
    final overlap = radius * overlapFactor;
    final shown = count;

    return SizedBox(
      width: (shown - 1) * overlap + radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown; i++)
            Positioned(
              left: i * overlap,
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  color: placeholder,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StackedUserAvatarEntry {
  const StackedUserAvatarEntry({
    required this.userId,
    this.displayName,
    this.photoURL,
  });

  final String userId;
  final String? displayName;
  final String? photoURL;
}

class _StackedAvatarCircle extends StatelessWidget {
  const _StackedAvatarCircle({
    required this.entry,
    required this.radius,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final StackedUserAvatarEntry entry;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final photo = entry.photoURL?.trim();
    final name = entry.displayName?.trim();
    final initial = (name != null && name.isNotEmpty)
        ? name[0].toUpperCase()
        : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor,
      backgroundImage: (photo != null && photo.isNotEmpty)
          ? NetworkImage(photo)
          : null,
      child: (photo == null || photo.isEmpty)
          ? Text(
              initial,
              style: TextStyle(
                fontSize: radius * 0.9,
                fontWeight: FontWeight.w600,
                color: foregroundColor,
              ),
            )
          : null,
    );
  }
}
