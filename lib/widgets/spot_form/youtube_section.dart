import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/youtube_utils.dart';
import '../custom_text_field.dart';

/// Moderator edit card for YouTube video IDs/URLs, with drag-to-reorder.
class SpotYoutubeSection extends StatelessWidget {
  final List<TextEditingController> controllers;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback? onChanged;

  const SpotYoutubeSection({
    super.key,
    required this.controllers,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.editSpotYoutubeSectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: onAdd,
                  tooltip: l10n.editSpotYoutubeAddTooltip,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.editSpotYoutubeHint,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (controllers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  l10n.editSpotYoutubeEmpty,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: controllers.length,
                proxyDecorator: (child, index, animation) => child,
                onReorder: (oldIndex, newIndex) {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  onReorder(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  return _YoutubeLinkRow(
                    key: ObjectKey(controllers[index]),
                    index: index,
                    controller: controllers[index],
                    labelText: l10n.editSpotYoutubeLinkLabel(index + 1),
                    hintText: l10n.editSpotYoutubeLinkHint,
                    removeTooltip: l10n.editSpotYoutubeRemoveTooltip,
                    reorderTooltip: l10n.editSpotYoutubeReorderTooltip,
                    thumbnailSemanticLabel:
                        l10n.editSpotYoutubeThumbnailSemanticLabel,
                    onRemove: () => onRemove(index),
                    onChanged: onChanged,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _YoutubeLinkRow extends StatelessWidget {
  final int index;
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final String removeTooltip;
  final String reorderTooltip;
  final String thumbnailSemanticLabel;
  final VoidCallback onRemove;
  final VoidCallback? onChanged;

  const _YoutubeLinkRow({
    super.key,
    required this.index,
    required this.controller,
    required this.labelText,
    required this.hintText,
    required this.removeTooltip,
    required this.reorderTooltip,
    required this.thumbnailSemanticLabel,
    required this.onRemove,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final videoId = extractYoutubeVideoId(controller.text);
    final hasPreview = videoId != null &&
        videoId.isNotEmpty &&
        !videoId.contains('/') &&
        !videoId.contains(' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Semantics(
              label: reorderTooltip,
              button: true,
              child: Tooltip(
                message: reorderTooltip,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.drag_handle,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            label: thumbnailSemanticLabel,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: hasPreview
                    ? Image.network(
                        youtubePreviewThumbnailUrl(videoId),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _ThumbnailPlaceholder(color: scheme.onSurfaceVariant),
                      )
                    : _ThumbnailPlaceholder(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: CustomTextField(
              controller: controller,
              labelText: labelText,
              hintText: hintText,
              onChanged: (_) => onChanged?.call(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle),
            color: scheme.error,
            onPressed: onRemove,
            tooltip: removeTooltip,
          ),
        ],
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  final Color color;

  const _ThumbnailPlaceholder({required this.color});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(Icons.play_circle_outline, color: color),
    );
  }
}
