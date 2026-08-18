import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/spot_list.dart';
import 'package:parkour_spot/widgets/spot_list_visibility_selector.dart';

void main() {
  testWidgets('keeps a stable height when switching visibility', (tester) async {
    var visibility = SpotListVisibility.public;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: StatefulBuilder(
                builder: (context, setState) {
                  return SpotListVisibilitySelector(
                    value: visibility,
                    onChanged: (value) => setState(() => visibility = value),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    final publicSize = tester.getSize(find.byType(SpotListVisibilitySelector));

    await tester.tap(find.text('Unlisted'));
    await tester.pump();
    expect(
      tester.getSize(find.byType(SpotListVisibilitySelector)),
      publicSize,
    );

    await tester.tap(find.text('Private'));
    await tester.pump();
    expect(
      tester.getSize(find.byType(SpotListVisibilitySelector)),
      publicSize,
    );
  });
}
