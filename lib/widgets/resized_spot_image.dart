import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_url_utils.dart';

/// Displays a spot image with fallback: tries 1200x1200, then 1200x630, then original.
/// Use for Firebase Storage spot images where the 1200x1200 resized version may not exist yet.
class ResizedSpotImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget Function(BuildContext context, String url)? placeholder;
  final Widget Function(BuildContext context, String url, Object error)?
      errorWidget;

  const ResizedSpotImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<ResizedSpotImage> createState() => _ResizedSpotImageState();
}

class _ResizedSpotImageState extends State<ResizedSpotImage> {
  late List<String> _candidates;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _candidates = getResizedImageUrlCandidates(widget.imageUrl);
  }

  @override
  void didUpdateWidget(ResizedSpotImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _candidates = getResizedImageUrlCandidates(widget.imageUrl);
      _currentIndex = 0;
    }
  }

  void _tryNextCandidate() {
    if (_currentIndex < _candidates.length - 1 && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _currentIndex++);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _candidates[_currentIndex];
    final hasMore = _currentIndex < _candidates.length - 1;

    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      placeholder: widget.placeholder,
      errorWidget: (context, url, error) {
        if (hasMore) {
          _tryNextCandidate();
          return widget.placeholder?.call(context, url) ??
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: CircularProgressIndicator()),
              );
        }
        return widget.errorWidget?.call(context, url, error) ??
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.image_not_supported,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
      },
    );
  }
}
