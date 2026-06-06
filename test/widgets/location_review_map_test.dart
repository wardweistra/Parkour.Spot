import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkour_spot/widgets/location_review_map.dart';

void main() {
  testWidgets('renders a single-pin map for one location', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationReviewMap(
            suggested: const LatLng(52.1, 4.3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GoogleMap), findsOneWidget);
    expect(find.text('Current'), findsNothing);
  });

  testWidgets('renders legend when current and suggested differ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationReviewMap(
            current: const LatLng(52.1, 4.3),
            suggested: const LatLng(52.2, 4.4),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GoogleMap), findsOneWidget);
    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Suggested'), findsOneWidget);
  });
}
