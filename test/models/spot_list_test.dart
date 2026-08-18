import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot_list.dart';
import 'package:parkour_spot/models/spot_list_edit_draft.dart';

SpotList buildList({
  String id = 'list-1',
  String name = 'Session',
  List<String> spotIds = const ['s1'],
  List<SpotListSection>? sections,
}) {
  return SpotList(
    id: id,
    name: name,
    spotIds: spotIds,
    sections: sections,
    createdBy: 'user-1',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
  );
}

void main() {
  group('SpotList.isPlainList', () {
    test('legacy lists without sections are plain', () {
      final list = buildList();
      expect(list.isPlainList, isTrue);
      expect(list.needsSectionChoice, isFalse);
    });

    test('one unnamed section is plain', () {
      final list = buildList(
        sections: [
          SpotListSection(
            id: 'sec-1',
            entries: [SpotListEntry(spotId: 's1')],
          ),
        ],
      );
      expect(list.isPlainList, isTrue);
      expect(list.needsSectionChoice, isFalse);
      expect(SpotListEditDraft.fromList(list).isPlainList, isTrue);
    });

    test('one named section needs a section choice', () {
      final list = buildList(
        sections: [
          SpotListSection(
            id: 'sec-1',
            title: 'Warmup',
            entries: [SpotListEntry(spotId: 's1')],
          ),
        ],
      );
      expect(list.isPlainList, isFalse);
      expect(list.needsSectionChoice, isTrue);
      expect(SpotListEditDraft.fromList(list).isPlainList, isFalse);
    });

    test('two sections need a section choice', () {
      final list = buildList(
        sections: [
          SpotListSection(
            id: 'sec-1',
            entries: [SpotListEntry(spotId: 's1')],
          ),
          SpotListSection(
            id: 'sec-2',
            title: 'Lines',
            entries: [SpotListEntry(spotId: 's2')],
          ),
        ],
      );
      expect(list.isPlainList, isFalse);
      expect(list.needsSectionChoice, isTrue);
      expect(SpotListEditDraft.fromList(list).isPlainList, isFalse);
    });
  });
}
