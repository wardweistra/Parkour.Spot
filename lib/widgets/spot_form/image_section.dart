import 'dart:typed_data';
import 'package:flutter/material.dart';

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Select Spot Images',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(width: 8),
                Text(
                  '*',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(existingImageUrls.length, (index) {
                    final url = existingImageUrls[index];
                    return Stack(
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
                    );
                  }),
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
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onTakePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
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

  Widget _buildReorderableImageGrid(
    BuildContext context, {
    required List<dynamic> items,
    required bool isExisting,
    required void Function(int) onRemove,
    required void Function(int, int) onReorder,
  }) {
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
          // Use stable keys: URL for existing images, index-based for new images
          final key = isExisting
              ? ValueKey<String>('existing_${item as String}')
              : ValueKey<String>('selected_$index');
          return _buildReorderableImageItem(
            context,
            key: key,
            item: item,
            index: index,
            isExisting: isExisting,
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
          color: Colors.grey.withValues(alpha: 0.3),
          width: 1,
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
                      )
                    : const SizedBox.shrink(),
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


