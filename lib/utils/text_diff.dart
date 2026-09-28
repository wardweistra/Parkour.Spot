enum TextDiffOp { equal, delete, insert }

/// One run of unchanged, removed, or added text inside a line.
class TextDiffSpan {
  const TextDiffSpan(this.op, this.text);

  final TextDiffOp op;
  final String text;
}

/// One unified-diff line. Unchanged lines use [TextDiffOp.equal] and appear
/// once. Removed and added lines use [TextDiffOp.delete] and [TextDiffOp.insert].
class TextDiffRow {
  const TextDiffRow({required this.op, required this.spans});

  final TextDiffOp op;
  final List<TextDiffSpan> spans;

  String get text => spans.map((span) => span.text).join();
}

/// Unified diff of [before] and [after]. Matching lines are emitted once.
/// A replaced line is a removal followed by an addition, with the changed
/// words marked inside those two lines.
List<TextDiffRow> diffText(String before, String after) {
  final beforeLines = _lines(before);
  final afterLines = _lines(after);
  if (_sameLines(beforeLines, afterLines)) {
    return [for (final line in beforeLines) _line(TextDiffOp.equal, line)];
  }
  return _lineDiff(beforeLines, afterLines);
}

/// Text to paint for [span]. Changed spaces become dots so a spacing-only
/// edit stays visible.
String visibleDiffSpanText(TextDiffSpan span) {
  if (span.op == TextDiffOp.equal) return span.text;
  return span.text.replaceAll(' ', '·').replaceAll('\t', '→');
}

List<TextDiffRow> _lineDiff(List<String> beforeLines, List<String> afterLines) {
  final spans = _diffTokens(beforeLines, afterLines, merge: false);
  final rows = <TextDiffRow>[];
  var index = 0;
  while (index < spans.length) {
    if (spans[index].op == TextDiffOp.equal) {
      rows.add(_line(TextDiffOp.equal, spans[index].text));
      index++;
      continue;
    }

    final deletes = <String>[];
    final inserts = <String>[];
    while (index < spans.length && spans[index].op == TextDiffOp.delete) {
      deletes.add(spans[index].text);
      index++;
    }
    while (index < spans.length && spans[index].op == TextDiffOp.insert) {
      inserts.add(spans[index].text);
      index++;
    }
    final pairs = deletes.length < inserts.length
        ? deletes.length
        : inserts.length;
    for (var pair = 0; pair < pairs; pair++) {
      rows.addAll(_replacedLine(deletes[pair], inserts[pair]));
    }
    for (final line in deletes.skip(pairs)) {
      rows.add(_line(TextDiffOp.delete, line));
    }
    for (final line in inserts.skip(pairs)) {
      rows.add(_line(TextDiffOp.insert, line));
    }
  }
  return rows;
}

List<TextDiffRow> _replacedLine(String before, String after) {
  final spans = _diffTokens(_tokenize(before), _tokenize(after));
  return [
    TextDiffRow(
      op: TextDiffOp.delete,
      spans: [
        for (final span in spans)
          if (span.op != TextDiffOp.insert) span,
      ],
    ),
    TextDiffRow(
      op: TextDiffOp.insert,
      spans: [
        for (final span in spans)
          if (span.op != TextDiffOp.delete) span,
      ],
    ),
  ];
}

TextDiffRow _line(TextDiffOp op, String line) {
  if (line.isEmpty) {
    return TextDiffRow(
      op: op,
      spans: [TextDiffSpan(op == TextDiffOp.equal ? TextDiffOp.equal : op, '')],
    );
  }
  return TextDiffRow(
    op: op,
    spans: [TextDiffSpan(op == TextDiffOp.equal ? TextDiffOp.equal : op, line)],
  );
}

List<String> _lines(String input) {
  if (input.isEmpty) return const [];
  final normalized = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final lines = normalized.split('\n');
  if (normalized.endsWith('\n')) lines.removeLast();
  return lines;
}

bool _sameLines(List<String> before, List<String> after) {
  if (before.length != after.length) return false;
  for (var i = 0; i < before.length; i++) {
    if (before[i] != after[i]) return false;
  }
  return true;
}

List<String> _tokenize(String input) {
  return RegExp(
    r'[ \t]+|[^\s]+',
  ).allMatches(input).map((match) => match.group(0)!).toList();
}

List<TextDiffSpan> _diffTokens(
  List<String> before,
  List<String> after, {
  bool merge = true,
}) {
  final beforeLength = before.length;
  final afterLength = after.length;
  final lcs = List.generate(
    beforeLength + 1,
    (_) => List<int>.filled(afterLength + 1, 0),
  );
  for (var i = beforeLength - 1; i >= 0; i--) {
    for (var j = afterLength - 1; j >= 0; j--) {
      if (before[i] == after[j]) {
        lcs[i][j] = lcs[i + 1][j + 1] + 1;
      } else {
        final skipBefore = lcs[i + 1][j];
        final skipAfter = lcs[i][j + 1];
        lcs[i][j] = skipBefore >= skipAfter ? skipBefore : skipAfter;
      }
    }
  }

  final spans = <TextDiffSpan>[];
  var i = 0;
  var j = 0;
  while (i < beforeLength && j < afterLength) {
    if (before[i] == after[j]) {
      spans.add(TextDiffSpan(TextDiffOp.equal, before[i]));
      i++;
      j++;
    } else if (lcs[i + 1][j] >= lcs[i][j + 1]) {
      spans.add(TextDiffSpan(TextDiffOp.delete, before[i]));
      i++;
    } else {
      spans.add(TextDiffSpan(TextDiffOp.insert, after[j]));
      j++;
    }
  }
  while (i < beforeLength) {
    spans.add(TextDiffSpan(TextDiffOp.delete, before[i]));
    i++;
  }
  while (j < afterLength) {
    spans.add(TextDiffSpan(TextDiffOp.insert, after[j]));
    j++;
  }
  return merge ? _mergeSpans(spans) : spans;
}

List<TextDiffSpan> _mergeSpans(List<TextDiffSpan> spans) {
  if (spans.isEmpty) return spans;
  final merged = <TextDiffSpan>[spans.first];
  for (final span in spans.skip(1)) {
    final previous = merged.last;
    if (previous.op == span.op) {
      merged[merged.length - 1] = TextDiffSpan(
        previous.op,
        '${previous.text}${span.text}',
      );
    } else {
      merged.add(span);
    }
  }
  return merged;
}
