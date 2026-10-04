import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/utils/marker_icon_utils.dart';
import 'package:parkour_spot/widgets/location_review_map.dart';

void main() {
  testWidgets('renders a single-pin map for one location', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

  testWidgets('renders legend with explore pin assets when comparing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

    final currentPin = tester.widget<Image>(
      find.image(AssetImage(MarkerIconUtils.mapPinNormalAsset)),
    );
    final suggestedPin = tester.widget<Image>(
      find.image(AssetImage(MarkerIconUtils.mapPinNormalSelectedAsset)),
    );
    expect(currentPin.image, isA<AssetImage>());
    expect(suggestedPin.image, isA<AssetImage>());
  });

  testWidgets('supports multiple suggested pins', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: LocationReviewMap(
            current: const LatLng(52.1, 4.3),
            suggestedPins: const <LatLng>[
              LatLng(52.2, 4.4),
              LatLng(52.21, 4.41),
            ],
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
