import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/text_diff.dart';

void main() {
  group('diffText', () {
    test('keeps an unchanged value as one unmarked row', () {
      final rows = diffText('Central Rails', 'Central Rails');
      expect(rows, hasLength(1));
      expect(rows.single.op, TextDiffOp.equal);
      expect(rows.single.text, 'Central Rails');
    });

    test('shows unchanged lines once, including blank lines', () {
      final rows = diffText(
        'LIL GIZMO IS COMING.\n\nFrom November\n\nStill here',
        'LIL GIZMO IS COMING.\n\nFrom December\n\nStill here',
      );
      expect(rows.map((row) => row.op), [
        TextDiffOp.equal,
        TextDiffOp.equal,
        TextDiffOp.delete,
        TextDiffOp.insert,
        TextDiffOp.equal,
        TextDiffOp.equal,
      ]);
      expect(rows[0].text, 'LIL GIZMO IS COMING.');
      expect(rows[1].text, isEmpty);
      expect(rows[2].text, 'From November');
      expect(rows[3].text, 'From December');
      expect(rows[5].text, 'Still here');
    });

    test('shows an added word as a removed line and an added line', () {
      final rows = diffText('Central Rails', 'Central Rails Indoor');
      expect(rows.map((row) => row.op), [TextDiffOp.delete, TextDiffOp.insert]);
      expect(rows[0].text, 'Central Rails');
      expect(rows[1].text, 'Central Rails Indoor');
      expect(
        rows[1].spans.where((span) => span.op == TextDiffOp.insert).single.text,
        ' Indoor',
      );
    });

    test('marks a replaced word on both rows', () {
      final rows = diffText('Central Rails', 'Central Walls');
      expect(rows[0].spans.last.op, TextDiffOp.delete);
      expect(rows[0].spans.last.text, 'Rails');
      expect(rows[1].spans.last.op, TextDiffOp.insert);
      expect(rows[1].spans.last.text, 'Walls');
    });

    test('shows unchanged lines once and only marks the edited line', () {
      final rows = diffText(
        'Keep this\n\nOld line\n\nAlso keep',
        'Keep this\n\nNew line\n\nAlso keep',
      );
      expect(rows.map((row) => row.op), [
        TextDiffOp.equal,
        TextDiffOp.equal,
        TextDiffOp.delete,
        TextDiffOp.insert,
        TextDiffOp.equal,
        TextDiffOp.equal,
      ]);
      expect(rows.map((row) => row.text), [
        'Keep this',
        '',
        'Old line',
        'New line',
        '',
        'Also keep',
      ]);
    });

    test('shows a removed blank line once, as a removal', () {
      final rows = diffText(
        'Coming.\n\nFrom November',
        'Coming.\nFrom November',
      );
      expect(rows.map((row) => row.op), [
        TextDiffOp.equal,
        TextDiffOp.delete,
        TextDiffOp.equal,
      ]);
      expect(rows[1].text, isEmpty);
    });

    test('shows changed spaces as dots', () {
      expect(
        visibleDiffSpanText(const TextDiffSpan(TextDiffOp.insert, '  ')),
        '··',
      );
      expect(
        visibleDiffSpanText(const TextDiffSpan(TextDiffOp.equal, '  ')),
        '  ',
      );
    });
  });
}
