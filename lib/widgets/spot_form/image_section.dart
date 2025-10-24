import 'dart:typed_data';
import 'package:flutter/material.dart';

class SpotImageSection extends StatelessWidget {
  final List<Uint8List?> selectedImageBytes;
  final List<String> existingImageUrls;
  final void Function() onPickFromGallery;
  final void Function() onTakePhoto;
  final void Function(int) onRemoveSelectedAt;
  final void Function(int) onRemoveExistingAt;

  const SpotImageSection({
    super.key,
    required this.selectedImageBytes,
    this.existingImageUrls = const <String>[],
    required this.onPickFromGallery,
    required this.onTakePhoto,
    required this.onRemoveSelectedAt,
    required this.onRemoveExistingAt,
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
                  'Spot Images',
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
}


