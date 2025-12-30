import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/spot_list.dart';
import '../../models/spot.dart';
import '../../services/spot_list_service.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../services/feature_access_service.dart';
import '../../widgets/spot_card.dart';
import '../../services/snackbar_service.dart';

class SpotListDetailScreen extends StatefulWidget {
  final String listId;

  const SpotListDetailScreen({super.key, required this.listId});

  @override
  State<SpotListDetailScreen> createState() => _SpotListDetailScreenState();
}

class _SpotListDetailScreenState extends State<SpotListDetailScreen> {
  SpotList? _list;
  List<Spot> _spots = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final spotListService = Provider.of<SpotListService>(context, listen: false);
    final list = await spotListService.getSpotListById(widget.listId);

    if (list == null) {
      setState(() {
        _isLoading = false;
        _error = 'List not found';
      });
      return;
    }

    setState(() {
      _list = list;
    });

    // Load spots
    if (list.spotIds.isNotEmpty) {
      await _loadSpots(list.spotIds);
    } else {
      setState(() {
        _isLoading = false;
        _spots = [];
      });
    }
  }

  Future<void> _loadSpots(List<String> spotIds) async {
    final spotService = Provider.of<SpotService>(context, listen: false);
    final List<Spot> loadedSpots = [];

    for (final spotId in spotIds) {
      final spot = await spotService.getSpotById(spotId);
      if (spot != null) {
        loadedSpots.add(spot);
      }
    }

    setState(() {
      _spots = loadedSpots;
      _isLoading = false;
    });
  }

  Future<void> _removeSpot(String spotId) async {
    final spotListService = Provider.of<SpotListService>(context, listen: false);
    final success = await spotListService.removeSpotFromList(widget.listId, spotId);

    if (success) {
      SnackbarService.showSuccess('Spot removed from list');
      // Reload the list
      await _loadList();
    } else {
      SnackbarService.showError(spotListService.error ?? 'Failed to remove spot');
    }
  }

  Future<void> _deleteList() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete List'),
        content: Text('Are you sure you want to delete "${_list?.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && _list?.id != null) {
      final spotListService = Provider.of<SpotListService>(context, listen: false);
      final success = await spotListService.deleteSpotList(_list!.id!);

      if (success) {
        SnackbarService.showSuccess('List deleted');
        if (context.mounted) {
          context.pop();
        }
      } else {
        SnackbarService.showError(spotListService.error ?? 'Failed to delete list');
      }
    }
  }

  Widget _buildSpotsList() {
    if (_spots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No spots in this list',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add spots from spot detail pages',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = screenWidth >= 600; // Use grid layout on wider screens
    final canManage = _canManageList();

    if (useGrid) {
      // Calculate optimal grid dimensions based on screen size
      final maxCrossAxisExtent = 480.0;
      final mainAxisExtent = 440.0; // Height to accommodate bottom content

      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: maxCrossAxisExtent,
          mainAxisExtent: mainAxisExtent,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _spots.length,
        itemBuilder: (context, index) {
          final spot = _spots[index];
          return Stack(
            clipBehavior: Clip.none,
            children: [
              SpotCard(
                spot: spot,
                onTap: () {
                  // Navigate to spot detail
                  final navigationUrl = spot.id != null
                      ? '/spot/${spot.id}'
                      : null;
                  if (navigationUrl != null) {
                    context.go(navigationUrl);
                  }
                },
              ),
              if (canManage)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove from list',
                    onPressed: () {
                      if (spot.id != null) {
                        _removeSpot(spot.id!);
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ),
            ],
          );
        },
      );
    } else {
      // Use list layout on narrower screens
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _spots.length,
        itemBuilder: (context, index) {
          final spot = _spots[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Stack(
              children: [
                SpotCard(
                  spot: spot,
                  onTap: () {
                    // Navigate to spot detail
                    final navigationUrl = spot.id != null
                        ? '/spot/${spot.id}'
                        : null;
                    if (navigationUrl != null) {
                      context.go(navigationUrl);
                    }
                  },
                ),
                if (canManage)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Remove from list',
                      onPressed: () {
                        if (spot.id != null) {
                          _removeSpot(spot.id!);
                        }
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.surface,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    }
  }

  Future<void> _editList() async {
    if (_list == null) return;

    final nameController = TextEditingController(text: _list!.name);
    final descriptionController = TextEditingController(text: _list!.description ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'List Name',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('List name cannot be empty')),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && _list?.id != null) {
      final spotListService = Provider.of<SpotListService>(context, listen: false);
      final success = await spotListService.updateSpotList(
        _list!.id!,
        name: nameController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      );

      if (success) {
        SnackbarService.showSuccess('List updated');
        await _loadList();
      } else {
        SnackbarService.showError(spotListService.error ?? 'Failed to update list');
      }
    }
  }

  bool _canManageList() {
    if (_list == null) return false;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return false;
    
    final userId = authService.currentUser?.uid;
    if (userId == null || _list!.createdBy != userId) return false;
    
    final featureAccessService = FeatureAccessService(authService);
    return featureAccessService.hasFeatureAccess('spotLists');
  }

  @override
  Widget build(BuildContext context) {
    final canManage = _canManageList();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_list?.name ?? 'Spot List'),
        actions: [
          if (_list != null && canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit List',
              onPressed: _editList,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete List',
              onPressed: _deleteList,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.pop(),
                        child: const Text('Go Back'),
                      ),
                    ],
                  ),
                )
              : _list == null
                  ? const Center(child: Text('List not found'))
                  : Column(
                      children: [
                        // List info header
                        if (_list!.description != null && _list!.description!.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: Text(
                              _list!.description!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        // Spots list
                        Expanded(
                          child: _buildSpotsList(),
                        ),
                      ],
                    ),
    );
  }
}

