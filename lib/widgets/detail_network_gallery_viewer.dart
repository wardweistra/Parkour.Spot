import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../l10n/app_localizations.dart';

/// Full-screen swipeable gallery for network image URLs.
class DetailNetworkGalleryViewer extends StatefulWidget {
  const DetailNetworkGalleryViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<DetailNetworkGalleryViewer> createState() =>
      _DetailNetworkGalleryViewerState();
}

class _DetailNetworkGalleryViewerState extends State<DetailNetworkGalleryViewer> {
  late PageController _pageController;
  late int _currentIndex;
  static const int _virtualPageMultiplier = 1000;
  late int _virtualInitialPage;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    final length = widget.imageUrls.length;
    final basePage = length > 0
        ? (_virtualPageMultiplier ~/ length) * length
        : _virtualPageMultiplier;
    _virtualInitialPage = basePage + widget.initialIndex;
    _pageController = PageController(initialPage: _virtualInitialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int virtualIndex) {
    final actualIndex = virtualIndex % widget.imageUrls.length;
    setState(() => _currentIndex = actualIndex);

    final lowerBound = _virtualPageMultiplier ~/ 2;
    final upperBound = _virtualPageMultiplier * 2 - 100;
    if (virtualIndex < lowerBound || virtualIndex > upperBound) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients || widget.imageUrls.isEmpty) {
          return;
        }
        final length = widget.imageUrls.length;
        final basePage = (_virtualPageMultiplier ~/ length) * length;
        _pageController.jumpToPage(basePage + actualIndex);
      });
    }
  }

  void _goToPrevious() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _goToPrevious();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _goToNext();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop(_currentIndex);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(_currentIndex),
          ),
          title: Text(
            l10n.spotDetailGalleryPageIndicator(
              _currentIndex + 1,
              widget.imageUrls.length,
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Stack(
          children: [
            PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (context, virtualIndex) {
                final actualIndex = virtualIndex % widget.imageUrls.length;
                final url = widget.imageUrls[actualIndex];
                return PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(url),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  heroAttributes: PhotoViewHeroAttributes(tag: url),
                );
              },
              itemCount: _virtualPageMultiplier * 2,
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded /
                            event.expectedTotalBytes!,
                ),
              ),
              pageController: _pageController,
              onPageChanged: _onPageChanged,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
            if (widget.imageUrls.length > 1) ...[
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.black26,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(
                        Icons.chevron_left,
                        size: 40,
                        color: Colors.white,
                      ),
                      onPressed: _goToPrevious,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.black26,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        size: 40,
                        color: Colors.white,
                      ),
                      onPressed: _goToNext,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
