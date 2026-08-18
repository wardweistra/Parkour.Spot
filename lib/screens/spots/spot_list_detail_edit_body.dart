import 'package:flutter/material.dart';

import '../../constants/spot_detail_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/spot.dart';
import '../../models/spot_list.dart';
import '../../models/spot_list_edit_draft.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/resized_spot_image.dart';
import '../../widgets/spot_list_edit_spot_row.dart';

Future<bool> confirmDiscardSpotListEdits(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.spotListEditDiscardTitle),
      content: Text(l10n.spotListEditDiscardMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.profileCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: Text(l10n.spotListEditDiscardAction),
        ),
      ],
    ),
  );
  return result == true;
}

class SpotListDetailEditBody extends StatefulWidget {
  final SpotListEditDraft draft;
  final Map<String, Spot> spotsById;
  final VoidCallback onChanged;

  const SpotListDetailEditBody({
    super.key,
    required this.draft,
    required this.spotsById,
    required this.onChanged,
  });

  @override
  State<SpotListDetailEditBody> createState() => _SpotListDetailEditBodyState();
}

class _SpotListDetailEditBodyState extends State<SpotListDetailEditBody> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _moreInfoUrlController;
  final Map<String, TextEditingController> _sectionTitleControllers = {};
  final Map<String, TextEditingController> _sectionTextControllers = {};
  final Map<String, TextEditingController> _noteControllers = {};
  final Map<String, GlobalKey> _sectionDragKeys = {};
  final Set<String> _expandedNotes = {};
  final Set<String> _editingSectionIds = {};
  String? _draggingSectionId;
  String? _dropBeforeSectionId;
  bool _dropAtEnd = false;
  double _listWidth = 320;
  EdgeDraggingAutoScroller? _autoScroller;

  static const double _sectionAutoScrollHotzone = 72;
  static const double _autoScrollVelocityScalar = 50;

  SpotListEditDraft get _draft => widget.draft;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _draft.name);
    _descriptionController = TextEditingController(text: _draft.description);
    _moreInfoUrlController = TextEditingController(text: _draft.moreInfoUrl);
    _syncSectionControllers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null) return;
    if (_autoScroller?.scrollable != scrollable) {
      _autoScroller?.stopAutoScroll();
      _autoScroller = EdgeDraggingAutoScroller(
        scrollable,
        velocityScalar: _autoScrollVelocityScalar,
      );
    }
  }

  @override
  void didUpdateWidget(covariant SpotListDetailEditBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSectionControllers();
  }

  @override
  void dispose() {
    _autoScroller?.stopAutoScroll();
    _nameController.dispose();
    _descriptionController.dispose();
    _moreInfoUrlController.dispose();
    for (final c in _sectionTitleControllers.values) {
      c.dispose();
    }
    for (final c in _sectionTextControllers.values) {
      c.dispose();
    }
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _notify() => widget.onChanged();

  void _syncSectionControllers() {
    final ids = _draft.sections.map((s) => s.id).toSet();
    _disposeMissing(_sectionTitleControllers, ids);
    _disposeMissing(_sectionTextControllers, ids);

    for (final section in _draft.sections) {
      _sectionTitleControllers.putIfAbsent(
        section.id,
        () => TextEditingController(text: section.title ?? ''),
      );
      _sectionTextControllers.putIfAbsent(
        section.id,
        () => TextEditingController(text: section.text ?? ''),
      );
      _sectionDragKeys.putIfAbsent(section.id, GlobalKey.new);
    }
    _sectionDragKeys.removeWhere((id, _) => !ids.contains(id));
    _editingSectionIds.removeWhere((id) => !ids.contains(id));
  }

  void _disposeMissing(
    Map<String, TextEditingController> controllers,
    Set<String> keepIds,
  ) {
    final removed = controllers.keys
        .where((id) => !keepIds.contains(id))
        .toList();
    for (final id in removed) {
      controllers.remove(id)?.dispose();
    }
  }

  String _noteKey(String sectionId, int entryIndex) => '$sectionId|$entryIndex';

  void _clearNoteUi() {
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    _noteControllers.clear();
    _expandedNotes.clear();
  }

  String _visibilityHelp(AppLocalizations l10n, SpotListVisibility visibility) {
    switch (visibility) {
      case SpotListVisibility.public:
        return l10n.spotListEditVisibilityPublicHelp;
      case SpotListVisibility.unlisted:
        return l10n.spotListEditVisibilityUnlistedHelp;
      case SpotListVisibility.private:
        return l10n.spotListEditVisibilityPrivateHelp;
    }
  }

  Future<void> _confirmRemoveEntry(
    int sectionIndex,
    int entryIndex,
    String displayName,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.spotListEditRemoveSpotTitle),
        content: Text(l10n.spotListEditRemoveSpotMessage(displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.profileCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.spotListEditRemoveSpotAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _draft.removeEntry(sectionIndex, entryIndex);
      _clearNoteUi();
    });
    _notify();
  }

  Future<void> _confirmDeleteSection(int index) async {
    final l10n = AppLocalizations.of(context)!;
    final hasSpots = _draft.sections[index].entries.isNotEmpty;
    if (hasSpots) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.spotListEditDeleteSectionTitle),
          content: Text(l10n.spotListEditDeleteSectionMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.profileCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(l10n.spotListEditRemoveSpotAction),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _draft.deleteSection(index);
      _clearNoteUi();
      _syncSectionControllers();
    });
    _notify();
  }

  List<_FlatItem> _flatten() {
    final items = <_FlatItem>[];
    for (var s = 0; s < _draft.sections.length; s++) {
      final section = _draft.sections[s];
      items.add(_FlatItem.header(s, section.id));
      if (section.entries.isEmpty) {
        items.add(_FlatItem.empty(s, section.id));
      } else {
        for (var e = 0; e < section.entries.length; e++) {
          items.add(_FlatItem.spot(s, section.id, e, section.entries[e]));
        }
      }
    }
    items.add(const _FlatItem.add());
    return items;
  }

  void _onReorder(int oldIndex, int newIndex) {
    final items = _flatten();
    if (oldIndex < 0 || oldIndex >= items.length) return;
    final dragged = items[oldIndex];
    if (dragged.kind != _FlatKind.spot) return;

    if (oldIndex < newIndex) newIndex -= 1;
    final item = items.removeAt(oldIndex);
    newIndex = newIndex.clamp(0, items.length);
    final addAt = items.indexWhere((i) => i.kind == _FlatKind.add);
    if (addAt >= 0 && newIndex > addAt) newIndex = addAt;
    items.insert(newIndex, item);

    setState(() {
      _draft.applyFlattenedLayout([
        for (final item in items)
          if (item.kind == _FlatKind.header)
            SpotListLayoutItem.header(item.sectionId)
          else if (item.kind == _FlatKind.spot)
            SpotListLayoutItem.spot(item.entry!),
      ]);
      _clearNoteUi();
      _syncSectionControllers();
    });
    _notify();
  }

  void _clearSectionDrag() {
    _autoScroller?.stopAutoScroll();
    if (_draggingSectionId == null &&
        _dropBeforeSectionId == null &&
        !_dropAtEnd) {
      return;
    }
    setState(() {
      _draggingSectionId = null;
      _dropBeforeSectionId = null;
      _dropAtEnd = false;
    });
  }

  void _updateSectionAutoScroll(Offset globalPosition) {
    _autoScroller?.startAutoScrollIfNecessary(
      Rect.fromCenter(
        center: globalPosition,
        width: 24,
        height: _sectionAutoScrollHotzone * 2,
      ),
    );
  }

  void _setDropBeforeSection(String sectionId) {
    if (_dropBeforeSectionId == sectionId && !_dropAtEnd) return;
    setState(() {
      _dropBeforeSectionId = sectionId;
      _dropAtEnd = false;
    });
  }

  void _setDropAtEnd() {
    if (_dropAtEnd && _dropBeforeSectionId == null) return;
    setState(() {
      _dropBeforeSectionId = null;
      _dropAtEnd = true;
    });
  }

  void _commitSectionMoveBefore(String fromId, String beforeId) {
    setState(() {
      _draft.moveSectionBefore(fromId, beforeId);
      _draggingSectionId = null;
      _dropBeforeSectionId = null;
      _dropAtEnd = false;
      _clearNoteUi();
      _syncSectionControllers();
    });
    _notify();
  }

  void _commitSectionMoveToEnd(String fromId) {
    setState(() {
      _draft.moveSectionToEnd(fromId);
      _draggingSectionId = null;
      _dropBeforeSectionId = null;
      _dropAtEnd = false;
      _clearNoteUi();
      _syncSectionControllers();
    });
    _notify();
  }

  Widget _sectionDropLine(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(2),
        ),
        child: const SizedBox(height: 3, width: double.infinity),
      ),
    );
  }

  Widget _withSectionDropTarget({
    required String sectionId,
    required bool showDropLine,
    required Widget child,
  }) {
    return DragTarget<_SectionDragData>(
      onWillAcceptWithDetails: (details) => details.data.sectionId != sectionId,
      onMove: (details) {
        if (details.data.sectionId == sectionId) return;
        _setDropBeforeSection(sectionId);
      },
      onAcceptWithDetails: (details) {
        _commitSectionMoveBefore(details.data.sectionId, sectionId);
      },
      builder: (context, _, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDropLine &&
                _dropBeforeSectionId == sectionId &&
                !_dropAtEnd)
              _sectionDropLine(Theme.of(context)),
            child,
          ],
        );
      },
    );
  }

  Widget _fadeIfDraggingSection(String sectionId, Widget child) {
    if (_draggingSectionId != sectionId) return child;
    return Opacity(opacity: 0.32, child: child);
  }

  void _toggleSectionEditing(String sectionId) {
    setState(() {
      if (!_editingSectionIds.add(sectionId)) {
        _editingSectionIds.remove(sectionId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final items = _flatten();

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Box constraints here match the padded reorderable list
                // width. Do not use SliverLayoutBuilder around that list:
                // sliver constraints change every scroll frame and would
                // rebuild every row while the page moves.
                _listWidth = constraints.maxWidth;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomTextField(
                      controller: _nameController,
                      labelText: l10n.spotDetailListNameLabel,
                      onChanged: (value) {
                        _draft.name = value;
                        _notify();
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _descriptionController,
                      labelText: l10n.spotDetailListDescriptionLabel,
                      maxLines: 3,
                      onChanged: (value) {
                        _draft.description = value;
                        _notify();
                      },
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      controller: _moreInfoUrlController,
                      labelText: l10n.spotListDetailMoreInfoLinkLabel,
                      hintText: l10n.spotListDetailMoreInfoLinkHint,
                      keyboardType: TextInputType.url,
                      onChanged: (value) {
                        _draft.moreInfoUrl = value;
                        _notify();
                      },
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.spotDetailVisibilityLabel,
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<SpotListVisibility>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: SpotListVisibility.public,
                          label: Text(l10n.spotListEditVisibilityPublic),
                        ),
                        ButtonSegment(
                          value: SpotListVisibility.unlisted,
                          label: Text(l10n.spotListEditVisibilityUnlisted),
                        ),
                        ButtonSegment(
                          value: SpotListVisibility.private,
                          label: Text(l10n.spotListEditVisibilityPrivate),
                        ),
                      ],
                      selected: {_draft.visibility},
                      onSelectionChanged: (selected) {
                        if (selected.isEmpty) return;
                        setState(() {
                          _draft.visibility = selected.first;
                        });
                        _notify();
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _visibilityHelp(l10n, _draft.visibility),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverReorderableList(
            itemCount: items.length,
            onReorder: _onReorder,
            autoScrollerVelocityScalar: _autoScrollVelocityScalar,
            itemBuilder: (context, index) {
              return _buildFlatItem(index, items[index], theme, l10n);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlatItem(
    int index,
    _FlatItem item,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    switch (item.kind) {
      case _FlatKind.add:
        return Padding(
          key: const ValueKey('add_section'),
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: DragTarget<_SectionDragData>(
            onWillAcceptWithDetails: (_) => true,
            onMove: (_) => _setDropAtEnd(),
            onAcceptWithDetails: (details) {
              _commitSectionMoveToEnd(details.data.sectionId);
            },
            builder: (context, _, __) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_dropAtEnd) _sectionDropLine(theme),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        final id = _draft.addSection();
                        _syncSectionControllers();
                        _editingSectionIds.add(id);
                      });
                      _notify();
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l10n.spotListEditAddSection),
                  ),
                ],
              );
            },
          ),
        );
      case _FlatKind.empty:
        return KeyedSubtree(
          key: ValueKey('empty-${item.sectionId}'),
          child: _withSectionDropTarget(
            sectionId: item.sectionId,
            showDropLine: false,
            child: _fadeIfDraggingSection(
              item.sectionId,
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.spotListEditNoSpotsInSection,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.spotListEditEmptySectionsRemovedOnSave,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      case _FlatKind.header:
        return _buildSectionHeader(item.sectionIndex, theme, l10n);
      case _FlatKind.spot:
        return _buildSpotRow(index, item, l10n);
    }
  }

  Widget _buildSectionHeader(
    int sectionIndex,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final section = _draft.sections[sectionIndex];
    final titleController = _sectionTitleControllers[section.id]!;
    final textController = _sectionTextControllers[section.id]!;
    final handle = _sectionHandle(theme, l10n);
    final editing = _editingSectionIds.contains(section.id);
    final title = titleController.text.trim();
    final body = textController.text.trim();
    final hasTitle = title.isNotEmpty;
    final hasText = body.isNotEmpty;

    return KeyedSubtree(
      key: ValueKey('header-${section.id}'),
      child: _withSectionDropTarget(
        sectionId: section.id,
        showDropLine: true,
        child: _fadeIfDraggingSection(
          section.id,
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Draggable<_SectionDragData>(
                  key: _sectionDragKeys[section.id],
                  data: _SectionDragData(section.id),
                  dragAnchorStrategy: childDragAnchorStrategy,
                  rootOverlay: true,
                  onDragStarted: () {
                    setState(() {
                      _draggingSectionId = section.id;
                      _dropBeforeSectionId = null;
                      _dropAtEnd = false;
                    });
                  },
                  onDragUpdate: (details) {
                    _updateSectionAutoScroll(details.globalPosition);
                  },
                  onDragEnd: (_) => _clearSectionDrag(),
                  feedback: _buildSectionDragFeedback(section, theme, l10n),
                  childWhenDragging: Opacity(opacity: 0.35, child: handle),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: handle,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: editing
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: titleController,
                                autofocus: true,
                                style: theme.textTheme.titleLarge,
                                decoration: InputDecoration(
                                  hintText: l10n.spotListEditSectionTitleLabel,
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (value) {
                                  _draft.updateSection(
                                    sectionIndex,
                                    title: value,
                                  );
                                  _notify();
                                },
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: textController,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                                maxLines: 3,
                                minLines: 1,
                                decoration: InputDecoration(
                                  hintText: l10n.spotListEditSectionTextLabel,
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (value) {
                                  _draft.updateSection(
                                    sectionIndex,
                                    text: value,
                                  );
                                  _notify();
                                },
                              ),
                            ],
                          )
                        : InkWell(
                            onTap: () => _toggleSectionEditing(section.id),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasTitle)
                                  Text(
                                    title,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                if (hasTitle && hasText)
                                  const SizedBox(height: 10),
                                if (hasText)
                                  Text(
                                    body,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.8),
                                    ),
                                  ),
                                if (!hasTitle && !hasText)
                                  Text(
                                    l10n.spotListEditAddSectionTitle,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
                IconButton(
                  icon: Icon(editing ? Icons.check : Icons.edit_outlined),
                  tooltip: editing
                      ? l10n.spotListEditDoneSectionTooltip
                      : l10n.spotListEditEditSectionTooltip,
                  onPressed: () => _toggleSectionEditing(section.id),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.spotListEditDeleteSectionTooltip,
                  color: theme.colorScheme.error,
                  onPressed: () => _confirmDeleteSection(sectionIndex),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHandle(ThemeData theme, AppLocalizations l10n) {
    return Semantics(
      label: l10n.spotListEditDragHandleTooltip,
      child: Padding(
        padding: const EdgeInsets.only(top: 12, right: 8),
        child: Icon(
          Icons.drag_handle,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildSectionDragFeedback(
    SpotListSection section,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final title = _sectionTitleControllers[section.id]?.text.trim() ?? '';
    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerLow,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _listWidth,
          minWidth: _listWidth,
          maxHeight: 320,
        ),
        child: IgnorePointer(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.isEmpty ? l10n.spotListEditSectionTitleLabel : title,
                  style: theme.textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (section.entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      l10n.spotListEditNoSpotsInSection,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in section.entries.take(5))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SectionDragSpotPreview(
                              spot: widget.spotsById[entry.spotId],
                              spotId: entry.spotId,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpotRow(int flatIndex, _FlatItem item, AppLocalizations l10n) {
    final section = _draft.sections[item.sectionIndex];
    final entryIndex = item.entryIndex!;
    final entry = section.entries[entryIndex];
    final spot = widget.spotsById[entry.spotId];
    final noteKey = _noteKey(section.id, entryIndex);
    final expanded = _expandedNotes.contains(noteKey);
    final noteController = _noteControllers[noteKey];

    return KeyedSubtree(
      key: ValueKey('${section.id}_${entry.spotId}_$entryIndex'),
      child: _withSectionDropTarget(
        sectionId: section.id,
        showDropLine: false,
        child: _fadeIfDraggingSection(
          section.id,
          SpotListEditSpotRow(
            spot: spot,
            spotId: entry.spotId,
            note: entry.note,
            noteExpanded: expanded,
            noteController: noteController,
            dragIndex: flatIndex,
            onToggleNote: () {
              setState(() {
                if (expanded) {
                  _expandedNotes.remove(noteKey);
                } else {
                  _expandedNotes.add(noteKey);
                  _noteControllers.putIfAbsent(
                    noteKey,
                    () => TextEditingController(text: entry.note ?? ''),
                  );
                }
              });
            },
            onNoteChanged: (value) {
              _draft.updateEntryNote(item.sectionIndex, entryIndex, value);
              _notify();
            },
            onRemoveNote: () {
              _noteControllers[noteKey]?.clear();
              setState(() {
                _draft.updateEntryNote(item.sectionIndex, entryIndex, '');
                _expandedNotes.remove(noteKey);
              });
              _notify();
            },
            onRemove: () => _confirmRemoveEntry(
              item.sectionIndex,
              entryIndex,
              spot?.name ?? entry.spotId,
            ),
          ),
        ),
      ),
    );
  }
}

enum _FlatKind { header, spot, empty, add }

class _FlatItem {
  const _FlatItem._({
    required this.kind,
    required this.sectionIndex,
    required this.sectionId,
    this.entryIndex,
    this.entry,
  });

  const _FlatItem.header(int sectionIndex, String sectionId)
    : this._(
        kind: _FlatKind.header,
        sectionIndex: sectionIndex,
        sectionId: sectionId,
      );

  const _FlatItem.spot(
    int sectionIndex,
    String sectionId,
    int entryIndex,
    SpotListEntry entry,
  ) : this._(
        kind: _FlatKind.spot,
        sectionIndex: sectionIndex,
        sectionId: sectionId,
        entryIndex: entryIndex,
        entry: entry,
      );

  const _FlatItem.empty(int sectionIndex, String sectionId)
    : this._(
        kind: _FlatKind.empty,
        sectionIndex: sectionIndex,
        sectionId: sectionId,
      );

  const _FlatItem.add()
    : this._(kind: _FlatKind.add, sectionIndex: -1, sectionId: '');

  final _FlatKind kind;
  final int sectionIndex;
  final String sectionId;
  final int? entryIndex;
  final SpotListEntry? entry;
}

class _SectionDragData {
  const _SectionDragData(this.sectionId);

  final String sectionId;
}

class _SectionDragSpotPreview extends StatelessWidget {
  const _SectionDragSpotPreview({required this.spot, required this.spotId});

  final Spot? spot;
  final String spotId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = spot?.imageUrls != null && spot!.imageUrls!.isNotEmpty;
    final displayName = spot?.name ?? spotId;

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: hasImage
              ? ResizedSpotImage(
                  imageUrl: spot!.imageUrls!.first,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      _previewPlaceholder(theme, Icons.image),
                  errorWidget: (context, url, error) =>
                      _previewPlaceholder(theme, Icons.image_not_supported),
                )
              : _previewPlaceholder(theme, Icons.location_on_outlined),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            displayName,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _previewPlaceholder(ThemeData theme, IconData icon) {
    return Container(
      width: 40,
      height: 40,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        icon,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        size: 20,
      ),
    );
  }
}
