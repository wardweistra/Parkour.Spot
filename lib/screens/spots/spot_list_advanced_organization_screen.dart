import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/spot.dart';
import '../../models/spot_list.dart';
import '../../services/spot_list_service.dart';
import '../../services/spot_service.dart';
import '../../services/snackbar_service.dart';

/// Full-screen advanced organization: sections, reorder, add text to sections and spots.
class SpotListAdvancedOrganizationScreen extends StatefulWidget {
  final String listName;
  final String listId;
  final SpotList list;

  const SpotListAdvancedOrganizationScreen({
    super.key,
    required this.listName,
    required this.listId,
    required this.list,
  });

  @override
  State<SpotListAdvancedOrganizationScreen> createState() =>
      _SpotListAdvancedOrganizationScreenState();
}

class _SpotListAdvancedOrganizationScreenState
    extends State<SpotListAdvancedOrganizationScreen> {
  late List<SpotListSection> _sections;
  Map<String, Spot> _spotCache = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _sections = widget.list.sections != null && widget.list.sections!.isNotEmpty
        ? widget.list.sections!
            .map((s) => SpotListSection(
                  id: s.id,
                  title: s.title,
                  text: s.text,
                  entries: s.entries.map((e) => SpotListEntry(spotId: e.spotId, note: e.note)).toList(),
                ))
            .toList()
        : [
            SpotListSection(
              id: const Uuid().v4(),
              entries: widget.list.spotIds.map((id) => SpotListEntry(spotId: id)).toList(),
            )
          ];
    _loadSpotCache();
  }

  Future<void> _loadSpotCache() async {
    final ids = <String>{};
    for (final s in _sections) {
      for (final e in s.entries) {
        if (e.spotId.isNotEmpty) ids.add(e.spotId);
      }
    }
    if (ids.isEmpty) return;
    final spotService = Provider.of<SpotService>(context, listen: false);
    final cache = <String, Spot>{};
    for (final id in ids) {
      final spot = await spotService.getSpotById(id);
      if (spot != null) cache[id] = spot;
    }
    if (mounted) setState(() => _spotCache = cache);
  }

  Future<bool> _save() async {
    if (_sections.isEmpty) {
      SnackbarService.showError('Add at least one section');
      return false;
    }
    // Ensure no empty sections when we have multiple
    final nonEmpty = _sections.where((s) => s.entries.isNotEmpty).toList();
    if (nonEmpty.isEmpty) {
      SnackbarService.showError('Add at least one spot to a section');
      return false;
    }
    setState(() => _isSaving = true);
    final spotListService = Provider.of<SpotListService>(context, listen: false);
    final success =
        await spotListService.updateSpotListOrganization(widget.listId, nonEmpty);
    if (!mounted) return success;
    setState(() => _isSaving = false);
    if (success) {
      SnackbarService.showSuccess('List updated');
    } else {
      SnackbarService.showError(
          spotListService.error ?? 'Failed to update list');
    }
    return success;
  }

  void _reorderSections(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final item = _sections.removeAt(oldIndex);
      _sections.insert(newIndex, item);
    });
  }

  void _addSection() {
    setState(() {
      _sections.add(SpotListSection(id: const Uuid().v4(), entries: []));
    });
  }

  void _deleteSection(int index) {
    setState(() => _sections.removeAt(index));
  }

  void _updateSection(int index, {String? title, String? text}) {
    setState(() {
      final s = _sections[index];
      _sections[index] = s.copyWith(
        title: title ?? s.title,
        text: text ?? s.text,
      );
    });
  }

  void _reorderEntries(int sectionIndex, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    setState(() {
      final section = _sections[sectionIndex];
      final entries = List<SpotListEntry>.from(section.entries);
      final item = entries.removeAt(oldIndex);
      entries.insert(newIndex, item);
      _sections[sectionIndex] = section.copyWith(entries: entries);
    });
  }

  Future<void> _removeEntryAt(int sectionIndex, int entryIndex) async {
    setState(() {
      final section = _sections[sectionIndex];
      final entries = List<SpotListEntry>.from(section.entries)..removeAt(entryIndex);
      if (entries.isEmpty) {
        _sections.removeAt(sectionIndex);
      } else {
        _sections[sectionIndex] = section.copyWith(entries: entries);
      }
    });
  }

  void _updateEntryNote(int sectionIndex, int entryIndex, String? note) {
    setState(() {
      final section = _sections[sectionIndex];
      final entries = List<SpotListEntry>.from(section.entries);
      final current = entries[entryIndex];
      final newNote = note?.trim().isEmpty == true ? null : note;
      entries[entryIndex] = newNote == null
          ? SpotListEntry(spotId: current.spotId)
          : current.copyWith(note: newNote);
      _sections[sectionIndex] = section.copyWith(entries: entries);
    });
  }

  Future<void> _showEditSectionDialog(int index) async {
    final section = _sections[index];
    final titleController = TextEditingController(text: section.title ?? '');
    final textController = TextEditingController(text: section.text ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit section'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Section title (optional)',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Section text (optional)',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      _updateSection(index,
          title: titleController.text.trim().isEmpty ? null : titleController.text.trim(),
          text: textController.text.trim().isEmpty ? null : textController.text.trim());
    }
  }

  void _moveEntryToSection(int fromSectionIndex, int entryIndex, int toSectionIndex) {
    if (fromSectionIndex == toSectionIndex) return;
    setState(() {
      final fromSection = _sections[fromSectionIndex];
      final toSection = _sections[toSectionIndex];
      final entry = fromSection.entries[entryIndex];
      final newFromEntries = List<SpotListEntry>.from(fromSection.entries)..removeAt(entryIndex);
      final newToEntries = List<SpotListEntry>.from(toSection.entries)..add(entry);

      _sections[fromSectionIndex] = fromSection.copyWith(entries: newFromEntries);
      var actualToIndex = toSectionIndex;
      if (newFromEntries.isEmpty) {
        _sections.removeAt(fromSectionIndex);
        if (fromSectionIndex < toSectionIndex) actualToIndex = toSectionIndex - 1;
      }
      _sections[actualToIndex] = toSection.copyWith(entries: newToEntries);
    });
  }

  Future<void> _showMoveToSectionDialog(int fromSectionIndex, int entryIndex) async {
    if (_sections.length < 2) return;
    final entry = _sections[fromSectionIndex].entries[entryIndex];
    final spot = _spotCache[entry.spotId];

    final toIndex = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Move "${spot?.name ?? entry.spotId}" to section'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _sections.length,
            itemBuilder: (context, i) {
              if (i == fromSectionIndex) return const SizedBox.shrink();
              final s = _sections[i];
              final title = s.title?.trim().isEmpty != false
                  ? 'Section ${i + 1}'
                  : s.title!;
              final count = s.entries.length;
              return ListTile(
                title: Text(title),
                subtitle: Text('$count spot${count == 1 ? '' : 's'}'),
                onTap: () => Navigator.pop(context, i),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (toIndex != null && mounted) {
      _moveEntryToSection(fromSectionIndex, entryIndex, toIndex);
    }
  }

  Future<void> _showEditNoteDialog(int sectionIndex, int entryIndex) async {
    final entry = _sections[sectionIndex].entries[entryIndex];
    final controller = TextEditingController(text: entry.note ?? '');
    final hasNote = entry.note != null && entry.note!.trim().isNotEmpty;
    final result = await showDialog<Object>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit note'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Note for this spot',
          ),
          maxLines: 3,
        ),
        actions: [
          if (hasNote)
            TextButton(
              onPressed: () => Navigator.pop(context, 'remove'),
              child: Text(
                'Remove note',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == 'remove' && mounted) {
      _updateEntryNote(sectionIndex, entryIndex, null);
    } else if (result == true && mounted) {
      _updateEntryNote(sectionIndex, entryIndex,
          controller.text.trim().isEmpty ? null : controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Organize: ${widget.listName}'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: () async {
                final ok = await _save();
                if (ok && mounted) Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
        ],
      ),
      body: _sections.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.folder_open,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Add a section to get started',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add new spots from their spot page',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _addSection,
                      icon: const Icon(Icons.add),
                      label: const Text('Add section'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Add new spots from their spot page',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.all(16),
              itemCount: _sections.length + 1,
              onReorder: (oldIndex, newIndex) {
                if (newIndex == _sections.length) return;
                if (oldIndex == _sections.length) return;
                _reorderSections(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                if (index == _sections.length) {
                  return Padding(
                    key: const ValueKey('add_section'),
                    padding: const EdgeInsets.only(bottom: 16),
                    child: OutlinedButton.icon(
                      onPressed: _addSection,
                      icon: const Icon(Icons.add),
                      label: const Text('Add section'),
                    ),
                  );
                }
                return _buildSectionCard(index, theme);
              },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionCard(int sectionIndex, ThemeData theme) {
    final section = _sections[sectionIndex];
    return Card(
      key: ValueKey(section.id),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          ListTile(
            leading: ReorderableDragStartListener(
              index: sectionIndex,
              child: Icon(Icons.drag_handle, color: theme.colorScheme.onSurfaceVariant),
            ),
            title: Text(
              section.title?.trim().isEmpty != false ? 'Section ${sectionIndex + 1}' : section.title!,
              style: theme.textTheme.titleMedium,
            ),
            subtitle: section.text != null && section.text!.trim().isNotEmpty
                ? Text(
                    section.text!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showEditSectionDialog(sectionIndex),
                  tooltip: 'Edit section',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteSection(sectionIndex),
                  tooltip: 'Delete section',
                  color: theme.colorScheme.error,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Entries
          section.entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No spots in this section',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Empty sections will be removed when you save',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: section.entries.length,
                  onReorder: (oldIndex, newIndex) =>
                      _reorderEntries(sectionIndex, oldIndex, newIndex),
                  itemBuilder: (context, entryIndex) {
                    final entry = section.entries[entryIndex];
                    final spot = _spotCache[entry.spotId];
                    return _buildEntryTile(sectionIndex, entryIndex, entry, spot, theme);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildEntryTile(
    int sectionIndex,
    int entryIndex,
    SpotListEntry entry,
    Spot? spot,
    ThemeData theme,
  ) {
    final section = _sections[sectionIndex];
    return ListTile(
      key: ValueKey('${section.id}_$entryIndex'),
      leading: ReorderableDragStartListener(
        index: entryIndex,
        child: Icon(Icons.drag_handle, color: theme.colorScheme.onSurfaceVariant),
      ),
      title: Text(
        spot?.name ?? entry.spotId,
        style: theme.textTheme.bodyLarge,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: entry.note != null && entry.note!.isNotEmpty
          ? Text('💬 ${entry.note!}', maxLines: 2, overflow: TextOverflow.ellipsis)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_sections.length > 1)
            IconButton(
              icon: const Icon(Icons.drive_file_move_outline),
              onPressed: () => _showMoveToSectionDialog(sectionIndex, entryIndex),
              tooltip: 'Move to section',
            ),
          if (entry.note != null && entry.note!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.note),
              onPressed: () => _showEditNoteDialog(sectionIndex, entryIndex),
              tooltip: 'Edit note',
            ),
          if (entry.note == null || entry.note!.isEmpty)
            IconButton(
              icon: const Icon(Icons.note_add),
              onPressed: () => _showEditNoteDialog(sectionIndex, entryIndex),
              tooltip: 'Add note',
            ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _removeEntryAt(sectionIndex, entryIndex),
            tooltip: 'Remove',
            color: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }
}
