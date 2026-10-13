import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/widgets/source_logo_image.dart';

void main() {
  testWidgets('SourceLogoImage shows fallback when url is missing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SourceLogoImage(logoUrl: null),
        ),
      ),
    );

    expect(find.byIcon(Icons.public), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
