import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../models/spot.dart';
import '../services/mobile_detection_service.dart';

enum SpotCardVariant {
  list,      // For list view (original SpotCard behavior)
  overlay,   // For map overlay (current _buildSpotDetailCard behavior)
}

class SpotCard extends StatefulWidget {
  final Spot spot;
  final VoidCallback? onTap;
  final VoidCallback? onLocate;
  final bool showRating;
  final SpotCardVariant variant;
  final VoidCallback? onClose; // For overlay variant
  final VoidCallback? onViewDetails; // For overlay variant
  final double? maxWidth; // For overlay variant

  const SpotCard({
    super.key,
    required this.spot,
    this.onTap,
    this.onLocate,
    this.showRating = true,
    this.variant = SpotCardVariant.list,
    this.onClose,
    this.onViewDetails,
    this.maxWidth,
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
        onTap: widget.onTap,
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
                                imageUrl: widget.spot.imageUrls![index],
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
                                child: GestureDetector(
                                  onTap: () => _previousImage(),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chevron_left,
                                      color: Colors.white,
                                      size: 24,
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
                                child: GestureDetector(
                                  onTap: () => _nextImage(),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                      size: 24,
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
                          child: Icon(
                            Icons.location_on,
                            size: 48,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        
                        const SizedBox(height: 16),
                        
                        // Add bottom padding to make room for the "Added by" text
                        if (widget.spot.createdBy != null || widget.spot.createdByName != null)
                          const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Locate button (bottom-right)
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: Theme.of(context).colorScheme.primary,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  onTap: widget.onLocate,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.my_location,
                      size: 20,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
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

            // "Added by" text positioned at bottom left
            if (widget.spot.createdBy != null || widget.spot.createdByName != null)
              Positioned(
                bottom: 16,
                left: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Added by ${widget.spot.createdByName ?? widget.spot.createdBy}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.spot.createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '• ${_formatDate(widget.spot.createdAt!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
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
      onTap: widget.onTap,
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
                                imageUrl: widget.spot.imageUrls![index],
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
                                child: GestureDetector(
                                  onTap: _previousImage,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chevron_left,
                                      color: Colors.white,
                                      size: 24,
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
                                child: GestureDetector(
                                  onTap: _nextImage,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.chevron_right,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ] else ...[
                          // Location marker when no images
                          Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.location_on,
                                size: 48,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.onViewDetails,
                          child: const Text('View Details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Close button positioned at top right of entire card
            if (widget.onClose != null)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
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
    ),
  );
}

String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
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
