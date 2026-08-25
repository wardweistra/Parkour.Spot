import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../utils/emoji_display.dart';
import 'browser_emoji_span_stub.dart'
    if (dart.library.js_interop) 'browser_emoji_span_web.dart' as browser_emoji;

/// [Text] that keeps emoji (especially keycaps) intact on Flutter web.
///
/// CanvasKit + custom fonts mishandle keycap sequences that contain U+FE0F
/// (https://github.com/flutter/flutter/issues/157831). On web, emoji runs are
/// painted by the browser via [HtmlElementView]; Latin text stays Fredoka.
class EmojiText extends StatelessWidget {
  const EmojiText(
    this.data, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.softWrap,
  });

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool? softWrap;

  /// Gap between an emoji run and neighboring Fredoka text.
  static const _edgeGap = 4.0;

  /// Gap between consecutive emoji graphemes (e.g. 4️⃣ and 0️⃣).
  static const _interEmojiGap = 2.0;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Text(
        data,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        softWrap: softWrap,
      );
    }

    final runs = emojiTextRuns(data);
    if (!runs.any((run) => run.isEmoji)) {
      return Text(
        data,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        softWrap: softWrap,
      );
    }

    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final fontSize = baseStyle.fontSize ?? 16;
    final children = <InlineSpan>[];

    for (var i = 0; i < runs.length; i++) {
      final run = runs[i];
      if (!run.isEmoji) {
        children.add(TextSpan(text: run.text, style: baseStyle));
        continue;
      }

      // One WidgetSpan per run with a Row so inter-emoji gaps stay visible
      // inside ListTile titles (adjacent WidgetSpans were getting covered by
      // overflowing keycap glyphs at titleMedium size).
      final graphemes = run.text.characters.toList();
      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsets.only(
              left: i > 0 ? _edgeGap : 0,
              right: i < runs.length - 1 ? _edgeGap : 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var j = 0; j < graphemes.length; j++) ...[
                  if (j > 0) const SizedBox(width: _interEmojiGap),
                  browser_emoji.buildBrowserEmojiSpan(
                    text: graphemes[j],
                    fontSize: fontSize,
                    color: baseStyle.color,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(
        style: baseStyle.copyWith(inherit: false),
        children: children,
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
    );
  }
}
