import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/event_map_pin.dart';
import '../services/mobile_detection_service.dart';
import '../services/snackbar_service.dart';
import '../services/url_service.dart';
import '../services/web_share_service.dart';
import 'resized_spot_image.dart';

/// Card for an event in Explore, styled like [SpotCard] list variant.
class EventCard extends StatefulWidget {
  final EventMapPin pin;
  final VoidCallback? onTap;
  final ValueChanged<int>? onTapWithImageIndex;
  final VoidCallback? onLocate;

  const EventCard({
    super.key,
    required this.pin,
    this.onTap,
    this.onTapWithImageIndex,
    this.onLocate,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatWhen(BuildContext context) {
    final local = widget.pin.startAt.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(local);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date · $time';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final images = widget.pin.imageUrls;
    final description = widget.pin.description?.trim() ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: widget.onTapWithImageIndex != null
            ? () => widget.onTapWithImageIndex!(_currentPage)
            : widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (images.isNotEmpty)
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _buildImageGallery(context, images),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_outlined,
                                size: 48,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.noImagesYet,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.pin.title,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatWhen(context),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description.isEmpty
                              ? l10n.spotCardNoDescription
                              : description,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            height: 1.4,
                            fontStyle: description.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    widget.pin.kind == EventMapPinKind.venue
                        ? Icons.event
                        : Icons.place_outlined,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Theme.of(context).colorScheme.secondary,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _shareEvent(context),
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.share,
                              size: 18,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondary,
                            ),
                          ),
                        ),
                      ),
                      if (widget.onLocate != null) ...[
                        const SizedBox(width: 8),
                        Material(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            onTap: widget.onLocate,
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.my_location,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSecondary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery(BuildContext context, List<String> images) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemBuilder: (context, index) {
            return ResizedSpotImage(
              imageUrl: images[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.image_not_supported,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          },
        ),
        if (images.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (index) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentPage
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        if (images.length > 1 && !MobileDetectionService.isMobileDevice) ...[
          Positioned(
            left: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _galleryArrow(Icons.chevron_left, _previousImage),
            ),
          ),
          Positioned(
            right: 8,
            top: 0,
            bottom: 0,
            child: Center(
              child: _galleryArrow(Icons.chevron_right, _nextImage),
            ),
          ),
        ],
      ],
    );
  }

  Widget _galleryArrow(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Future<void> _shareEvent(BuildContext context) async {
    try {
      final l10n = AppLocalizations.of(context)!;
      final url = UrlService.generateEventUrl(widget.pin.eventId);
      final label = widget.pin.title.trim();
      final text = l10n.spotCardShareClipboardText(label, url);

      final outcome =
          await WebShareService.tryShareLink(text: label, url: url);
      if (outcome == WebShareOutcome.shared ||
          outcome == WebShareOutcome.cancelled) {
        return;
      }

      await Clipboard.setData(ClipboardData(text: text));
      SnackbarService.showClipboardCopied(l10n.eventDetailCopiedToClipboard);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.eventDetailShareFailed('$e'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _nextImage() {
    final count = widget.pin.imageUrls.length;
    if (count <= 1) return;
    final next = (_currentPage + 1) % count;
    setState(() => _currentPage = next);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousImage() {
    final count = widget.pin.imageUrls.length;
    if (count <= 1) return;
    final prev = (_currentPage - 1 + count) % count;
    setState(() => _currentPage = prev);
    _pageController.animateToPage(
      prev,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}

/// Centers the map on [pin] (used from Explore locate).
void locateEventPinOnMap(
  GoogleMapController? controller,
  EventMapPin pin,
) {
  controller?.animateCamera(
    CameraUpdate.newLatLng(LatLng(pin.latitude, pin.longitude)),
  );
}
