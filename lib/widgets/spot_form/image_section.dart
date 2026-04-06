import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';

class SpotImageSection extends StatelessWidget {
  final List<Uint8List?> selectedImageBytes;
  final List<String> existingImageUrls;
  final void Function() onPickFromGallery;
  final void Function() onTakePhoto;
  final void Function(int) onRemoveSelectedAt;
  final void Function(int) onRemoveExistingAt;
  final void Function(int, int)? onReorderExisting;
  final void Function(int, int)? onReorderSelected;

  const SpotImageSection({
    super.key,
    required this.selectedImageBytes,
    this.existingImageUrls = const <String>[],
    required this.onPickFromGallery,
    required this.onTakePhoto,
    required this.onRemoveSelectedAt,
    required this.onRemoveExistingAt,
    this.onReorderExisting,
    this.onReorderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.addSpotImagesSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                Text(
                  '*',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Existing images (for edit mode)
            if (existingImageUrls.isNotEmpty) ...[
              if (onReorderExisting != null)
                _buildReorderableImageGrid(
                  context,
                  items: existingImageUrls,
                  isExisting: true,
                  onRemove: onRemoveExistingAt,
                  onReorder: onReorderExisting!,
                )
              else
                Builder(
                  builder: (context) {
                    final duplicateUrls = _findDuplicateUrls(existingImageUrls);
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(existingImageUrls.length, (index) {
                        final url = existingImageUrls[index];
                        final isDuplicate = duplicateUrls.contains(url);
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: isDuplicate
                                ? Border.all(color: Colors.orange, width: 3)
                                : null,
                          ),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  url,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              if (isDuplicate)
                                Positioned(
                                  top: 6,
                                  left: 6,
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
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () => onRemoveExistingAt(index),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4.0),
                                      child: Icon(Icons.delete, size: 18, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    );
                  },
                ),
              const SizedBox(height: 12),
              const Divider(height: 24),
            ],

            // Newly selected images (before upload)
            if (selectedImageBytes.isNotEmpty) ...[
              if (onReorderSelected != null)
                _buildReorderableImageGrid(
                  context,
                  items: selectedImageBytes,
                  isExisting: false,
                  onRemove: onRemoveSelectedAt,
                  onReorder: onReorderSelected!,
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < selectedImageBytes.length; i++)
                      _buildSelectedImageBytes(context, i),
                  ],
                ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onPickFromGallery,
                    icon: const Icon(Icons.photo_library),
                    label: Text(l10n.addSpotGalleryButton),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onTakePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(l10n.addSpotCameraButton),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImageBytes(BuildContext context, int index) {
    final bytes = selectedImageBytes[index];
    if (bytes == null) return const SizedBox.shrink();
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 120,
              height: 120,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.error,
                size: 48,
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onRemoveSelectedAt(index),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.close, size: 18, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Helper method to find duplicate URLs
  Set<String> _findDuplicateUrls(List<String> urls) {
    final seen = <String>{};
    final duplicates = <String>{};
    
    for (final url in urls) {
      if (seen.contains(url)) {
        duplicates.add(url);
      } else {
        seen.add(url);
      }
    }
    
    return duplicates;
  }

  Widget _buildReorderableImageGrid(
    BuildContext context, {
    required List<dynamic> items,
    required bool isExisting,
    required void Function(int) onRemove,
    required void Function(int, int) onReorder,
  }) {
    // Find duplicate URLs for existing images
    final duplicateUrls = isExisting && items.isNotEmpty
        ? _findDuplicateUrls(items.cast<String>())
        : <String>{};
    
    return SizedBox(
      height: 120,
      child: ReorderableListView(
        scrollDirection: Axis.horizontal,
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          // Return child directly without default Material wrapper to avoid white background
          return child;
        },
        onReorder: (oldIndex, newIndex) {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          onReorder(oldIndex, newIndex);
        },
        children: List.generate(items.length, (index) {
          final item = items[index];
          // Use index-based keys to preserve duplicates (same URL can appear multiple times)
          final key = isExisting
              ? ValueKey<String>('existing_$index')
              : ValueKey<String>('selected_$index');
          final isDuplicate = isExisting && duplicateUrls.contains(item as String);
          return _buildReorderableImageItem(
            context,
            key: key,
            item: item,
            index: index,
            isExisting: isExisting,
            isDuplicate: isDuplicate,
            onRemove: onRemove,
          );
        }),
      ),
    );
  }

  Widget _buildReorderableImageItem(
    BuildContext context, {
    required Key key,
    required dynamic item,
    required int index,
    required bool isExisting,
    bool isDuplicate = false,
    required void Function(int) onRemove,
  }) {
    return Container(
      key: key,
      width: 120,
      height: 120,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDuplicate
              ? Colors.orange
              : Colors.grey.withValues(alpha: 0.3),
          width: isDuplicate ? 3 : 1,
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isExisting
                ? Image.network(
                    item as String,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  )
                : item != null
                    ? Image.memory(
                        item as Uint8List,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 120,
                          height: 120,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Theme.of(context).colorScheme.error,
                            size: 48,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
          // Duplicate warning indicator
          if (isDuplicate)
            Positioned(
              top: 6,
              left: 6,
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
          // Delete button
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onRemove(index),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    isExisting ? Icons.delete : Icons.close,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          // Custom drag handle at bottom center with styled background
          Positioned(
            bottom: 6,
            left: 0,
            right: 0,
            child: Center(
              child: ReorderableDragStartListener(
                index: index,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  child: const Icon(
                    Icons.drag_handle,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


