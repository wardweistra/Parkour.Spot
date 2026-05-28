enum ShareLinkKind {
  spot,
  event,
  list,
  profile,
}

/// Builds consistent share/clipboard strings: `<icon> <title> <url>`.
class ShareLinkText {
  ShareLinkText._();

  static String _icon(ShareLinkKind kind) => switch (kind) {
        ShareLinkKind.spot => '📍',
        ShareLinkKind.event => '🗓️',
        ShareLinkKind.list => '📋',
        ShareLinkKind.profile => '👤',
      };

  /// Web Share title/text: icon + title (URL passed separately).
  static String shareLabel(ShareLinkKind kind, String title) {
    final trimmed = title.trim();
    return '${_icon(kind)} $trimmed';
  }

  /// Clipboard fallback: icon + title + URL.
  static String clipboardText(ShareLinkKind kind, String title, String url) {
    return '${shareLabel(kind, title)} $url';
  }
}
