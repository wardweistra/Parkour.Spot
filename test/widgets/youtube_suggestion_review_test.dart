import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/widgets/youtube_suggestion_review.dart';

void main() {
  testWidgets('shows thumbnail outcomes for newly suggested videos', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: YoutubeSuggestionReview(
              existingVideoIds: const ['alreadyOnSpot'],
              suggestedVideoIds: const ['dQw4w9WgXcQ', 'alreadyOnSpot'],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Videos to add'), findsOneWidget);
    expect(find.text('Already on this spot'), findsOneWidget);
    expect(
      find.text(
        'Accepting adds the YouTube link to this spot and adds the video thumbnail to its photos.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Adds video link and spot thumbnail'),
      findsOneWidget,
    );
    expect(find.text('Open on YouTube'), findsOneWidget);
    expect(find.text('dQw4w9WgXcQ'), findsOneWidget);
  });
}
