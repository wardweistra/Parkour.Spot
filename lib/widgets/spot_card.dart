import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/spot.dart';

class SpotCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            if (spot.imageUrls != null && spot.imageUrls!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CachedNetworkImage(
                    imageUrl: spot.imageUrls!.first,
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
            
            // Content Section
            Flexible( // Wrapped in Flexible to allow content to expand
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Rating Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            spot.name,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (showRating && spot.rating != null) ...[
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            spot.rating!.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Description
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 60, // Ensure minimum height for description
                        maxHeight: 80, // Limit maximum height to prevent overlap
                      ),
                      child: Text(
                        spot.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          height: 1.4, // Better line height for readability
                        ),
                        maxLines: 3, // Keep at 3 lines
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                        softWrap: true, // Ensure text wraps properly
                      ),
                    ),
                    
                    const SizedBox(height: 16), // Increased spacing from 12 to 16
                    
                    // Tags and Location
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 40, // Ensure minimum height for tags and location
                      ),
                      child: Row(
                        children: [
                          // Tags
                          if (spot.tags != null && spot.tags!.isNotEmpty) ...[
                            Icon(
                              Icons.label,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                spot.tags!.take(2).join(', '),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                          
                          const Spacer(),
                          
                          // Location indicator
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Flexible( // Wrapped in Flexible to prevent overflow
                            child: Text(
                              '${spot.location.latitude.toStringAsFixed(4)}, ${spot.location.longitude.toStringAsFixed(4)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Created by and date
                    if (spot.createdBy != null || spot.createdByName != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(
                          minHeight: 20, // Ensure minimum height for "Added by" section
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Expanded( // Wrapped in Expanded to prevent overflow
                              child: Text(
                                'Added by ${spot.createdByName ?? spot.createdBy}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (spot.createdAt != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '• ${_formatDate(spot.createdAt!)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
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
}
