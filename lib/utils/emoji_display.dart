import 'package:characters/characters.dart';

/// Keycap base (0-9, #, *) + emoji variation selector + combining enclosing keycap.
///
/// Flutter web mishandles U+FE0F in the middle of these sequences
/// (https://github.com/flutter/flutter/issues/157831), so we prefer the
/// unqualified form (base + U+20E3) which still renders as a keycap emoji.
final _keycapWithVariationSelector = RegExp(r'([0-9#*])\uFE0F\u20E3');

/// Strip mid-sequence VS16 from keycap emoji so Flutter web can shape them.
String normalizeKeycapEmojis(String text) {
  return text.replaceAllMapped(
    _keycapWithVariationSelector,
    (match) => '${match[1]!}\u20E3',
  );
}

/// Whether this grapheme cluster should be painted with an emoji font.
///
/// Custom UI fonts (e.g. Fredoka) include Latin digits, so keycap sequences
/// get split unless the whole cluster uses an emoji font as primary.
bool isEmojiGrapheme(String grapheme) {
  for (final r in grapheme.runes) {
    if (r == 0xFE0F || r == 0xFE0E || r == 0x200D || r == 0x20E3) {
      return true;
    }
    // Miscellaneous Symbols, Dingbats.
    if (r >= 0x2600 && r <= 0x27BF) return true;
    // Regional indicator symbols (flags).
    if (r >= 0x1F1E6 && r <= 0x1F1FF) return true;
    // Emoticons, symbols, and supplemental emoji blocks.
    if (r >= 0x1F300 && r <= 0x1FAFF) return true;
  }
  return false;
}

/// Graphemes for display, with keycaps normalized for Flutter web.
List<String> emojiDisplayGraphemes(String text) {
  return normalizeKeycapEmojis(text).characters.map((g) => g).toList();
}

/// Alternating plain / emoji runs so consecutive emoji share one browser span.
List<({bool isEmoji, String text})> emojiTextRuns(String text) {
  final graphemes = text.characters.map((g) => g).toList();
  if (graphemes.isEmpty) return const [];

  final runs = <({bool isEmoji, String text})>[];
  var buffer = StringBuffer(graphemes.first);
  var emojiRun = isEmojiGrapheme(graphemes.first);

  for (var i = 1; i < graphemes.length; i++) {
    final grapheme = graphemes[i];
    final isEmoji = isEmojiGrapheme(grapheme);
    if (isEmoji == emojiRun) {
      buffer.write(grapheme);
    } else {
      runs.add((isEmoji: emojiRun, text: buffer.toString()));
      buffer = StringBuffer(grapheme);
      emojiRun = isEmoji;
    }
  }
  runs.add((isEmoji: emojiRun, text: buffer.toString()));
  return runs;
}
