import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/models/spot_list.dart';
import 'package:parkour_spot/models/spot_list_edit_draft.dart';

SpotList buildList({
  String name = 'Session',
  String? description,
  String? moreInfoUrl,
  List<String> spotIds = const ['s1', 's2'],
  List<SpotListSection>? sections,
  SpotListVisibility visibility = SpotListVisibility.unlisted,
}) {
  return SpotList(
    id: 'list-1',
    name: name,
    description: description,
    moreInfoUrl: moreInfoUrl,
    spotIds: spotIds,
    sections: sections,
    visibility: visibility,
    createdBy: 'user-1',
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
  );
}

void main() {
  group('SpotListEditDraft', () {
    test('is not dirty until a field changes', () {
      final draft = SpotListEditDraft.fromList(
        buildList(description: 'A loop'),
      );

      expect(draft.isDirty, isFalse);

      draft.name = 'Session';
      expect(draft.isDirty, isFalse);

      draft.name = 'Night session';
      expect(draft.isDirty, isTrue);
    });

    test('wraps legacy spotIds in one section', () {
      final draft = SpotListEditDraft.fromList(
        buildList(spotIds: const ['a', 'b', 'c']),
      );

      expect(draft.sections, hasLength(1));
      expect(draft.sections.first.entries.map((e) => e.spotId), [
        'a',
        'b',
        'c',
      ]);
    });

    test('clones existing sections', () {
      final draft = SpotListEditDraft.fromList(
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              title: 'Warmup',
              entries: [SpotListEntry(spotId: 's1', note: 'rail')],
            ),
          ],
        ),
      );

      expect(draft.sections.single.title, 'Warmup');
      expect(draft.sections.single.entries.single.note, 'rail');

      draft.updateEntryNote(0, 0, 'updated');
      expect(draft.isDirty, isTrue);
      expect(draft.sections.single.entries.single.note, 'updated');
    });

    test('sectionsForSave drops empty sections', () {
      final draft = SpotListEditDraft.fromList(
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              entries: [SpotListEntry(spotId: 's1')],
            ),
            SpotListSection(id: 'sec-2', title: 'Empty', entries: []),
          ],
        ),
      );

      expect(draft.sections, hasLength(2));
      expect(draft.sectionsForSave, hasLength(1));
      expect(draft.sectionsForSave.single.id, 'sec-1');
    });

    test('effectiveSpotIds drop a removed spot', () {
      final draft = SpotListEditDraft.fromList(
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              entries: [
                SpotListEntry(spotId: 's1'),
                SpotListEntry(spotId: 's2'),
              ],
            ),
          ],
        ),
      );

      expect(draft.effectiveSpotIds, ['s1', 's2']);
      draft.removeEntry(0, 0);
      expect(draft.effectiveSpotIds, ['s2']);
    });

    test('reorders spots and sections', () {
      final draft = SpotListEditDraft.fromList(
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              entries: [
                SpotListEntry(spotId: 's1'),
                SpotListEntry(spotId: 's2'),
              ],
            ),
            SpotListSection(
              id: 'sec-2',
              entries: [SpotListEntry(spotId: 's3')],
            ),
          ],
        ),
      );

      draft.reorderEntries(0, 0, 2);
      expect(draft.sections.first.entries.map((e) => e.spotId), ['s2', 's1']);

      draft.reorderSections(0, 2);
      expect(draft.sections.map((s) => s.id), ['sec-2', 'sec-1']);
    });

    test('moves an entry to another section', () {
      final draft = SpotListEditDraft.fromList(
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              entries: [SpotListEntry(spotId: 's1')],
            ),
            SpotListSection(
              id: 'sec-2',
              entries: [SpotListEntry(spotId: 's2')],
            ),
          ],
        ),
      );

      draft.moveEntry(0, 0, 1);
      expect(draft.sections[0].entries, isEmpty);
      expect(draft.sections[1].entries.map((e) => e.spotId), ['s2', 's1']);
    });

    test('applyFlattenedLayout moves a spot into another section', () {
      final draft = SpotListEditDraft.fromList(
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              title: 'Warmup',
              entries: [
                SpotListEntry(spotId: 's1'),
                SpotListEntry(spotId: 's2'),
              ],
            ),
            SpotListSection(
              id: 'sec-2',
              title: 'Lines',
              entries: [SpotListEntry(spotId: 's3')],
            ),
          ],
        ),
      );

      draft.applyFlattenedLayout([
        const SpotListLayoutItem.header('sec-1'),
        SpotListLayoutItem.spot(SpotListEntry(spotId: 's2')),
        const SpotListLayoutItem.header('sec-2'),
        SpotListLayoutItem.spot(SpotListEntry(spotId: 's3')),
        SpotListLayoutItem.spot(SpotListEntry(spotId: 's1')),
      ]);

      expect(draft.sections.map((s) => s.id), ['sec-1', 'sec-2']);
      expect(draft.sections[0].title, 'Warmup');
      expect(draft.sections[0].entries.map((e) => e.spotId), ['s2']);
      expect(draft.sections[1].entries.map((e) => e.spotId), ['s3', 's1']);
    });

    test('applyFlattenedLayout can drop a spot into an empty section', () {
      final draft = SpotListEditDraft.fromList(
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              entries: [SpotListEntry(spotId: 's1')],
            ),
            SpotListSection(id: 'sec-2', title: 'Empty', entries: []),
          ],
        ),
      );

      draft.applyFlattenedLayout([
        const SpotListLayoutItem.header('sec-1'),
        const SpotListLayoutItem.header('sec-2'),
        SpotListLayoutItem.spot(SpotListEntry(spotId: 's1')),
      ]);

      expect(draft.sections[0].entries, isEmpty);
      expect(draft.sections[1].entries.map((e) => e.spotId), ['s1']);
    });

    test('moveSectionBefore inserts a section as a whole block', () {
      final draft = SpotListEditDraft.fromList(
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              entries: [SpotListEntry(spotId: 's1')],
            ),
            SpotListSection(
              id: 'sec-2',
              entries: [SpotListEntry(spotId: 's2')],
            ),
            SpotListSection(
              id: 'sec-3',
              entries: [SpotListEntry(spotId: 's3')],
            ),
          ],
        ),
      );

      draft.moveSectionBefore('sec-3', 'sec-1');
      expect(draft.sections.map((s) => s.id), ['sec-3', 'sec-1', 'sec-2']);
      expect(draft.sections.first.entries.single.spotId, 's3');

      draft.moveSectionToEnd('sec-3');
      expect(draft.sections.map((s) => s.id), ['sec-1', 'sec-2', 'sec-3']);
    });

    test('clearing a note is dirty', () {
      final draft = SpotListEditDraft.fromList(
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              entries: [SpotListEntry(spotId: 's1', note: 'keep')],
            ),
          ],
        ),
      );

      draft.updateEntryNote(0, 0, '  ');
      expect(draft.sections.single.entries.single.note, isNull);
      expect(draft.isDirty, isTrue);
    });

    test('addEntries appends spots, allows duplicates, and marks dirty', () {
      final draft = SpotListEditDraft.fromList(
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              entries: [
                SpotListEntry(spotId: 's1'),
                SpotListEntry(spotId: 's2'),
              ],
            ),
          ],
        ),
      );

      expect(draft.isDirty, isFalse);
      draft.addEntries(0, ['s3', 's1', '']);
      expect(draft.sections.single.entries.map((e) => e.spotId), [
        's1',
        's2',
        's3',
        's1',
      ]);
      expect(draft.effectiveSpotIds, ['s1', 's2', 's3']);
      expect(draft.isDirty, isTrue);
    });

    test('plain list is a single untitled section', () {
      final plain = SpotListEditDraft.fromList(
        buildList(spotIds: const ['a', 'b']),
      );
      expect(plain.isSingleSection, isTrue);
      expect(plain.isPlainList, isTrue);

      final named = SpotListEditDraft.fromList(
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              title: 'Warmup',
              entries: [SpotListEntry(spotId: 's1')],
            ),
          ],
        ),
      );
      expect(named.isSingleSection, isTrue);
      expect(named.isPlainList, isFalse);

      named.addSection();
      expect(named.isSingleSection, isFalse);
      expect(named.isPlainList, isFalse);
    });

    test('deleteSection refuses to drop the last section', () {
      final draft = SpotListEditDraft.fromList(
        buildList(
          sections: [
            SpotListSection(
              id: 'sec-1',
              entries: [SpotListEntry(spotId: 's1')],
            ),
            SpotListSection(
              id: 'sec-2',
              entries: [SpotListEntry(spotId: 's2')],
            ),
          ],
        ),
      );

      draft.deleteSection(1);
      expect(draft.sections, hasLength(1));
      expect(draft.sections.single.id, 'sec-1');

      draft.deleteSection(0);
      expect(draft.sections, hasLength(1));
      expect(draft.sections.single.id, 'sec-1');
    });
  });
}
