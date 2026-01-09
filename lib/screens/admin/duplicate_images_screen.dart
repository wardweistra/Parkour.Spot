import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/spot_service.dart';
import '../../models/spot.dart';

class DuplicateImagesScreen extends StatefulWidget {
  const DuplicateImagesScreen({super.key});

  @override
  State<DuplicateImagesScreen> createState() => _DuplicateImagesScreenState();
}

class _DuplicateImagesScreenState extends State<DuplicateImagesScreen> {
  List<Spot> _spots = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _findSpotsWithDuplicates();
    });
  }

  Future<void> _findSpotsWithDuplicates() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _spots = [];
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final spots = await spotService.findSpotsWithDuplicateImageUrls();
      
      setState(() {
        _spots = spots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to find spots: $e';
        _isLoading = false;
      });
    }
  }

  // Get duplicate URLs for a spot
  List<String> _getDuplicateUrls(Spot spot) {
    if (spot.imageUrls == null || spot.imageUrls!.isEmpty) {
      return [];
    }
    
    final seen = <String>{};
    final duplicates = <String>[];
    
    for (final url in spot.imageUrls!) {
      if (seen.contains(url)) {
        if (!duplicates.contains(url)) {
          duplicates.add(url);
        }
      } else {
        seen.add(url);
      }
    }
    
    return duplicates;
  }

  // Count occurrences of a URL in the list
  int _countOccurrences(List<String> list, String url) {
    return list.where((u) => u == url).length;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Duplicate Images')),
        body: const Center(
          child: Text('Administrator access required'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Spots with Duplicate Images'),
            if (_spots.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_spots.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _findSpotsWithDuplicates,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                });
                _findSpotsWithDuplicates();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_spots.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'No spots with duplicate image URLs found',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Results header with count
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found ${_spots.length} spot${_spots.length == 1 ? '' : 's'} with duplicate image URLs',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total count: ${_spots.length}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Spots list
        Expanded(
          child: ListView.builder(
            itemCount: _spots.length,
            itemBuilder: (context, index) {
              final spot = _spots[index];
              final duplicateUrls = _getDuplicateUrls(spot);
              final totalImages = spot.imageUrls?.length ?? 0;
              final uniqueImages = spot.imageUrls?.toSet().length ?? 0;
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: InkWell(
                  onTap: () {
                    if (spot.id != null) {
                      context.go('/spot/${spot.id}');
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                spot.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (spot.id != null)
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () {
                                  context.go('/spot/${spot.id}/edit');
                                },
                                tooltip: 'Edit spot',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Spot source information
                        if (spot.spotSource != null || spot.spotSourceName != null)
                          Row(
                            children: [
                              Icon(Icons.source, size: 16, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  spot.spotSourceName ?? spot.spotSource ?? 'Unknown source',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        if (spot.spotSource != null || spot.spotSourceName != null)
                          const SizedBox(height: 4),
                        // Link to spot
                        if (spot.id != null)
                          InkWell(
                            onTap: () {
                              context.go('/spot/${spot.id}');
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.link, size: 16, color: Theme.of(context).primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'View spot',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontSize: 12,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (spot.id != null)
                          const SizedBox(height: 8),
                        if (spot.description.isNotEmpty)
                          Text(
                            spot.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        if (spot.description.isNotEmpty)
                          const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                spot.address ?? '${spot.latitude.toStringAsFixed(4)}, ${spot.longitude.toStringAsFixed(4)}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber, size: 20, color: Colors.orange[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Duplicate Image URLs Detected',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Total images: $totalImages | Unique images: $uniqueImages | Duplicates: ${totalImages - uniqueImages}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[900],
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...duplicateUrls.map((url) {
                                final count = _countOccurrences(spot.imageUrls!, url);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.image, size: 16, color: Colors.orange[700]),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'URL appears $count time${count == 1 ? '' : 's'}:',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.orange[900],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              ...duplicateUrls.take(2).map((url) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 20, top: 2),
                                  child: Text(
                                    url,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange[800],
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                              if (duplicateUrls.length > 2)
                                Padding(
                                  padding: const EdgeInsets.only(left: 20, top: 2),
                                  child: Text(
                                    '... and ${duplicateUrls.length - 2} more duplicate URL${duplicateUrls.length - 2 == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange[800],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (spot.imageUrls?.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: spot.imageUrls!.length,
                              itemBuilder: (context, imgIndex) {
                                final url = spot.imageUrls![imgIndex];
                                final isDuplicate = duplicateUrls.contains(url);
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    border: isDuplicate
                                        ? Border.all(color: Colors.orange, width: 3)
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Stack(
                                      children: [
                                        Image.network(
                                          url,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 80,
                                              height: 80,
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.image_not_supported),
                                            );
                                          },
                                        ),
                                        if (isDuplicate)
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.warning,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
