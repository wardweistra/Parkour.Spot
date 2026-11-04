import 'package:flutter/material.dart';

import '../models/rating.dart';

/// Rows of who rated a spot (avatar, name, score).
class SpotRaterList extends StatelessWidget {
  const SpotRaterList({
    super.key,
    required this.ratings,
    required this.onRaterTap,
  });

  final List<Rating> ratings;
  final ValueChanged<Rating> onRaterTap;

  @override
  Widget build(BuildContext context) {
    if (ratings.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < ratings.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          SpotRaterListTile(
            rating: ratings[i],
            onTap: () => onRaterTap(ratings[i]),
          ),
        ],
      ],
    );
  }
}

class SpotRaterListTile extends StatelessWidget {
  const SpotRaterListTile({
    super.key,
    required this.rating,
    required this.onTap,
  });

  final Rating rating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = rating.displayName?.trim();
    final label = (name != null && name.isNotEmpty) ? name : '?';
    final photo = rating.photoURL?.trim();
    final initial = label[0].toUpperCase();
    final scoreLabel = rating.rating == rating.rating.roundToDouble()
        ? rating.rating.toStringAsFixed(0)
        : rating.rating.toStringAsFixed(1);

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
                Icon(Icons.star, size: 18, color: Colors.amber.shade700),
                const SizedBox(width: 4),
                Text(
                  scoreLabel,
                  style: theme.textTheme.titleMedium?.copyWith(
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
