import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/spot_service.dart' show SpotService, SpotWithMissingResizedImages;
import '../../services/url_service.dart';

class MissingResizedImagesScreen extends StatefulWidget {
  const MissingResizedImagesScreen({super.key});

  @override
  State<MissingResizedImagesScreen> createState() =>
      _MissingResizedImagesScreenState();
}

class _MissingResizedImagesScreenState extends State<MissingResizedImagesScreen> {
  List<SpotWithMissingResizedImages> _results = [];
  bool _isLoading = false;
  String? _error;
  int _imagesChecked = 0;
  int _totalToCheck = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runCheck();
    });
  }

  Future<void> _runCheck() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
      _imagesChecked = 0;
      _totalToCheck = 0;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final results = await spotService.findSpotsWithMissingResizedImages(
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _imagesChecked = current;
              _totalToCheck = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to check: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openSpot(String spotId, {String? countryCode, String? city}) async {
    if (MobileDetectionService.isRunningInBrowser) {
      final url = UrlService.generateSpotUrl(
        spotId,
        countryCode: countryCode,
        city: city,
      );
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      context.push('/spot/$spotId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    if (authService.isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Missing Resized Images')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!authService.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Missing Resized Images')),
        body: const Center(
          child: Text('Administrator access required'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Spots with Missing Resized Images'),
            if (_results.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_results.length}',
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
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/admin');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _runCheck,
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
                setState(() => _error = null);
                _runCheck();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            if (_totalToCheck > 0)
              Text(
                'Checking images $_imagesChecked / $_totalToCheck...',
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'All spot images have resized versions',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
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
                      'Found ${_results.length} spot${_results.length == 1 ? '' : 's'} with images missing resized versions',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total images missing resize: ${_results.fold<int>(0, (s, r) => s + r.missingImageUrls.length)}',
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
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final item = _results[index];
              final spot = item.spot;
              final missingUrls = item.missingImageUrls;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: InkWell(
                  onTap: () {
                    if (spot.id != null) {
                      _openSpot(
                        spot.id!,
                        countryCode: spot.countryCode,
                        city: spot.city,
                      );
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
                                  context.push('/spot/${spot.id}/edit');
                                },
                                tooltip: 'Edit spot',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                        if (spot.id != null)
                          InkWell(
                            onTap: () => _openSpot(
                              spot.id!,
                              countryCode: spot.countryCode,
                              city: spot.city,
                            ),
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
                                  if (MobileDetectionService.isRunningInBrowser) ...[
                                    const SizedBox(width: 6),
                                    Icon(Icons.open_in_new, size: 14, color: Theme.of(context).primaryColor),
                                  ],
                                ],
                              ),
                            ),
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
                                  Icon(Icons.image_not_supported, size: 20, color: Colors.orange[700]),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${missingUrls.length} image${missingUrls.length == 1 ? '' : 's'} missing resized version',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[900],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...missingUrls.take(3).map(
                                    (url) => Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
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
                                    ),
                                  ),
                              if (missingUrls.length > 3)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '... and ${missingUrls.length - 3} more',
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
                        if (missingUrls.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: missingUrls.length,
                              itemBuilder: (context, imgIndex) {
                                final url = missingUrls[imgIndex];
                                return Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.orange, width: 2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
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
