import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../models/spot.dart'; // ignore: unused_import
import '../../widgets/spot_card.dart';

class SpotsListScreen extends StatefulWidget {
  const SpotsListScreen({super.key});

  @override
  State<SpotsListScreen> createState() => _SpotsListScreenState();
}

class _SpotsListScreenState extends State<SpotsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _isSearching = _searchController.text.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Welcome to Parkour.Spot!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search spots...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                // Search functionality will be implemented when we have the service
                setState(() {
                  _isSearching = value.isNotEmpty;
                });
              },
            ),
          ),
          

          
          // Spots List
          Expanded(
            child: Consumer<SpotService>(
              builder: (context, spotService, child) {
                if (spotService.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (spotService.error != null) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading spots',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            spotService.error!,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => spotService.fetchSpots(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final spots = _isSearching && _searchController.text.isNotEmpty
                    ? spotService.searchSpots(_searchController.text)
                    : spotService.spots;

                if (spots.isEmpty) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSearching ? Icons.search_off : Icons.location_off,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isSearching ? 'No spots found' : 'No spots yet',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isSearching
                                ? 'Try adjusting your search terms'
                                : 'Be the first to add a parkour spot!',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final screenWidth = MediaQuery.of(context).size.width;
                final useGrid = screenWidth >= 600;
                
                // Calculate optimal grid dimensions based on screen size
                final maxCrossAxisExtent = screenWidth >= 1200 ? 600 : 480;
                final mainAxisExtent = screenWidth >= 1200 ? 480 : 440; // Increased height to accommodate bottom content

                return RefreshIndicator(
                  onRefresh: () => spotService.fetchSpots(),
                  child: useGrid
                      ? GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: maxCrossAxisExtent.toDouble(),
                            mainAxisExtent: mainAxisExtent.toDouble(),
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: spots.length,
                          itemBuilder: (context, index) {
                            final spot = spots[index];
                            return SpotCard(
                              spot: spot,
                              onTap: () {
                                // Navigate to spot detail using GoRouter
                                context.go('/spot/${spot.id}');
                              },
                            );
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: spots.length,
                          itemBuilder: (context, index) {
                            final spot = spots[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: SpotCard(
                                spot: spot,
                                onTap: () {
                                  // Navigate to spot detail using GoRouter
                                  context.go('/spot/${spot.id}');
                                },
                              ),
                            );
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
