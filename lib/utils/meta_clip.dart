/// Pure utility for clipping text at word boundaries for meta descriptions.
/// Extracted for testability without web platform dependencies.
///
/// Clips text for meta description at word boundary. Returns original if within limit.
String clipForMetaImpl(String text, {int maxLength = 280}) {
  if (text.length <= maxLength) return text;
  final clipped = text.substring(0, maxLength - 1);
  final lastSpace = clipped.lastIndexOf(' ');
  final cut = lastSpace > maxLength * 0.7 ? lastSpace : maxLength - 1;
  return '${clipped.substring(0, cut).trim()}…';
}
