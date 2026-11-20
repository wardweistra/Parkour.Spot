import 'package:material_ui/material_ui.dart';

/// Non-web fallback: paint emoji with Flutter [Text].
Widget buildBrowserEmojiSpan({
  required String text,
  required double fontSize,
  required Color? color,
}) {
  return Text(
    text,
    style: TextStyle(
      inherit: false,
      fontSize: fontSize,
      color: color,
      height: 1,
    ),
  );
}
