import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../utils/youtube_utils.dart';

/// Moderator preview of suggested YouTube videos: thumbnails, open link, and
/// a clear note that accepting adds both the video link and a spot thumbnail.
class YoutubeSuggestionReview extends StatelessWidget {
  const YoutubeSuggestionReview({
    super.key,
    required this.existingVideoIds,
    required this.suggestedVideoIds,
  });

  final List<String>? existingVideoIds;
  final List<String> suggestedVideoIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;

    final existing = [
      for (final id in existingVideoIds ?? const <String>[])
        if (id.trim().isNotEmpty) id.trim(),
    ];
    final existingSet = existing.toSet();
    final toAdd = [
      for (final id in suggestedVideoIds)
        if (id.trim().isNotEmpty && !existingSet.contains(id.trim()))
          id.trim(),
    ];

    if (toAdd.isEmpty && existing.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.editSuggestionYoutubeEffectHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        if (toAdd.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            l10n.editSuggestionYoutubeToAddHeading,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          for (final id in toAdd) ...[
            _SuggestedYoutubeCard(videoId: id),
            const SizedBox(height: 8),
          ],
        ],
        if (existing.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            l10n.editSuggestionYoutubeExistingHeading,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in existing) _ExistingYoutubeThumb(videoId: id),
            ],
          ),
        ],
      ],
    );
  }
}

class _SuggestedYoutubeCard extends StatelessWidget {
  const _SuggestedYoutubeCard({required this.videoId});

  final String videoId;

  Future<void> _open() async {
    final uri = Uri.parse(youtubeWatchUrl(videoId));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: l10n.editSpotYoutubeThumbnailSemanticLabel,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 160,
                    height: 90,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          youtubePreviewThumbnailUrl(videoId),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              ColoredBox(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.play_circle_outline,
                                  size: 36,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                        ),
                        const Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x73000000),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.editSuggestionYoutubeOutcomes,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      videoId,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: _open,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: Text(l10n.editSuggestionYoutubeOpenLink),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExistingYoutubeThumb extends StatelessWidget {
  const _ExistingYoutubeThumb({required this.videoId});

  final String videoId;

  Future<void> _open() async {
    final uri = Uri.parse(youtubeWatchUrl(videoId));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = theme.colorScheme;

    return Tooltip(
      message: l10n.editSuggestionYoutubeOpenLink,
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(8),
        child: Semantics(
          label: l10n.editSpotYoutubeThumbnailSemanticLabel,
          button: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 96,
              height: 54,
              child: Image.network(
                youtubePreviewThumbnailUrl(videoId),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.play_circle_outline,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
