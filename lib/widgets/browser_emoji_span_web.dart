import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Web: let the browser paint emoji (CanvasKit mishandles keycap VS16 sequences).
Widget buildBrowserEmojiSpan({
  required String text,
  required double fontSize,
  required Color? color,
}) {
  // Slightly roomy so keycaps/flags are not clipped; overflow hidden so paint
  // cannot spill into neighboring gaps (especially in ListTile titles).
  final width = fontSize * 1.2;
  final height = fontSize * 1.35;
  return SizedBox(
    width: width,
    height: height,
    child: HtmlElementView.fromTagName(
      tagName: 'span',
      onElementCreated: (Object element) {
        final el = element as web.HTMLElement;
        el.textContent = text;
        el.style
          ..fontSize = '${fontSize}px'
          ..lineHeight = '1.2'
          ..display = 'inline-flex'
          ..alignItems = 'center'
          ..justifyContent = 'center'
          ..whiteSpace = 'nowrap'
          ..overflow = 'hidden'
          ..width = '100%'
          ..height = '100%'
          // Let ListTile / InkWell receive taps.
          ..pointerEvents = 'none'
          ..fontFamily =
              '"Apple Color Emoji", "Segoe UI Emoji", "Noto Color Emoji", sans-serif';
        if (color != null) {
          el.style.color = _cssColor(color);
        }
      },
    ),
  );
}

String _cssColor(Color color) {
  final a = (color.a * 255.0).round().clamp(0, 255);
  final r = (color.r * 255.0).round().clamp(0, 255);
  final g = (color.g * 255.0).round().clamp(0, 255);
  final b = (color.b * 255.0).round().clamp(0, 255);
  if (a == 255) {
    return 'rgb($r, $g, $b)';
  }
  return 'rgba($r, $g, $b, ${a / 255.0})';
}
