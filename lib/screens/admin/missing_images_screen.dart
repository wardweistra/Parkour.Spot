import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/sync_source_service.dart';
import '../../utils/image_picker_utils.dart';
import '../../utils/image_preparation.dart';

class MissingImagesScreen extends StatefulWidget {
  final List<dynamic> missingImages;
  final int totalReferenced;
  final int totalExisting;

  const MissingImagesScreen({
    super.key,
    required this.missingImages,
    required this.totalReferenced,
    required this.totalExisting,
  });

  @override
  State<MissingImagesScreen> createState() => _MissingImagesScreenState();
}

class _MissingImagesScreenState extends State<MissingImagesScreen> {
  final Map<String, Uint8List?> _selectedImages = {};
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Missing images (${widget.missingImages.length})'),
        actions: [
          if (_selectedImages.isNotEmpty)
            TextButton(
              onPressed: _isUploading ? null : _uploadSelectedImages,
              child: Text(_isUploading ? 'Uploading...' : 'Upload Selected'),
            ),
        ],
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Missing Images Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text('Total referenced images: ${widget.totalReferenced}'),
                  Text('Total existing files: ${widget.totalExisting}'),
                  Text('Missing images: ${widget.missingImages.length}'),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.missingImages.length,
              itemBuilder: (context, index) {
                final missingImage = widget.missingImages[index];
                final filename = missingImage['filename'] as String;
                final spots = missingImage['spots'] as List<dynamic>;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: SelectableText(filename),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Referenced by ${spots.length} spot(s):'),
                        ...spots.map(
                          (spot) => SelectableText(
                            '• ${spot['spotName']} (${spot['spotId']})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedImages.containsKey(filename))
                          const Icon(Icons.check_circle, color: Colors.green)
                        else
                          IconButton(
                            icon: const Icon(Icons.upload),
                            onPressed: () => _selectImage(filename),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectImage(String filename) async {
    try {
      final image = await pickImage(source: ImageSource.gallery);

      if (image != null) {
        final bytes = await image.readAsBytes();
        final prepared = await preparePickedImageBytes(bytes);
        setState(() {
          _selectedImages[filename] = prepared.bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadSelectedImages() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isUploading = true;
    });

    var successCount = 0;
    var failCount = 0;

    final syncService = context.read<SyncSourceService>();
    for (final entry in _selectedImages.entries) {
      if (entry.value == null) continue;

      try {
        final prepared = await prepareImageForUpload(entry.value!);
        final base64Image = base64Encode(prepared.bytes);
        final result = await syncService.uploadReplacementImage(
          filename: entry.key,
          imageData: base64Image,
          contentType: prepared.contentType,
        );

        if (result != null && result['success'] == true) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
        debugPrint('Failed to upload ${entry.key}: $e');
        if (mounted && e is ImagePreparationException) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red),
          );
        }
      }
    }

    setState(() {
      _isUploading = false;
      _selectedImages.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Upload completed: $successCount successful, $failCount failed',
          ),
          backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }
}
