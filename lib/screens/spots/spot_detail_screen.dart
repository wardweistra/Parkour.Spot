import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/spot.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';

class SpotDetailScreen extends StatefulWidget {
  final Spot spot;

  const SpotDetailScreen({super.key, required this.spot});

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  double _userRating = 0;
  bool _hasRated = false;
  int _currentImageIndex = 0;
  late final PageController _imagePageController;

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            surfaceTintColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Images Carousel
                  if (widget.spot.imageUrls != null && widget.spot.imageUrls!.isNotEmpty)
                    PageView.builder(
                      controller: _imagePageController,
                      onPageChanged: (index) => setState(() => _currentImageIndex = index),
                      itemCount: widget.spot.imageUrls!.length,
                      itemBuilder: (context, index) {
                        final url = widget.spot.imageUrls![index];
                        return Image.network(
                          url,
                          fit: BoxFit.cover,
                        );
                      },
                    )
                  else
                    Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  
                  // Back Button
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withOpacity(0.5),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  
                  // Action Buttons
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 16,
                    child: Row(
                      children: [
                        if (widget.spot.createdBy == Provider.of<AuthService>(context, listen: false).userProfile?.id) ...[
                          CircleAvatar(
                            backgroundColor: Colors.black.withOpacity(0.5),
                            child: IconButton(
                              icon: const Icon(Icons.edit, color: Colors.white),
                              onPressed: () {
                                // TODO: Navigate to edit screen
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: Colors.red.withOpacity(0.8),
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.white),
                              onPressed: _showDeleteDialog,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Page indicators
                  if (widget.spot.imageUrls != null && widget.spot.imageUrls!.length > 1)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.spot.imageUrls!.length, (index) {
                          final isActive = index == _currentImageIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 10 : 8,
                            height: isActive ? 10 : 8,
                            decoration: BoxDecoration(
                              color: isActive ? Colors.white : Colors.white54,
                              shape: BoxShape.circle,
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.spot.name,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (widget.spot.rating != null) ...[
                        Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 24,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.spot.rating!.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.spot.ratingCount != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '(${widget.spot.ratingCount})',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.spot.description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Tags
                  if (widget.spot.tags != null && widget.spot.tags!.isNotEmpty) ...[
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.spot.tags!.map((tag) {
                        return Chip(
                          label: Text(tag),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Location
                  Text(
                    'Location',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.spot.location.latitude.toStringAsFixed(4)}°, ${widget.spot.location.longitude.toStringAsFixed(4)}°',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Rating Section
                  if (Provider.of<AuthService>(context, listen: false).userProfile != null) ...[
                    Text(
                      'Rate this spot',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ...List.generate(5, (index) {
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _userRating = index + 1.0;
                                _hasRated = true;
                              });
                            },
                            child: Icon(
                              index < _userRating ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 32,
                            ),
                          );
                        }),
                        const SizedBox(width: 16),
                        if (_hasRated)
                          CustomButton(
                            onPressed: _submitRating,
                            text: 'Submit Rating',
                            isLoading: false,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Additional Info
                  if (widget.spot.createdBy != null || widget.spot.createdAt != null) ...[
                    Text(
                      'Additional Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (widget.spot.createdBy != null) ...[
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: const Text('Added by'),
                        subtitle: Text(widget.spot.createdBy!),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                    if (widget.spot.createdAt != null) ...[
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Created on'),
                        subtitle: Text(_formatDate(widget.spot.createdAt!)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                    if (widget.spot.updatedAt != null && 
                        widget.spot.updatedAt != widget.spot.createdAt) ...[
                      ListTile(
                        leading: const Icon(Icons.update),
                        title: const Text('Last updated'),
                        subtitle: Text(_formatDate(widget.spot.updatedAt!)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ],
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRating() async {
    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final success = await spotService.rateSpot(widget.spot.id!, _userRating);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _hasRated = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Spot'),
        content: const Text('Are you sure you want to delete this spot? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final spotService = Provider.of<SpotService>(context, listen: false);
                final success = await spotService.deleteSpot(widget.spot.id!);
                
                if (success && mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Spot deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting spot: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
