import 'package:cloud_firestore/cloud_firestore.dart';

/// A single spot entry within a section. Same spotId can appear multiple times.
class SpotListEntry {
  final String spotId;
  final String? note;

  SpotListEntry({required this.spotId, this.note});

  factory SpotListEntry.fromMap(Map<String, dynamic> data) {
    return SpotListEntry(
      spotId: data['spotId'] as String? ?? '',
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'spotId': spotId,
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }

  SpotListEntry copyWith({String? spotId, String? note}) {
    return SpotListEntry(
      spotId: spotId ?? this.spotId,
      note: note ?? this.note,
    );
  }
}

/// A section within an advanced spot list.
class SpotListSection {
  final String id;
  final String? title;
  final String? text;
  final List<SpotListEntry> entries;

  SpotListSection({
    required this.id,
    this.title,
    this.text,
    List<SpotListEntry>? entries,
  }) : entries = entries ?? [];

  factory SpotListSection.fromMap(Map<String, dynamic> data) {
    final entriesList = data['entries'];
    return SpotListSection(
      id: data['id'] as String? ?? '',
      title: data['title'] as String?,
      text: data['text'] as String?,
      entries: entriesList is List
          ? (entriesList)
                .map(
                  (e) => SpotListEntry.fromMap(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList()
          : [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (title != null && title!.isNotEmpty) 'title': title,
      if (text != null && text!.isNotEmpty) 'text': text,
      'entries': entries.map((e) => e.toMap()).toList(),
    };
  }

  SpotListSection copyWith({
    String? id,
    String? title,
    String? text,
    List<SpotListEntry>? entries,
  }) {
    return SpotListSection(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? this.text,
      entries: entries ?? this.entries,
    );
  }
}

enum SpotListVisibility {
  public,
  unlisted,
  private;

  static SpotListVisibility fromString(String? value) {
    switch (value) {
      case 'public':
        return SpotListVisibility.public;
      case 'private':
        return SpotListVisibility.private;
      case 'unlisted':
      default:
        // Legacy lists without this field default to unlisted.
        return SpotListVisibility.unlisted;
    }
  }

  String get firestoreValue {
    switch (this) {
      case SpotListVisibility.public:
        return 'public';
      case SpotListVisibility.unlisted:
        return 'unlisted';
      case SpotListVisibility.private:
        return 'private';
    }
  }

  String get label {
    switch (this) {
      case SpotListVisibility.public:
        return 'Public';
      case SpotListVisibility.unlisted:
        return 'Unlisted';
      case SpotListVisibility.private:
        return 'Private';
    }
  }

  String get description {
    switch (this) {
      case SpotListVisibility.public:
        return 'Listed on your profile and visible to everyone';
      case SpotListVisibility.unlisted:
        return 'Visible with a direct link, but hidden from your profile';
      case SpotListVisibility.private:
        return 'Only visible to you';
    }
  }
}

class SpotList {
  final String? id;
  final String name;
  final String? description;

  /// Optional link (http/https) to a page with more about this list.
  final String? moreInfoUrl;
  final List<String> spotIds;
  final List<SpotListSection>? sections;
  final SpotListVisibility visibility;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  SpotList({
    this.id,
    required this.name,
    this.description,
    this.moreInfoUrl,
    required this.spotIds,
    this.sections,
    this.visibility = SpotListVisibility.unlisted,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// When sections exist and are non-empty, returns ordered unique spot IDs.
  /// Otherwise returns spotIds.
  List<String> get effectiveSpotIds {
    if (sections != null && sections!.isNotEmpty) {
      final seen = <String>{};
      final result = <String>[];
      for (final section in sections!) {
        for (final entry in section.entries) {
          if (entry.spotId.isNotEmpty && !seen.contains(entry.spotId)) {
            seen.add(entry.spotId);
            result.add(entry.spotId);
          }
        }
      }
      return result;
    }
    return spotIds;
  }

  /// True when this list uses advanced organization (sections).
  bool get hasAdvancedOrganization => sections != null && sections!.isNotEmpty;

  /// No sections, or exactly one untitled section with no intro text.
  static bool sectionsArePlain(List<SpotListSection>? sections) {
    if (sections == null || sections.isEmpty) return true;
    if (sections.length != 1) return false;
    final section = sections.first;
    final title = section.title?.trim() ?? '';
    final text = section.text?.trim() ?? '';
    return title.isEmpty && text.isEmpty;
  }

  bool get isPlainList => sectionsArePlain(sections);

  /// Named section or more than one section: the add-to-list sheet asks where.
  bool get needsSectionChoice => !isPlainList;

  factory SpotList.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final sectionsData = data['sections'];
    return SpotList(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      moreInfoUrl: data['moreInfoUrl'] as String?,
      spotIds: data['spotIds'] != null
          ? List<String>.from(data['spotIds'])
          : [],
      sections: sectionsData is List && sectionsData.isNotEmpty
          ? (sectionsData)
                .map(
                  (s) => SpotListSection.fromMap(
                    Map<String, dynamic>.from(s as Map),
                  ),
                )
                .toList()
          : null,
      visibility: SpotListVisibility.fromString(data['visibility'] as String?),
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      updatedAt: data['updatedAt']?.toDate() ?? DateTime.now(),
    );
  }

  factory SpotList.fromMap(Map<String, dynamic> data) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) {
        try {
          return DateTime.tryParse(v);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    final sectionsData = data['sections'];
    return SpotList(
      id: data['id'] as String?,
      name: (data['name'] ?? '') as String,
      description: data['description'] as String?,
      moreInfoUrl: data['moreInfoUrl'] as String?,
      spotIds: data['spotIds'] is List
          ? List<String>.from(data['spotIds'])
          : [],
      sections: sectionsData is List && sectionsData.isNotEmpty
          ? (sectionsData)
                .map(
                  (s) => SpotListSection.fromMap(
                    Map<String, dynamic>.from(s as Map),
                  ),
                )
                .toList()
          : null,
      visibility: SpotListVisibility.fromString(data['visibility'] as String?),
      createdBy: (data['createdBy'] ?? '') as String,
      createdAt: parseDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(data['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (moreInfoUrl != null && moreInfoUrl!.isNotEmpty)
        'moreInfoUrl': moreInfoUrl,
      'spotIds': spotIds,
      if (sections != null)
        'sections': sections!.map((s) => s.toMap()).toList(),
      'visibility': visibility.firestoreValue,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  SpotList copyWith({
    String? id,
    String? name,
    String? description,
    String? moreInfoUrl,
    List<String>? spotIds,
    List<SpotListSection>? sections,
    SpotListVisibility? visibility,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SpotList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      moreInfoUrl: moreInfoUrl ?? this.moreInfoUrl,
      spotIds: spotIds ?? this.spotIds,
      sections: sections ?? this.sections,
      visibility: visibility ?? this.visibility,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  int get spotCount => effectiveSpotIds.length;

  @override
  String toString() {
    return 'SpotList(id: $id, name: $name, visibility: ${visibility.label}, spotCount: $spotCount)';
  }
}
