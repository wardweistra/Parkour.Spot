import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_list.dart';
import '../widgets/custom_text_field.dart';

class AddToSpotListDialogResult {
  const AddToSpotListDialogResult.added() : created = false, error = null;

  const AddToSpotListDialogResult.created() : created = true, error = null;

  const AddToSpotListDialogResult.error(this.error) : created = false;

  final bool created;
  final String? error;
}

class AddToSpotListDialog extends StatefulWidget {
  const AddToSpotListDialog({
    super.key,
    required this.lists,
    required this.listsWithSpot,
    required this.addSpot,
    required this.createList,
    required this.addToNewSection,
    this.onOpenList,
    this.errorMessage,
  });

  final List<SpotList> lists;
  final List<SpotList> listsWithSpot;
  final Future<bool> Function(String listId, {String? sectionId}) addSpot;
  final Future<String?> Function({
    required String name,
    required SpotListVisibility visibility,
  })
  createList;
  final Future<bool> Function(String listId, {String? sectionTitle})
  addToNewSection;
  final ValueChanged<String>? onOpenList;
  final String? Function()? errorMessage;

  @override
  State<AddToSpotListDialog> createState() => _AddToSpotListDialogState();
}

class _AddToSpotListDialogState extends State<AddToSpotListDialog> {
  final _nameController = TextEditingController();
  final _newSectionTitleController = TextEditingController();
  SpotListVisibility _newListVisibility = SpotListVisibility.unlisted;
  bool _showCreateForm = false;
  bool _addingNewSection = false;
  SpotList? _pickingList;
  bool _isBusy = false;

  @override
  void dispose() {
    _nameController.dispose();
    _newSectionTitleController.dispose();
    super.dispose();
  }

  String _fallbackError(AppLocalizations l10n) =>
      widget.errorMessage?.call() ?? l10n.spotDetailFailedAddToListGeneric;

  Future<void> _addToList(String listId, {String? sectionId}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isBusy = true);
    final success = await widget.addSpot(listId, sectionId: sectionId);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(const AddToSpotListDialogResult.added());
      return;
    }
    setState(() => _isBusy = false);
    Navigator.of(
      context,
    ).pop(AddToSpotListDialogResult.error(_fallbackError(l10n)));
  }

  Future<void> _addToNewSection(SpotList list) async {
    final id = list.id;
    if (id == null || _isBusy) return;
    final l10n = AppLocalizations.of(context)!;
    final title = _newSectionTitleController.text.trim();
    setState(() => _isBusy = true);
    final success = await widget.addToNewSection(
      id,
      sectionTitle: title.isEmpty ? null : title,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(const AddToSpotListDialogResult.added());
      return;
    }
    setState(() => _isBusy = false);
    Navigator.of(
      context,
    ).pop(AddToSpotListDialogResult.error(_fallbackError(l10n)));
  }

  Future<void> _onListTap(SpotList list) async {
    final id = list.id;
    if (id == null || _isBusy) return;
    if (list.needsSectionChoice) {
      setState(() {
        _pickingList = list;
        _addingNewSection = false;
        _newSectionTitleController.clear();
      });
      return;
    }
    await _addToList(id);
  }

  void _leaveSectionPicker() {
    setState(() {
      _pickingList = null;
      _addingNewSection = false;
      _newSectionTitleController.clear();
    });
  }

  Future<void> _createListAndAdd() async {
    final l10n = AppLocalizations.of(context)!;
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.spotDetailListNameEmpty)));
      return;
    }

    setState(() => _isBusy = true);
    final listId = await widget.createList(
      name: _nameController.text.trim(),
      visibility: _newListVisibility,
    );
    if (!mounted) return;

    if (listId == null) {
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.errorMessage?.call() ?? l10n.spotDetailFailedCreateList,
          ),
        ),
      );
      return;
    }

    final success = await widget.addSpot(listId);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(const AddToSpotListDialogResult.created());
      return;
    }
    setState(() => _isBusy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_fallbackError(l10n))));
  }

  String _sectionLabel(SpotListSection section, AppLocalizations l10n) {
    final title = section.title?.trim() ?? '';
    if (title.isNotEmpty) return title;
    return l10n.spotDetailSectionEntryCount(section.entries.length);
  }

  Widget _openListButton(ThemeData theme, AppLocalizations l10n, String? id) {
    if (id == null || widget.onOpenList == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: l10n.spotDetailViewFullListTooltip,
      icon: Icon(
        Icons.list_alt_outlined,
        size: 20,
        color: theme.colorScheme.primary,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      onPressed: _isBusy ? null : () => widget.onOpenList!(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final picking = _pickingList;

    return AlertDialog(
      title: picking == null
          ? Text(l10n.spotDetailAddToListDialogTitle)
          : Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _isBusy ? null : _leaveSectionPicker,
                ),
                Expanded(
                  child: Text(
                    l10n.spotDetailAddToListTitle(picking.name),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: picking != null
              ? _buildSectionPicker(theme, l10n, picking)
              : _showCreateForm
              ? _buildCreateForm(theme, l10n)
              : _buildListPicker(theme, l10n),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.profileCancel),
        ),
        if (_showCreateForm && picking == null)
          ElevatedButton(
            onPressed: _isBusy ? null : _createListAndAdd,
            child: _isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.spotDetailCreateAndAdd),
          ),
      ],
    );
  }

  Widget _buildListPicker(ThemeData theme, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.listsWithSpot.isNotEmpty) ...[
          Text(
            l10n.spotDetailAlreadyInLists,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          ...widget.listsWithSpot.map(
            (list) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(list.name, style: theme.textTheme.bodyMedium),
                  ),
                  _openListButton(theme, l10n, list.id),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (widget.lists.isEmpty)
          Text(l10n.spotDetailNoListsYet, style: theme.textTheme.bodyMedium)
        else
          ...widget.lists.map(
            (list) => ListTile(
              title: Text(list.name),
              subtitle: list.description != null && list.description!.isNotEmpty
                  ? Text(
                      list.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    )
                  : null,
              trailing: _openListButton(theme, l10n, list.id),
              contentPadding: EdgeInsets.zero,
              enabled: !_isBusy,
              onTap: _isBusy ? null : () => _onListTap(list),
            ),
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.add, color: theme.colorScheme.primary),
          title: Text(l10n.spotDetailCreateNewList),
          enabled: !_isBusy,
          onTap: _isBusy
              ? null
              : () => setState(() => _showCreateForm = true),
        ),
      ],
    );
  }

  Widget _buildSectionPicker(
    ThemeData theme,
    AppLocalizations l10n,
    SpotList list,
  ) {
    final sections = list.sections ?? const <SpotListSection>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sections.map(
          (section) => ListTile(
            title: Text(_sectionLabel(section, l10n)),
            contentPadding: EdgeInsets.zero,
            enabled: !_isBusy,
            onTap: _isBusy || list.id == null
                ? null
                : () => _addToList(list.id!, sectionId: section.id),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.add, color: theme.colorScheme.primary),
          title: Text(l10n.spotDetailAddToNewSection),
          enabled: !_isBusy,
          onTap: _isBusy
              ? null
              : () => setState(() => _addingNewSection = true),
        ),
        if (_addingNewSection) ...[
          TextField(
            controller: _newSectionTitleController,
            decoration: InputDecoration(
              labelText: l10n.spotDetailSectionNameOptional,
            ),
            enabled: !_isBusy,
            autofocus: true,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isBusy ? null : () => _addToNewSection(list),
              child: Text(l10n.spotDetailAdd),
            ),
          ),
        ],
        if (_isBusy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCreateForm(ThemeData theme, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.spotDetailCreateNewList, style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _nameController,
          labelText: l10n.spotDetailListNameLabel,
          hintText: l10n.spotDetailListNameHint,
          prefixIcon: Icons.list_alt_outlined,
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          enabled: !_isBusy,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<SpotListVisibility>(
          initialValue: _newListVisibility,
          decoration: CustomTextField.decoration(
            context,
            labelText: l10n.spotDetailVisibilityLabel,
            prefixIcon: Icons.visibility_outlined,
          ),
          items: SpotListVisibility.values
              .map(
                (visibility) => DropdownMenuItem<SpotListVisibility>(
                  value: visibility,
                  child: Text(visibility.label),
                ),
              )
              .toList(),
          onChanged: _isBusy
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() => _newListVisibility = value);
                },
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _newListVisibility.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isBusy
              ? null
              : () {
                  setState(() {
                    _showCreateForm = false;
                    _nameController.clear();
                    _newListVisibility = SpotListVisibility.unlisted;
                  });
                },
          child: Text(l10n.profileCancel),
        ),
      ],
    );
  }
}
