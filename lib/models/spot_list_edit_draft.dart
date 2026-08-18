import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'spot_list.dart';

/// One row in the flattened list editor: a section header or a spot entry.
class SpotListLayoutItem {
  const SpotListLayoutItem.header(this.sectionId) : entry = null;

  const SpotListLayoutItem.spot(this.entry) : sectionId = null;

  final String? sectionId;
  final SpotListEntry? entry;

  bool get isHeader => sectionId != null;
}

/// In-memory draft of list metadata and section organization.
///
/// Empty sections are kept while editing and dropped in [sectionsForSave].
class SpotListEditDraft {
  SpotListEditDraft._({
    required this.name,
    required this.description,
    required this.moreInfoUrl,
    required this.visibility,
    required this.sections,
    required String originalName,
    required String originalDescription,
    required String originalMoreInfoUrl,
    required SpotListVisibility originalVisibility,
    required List<SpotListSection> originalSections,
  }) : _originalName = originalName,
       _originalDescription = originalDescription,
       _originalMoreInfoUrl = originalMoreInfoUrl,
       _originalVisibility = originalVisibility,
       _originalSections = originalSections;

  factory SpotListEditDraft.fromList(SpotList list) {
    final sections = _cloneOrWrap(list);
    return SpotListEditDraft._(
      name: list.name,
      description: list.description ?? '',
      moreInfoUrl: list.moreInfoUrl ?? '',
      visibility: list.visibility,
      sections: sections,
      originalName: list.name,
      originalDescription: list.description ?? '',
      originalMoreInfoUrl: list.moreInfoUrl ?? '',
      originalVisibility: list.visibility,
      originalSections: _deepCopySections(sections),
    );
  }

  String name;
  String description;
  String moreInfoUrl;
  SpotListVisibility visibility;
  List<SpotListSection> sections;

  final String _originalName;
  final String _originalDescription;
  final String _originalMoreInfoUrl;
  final SpotListVisibility _originalVisibility;
  final List<SpotListSection> _originalSections;

  bool get isDirty {
    if (name.trim() != _originalName.trim()) return true;
    if (description.trim() != _originalDescription.trim()) return true;
    if (moreInfoUrl.trim() != _originalMoreInfoUrl.trim()) return true;
    if (visibility != _originalVisibility) return true;
    return jsonEncode(sections.map((s) => s.toMap()).toList()) !=
        jsonEncode(_originalSections.map((s) => s.toMap()).toList());
  }

  /// Unique spot IDs in section order. Same membership the map should show.
  List<String> get effectiveSpotIds {
    final seen = <String>{};
    final result = <String>[];
    for (final section in sections) {
      for (final entry in section.entries) {
        if (entry.spotId.isNotEmpty && seen.add(entry.spotId)) {
          result.add(entry.spotId);
        }
      }
    }
    return result;
  }

  /// Non-empty sections only; used when persisting.
  List<SpotListSection> get sectionsForSave =>
      sections.where((s) => s.entries.isNotEmpty).toList();

  bool get isSingleSection => sections.length == 1;

  /// One untitled section with no intro text: treat the editor as a flat list.
  bool get isPlainList {
    if (!isSingleSection) return false;
    final section = sections.first;
    final title = section.title?.trim() ?? '';
    final text = section.text?.trim() ?? '';
    return title.isEmpty && text.isEmpty;
  }

  void reorderSections(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = sections.removeAt(oldIndex);
    sections.insert(newIndex, item);
  }

  void reorderEntries(int sectionIndex, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final section = sections[sectionIndex];
    final entries = List<SpotListEntry>.from(section.entries);
    final item = entries.removeAt(oldIndex);
    entries.insert(newIndex, item);
    sections[sectionIndex] = _copySection(section, entries: entries);
  }

  String addSection() {
    final id = const Uuid().v4();
    sections.add(SpotListSection(id: id, entries: []));
    return id;
  }

  void deleteSection(int index) {
    if (sections.length <= 1) return;
    if (index < 0 || index >= sections.length) return;
    sections.removeAt(index);
  }

  void updateSection(int index, {String? title, String? text}) {
    final section = sections[index];
    sections[index] = SpotListSection(
      id: section.id,
      title: title != null
          ? (title.trim().isEmpty ? null : title.trim())
          : section.title,
      text: text != null
          ? (text.trim().isEmpty ? null : text.trim())
          : section.text,
      entries: section.entries,
    );
  }

  void addEntries(int sectionIndex, Iterable<String> spotIds) {
    final section = sections[sectionIndex];
    final entries = List<SpotListEntry>.from(section.entries);
    for (final id in spotIds) {
      if (id.isEmpty) continue;
      entries.add(SpotListEntry(spotId: id));
    }
    sections[sectionIndex] = _copySection(section, entries: entries);
  }

  void removeEntry(int sectionIndex, int entryIndex) {
    final section = sections[sectionIndex];
    final entries = List<SpotListEntry>.from(section.entries)
      ..removeAt(entryIndex);
    sections[sectionIndex] = _copySection(section, entries: entries);
  }

  void updateEntryNote(int sectionIndex, int entryIndex, String? note) {
    final section = sections[sectionIndex];
    final entries = List<SpotListEntry>.from(section.entries);
    final current = entries[entryIndex];
    final trimmed = note?.trim();
    entries[entryIndex] = SpotListEntry(
      spotId: current.spotId,
      note: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
    sections[sectionIndex] = _copySection(section, entries: entries);
  }

  void moveEntry(int fromSectionIndex, int entryIndex, int toSectionIndex) {
    if (fromSectionIndex == toSectionIndex) return;
    final fromSection = sections[fromSectionIndex];
    final toSection = sections[toSectionIndex];
    final entry = fromSection.entries[entryIndex];
    final newFromEntries = List<SpotListEntry>.from(fromSection.entries)
      ..removeAt(entryIndex);
    final newToEntries = List<SpotListEntry>.from(toSection.entries)
      ..add(entry);

    sections[fromSectionIndex] = _copySection(
      fromSection,
      entries: newFromEntries,
    );
    sections[toSectionIndex] = _copySection(toSection, entries: newToEntries);
  }

  /// Moves [fromId] so it sits immediately before [beforeId].
  void moveSectionBefore(String fromId, String beforeId) {
    final from = sections.indexWhere((s) => s.id == fromId);
    final to = sections.indexWhere((s) => s.id == beforeId);
    if (from < 0 || to < 0 || from == to) return;
    final section = sections.removeAt(from);
    var dest = to;
    if (from < to) dest -= 1;
    sections.insert(dest.clamp(0, sections.length), section);
  }

  /// Moves [fromId] to the end of the section list.
  void moveSectionToEnd(String fromId) {
    final from = sections.indexWhere((s) => s.id == fromId);
    if (from < 0 || from == sections.length - 1) return;
    final section = sections.removeAt(from);
    sections.add(section);
  }

  /// Rebuilds [sections] from a flattened editor layout: headers then spots.
  /// Spots are assigned to the nearest preceding header.
  void applyFlattenedLayout(List<SpotListLayoutItem> items) {
    final byId = {for (final section in sections) section.id: section};
    final order = <String>[];
    final entriesById = {
      for (final section in sections) section.id: <SpotListEntry>[],
    };
    String? currentId;
    final orphans = <SpotListEntry>[];

    for (final item in items) {
      if (item.isHeader) {
        final id = item.sectionId!;
        if (!byId.containsKey(id)) continue;
        if (!order.contains(id)) order.add(id);
        currentId = id;
      } else if (item.entry != null) {
        if (currentId != null) {
          entriesById[currentId]!.add(item.entry!);
        } else {
          orphans.add(item.entry!);
        }
      }
    }

    if (orphans.isNotEmpty) {
      if (order.isEmpty && sections.isNotEmpty) {
        order.add(sections.first.id);
      }
      if (order.isNotEmpty) {
        entriesById[order.first]!.insertAll(0, orphans);
      }
    }

    for (final section in sections) {
      if (!order.contains(section.id)) order.add(section.id);
    }

    sections = [
      for (final id in order)
        SpotListSection(
          id: id,
          title: byId[id]!.title,
          text: byId[id]!.text,
          entries: entriesById[id] ?? [],
        ),
    ];
  }

  static SpotListSection _copySection(
    SpotListSection section, {
    List<SpotListEntry>? entries,
  }) {
    return SpotListSection(
      id: section.id,
      title: section.title,
      text: section.text,
      entries: entries ?? section.entries,
    );
  }

  static List<SpotListSection> _cloneOrWrap(SpotList list) {
    if (list.sections != null && list.sections!.isNotEmpty) {
      return _deepCopySections(list.sections!);
    }
    return [
      SpotListSection(
        id: const Uuid().v4(),
        entries: list.spotIds.map((id) => SpotListEntry(spotId: id)).toList(),
      ),
    ];
  }

  static List<SpotListSection> _deepCopySections(List<SpotListSection> source) {
    return source
        .map(
          (s) => SpotListSection(
            id: s.id,
            title: s.title,
            text: s.text,
            entries: s.entries
                .map((e) => SpotListEntry(spotId: e.spotId, note: e.note))
                .toList(),
          ),
        )
        .toList();
  }
}
