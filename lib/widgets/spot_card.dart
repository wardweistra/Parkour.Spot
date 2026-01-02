import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:country_flags/country_flags.dart';
import 'package:go_router/go_router.dart';
import '../models/spot.dart';
import '../services/mobile_detection_service.dart';
import '../services/url_service.dart';
import '../utils/image_url_utils.dart';

enum SpotCardVariant {
  list,      // For list view (original SpotCard behavior)
  overlay,   // For map overlay (current _buildSpotDetailCard behavior)
}

class SpotCard extends StatefulWidget {
  final Spot spot;
  final VoidCallback? onTap;
  final ValueChanged<int>? onTapWithImageIndex; // Callback that provides current image index
  final VoidCallback? onLocate;
  final bool showRating;
  final SpotCardVariant variant;
  final VoidCallback? onClose; // For overlay variant
  final VoidCallback? onViewDetails; // For overlay variant
  final double? maxWidth; // For overlay variant
  final VoidCallback? onRemove; // For list variant - shows remove button
  final String? spotListId; // ID of the spot list this spot belongs to (for highlighting)
  final String? spotListName; // Name of the spot list this spot belongs to (for highlighting)

  const SpotCard({
    super.key,
    required this.spot,
    this.onTap,
    this.onTapWithImageIndex,
    this.onLocate,
    this.showRating = true,
    this.variant = SpotCardVariant.list,
    this.onClose,
    this.onViewDetails,
    this.maxWidth,
    this.onRemove,
    this.spotListId,
    this.spotListName,
  });

  @override
  State<SpotCard> createState() => _SpotCardState();
}

class _SpotCardState extends State<SpotCard> {
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

  @override
  Widget build(BuildContext context) {
    if (widget.variant == SpotCardVariant.overlay) {
      return _buildOverlayCard(context);
    } else {
      return _buildListCard(context);
    }
  }

  Widget _buildListCard(BuildContext context) {
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
            // Main content column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Section
                if (widget.spot.imageUrls != null && widget.spot.imageUrls!.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        children: [
                          // Image Gallery
                          PageView.builder(
                            controller: _pageController,
                            itemCount: widget.spot.imageUrls!.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return CachedNetworkImage(
                                imageUrl: getResizedImageUrl(widget.spot.imageUrls![index]),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
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
                          
                          // Page Indicator Dots (only show if multiple images)
                          if (widget.spot.imageUrls!.length > 1)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  widget.spot.imageUrls!.length,
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
                          
                          // Navigation arrows (left and right)
                          if (widget.spot.imageUrls!.length > 1 && !MobileDetectionService.isMobileDevice) ...[
                            // Left arrow
                            Positioned(
                              left: 8,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: () => _previousImage(),
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
                                      child: const Icon(
                                        Icons.chevron_left,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Right arrow
                            Positioned(
                              right: 8,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: () => _nextImage(),
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
                                      child: const Icon(
                                        Icons.chevron_right,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_not_supported,
                                size: 48,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No images',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                
                // Content Section - Wrapped in SingleChildScrollView to prevent overflow
                SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(), // Disable scrolling within card
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // Prevent unnecessary expansion
                      children: [
                        // Title and Rating Row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.spot.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (widget.showRating) ...[
                              // Rating display using Spot model fields directly
                              widget.spot.ratingCount != null && widget.spot.ratingCount! > 0
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.amber,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (widget.spot.averageRating ?? 0.0).toStringAsFixed(1),
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ],
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Description - Removed fixed height constraints
                        Text(
                          widget.spot.description.trim().isEmpty 
                              ? 'No description provided'
                              : widget.spot.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.4, // Better line height for readability
                            fontStyle: widget.spot.description.trim().isEmpty 
                                ? FontStyle.italic 
                                : FontStyle.normal,
                          ),
                          maxLines: 3, // Keep at 3 lines
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          softWrap: true, // Ensure text wraps properly
                        ),
                        
                        // "Part of" indicator for highlighted spots (chip/badge style)
                        if (widget.spotListId != null && widget.spotListName != null) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              context.go('/list/${widget.spotListId}');
                            },
                            child: Chip(
                              avatar: Icon(
                                Icons.list,
                                size: 16,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                              label: Text.rich(
                                TextSpan(
                                  text: 'Part of ',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: widget.spotListName,
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                        
                        // Add bottom padding to make room for the bottom row
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Bottom row: Flag + City (left) | Share + Locate buttons (right) - floated to bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left: Flag + City
                  if (widget.spot.city != null || widget.spot.countryCode != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.spot.countryCode != null)
                          CountryFlag.fromCountryCode(
                            widget.spot.countryCode!,
                            height: 20,
                            width: 30,
                            borderRadius: 2,
                          ),
                        if (widget.spot.countryCode != null && widget.spot.city != null)
                          const SizedBox(width: 8),
                        if (widget.spot.city != null)
                          Text(
                            widget.spot.city!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    )
                  else
                    const SizedBox.shrink(),
                  
                  // Right: Share + Locate buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Share button (always shown)
                      Material(
                        color: Theme.of(context).colorScheme.secondary,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: InkWell(
                          onTap: () => _shareSpot(context),
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
                      // Spacing between Share and Locate buttons
                      if (widget.onLocate != null)
                        const SizedBox(width: 8),
                      // Locate button
                      if (widget.onLocate != null)
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
                  ),
                ],
              ),
            ),

            // External source indicator - positioned at top right
            if (widget.spot.spotSource != null)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    widget.spot.spotSourceName ?? widget.spot.spotSource!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            // Removed badge - position on left if remove button exists, otherwise right
            if (widget.spot.spotSourceRemoved)
              Positioned(
                top: 8,
                left: widget.onRemove != null ? 8 : null,
                right: widget.onRemove != null ? null : 8,
                child: _buildRemovedBadge(context),
              ),

            // Remove button (for list variant)
            if (widget.onRemove != null)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Remove from list',
                  onPressed: widget.onRemove,
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayCard(BuildContext context) {
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
              children: [
                // Spot image gallery or location marker
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      children: [
                        if (widget.spot.imageUrls != null && widget.spot.imageUrls!.isNotEmpty) ...[
                          // Image Gallery with PageView
                          PageView.builder(
                            controller: _pageController,
                            itemCount: widget.spot.imageUrls!.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentPage = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return CachedNetworkImage(
                                imageUrl: getResizedImageUrl(widget.spot.imageUrls![index]),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              );
                            },
                          ),
                          
                          // Page Indicator Dots (only show if multiple images)
                          if (widget.spot.imageUrls!.length > 1)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  widget.spot.imageUrls!.length,
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
                          
                          // Navigation arrows (left and right)
                          if (widget.spot.imageUrls!.length > 1 && !MobileDetectionService.isMobileDevice) ...[
                            // Left arrow
                            Positioned(
                              left: 8,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: _previousImage,
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
                                      child: const Icon(
                                        Icons.chevron_left,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Right arrow
                            Positioned(
                              right: 8,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    onTap: _nextImage,
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
                                      child: const Icon(
                                        Icons.chevron_right,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          // No images indicator
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No images',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        
                        // External source indicator - positioned on the image/marker area
                        if (widget.spot.spotSource != null)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: SizedBox(
                              height: 32, // match close button size for vertical centering
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    widget.spot.spotSourceName ?? widget.spot.spotSource!,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        if (widget.spot.spotSourceRemoved)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: _buildRemovedBadge(context),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // Spot details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Rating Row (same as list)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.spot.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Always show ratings in overlay like list style
                          widget.spot.ratingCount != null && widget.spot.ratingCount! > 0
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 16,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      (widget.spot.averageRating ?? 0.0).toStringAsFixed(1),
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.spot.description.trim().isEmpty 
                            ? 'No description provided'
                            : widget.spot.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontStyle: widget.spot.description.trim().isEmpty 
                              ? FontStyle.italic 
                              : FontStyle.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // "Part of" indicator for highlighted spots (chip/badge style)
                      if (widget.spotListId != null && widget.spotListName != null) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            context.go('/list/${widget.spotListId}');
                          },
                          child: Chip(
                            avatar: Icon(
                              Icons.list,
                              size: 16,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                            label: Text.rich(
                              TextSpan(
                                text: 'Part of ',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                                children: [
                                  TextSpan(
                                    text: widget.spotListName,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                      // Flag + City after description
                      if (widget.spot.city != null || widget.spot.countryCode != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.spot.countryCode != null)
                              CountryFlag.fromCountryCode(
                                widget.spot.countryCode!,
                                height: 16,
                                width: 24,
                                borderRadius: 2,
                              ),
                            if (widget.spot.countryCode != null && widget.spot.city != null)
                              const SizedBox(width: 6),
                            if (widget.spot.city != null)
                              Text(
                                widget.spot.city!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            
            // Share and Close buttons positioned at top right of entire card
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Share button (always shown)
                  Material(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => _shareSpot(context),
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
                        child: const Icon(
                          Icons.share,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                  // Spacing between Share and Close buttons
                  if (widget.onClose != null)
                    const SizedBox(width: 8),
                  // Close button
                  if (widget.onClose != null)
                    Material(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: widget.onClose,
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
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Future<void> _shareSpot(BuildContext context) async {
    if (widget.spot.id == null) return;
    
    try {
      final url = UrlService.generateSpotUrl(
        widget.spot.id!,
        countryCode: widget.spot.countryCode,
        city: widget.spot.city,
      );
      final text = '${widget.spot.name.trim()} 👉 $url';
      
      await Clipboard.setData(ClipboardData(text: text));
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spot copied to clipboard!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share spot: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRemovedBadge(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ) ??
        const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            'Removed from source',
            style: textStyle,
          ),
        ],
      ),
    );
  }

  void _nextImage() {
    if (_currentPage < widget.spot.imageUrls!.length - 1) {
      setState(() {
        _currentPage++;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Loop to first image
      setState(() {
        _currentPage = 0;
      });
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousImage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Loop to last image
      setState(() {
        _currentPage = widget.spot.imageUrls!.length - 1;
      });
      _pageController.animateToPage(
        widget.spot.imageUrls!.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }


}
