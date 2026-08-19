import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_list.dart';
import '../services/spot_list_service.dart';
import 'custom_text_field.dart';
import 'spot_list_visibility_selector.dart';

/// Returns the new list id, or null if the user cancelled or create failed.
Future<String?> showCreateSpotListDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => const CreateSpotListDialog(),
  );
}

class CreateSpotListDialog extends StatefulWidget {
  const CreateSpotListDialog({super.key});

  @override
  State<CreateSpotListDialog> createState() => _CreateSpotListDialogState();
}

class _CreateSpotListDialogState extends State<CreateSpotListDialog> {
  final _nameController = TextEditingController();
  SpotListVisibility _visibility = SpotListVisibility.unlisted;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.spotDetailListNameEmpty)));
      return;
    }

    setState(() => _isSubmitting = true);
    final spotListService = context.read<SpotListService>();
    final listId = await spotListService.createSpotList(
      name,
      visibility: _visibility,
    );
    if (!mounted) return;

    if (listId != null) {
      Navigator.pop(context, listId);
      return;
    }

    setState(() => _isSubmitting = false);
    final error = spotListService.error;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.spotDetailCreateNewList),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(
              controller: _nameController,
              labelText: l10n.spotDetailListNameLabel,
              hintText: l10n.spotDetailListNameHint,
              prefixIcon: Icons.list_alt_outlined,
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            SpotListVisibilitySelector(
              value: _visibility,
              enabled: !_isSubmitting,
              onChanged: (value) {
                setState(() => _visibility = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(l10n.profileCancel),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.spotDetailCreateButton),
        ),
      ],
    );
  }
}
