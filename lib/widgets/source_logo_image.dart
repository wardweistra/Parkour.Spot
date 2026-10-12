import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../utils/image_url_utils.dart';

/// Displays a community source logo with a neutral fallback icon.
class SourceLogoImage extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final BorderRadius? borderRadius;

  const SourceLogoImage({
    super.key,
    required this.logoUrl,
    this.size = 40,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final url = logoUrl?.trim();
    final radius = borderRadius ?? BorderRadius.circular(8);
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: radius,
      ),
      child: Icon(
        Icons.public,
        size: size * 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    if (url == null || url.isEmpty) {
      return fallback;
    }

    final resolvedUrl = rewriteEmulatorLocalhostUrl(url);
    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: resolvedUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorWidget: (_, _, _) => fallback,
        placeholder: (_, _) => SizedBox(
          width: size,
          height: size,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}
