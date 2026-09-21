import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/widgets/country_flag_badge.dart';

void main() {
  test('maps ISO country codes to lowercase alpha-2', () {
    expect(isoAlpha2CountryCode('FR'), 'fr');
    expect(isoAlpha2CountryCode(' gb-eng '), 'gb');
    expect(isoAlpha2CountryCode('X'), isNull);
    expect(isoAlpha2CountryCode('12'), isNull);
  });

  test('builds Flagcdn PNG URLs', () {
    expect(flagCdnPngUrl('FR'), 'https://flagcdn.com/w40/fr.png');
    expect(flagCdnPngUrl(' gb-eng '), 'https://flagcdn.com/w40/gb.png');
    expect(flagCdnPngUrl('not-a-country'), isNull);
  });

  testWidgets('renders a Flagcdn image for a country code', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CountryFlagBadge(countryCode: 'FR')),
      ),
    );

    expect(find.byType(CountryFlagBadge), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://flagcdn.com/w40/fr.png');
  });

  testWidgets('renders nothing for an invalid country code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CountryFlagBadge(countryCode: 'not-a-country')),
      ),
    );

    expect(find.byType(Text), findsNothing);
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
