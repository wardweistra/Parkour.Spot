import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/spot_detail_ui.dart';
import 'detail_network_gallery_viewer.dart';

/// Collapsing-header image carousel used on detail pages (spots, events).
class DetailImageCarousel extends StatefulWidget {
  const DetailImageCarousel({
    super.key,
    required this.imageUrls,
    this.height = 400,
    required this.emptyLabel,
    required this.failedLabel,
    this.imageBuilder,
  });

  final List<String> imageUrls;
  final double height;
  final String emptyLabel;
  final String failedLabel;
  final Widget Function(BuildContext context, String url)? imageBuilder;

  @override
  State<DetailImageCarousel> createState() => DetailImageCarouselState();
}

class DetailImageCarouselState extends State<DetailImageCarousel> {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void nextImage() {
    if (widget.imageUrls.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex + 1) % widget.imageUrls.length;
    });
  }

  void previousImage() {
    if (widget.imageUrls.isEmpty) return;
    setState(() {
      _currentIndex = (_currentIndex - 1 + widget.imageUrls.length) %
          widget.imageUrls.length;
    });
  }

  void goToImage(int index) {
    if (index < 0 || index >= widget.imageUrls.length) return;
    setState(() => _currentIndex = index);
  }

  Future<void> openFullScreenViewer() async {
    if (widget.imageUrls.isEmpty) return;
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (context) => DetailNetworkGalleryViewer(
          imageUrls: widget.imageUrls,
          initialIndex: _currentIndex,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _currentIndex = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        height: widget.height,
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported_outlined,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                widget.emptyLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final url = widget.imageUrls[_currentIndex];
    final horizontalInset = SpotDetailUi.contentHorizontalInset(context);

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: openFullScreenViewer,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity;
              if (velocity == null) return;
              if (velocity < -500) {
                nextImage();
              } else if (velocity > 500) {
                previousImage();
              }
            },
            child: Material(
              color: Colors.transparent,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: KeyedSubtree(
                  key: ValueKey(_currentIndex),
                  child: _buildImage(context, url),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
          if (widget.imageUrls.length > 1) ...[
            Positioned(
              left: horizontalInset,
              top: 0,
              bottom: 0,
              child: Center(
                child: _CarouselNavButton(
                  icon: Icons.chevron_left,
                  onTap: previousImage,
                ),
              ),
            ),
            Positioned(
              right: horizontalInset,
              top: 0,
              bottom: 0,
              child: Center(
                child: _CarouselNavButton(
                  icon: Icons.chevron_right,
                  onTap: nextImage,
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.imageUrls.length, (index) {
                  final isActive = index == _currentIndex;
                  return GestureDetector(
                    onTap: () => goToImage(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.white : Colors.white54,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, String url) {
    final builder = widget.imageBuilder;
    if (builder != null) {
      return SizedBox(
        width: double.infinity,
        height: widget.height,
        child: builder(context, url),
      );
    }
    return Image.network(
      url,
      width: double.infinity,
      height: widget.height,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _errorPlaceholder(context),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          width: double.infinity,
          height: widget.height,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _errorPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      height: widget.height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(height: 8),
          Text(
            widget.failedLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _CarouselNavButton extends StatelessWidget {
  const _CarouselNavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

/// Keyboard navigation wrapper for a detail page with an image carousel.
class DetailImageCarouselFocus extends StatelessWidget {
  const DetailImageCarouselFocus({
    super.key,
    required this.carouselKey,
    required this.child,
  });

  final GlobalKey<DetailImageCarouselState> carouselKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        final carousel = carouselKey.currentState;
        if (carousel == null) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          carousel.previousImage();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          carousel.nextImage();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
