import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Thumbnail for locally selected image bytes with a capped decode size.
class MemoryImagePreview extends StatelessWidget {
  const MemoryImagePreview({
    super.key,
    required this.bytes,
    required this.size,
    this.borderRadius = 8,
    this.fit = BoxFit.cover,
  });

  final Uint8List bytes;
  final double size;
  final double borderRadius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final cacheSize = (size * 3).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: fit,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.broken_image_outlined,
            color: Theme.of(context).colorScheme.error,
            size: size * 0.35,
          ),
        ),
      ),
    );
  }
}
