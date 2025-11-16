import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/spot.dart';
import '../services/spot_service.dart';
import '../services/url_service.dart';

class SpotSelectionDialog extends StatefulWidget {
  final String? currentSpotId; // ID of the spot being marked as duplicate (to exclude it)
  final Spot? currentSpot; // The current spot (to allow creating native spot from it)
  final bool allowExternalSources; // Allow spots from external sources (for reports)

  const SpotSelectionDialog({
    super.key,
    this.currentSpotId,
    this.currentSpot,
    this.allowExternalSources = false,
  });

  @override
  State<SpotSelectionDialog> createState() => _SpotSelectionDialogState();
}

class _SpotSelectionDialogState extends State<SpotSelectionDialog> {
  final TextEditingController _inputController = TextEditingController();
  Spot? _foundSpot;
  bool _isLoading = false;
  bool _isCheckingDuplicates = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Check if other spots are already marked as duplicates of the current spot
    // Only for moderator actions (not for user reports)
    if (!widget.allowExternalSources && widget.currentSpotId != null) {
      _checkExistingDuplicates();
    }
  }

  Future<void> _checkExistingDuplicates() async {
    setState(() {
      _isCheckingDuplicates = true;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final existingDuplicates = await spotService.getDuplicatesOfSpot(widget.currentSpotId!);
      if (mounted && existingDuplicates.isNotEmpty) {
        setState(() {
          _error = 'Cannot mark this spot as a duplicate because other spots are already marked as duplicates of it.';
          _isCheckingDuplicates = false;
        });
      } else if (mounted) {
        setState(() {
          _isCheckingDuplicates = false;
        });
      }
    } catch (e) {
      // If check fails, continue anyway (validation will catch it later)
      debugPrint('Error checking for existing duplicates: $e');
      if (mounted) {
        setState(() {
          _isCheckingDuplicates = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  /// Extract spot ID from input (can be URL, ID, or text containing a URL)
  String? _extractSpotId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // First, try to find URLs within the text (for cases like "Barbican - Fountains 👉 https://parkour.spot/...")
    // Pattern to match http://, https://, or relative paths starting with /
    // Matches URLs until whitespace, common punctuation, or end of string
    final urlPattern = RegExp(
      r'(https?://[^\s<>"()]+|/[^\s<>"()]+)',
      caseSensitive: false,
    );
    
    final urlMatches = urlPattern.allMatches(trimmed);
    for (final match in urlMatches) {
      final urlCandidate = match.group(0);
      if (urlCandidate == null) continue;
      
      String? spotId;
      
      // If it's a full URL
      if (urlCandidate.startsWith('http://') || urlCandidate.startsWith('https://')) {
        spotId = UrlService.extractSpotIdFromUrl(urlCandidate);
        if (spotId != null) return spotId;
        
        // Also try to extract from /spot/:spotId format
        try {
          final uri = Uri.parse(urlCandidate);
          final pathSegments = uri.pathSegments;
          if (pathSegments.length == 2 && pathSegments[0] == 'spot') {
            return pathSegments[1];
          }
        } catch (_) {}
      }
      
      // If it's a relative path starting with /
      if (urlCandidate.startsWith('/')) {
        spotId = UrlService.extractSpotIdFromUrl('https://parkour.spot$urlCandidate');
        if (spotId != null) return spotId;
        
        // Also try to extract from /spot/:spotId format
        try {
          final uri = Uri.parse('https://parkour.spot$urlCandidate');
          final pathSegments = uri.pathSegments;
          if (pathSegments.length == 2 && pathSegments[0] == 'spot') {
            return pathSegments[1];
          }
        } catch (_) {}
      }
    }

    // If no URL found in text, check if the entire input is a URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final spotId = UrlService.extractSpotIdFromUrl(trimmed);
      if (spotId != null) return spotId;
      
      // Also try to extract from /spot/:spotId format
      try {
        final uri = Uri.parse(trimmed);
        final pathSegments = uri.pathSegments;
        if (pathSegments.length == 2 && pathSegments[0] == 'spot') {
          return pathSegments[1];
        }
      } catch (_) {}
      return null;
    }
    
    // Check if it's a relative URL path
    if (trimmed.startsWith('/')) {
      final spotId = UrlService.extractSpotIdFromUrl('https://parkour.spot$trimmed');
      if (spotId != null) return spotId;
      
      // Also try to extract from /spot/:spotId format
      try {
        final uri = Uri.parse('https://parkour.spot$trimmed');
        final pathSegments = uri.pathSegments;
        if (pathSegments.length == 2 && pathSegments[0] == 'spot') {
          return pathSegments[1];
        }
      } catch (_) {}
      return null;
    }

    // Otherwise, assume it's a direct spot ID
    // Validate it's not empty and looks like a valid ID (alphanumeric, dashes, underscores)
    if (RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }

  Future<void> _searchSpot() async {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _error = 'Please enter a spot ID or URL';
        _foundSpot = null;
      });
      return;
    }

    final spotId = _extractSpotId(input);
    if (spotId == null) {
      setState(() {
        _error = 'Invalid spot ID or URL format';
        _foundSpot = null;
      });
      return;
    }

    // Check if trying to mark as duplicate of itself
    if (spotId == widget.currentSpotId) {
      setState(() {
        _error = 'Cannot mark a spot as duplicate of itself';
        _foundSpot = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _foundSpot = null;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final spot = await spotService.getSpotById(spotId);

      if (!mounted) return;

      if (spot == null) {
        setState(() {
          _error = 'Spot not found';
          _foundSpot = null;
          _isLoading = false;
        });
        return;
      }

      // Check if the found spot is already a duplicate (only for moderator actions)
      if (!widget.allowExternalSources && spot.duplicateOf != null) {
        setState(() {
          _error = 'This spot is already marked as a duplicate of another spot';
          _foundSpot = null;
          _isLoading = false;
        });
        return;
      }

      // Ensure the original spot is a native parkour.spot spot (not from external source)
      // Only enforce this for moderator actions, not for user reports
      if (!widget.allowExternalSources && spot.spotSource != null) {
        setState(() {
          _error = 'Original spot must be a native parkour.spot spot, not from an external source';
          _foundSpot = null;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _foundSpot = spot;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load spot: $e';
        _foundSpot = null;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.copy_all,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select Original Spot',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),
            
            // Input field and search button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter spot ID or URL',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          decoration: InputDecoration(
                            hintText: 'Paste shared text, URL, or spot ID',
                            prefixIcon: const Icon(Icons.link),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            errorText: _error,
                          ),
                          onSubmitted: (_) => _searchSpot(),
                          enabled: !_isLoading && !_isCheckingDuplicates,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: (_isLoading || _isCheckingDuplicates) ? null : _searchSpot,
                        icon: (_isLoading || _isCheckingDuplicates)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: const Text('Search'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paste the text copied when sharing a spot, a spot URL, or enter the spot ID directly',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            
            // Results area
            Expanded(
              child: _isCheckingDuplicates
                  ? const Center(child: CircularProgressIndicator())
                  : _foundSpot == null && !_isLoading && _error == null
                      ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Enter a spot ID or URL to search',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null && _foundSpot == null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(height: 16),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 32),
                                    child: Text(
                                      _error!,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _foundSpot != null
                              ? SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Found Spot',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildSpotItem(_foundSpot!),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
            ),
            
            const Divider(height: 1),
            
            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Create Native Spot option (only show if current spot is from external source)
                  if (widget.currentSpot != null && widget.currentSpot!.spotSource != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _error != null ? null : () => Navigator.of(context).pop('CREATE_NATIVE'),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Create Native Spot from Current Spot'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      if (_foundSpot != null && _error == null) ...[
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(_foundSpot!.id),
                          child: const Text('Confirm'),
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

  Widget _buildSpotItem(Spot spot) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Spot image and basic info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Spot image thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: spot.imageUrls != null && spot.imageUrls!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: spot.imageUrls!.first,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 100,
                            height: 100,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 100,
                            height: 100,
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.image_not_supported,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : Container(
                          width: 100,
                          height: 100,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_not_supported,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                ),
                
                const SizedBox(width: 16),
                
                // Spot details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        spot.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        spot.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (spot.address != null || spot.city != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                [spot.address, spot.city].whereType<String>().join(', '),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (spot.id != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Spot ID: ${spot.id}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

