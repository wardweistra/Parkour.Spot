import 'package:flutter/foundation.dart' show kIsWeb;

import 'browser_location.dart';
import 'meta_clip.dart';

/// Shared utilities for updating document title and Open Graph/Twitter meta tags on web.
/// Keeps browser tab title and meta tags consistent with share previews.
class WebMetaUtils {
  WebMetaUtils._();

  static const String defaultTitle = 'Parkour·Spot';

  /// Clips text for meta description at word boundary. Returns original if within limit.
  static String clipForMeta(String text, {int maxLength = 280}) =>
      clipForMetaImpl(text, maxLength: maxLength);
  static const String defaultDescription =
      'Discover, map, and share the best parkour spots worldwide with community photos, ratings, and local tips for your next training session.';

  /// Updates document title and OG/Twitter meta tags.
  /// No-op when not running on web.
  static void updatePageMeta(String title, String description) {
    if (!kIsWeb) return;
    updateBrowserPageMeta(title, description);
  }

  /// Resets document title and meta tags to defaults.
  /// Call in dispose when leaving a page.
  static void resetPageMeta() {
    if (!kIsWeb) return;
    updatePageMeta(defaultTitle, defaultDescription);
  }
}
