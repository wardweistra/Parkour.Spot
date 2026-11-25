import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/year_review.dart';
import '../../services/auth_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/web_share_service.dart';
import '../../services/year_review_service.dart';
import '../../utils/web_meta_utils.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/page_scaffold.dart';

/// Ground of the share card (`functions/lib/year-review-card.js`); the card's
/// placeholder uses it so the image fades in on its own colour.
const Color _cardGround = Color(0xFF13191C);
const Color _cardAccent = Color(0xFF8ECFF2);

/// `/year/<year>/<@username|uid>`: one person's yearly review.
///
/// The card image leads (it is what gets shared); below or beside it, the
/// owner shares it, visitors open the map, and everyone can open the spots.
class YearReviewScreen extends StatefulWidget {
  const YearReviewScreen({
    super.key,
    required this.year,
    required this.userIdOrUsername,
    this.service,
  });

  final int year;
  final String userIdOrUsername;
  final YearReviewService? service;

  @override
  State<YearReviewScreen> createState() => _YearReviewScreenState();
}

class _YearReviewScreenState extends State<YearReviewScreen> {
  late final YearReviewService _service = widget.service ?? YearReviewService();
  late Future<YearReview?> _future;
  YearReviewCardFormat? _sharing;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(YearReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year ||
        oldWidget.userIdOrUsername != widget.userIdOrUsername) {
      _load();
    }
  }

  @override
  void dispose() {
    if (kIsWeb) WebMetaUtils.resetPageMeta();
    super.dispose();
  }

  void _load() {
    _future = _service.getYearReview(
      userIdOrUsername: widget.userIdOrUsername.replaceFirst('@', ''),
      year: widget.year,
    );
    if (mounted) setState(() {});
  }

  bool _isOwn(YearReview review) =>
      context.read<AuthService>().currentUser?.uid == review.userId;

  Future<void> _shareCard(
    YearReview review,
    YearReviewCardFormat format,
  ) async {
    if (_sharing != null) return;
    setState(() => _sharing = format);
    try {
      final bytes = await _service.fetchCard(review, format);
      final outcome = await WebShareService.tryShareImage(
        bytes: bytes,
        fileName: YearReviewService.cardFileName(review, format),
        text: _service.pageUrl(review).toString(),
      );
      if (outcome == WebShareOutcome.fallback && mounted) {
        if (kIsWeb) {
          SnackbarService.showSuccess(_l10n.yearReviewImageSaved);
        } else {
          SnackbarService.showError(_l10n.yearReviewImageFailed);
        }
      }
    } catch (_) {
      if (mounted) SnackbarService.showError(_l10n.yearReviewImageFailed);
    } finally {
      if (mounted) setState(() => _sharing = null);
    }
  }

  Future<void> _copyLink(YearReview review) async {
    await Clipboard.setData(
      ClipboardData(text: _service.pageUrl(review).toString()),
    );
    SnackbarService.showClipboardCopied(_l10n.yearReviewLinkCopied);
  }

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: _l10n.yearReviewPageTitle,
      scrollable: false,
      body: FutureBuilder<YearReview?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _LoadError(onRetry: _load);
          }
          final review = snapshot.data;
          if (review == null) {
            // A valid link with nothing to show (private profile or an
            // empty year), not a broken one: no 404 page.
            return _NoReview(
              year: widget.year,
              onOpenMap: () => context.go('/explore'),
            );
          }
          if (kIsWeb) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                WebMetaUtils.updatePageMeta(
                  '${review.name} · ${review.year} - Parkour·Spot',
                  review.sentence,
                );
              }
            });
          }
          return _buildReview(context, review);
        },
      ),
    );
  }

  Widget _buildReview(BuildContext context, YearReview review) {
    final isOwn = _isOwn(review);
    final card = _CardImage(
      url: _service.cardUrl(review, YearReviewCardFormat.story).toString(),
      label: _l10n.yearReviewCardImageLabel(review.sentence),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isOwn) ..._ownActions(review) else ..._visitorActions(review),
        const SizedBox(height: 32),
        _SpotsSection(review: review),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 380, child: card),
                    const SizedBox(width: 40),
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: details,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [card, const SizedBox(height: 24), details],
                    ),
                  ),
                ),
        );
      },
    );
  }

  List<Widget> _ownActions(YearReview review) {
    final theme = Theme.of(context);
    return [
      CustomButton(
        onPressed: _sharing == null
            ? () => _shareCard(review, YearReviewCardFormat.story)
            : null,
        isLoading: _sharing == YearReviewCardFormat.story,
        text: _l10n.yearReviewShareStory,
        icon: Icons.ios_share,
      ),
      const SizedBox(height: 12),
      CustomButton(
        onPressed: _sharing == null
            ? () => _shareCard(review, YearReviewCardFormat.square)
            : null,
        isLoading: _sharing == YearReviewCardFormat.square,
        text: _l10n.yearReviewShareSquare,
        icon: Icons.crop_square,
        isOutlined: true,
      ),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _copyLink(review),
          icon: const Icon(Icons.link, size: 20),
          label: Text(_l10n.yearReviewCopyLink),
        ),
      ),
      if (review.soFar) ...[
        const SizedBox(height: 4),
        Text(
          _l10n.yearReviewSoFarNote,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ];
  }

  List<Widget> _visitorActions(YearReview review) {
    final theme = Theme.of(context);
    return [
      // Many visitors arrive from a story or a shared link and have never
      // heard of the app: say what it is before asking them to open it.
      Text(_l10n.yearReviewAboutTitle, style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        _l10n.yearReviewAboutBody,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 24),
      CustomButton(
        onPressed: () => context.go('/explore'),
        text: _l10n.yearReviewOpenMap,
        icon: Icons.map_outlined,
      ),
      const SizedBox(height: 12),
      CustomButton(
        onPressed: () => context.push(
          '/user/${Uri.encodeComponent(review.username ?? review.userId)}',
        ),
        text: _l10n.yearReviewSeeProfile(review.name),
        icon: Icons.person_outline,
        isOutlined: true,
      ),
    ];
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      image: true,
      label: label,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: ColoredBox(
            color: _cardGround,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              excludeFromSemantics: true,
              // The first frame decides loading vs loaded: progress events
              // (loadingBuilder) are often never reported on the web, which
              // left an empty dark box while the card rendered.
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                final loaded = frame != null;
                final duration = MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 280);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedOpacity(
                      opacity: loaded ? 0 : 1,
                      duration: duration,
                      child: const _CardLoading(),
                    ),
                    AnimatedOpacity(
                      opacity: loaded ? 1 : 0,
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      child: child,
                    ),
                  ],
                );
              },
              errorBuilder: (context, error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.yearReviewImageFailed,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
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

/// Shown on the card's own ground while the image renders (a first render
/// fetches photos server-side and can take a few seconds).
class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _cardAccent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.yearReviewCardLoading,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotsSection extends StatelessWidget {
  const _SpotsSection({required this.review});

  final YearReview review;

  @override
  Widget build(BuildContext context) {
    if (review.frames.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.yearReviewSpotsTitle('${review.year}'),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        for (final frame in review.frames) _SpotRow(frame: frame),
        if (review.moreCount > 0) ...[
          const SizedBox(height: 8),
          Text(
            l10n.yearReviewMoreSpots(review.moreCount),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SpotRow extends StatelessWidget {
  const _SpotRow({required this.frame});

  final YearReviewFrame frame;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final kind = switch (frame.kind) {
      YearReviewFrameKind.spotAdded => l10n.yearReviewKindSpotAdded,
      YearReviewFrameKind.photosAdded => l10n.yearReviewKindPhotosAdded,
      YearReviewFrameKind.spotImproved => l10n.yearReviewKindSpotImproved,
      YearReviewFrameKind.checkIn => l10n.yearReviewKindCheckIn,
      YearReviewFrameKind.rated => l10n.yearReviewKindRated,
    };
    final subtitle = [frame.city, kind].whereType<String>().join(' · ');

    return InkWell(
      onTap: () => context.push('/spot/${frame.spotId}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: frame.imageUrl == null
                    ? ColoredBox(color: colorScheme.surfaceContainerHighest)
                    : CachedNetworkImage(
                        imageUrl: frame.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (context, url, error) => ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    frame.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _NoReview extends StatelessWidget {
  const _NoReview({required this.year, required this.onOpenMap});

  final int year;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_location_alt_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.yearReviewNotFoundTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.yearReviewNotFoundBody('$year'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CustomButton(
              onPressed: onOpenMap,
              text: l10n.yearReviewOpenMap,
              icon: Icons.map_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.yearReviewLoadError,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          CustomButton(
            onPressed: onRetry,
            text: l10n.yearReviewRetry,
            isOutlined: true,
          ),
        ],
      ),
    );
  }
}
