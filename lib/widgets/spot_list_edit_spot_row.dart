import 'package:flutter/material.dart';

import '../constants/spot_detail_ui.dart';
import '../l10n/app_localizations.dart';
import '../models/spot.dart';
import 'resized_spot_image.dart';
import 'spot_list_note_block.dart';

/// Compact reorderable row for list edit mode (thumbnail, name, location).
class SpotListEditSpotRow extends StatelessWidget {
  final Spot? spot;
  final String spotId;
  final String? note;
  final bool noteExpanded;
  final TextEditingController? noteController;
  final int dragIndex;
  final VoidCallback onRemove;
  final VoidCallback onToggleNote;
  final VoidCallback onRemoveNote;
  final ValueChanged<String> onNoteChanged;

  const SpotListEditSpotRow({
    super.key,
    required this.spot,
    required this.spotId,
    required this.note,
    required this.noteExpanded,
    this.noteController,
    required this.dragIndex,
    required this.onRemove,
    required this.onToggleNote,
    required this.onRemoveNote,
    required this.onNoteChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final hasImage = spot?.imageUrls != null && spot!.imageUrls!.isNotEmpty;
    final locationText = [
      spot?.city,
      spot?.countryCode,
    ].whereType<String>().where((s) => s.isNotEmpty).join(', ');
    final displayName = spot?.name ?? spotId;
    final hasNote = note != null && note!.trim().isNotEmpty;
    final editingNote = noteExpanded && noteController != null;

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
          border: SpotDetailUi.outlineBorder(theme.colorScheme),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ReorderableDragStartListener(
                    index: dragIndex,
                    child: Semantics(
                      label: l10n.spotListEditDragHandleTooltip,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.drag_handle,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: hasImage
                        ? ResizedSpotImage(
                            imageUrl: spot!.imageUrls!.first,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                _thumbPlaceholder(theme, Icons.image),
                            errorWidget: (context, url, error) =>
                                _thumbPlaceholder(
                                  theme,
                                  Icons.image_not_supported,
                                ),
                          )
                        : _thumbPlaceholder(theme, Icons.location_on_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (locationText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            locationText,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.spotListEditRemoveSpotTooltip,
                    onPressed: onRemove,
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (editingNote)
                SpotListNoteBlock(
                  child: TextField(
                    controller: noteController,
                    onChanged: onNoteChanged,
                    autofocus: true,
                    maxLines: 3,
                    minLines: 1,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: l10n.spotListEditNoteLabel,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  actions: [
                    _noteAction(
                      icon: Icons.check,
                      tooltip: l10n.spotListEditDoneNoteTooltip,
                      onPressed: onToggleNote,
                    ),
                    _noteAction(
                      icon: Icons.delete_outline,
                      tooltip: l10n.spotListEditRemoveNoteTooltip,
                      onPressed: onRemoveNote,
                    ),
                  ],
                )
              else if (hasNote)
                SpotListNoteBlock(
                  onTap: onToggleNote,
                  child: Text(
                    note!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    _noteAction(
                      icon: Icons.edit_outlined,
                      tooltip: l10n.spotListEditEditNoteTooltip,
                      onPressed: onToggleNote,
                    ),
                    _noteAction(
                      icon: Icons.delete_outline,
                      tooltip: l10n.spotListEditRemoveNoteTooltip,
                      onPressed: onRemoveNote,
                    ),
                  ],
                )
              else
                SpotListNoteBlock(
                  icon: Icons.note_add_outlined,
                  muted: true,
                  onTap: onToggleNote,
                  child: Text(
                    l10n.spotListEditAddNoteTooltip,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _noteAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      iconSize: 20,
    );
  }

  Widget _thumbPlaceholder(ThemeData theme, IconData icon) {
    return Container(
      width: 72,
      height: 72,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        icon,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        size: 28,
      ),
    );
  }
}
