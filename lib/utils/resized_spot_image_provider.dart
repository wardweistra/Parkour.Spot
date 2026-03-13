import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

import 'image_url_utils.dart';

/// ImageProvider that tries multiple URLs in order (1200x1200, 1200x630, original).
/// Used by PhotoView and other widgets that require an ImageProvider.
class ResizedSpotImageProvider extends ImageProvider<ResizedSpotImageProvider> {
  final List<String> urlCandidates;

  const ResizedSpotImageProvider(this.urlCandidates);

  @override
  bool operator ==(Object other) =>
      other is ResizedSpotImageProvider &&
      listEquals(urlCandidates, other.urlCandidates);

  @override
  int get hashCode => Object.hashAll(urlCandidates);

  /// Creates from an original Firebase Storage spot URL.
  factory ResizedSpotImageProvider.fromUrl(String originalUrl) {
    return ResizedSpotImageProvider(
      getResizedImageUrlCandidates(originalUrl),
    );
  }

  @override
  Future<ResizedSpotImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<ResizedSpotImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    ResizedSpotImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: 'ResizedSpotImageProvider(${urlCandidates.first})',
      informationCollector: () => [
        ErrorDescription('URLs: ${urlCandidates.join(", ")}'),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    ResizedSpotImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    Object? lastError;
    for (final url in urlCandidates) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final buffer = await ui.ImmutableBuffer.fromUint8List(
            Uint8List.fromList(response.bodyBytes),
          );
          return decode(buffer);
        }
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? StateError('All image URLs failed to load');
  }
}
