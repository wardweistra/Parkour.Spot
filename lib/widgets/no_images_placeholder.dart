import 'package:flutter/material.dart';

/// Shared empty-state when a spot or event has no images.
enum NoImagesPlaceholderLayout {
  /// Explore cards and compact surfaces (16:9 areas).
  card,

  /// Detail page hero carousel (400px-tall header).
  detail,
}

class NoImagesPlaceholder extends StatelessWidget {
  final String label;
  final NoImagesPlaceholderLayout layout;

  const NoImagesPlaceholder({
    super.key,
    required this.label,
    this.layout = NoImagesPlaceholderLayout.card,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = colors.onSurface.withValues(alpha: 0.5);
    final isDetail = layout == NoImagesPlaceholderLayout.detail;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.image_not_supported,
          size: isDetail ? 64 : 48,
          color: muted,
        ),
        SizedBox(height: isDetail ? 16 : 8),
        Text(
          label,
          style: (isDetail
                  ? Theme.of(context).textTheme.titleMedium
                  : Theme.of(context).textTheme.bodySmall)
              ?.copyWith(color: muted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
