import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/emoji_display.dart';

void main() {
  group('normalizeKeycapEmojis', () {
    test('strips VS16 from digit keycaps', () {
      expect(
        normalizeKeycapEmojis('4️⃣0️⃣ Forty over Forty'),
        '4⃣0⃣ Forty over Forty',
      );
    });

    test('strips VS16 from hash and star keycaps', () {
      expect(normalizeKeycapEmojis('#️⃣*️⃣'), '#⃣*⃣');
    });

    test('leaves trailing VS16 on hearts alone', () {
      // ❤ + FE0F should stay so emoji presentation is preserved.
      expect(normalizeKeycapEmojis('I ❤️ parkour'), 'I ❤️ parkour');
    });

    test('leaves plain text unchanged', () {
      expect(normalizeKeycapEmojis('Forty over Forty'), 'Forty over Forty');
    });
  });

  group('isEmojiGrapheme', () {
    test('detects normalized keycaps', () {
      expect(isEmojiGrapheme('4⃣'), isTrue);
      expect(isEmojiGrapheme('0⃣'), isTrue);
    });

    test('detects fully-qualified keycaps', () {
      expect(isEmojiGrapheme('4️⃣'), isTrue);
    });

    test('rejects plain letters and digits', () {
      expect(isEmojiGrapheme('4'), isFalse);
      expect(isEmojiGrapheme('F'), isFalse);
      expect(isEmojiGrapheme(' '), isFalse);
    });
  });

  group('emojiTextRuns', () {
    test('groups consecutive keycaps into one emoji run', () {
      expect(emojiTextRuns('4️⃣0️⃣ Forty'), [
        (isEmoji: true, text: '4️⃣0️⃣'),
        (isEmoji: false, text: ' Forty'),
      ]);
    });

    test('keeps a lone emoji as its own run', () {
      expect(emojiTextRuns('🇺🇸 Spots'), [
        (isEmoji: true, text: '🇺🇸'),
        (isEmoji: false, text: ' Spots'),
      ]);
    });
  });
}
