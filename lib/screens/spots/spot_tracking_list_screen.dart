import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/spot.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../services/url_service.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/spot_card.dart';

enum SpotTrackingListType {
  wantToVisit,
  visited,
}

class SpotTrackingListScreen extends StatefulWidget {
  final SpotTrackingListType type;

  const SpotTrackingListScreen({super.key, required this.type});

  @override
  State<SpotTrackingListScreen> createState() => _SpotTrackingListScreenState();
}

class _SpotTrackingListScreenState extends State<SpotTrackingListScreen> {
  List<Spot> _spots = [];
  bool _isLoading = true;
  String? _error;
  List<String>? _lastLoadedSpotIds;

  @override
  void initState() {
    super.initState();
    _loadSpots();
  }

  bool _listEquals(List<String> a, List<String>? b) {
    if (b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _loadSpots() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final spotIds = widget.type == SpotTrackingListType.wantToVisit
        ? authService.userProfile?.wantToVisit ?? []
        : authService.userProfile?.visited ?? [];

    _lastLoadedSpotIds = List<String>.from(spotIds);

    if (spotIds.isEmpty) {
      setState(() {
        _spots = [];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final spotService = Provider.of<SpotService>(context, listen: false);
    final List<Spot> loadedSpots = [];

    for (final spotId in spotIds) {
      final spot = await spotService.getSpotById(spotId);
      if (spot != null) {
        loadedSpots.add(spot);
      }
    }

    if (mounted) {
      setState(() {
        _spots = loadedSpots;
        _isLoading = false;
      });
    }
  }

  String get _title {
    switch (widget.type) {
      case SpotTrackingListType.wantToVisit:
        return 'Want to visit';
      case SpotTrackingListType.visited:
        return 'Been to';
    }
  }

  void _checkProfileAndReload(AuthService authService) {
    // When navigating directly or refreshing, AuthService may load the profile
    // after initState. Re-load spots when the profile becomes available with
    // spot IDs we haven't loaded yet.
    final spotIds = widget.type == SpotTrackingListType.wantToVisit
        ? authService.userProfile?.wantToVisit ?? []
        : authService.userProfile?.visited ?? [];
    if (spotIds.isNotEmpty &&
        !_listEquals(spotIds, _lastLoadedSpotIds) &&
        !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSpots();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        _checkProfileAndReload(authService);

        if (!authService.isAuthenticated) {
          return PageScaffold(
            title: _title,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Sign in to view your $_title list',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/login?redirectTo=${Uri.encodeComponent('/profile/${widget.type == SpotTrackingListType.wantToVisit ? 'want-to-visit' : 'visited'}')}'),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
          );
        }

        return PageScaffold(
      title: _title,
      scrollable: false,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _spots.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.type == SpotTrackingListType.wantToVisit
                                  ? Icons.bookmark_border
                                  : Icons.check_circle_outline,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No spots in $_title',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add spots from spot detail pages',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSpots,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final useGrid = constraints.maxWidth >= 600;
                          if (useGrid) {
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 480,
                                mainAxisExtent: 440,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: _spots.length,
                              itemBuilder: (context, i) {
                                final spot = _spots[i];
                                return SpotCard(
                                  spot: spot,
                                  onTapWithImageIndex: (imageIndex) {
                                    if (spot.id != null) {
                                      final baseUrl =
                                          UrlService.generateNavigationUrl(
                                        spot.id!,
                                        countryCode: spot.countryCode,
                                        city: spot.city,
                                      );
                                      final url = imageIndex > 0
                                          ? '$baseUrl?imageIndex=$imageIndex'
                                          : baseUrl;
                                      context.push(url);
                                    }
                                  },
                                );
                              },
                            );
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _spots.length,
                            itemBuilder: (context, i) {
                              final spot = _spots[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: SpotCard(
                                  spot: spot,
                                  onTapWithImageIndex: (imageIndex) {
                                    if (spot.id != null) {
                                      final baseUrl =
                                          UrlService.generateNavigationUrl(
                                        spot.id!,
                                        countryCode: spot.countryCode,
                                        city: spot.city,
                                      );
                                      final url = imageIndex > 0
                                          ? '$baseUrl?imageIndex=$imageIndex'
                                          : baseUrl;
                                      context.push(url);
                                    }
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
        );
      },
    );
  }
}
