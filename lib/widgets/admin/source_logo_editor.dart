import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../utils/image_picker_utils.dart';
import '../../utils/image_preparation.dart';
import '../source_logo_image.dart';

typedef SourceLogoUploadFn = Future<String?> Function({
  required String sourceId,
  required Uint8List imageBytes,
  required String contentType,
});

typedef SourceLogoRemoveFn = Future<bool> Function(String sourceId);

/// Admin logo picker/upload/remove for an existing sync or event source.
class SourceLogoEditor extends StatefulWidget {
  final String? sourceId;
  final String? logoUrl;
  final SourceLogoUploadFn onUpload;
  final SourceLogoRemoveFn onRemove;
  final VoidCallback? onLogoChanged;

  const SourceLogoEditor({
    super.key,
    required this.sourceId,
    required this.logoUrl,
    required this.onUpload,
    required this.onRemove,
    this.onLogoChanged,
  });

  @override
  State<SourceLogoEditor> createState() => _SourceLogoEditorState();
}

class _SourceLogoEditorState extends State<SourceLogoEditor> {
  String? _displayLogoUrl;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _displayLogoUrl = widget.logoUrl;
  }

  @override
  void didUpdateWidget(covariant SourceLogoEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoUrl != widget.logoUrl && !_isWorking) {
      _displayLogoUrl = widget.logoUrl;
    }
  }

  Future<({Uint8List bytes, String contentType})> _prepareLogoUpload(
    Uint8List rawBytes,
  ) async {
    final prepared = await prepareImageForUpload(rawBytes);
    final decoded = img.decodeImage(prepared.bytes);
    if (decoded == null) {
      throw Exception('Could not decode image');
    }

    const maxDimension = 512;
    img.Image resized = decoded;
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      if (decoded.width >= decoded.height) {
        resized = img.copyResize(
          decoded,
          width: maxDimension,
          interpolation: img.Interpolation.linear,
        );
      } else {
        resized = img.copyResize(
          decoded,
          height: maxDimension,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    final contentType = prepared.contentType.startsWith('image/png')
        ? 'image/png'
        : prepared.contentType.startsWith('image/webp')
        ? 'image/webp'
        : prepared.contentType.startsWith('image/gif')
        ? 'image/gif'
        : 'image/jpeg';

    final Uint8List bytes;
    if (contentType == 'image/png') {
      bytes = Uint8List.fromList(img.encodePng(resized));
    } else if (contentType == 'image/gif') {
      bytes = Uint8List.fromList(img.encodeGif(resized));
    } else if (contentType == 'image/webp') {
      bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 88));
      return (bytes: bytes, contentType: 'image/jpeg');
    } else {
      bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 88));
    }

    return (bytes: bytes, contentType: contentType);
  }

  Future<void> _pickAndUpload() async {
    final sourceId = widget.sourceId;
    if (sourceId == null || sourceId.isEmpty) return;

    final preparedList = await pickAndPrepareGalleryImages(
      maxDimension: 512,
      maxImages: 1,
    );
    if (!mounted || preparedList.isEmpty) return;

    setState(() => _isWorking = true);
    try {
      final prepared = await _prepareLogoUpload(preparedList.first.bytes);
      final previousUrl = _displayLogoUrl;
      final newUrl = await widget.onUpload(
        sourceId: sourceId,
        imageBytes: prepared.bytes,
        contentType: prepared.contentType,
      );
      if (!mounted) return;
      if (newUrl != null && newUrl.isNotEmpty) {
        if (previousUrl != null && previousUrl.trim().isNotEmpty) {
          await CachedNetworkImage.evictFromCache(previousUrl.trim());
        }
        setState(() => _displayLogoUrl = newUrl);
        widget.onLogoChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo uploaded')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo upload failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  Future<void> _removeLogo() async {
    final sourceId = widget.sourceId;
    if (sourceId == null || sourceId.isEmpty) return;

    setState(() => _isWorking = true);
    try {
      final ok = await widget.onRemove(sourceId);
      if (!mounted) return;
      if (ok) {
        setState(() => _displayLogoUrl = null);
        widget.onLogoChanged?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo removed')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove logo')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isWorking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sourceId == null) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Save the source first, then you can upload a logo.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    final hasLogo =
        _displayLogoUrl != null && _displayLogoUrl!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Logo', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Square or wide logos work best. Shown in source details and on the About site.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SourceLogoImage(logoUrl: _displayLogoUrl, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isWorking ? null : _pickAndUpload,
                    icon: const Icon(Icons.upload_file),
                    label: Text(hasLogo ? 'Replace logo' : 'Upload logo'),
                  ),
                  if (hasLogo)
                    TextButton(
                      onPressed: _isWorking ? null : _removeLogo,
                      child: const Text('Remove'),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (_isWorking) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
      ],
    );
  }
}
