import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:country_flags/country_flags.dart';

import '../l10n/app_localizations.dart';
import '../models/event_map_pin.dart';
import '../services/mobile_detection_service.dart';
import '../services/snackbar_service.dart';
import '../services/url_service.dart';
import '../services/web_share_service.dart';
import '../utils/event_schedule_utils.dart';
import 'no_images_placeholder.dart';
import 'resized_spot_image.dart';

enum EventCardVariant { list, overlay }

/// Card for an event in Explore, styled like [SpotCard].
class EventCard extends StatefulWidget {
  final EventMapPin pin;
  final VoidCallback? onTap;
  final ValueChanged<int>? onTapWithImageIndex;
  final VoidCallback? onLocate;
  final VoidCallback? onClose;
  final EventCardVariant variant;
  final double? maxWidth;

  const EventCard({
    super.key,
    required this.pin,
    this.onTap,
    this.onTapWithImageIndex,
    this.onLocate,
    this.onClose,
    this.variant = EventCardVariant.list,
    this.maxWidth,
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
    return EventScheduleUtils.formatSummaryLine(
      context,
      startAt: widget.pin.startAt,
      endAt: widget.pin.endAt,
      isDateOnly: widget.pin.isDateOnly,
      timeZone: widget.pin.timeZone,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.variant == EventCardVariant.overlay) {
      return _buildOverlayCard(context);
    }
    return _buildListCard(context);
  }

  Widget _buildListCard(BuildContext context) {
    final images = widget.pin.imageUrls;
    final description = widget.pin.description?.trim() ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                _buildImageSection(context, images, borderRadius: 16),
                SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._buildTextContent(
                          context,
                          description: description,
                          descriptionMaxLines: 3,
                          includeLocationMeta: false,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildLocationMeta(
                    context,
                    flagHeight: 20,
                    flagWidth: 30,
                    spacing: 8,
                  ),
                  _buildListActionButtons(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayCard(BuildContext context) {
    final images = widget.pin.imageUrls;
    final description = widget.pin.description?.trim() ?? '';

    return PointerInterceptor(
      child: GestureDetector(
        onTap: widget.onTapWithImageIndex != null
            ? () => widget.onTapWithImageIndex!(_currentPage)
            : widget.onTap,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: widget.maxWidth ?? double.infinity,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImageSection(context, images, borderRadius: 12),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildTextContent(
                        context,
                        description: description,
                        descriptionMaxLines: 2,
                        includeLocationMeta: true,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _overlayCircleButton(
                      icon: Icons.share,
                      onTap: () => _shareEvent(context),
                    ),
                    if (widget.onClose != null) ...[
                      const SizedBox(width: 8),
                      _overlayCircleButton(
                        icon: Icons.close,
                        onTap: widget.onClose!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTextContent(
    BuildContext context, {
    required String description,
    required int descriptionMaxLines,
    required bool includeLocationMeta,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 8),
            child: Icon(
              Icons.event_available_outlined,
              size: 24,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Expanded(
            child: Text(
              widget.pin.title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        _formatWhen(context),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        description.isEmpty ? l10n.spotCardNoDescription : description,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          height: 1.4,
          fontStyle: description.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
        maxLines: descriptionMaxLines,
        overflow: TextOverflow.ellipsis,
      ),
      if (includeLocationMeta &&
          (widget.pin.city != null || widget.pin.countryCode != null)) ...[
        const SizedBox(height: 12),
        _buildLocationMeta(context, flagHeight: 16, flagWidth: 24, spacing: 6),
      ],
    ];
  }

  Widget _buildLocationMeta(
    BuildContext context, {
    required double flagHeight,
    required double flagWidth,
    required double spacing,
  }) {
    final city = widget.pin.city?.trim();
    final countryCode = widget.pin.countryCode?.trim().toUpperCase();
    if ((city == null || city.isEmpty) &&
        (countryCode == null || countryCode.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (countryCode != null && countryCode.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: flagHeight,
              width: flagWidth,
              child: CountryFlag.fromCountryCode(countryCode),
            ),
          ),
        if (countryCode != null &&
            countryCode.isNotEmpty &&
            city != null &&
            city.isNotEmpty)
          SizedBox(width: spacing),
        if (city != null && city.isNotEmpty)
          Text(
            city,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildImageSection(
    BuildContext context,
    List<String> images, {
    required double borderRadius,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final radius = BorderRadius.vertical(top: Radius.circular(borderRadius));

    if (images.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _buildImageGallery(context, images),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(child: NoImagesPlaceholder(label: l10n.noImagesYet)),
        ),
      ),
    );
  }

  Widget _buildListActionButtons(BuildContext context) {
    return Row(
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
                color: Theme.of(context).colorScheme.onSecondary,
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
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _overlayCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
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

      final outcome = await WebShareService.tryShareLink(text: label, url: url);
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
void locateEventPinOnMap(GoogleMapController? controller, EventMapPin pin) {
  controller?.animateCamera(
    CameraUpdate.newLatLng(LatLng(pin.latitude, pin.longitude)),
  );
}
