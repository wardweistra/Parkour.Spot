import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/widgets/brand_mark_icon.dart';
import 'package:parkour_spot/widgets/github_button.dart';
import 'package:parkour_spot/widgets/instagram_button.dart';

void main() {
  testWidgets('Instagram button uses the Instagram SVG mark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InstagramButton(
            handle: 'parkourdotspot',
            label: '@parkourdotspot',
          ),
        ),
      ),
    );

    expect(find.text('@parkourdotspot'), findsOneWidget);
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.bytesLoader, isA<SvgAssetLoader>());
    final loader = svg.bytesLoader as SvgAssetLoader;
    expect(loader.assetName, BrandMarkIcon.instagram);
  });

  testWidgets('GitHub button uses the GitHub SVG mark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GitHubButton(
            url: 'https://github.com/wardweistra/Parkour.Spot/',
            label: 'View source code',
          ),
        ),
      ),
    );

    expect(find.text('View source code'), findsOneWidget);
    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(svg.bytesLoader, isA<SvgAssetLoader>());
    final loader = svg.bytesLoader as SvgAssetLoader;
    expect(loader.assetName, BrandMarkIcon.github);
  });

  testWidgets('BrandMarkIcon tints the SVG with the given color', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BrandMarkIcon(
            asset: BrandMarkIcon.instagram,
            color: Color(0xFFE4405F),
            size: 24,
          ),
        ),
      ),
    );

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
      svg.colorFilter,
      const ColorFilter.mode(Color(0xFFE4405F), BlendMode.srcIn),
    );
    expect(svg.width, 24);
    expect(svg.height, 24);
  });
}
