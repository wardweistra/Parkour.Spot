import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/spot.dart';
import '../services/spot_service.dart';

class SpotCard extends StatefulWidget {
  final Spot spot;
  final VoidCallback? onTap;
  final bool showRating;

  const SpotCard({
    super.key,
    required this.spot,
    this.onTap,
    this.showRating = true,
  });

  @override
  State<SpotCard> createState() => _SpotCardState();
}

class _SpotCardState extends State<SpotCard> {
  late PageController _pageController;
  int _currentPage = 0;
  
  // Add rating cache variables
  Map<String, dynamic>? _cachedRatingStats;
  bool _isLoadingRatingStats = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.showRating) {
      _loadRatingStats(); // Load rating stats once on init
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          if (widget.spot.imageUrls!.length > 1) ...[
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
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.location_on,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                              // Rating display using cached data
                              _isLoadingRatingStats
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : _cachedRatingStats != null && _cachedRatingStats!['ratingCount'] > 0
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
                                              _cachedRatingStats!['averageRating'].toStringAsFixed(1),
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
                          widget.spot.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.4, // Better line height for readability
                          ),
                          maxLines: 3, // Keep at 3 lines
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          softWrap: true, // Ensure text wraps properly
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Add bottom padding to make room for the tags and "Added by" text
                        if (widget.spot.tags != null && widget.spot.tags!.isNotEmpty || 
                            widget.spot.createdBy != null || widget.spot.createdByName != null)
                          const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Tags positioned above "Added by" text
            if (widget.spot.tags != null && widget.spot.tags!.isNotEmpty)
              Positioned(
                bottom: 40,
                left: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.label,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.spot.tags!.take(2).join(', '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            
            // External source indicator - positioned at top right
            if (widget.spot.spotSource != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.source,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'External',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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


  Future<void> _loadRatingStats() async {
    try {
      setState(() {
        _isLoadingRatingStats = true;
      });
      final spotService = Provider.of<SpotService>(context, listen: false);
      final ratingStats = await spotService.getSpotRatingStats(widget.spot.id!);
      if (mounted) {
        setState(() {
          _cachedRatingStats = ratingStats;
          _isLoadingRatingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rating stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingRatingStats = false;
        });
      }
    }
  }
}
