import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

/// Shared utilities for updating document title and Open Graph/Twitter meta tags on web.
/// Keeps browser tab title and meta tags consistent with share previews.
class WebMetaUtils {
  WebMetaUtils._();

  static const String defaultTitle = 'Parkour·Spot';

  /// Clips text for meta description at word boundary. Returns original if within limit.
  static String clipForMeta(String text, {int maxLength = 280}) {
    if (text.length <= maxLength) return text;
    final clipped = text.substring(0, maxLength - 1);
    final lastSpace = clipped.lastIndexOf(' ');
    final cut = lastSpace > maxLength * 0.7 ? lastSpace : maxLength - 1;
    return '${clipped.substring(0, cut).trim()}…';
  }
  static const String defaultDescription =
      'Discover, map, and share the best parkour spots worldwide with community photos, ratings, and local tips for your next training session.';

  /// Updates document title and OG/Twitter meta tags.
  /// No-op when not running on web.
  static void updatePageMeta(String title, String description) {
    if (!kIsWeb) return;

    web.document.title = title;

    // meta description
    final metaDescription =
        web.document.querySelector('meta[name="description"]');
    if (metaDescription != null) {
      metaDescription.setAttribute('content', description);
    } else {
      final meta = web.document.createElement('meta') as web.HTMLMetaElement;
      meta.name = 'description';
      meta.content = description;
      web.document.head?.appendChild(meta);
    }

    // og:description
    final ogDescription =
        web.document.querySelector('meta[property="og:description"]');
    if (ogDescription != null) {
      ogDescription.setAttribute('content', description);
    }

    // twitter:description
    final twitterDescription =
        web.document.querySelector('meta[name="twitter:description"]');
    if (twitterDescription != null) {
      twitterDescription.setAttribute('content', description);
    }

    // og:title
    final ogTitle = web.document.querySelector('meta[property="og:title"]');
    if (ogTitle != null) {
      ogTitle.setAttribute('content', title);
    }

    // twitter:title
    final twitterTitle =
        web.document.querySelector('meta[name="twitter:title"]');
    if (twitterTitle != null) {
      twitterTitle.setAttribute('content', title);
    }
  }

  /// Resets document title and meta tags to defaults.
  /// Call in dispose when leaving a page.
  static void resetPageMeta() {
    if (!kIsWeb) return;
    updatePageMeta(defaultTitle, defaultDescription);
  }
}
