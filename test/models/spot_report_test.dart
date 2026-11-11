import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot_report.dart';

SpotReport _report({
  List<String>? suggestedYoutubeVideoIds,
}) {
  return SpotReport(
    id: 'r1',
    spotId: 's1',
    spotName: 'Test',
    categories: const ['Edit suggestion'],
    status: 'New',
    suggestedYoutubeVideoIds: suggestedYoutubeVideoIds,
  );
}

void main() {
  group('SpotReport.hasEditSuggestions', () {
    test('is true when YouTube video IDs are suggested', () {
      expect(
        _report(suggestedYoutubeVideoIds: const ['dQw4w9WgXcQ']).hasEditSuggestions,
        isTrue,
      );
    });

    test('is false when suggested YouTube list is empty', () {
      expect(_report(suggestedYoutubeVideoIds: const []).hasEditSuggestions, isFalse);
    });
  });
}
