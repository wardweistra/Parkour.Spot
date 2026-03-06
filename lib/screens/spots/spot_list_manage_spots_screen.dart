import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/spot.dart';
import '../../services/spot_list_service.dart';
import '../../services/snackbar_service.dart';
import '../../utils/image_url_utils.dart';

/// Full-screen manage spots UI: reorder and remove spots from a list.
/// Used for both narrow and wide screens when the owner wants to manage their list.
class SpotListManageSpotsScreen extends StatefulWidget {
  final String listName;
  final String listId;
  final List<Spot> spots;

  const SpotListManageSpotsScreen({
    super.key,
    required this.listName,
    required this.listId,
    required this.spots,
  });

  @override
  State<SpotListManageSpotsScreen> createState() =>
      _SpotListManageSpotsScreenState();
}

class _SpotListManageSpotsScreenState extends State<SpotListManageSpotsScreen> {
  late List<Spot> _spots;

  @override
  void initState() {
    super.initState();
    _spots = List.from(widget.spots);
  }

  Future<void> _reorderSpots(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final previousSpots = List<Spot>.from(_spots);
    setState(() {
      final item = _spots.removeAt(oldIndex);
      _spots.insert(newIndex, item);
    });

    final newSpotIds =
        _spots.map((s) => s.id).whereType<String>().toList();
    final spotListService =
        Provider.of<SpotListService>(context, listen: false);
    final success =
        await spotListService.reorderSpotsInList(widget.listId, newSpotIds);

    if (!mounted) return;
    if (!success) {
      setState(() {
        _spots = previousSpots;
      });
      SnackbarService.showError(
          spotListService.error ?? 'Failed to reorder list');
    }
  }

  Future<void> _removeSpot(Spot spot) async {
    final spotId = spot.id;
    if (spotId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from list'),
        content: Text(
          'Remove "${spot.name}" from this list?',
        ),
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final spotListService =
        Provider.of<SpotListService>(context, listen: false);
    final success =
        await spotListService.removeSpotFromList(widget.listId, spotId);

    if (!mounted) return;
    if (success) {
      setState(() {
        _spots.removeWhere((s) => s.id == spotId);
      });
      SnackbarService.showSuccess('Spot removed from list');
    } else {
      SnackbarService.showError(
          spotListService.error ?? 'Failed to remove spot');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage spots: ${widget.listName}'),
      ),
      body: _spots.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No spots in this list',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add spots from spot detail pages',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            )
          : ReorderableListView(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              proxyDecorator: (child, index, animation) => child,
              onReorder: _reorderSpots,
              children: [
                for (var i = 0; i < _spots.length; i++)
                  _buildManageableItem(_spots[i], i, theme),
              ],
            ),
    );
  }

  Widget _buildManageableItem(Spot spot, int index, ThemeData theme) {
    final hasImage = spot.imageUrls != null && spot.imageUrls!.isNotEmpty;
    final imageUrl = hasImage ? getResizedImageUrl(spot.imageUrls!.first) : null;
    final locationText = [spot.city, spot.countryCode]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(', ');

    return Container(
      key: ValueKey(spot.id ?? spot.name),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.drag_handle,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ),
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 72,
                      height: 72,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                        size: 28,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 72,
                      height: 72,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.5),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              if (imageUrl != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      spot.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (locationText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        locationText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (spot.id != null)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Remove from list',
                  onPressed: () => _removeSpot(spot),
                  color: theme.colorScheme.error,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
