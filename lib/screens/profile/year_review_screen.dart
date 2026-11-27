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
/// owner shares it, visitors add a spot or open the map, and everyone can
/// share the card and open the spots.
class YearReviewScreen extends StatefulWidget {
  const YearReviewScreen({
    super.key,
    required this.year,
    required this.userIdOrUsername,
    this.shareFirst = false,
    this.service,
  });

  final int year;
  final String userIdOrUsername;

  /// Lead with the share buttons when signed out: the yearly email links
  /// here with `?share`, and owners often open it in a signed-out browser.
  final bool shareFirst;
  final YearReviewService? service;

  @override
  State<YearReviewScreen> createState() => _YearReviewScreenState();
}

class _YearReviewScreenState extends State<YearReviewScreen> {
  late final YearReviewService _service = widget.service ?? YearReviewService();
  late Future<YearReview?> _future;
  YearReviewCardFormat? _sharing;
  bool _precached = false;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  /// The story card's URL from the route alone, so it loads alongside the
  /// review data instead of after it.
  String get _storyUrl => _service
      .cardUrlFor(
        year: widget.year,
        handle: widget.userIdOrUsername,
        format: YearReviewCardFormat.story,
      )
      .toString();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      // A first render fetches photos server-side; start it now. Failures
      // surface in the card's own error state.
      precacheImage(NetworkImage(_storyUrl), context, onError: (_, _) {});
    }
  }

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
      _precached = false;
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

  /// Signed in as this page's owner with a private profile: the page is
  /// empty for everyone else, but the owner should learn why.
  bool _isOwnPrivatePage() {
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) return false;
    final profile = auth.userProfile;
    final handle = widget.userIdOrUsername.replaceFirst('@', '');
    final mine =
        handle == user.uid ||
        (profile?.username != null && profile!.username == handle);
    return mine && profile?.isPublicProfile == false;
  }

  /// The map, opened on the city the card names first.
  void _openMap(YearReview? review) {
    final place = review?.places.firstOrNull;
    context.go(
      place == null
          ? '/explore'
          : '/explore?location=${Uri.encodeQueryComponent(place)}',
    );
  }

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
            return _LoadError(onRetry: _load, onOpenMap: () => _openMap(null));
          }
          final review = snapshot.data;
          if (review == null) {
            // A valid link with nothing to show (private profile or an
            // empty year), not a broken one: no 404 page.
            return _NoReview(
              year: widget.year,
              ownPrivate: _isOwnPrivatePage(),
              onOpenMap: () => _openMap(null),
              onOpenSettings: () => context.push('/profile/settings'),
            );
          }
          if (kIsWeb) {
            final who = review.name.isEmpty
                ? _l10n.yearReviewPageTitle
                : review.name;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                WebMetaUtils.updatePageMeta(
                  '$who · ${review.year} - Parkour·Spot',
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
    // ?share only stands in for a signed-out owner: signed in, we know
    // whose page this is.
    final signedOut = context.read<AuthService>().currentUser == null;
    final shareFirst = isOwn || (widget.shareFirst && signedOut);
    final card = _CardImage(
      url: _storyUrl,
      label: _l10n.yearReviewCardImageLabel(review.sentence),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shareFirst)
          ..._shareActions(review)
        else
          ..._visitorActions(review),
        const SizedBox(height: 32),
        _SpotsSection(review: review),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        if (wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 380, child: card),
                    const SizedBox(width: 40),
                    Expanded(child: details),
                  ],
                ),
              ),
            ),
          );
        }
        // A full-width 9:16 card would fill a phone's first screen. Cap it
        // so the next step shows: visitors (who just saw this image in a
        // story) get the tighter cap, so the ask to add a spot is in view.
        final viewHeight = MediaQuery.sizeOf(context).height;
        final cardHeight = viewHeight * (shareFirst ? 0.62 : 0.5);
        final cardWidth = (cardHeight * 9 / 16).clamp(200.0, 440.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: SizedBox(width: cardWidth, child: card),
                  ),
                  const SizedBox(height: 24),
                  details,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _shareActions(YearReview review) {
    final theme = Theme.of(context);
    return [
      Text(
        _l10n.yearReviewOwnThanks('${review.year}'),
        style: theme.textTheme.titleLarge,
      ),
      const SizedBox(height: 16),
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
      _FlushStart(
        child: TextButton.icon(
          onPressed: () => _copyLink(review),
          icon: const Icon(Icons.link, size: 20),
          label: Text(_l10n.yearReviewCopyLink),
        ),
      ),
      if (review.soFar) ...[
        // A separate task from sharing: its own group under a hairline.
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 24),
        Text(
          _l10n.yearReviewSoFarNote,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        CustomButton(
          onPressed: () => context.go('/explore?tab=add'),
          text: _l10n.yearReviewAddSpot,
          icon: Icons.add_location_alt_outlined,
          isOutlined: true,
        ),
      ],
    ];
  }

  List<Widget> _visitorActions(YearReview review) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.5,
    );
    final signedIn = context.read<AuthService>().currentUser != null;
    return [
      // Many visitors arrive from a story or a shared link and have never
      // heard of the app: say what it is, that people like this card's owner
      // made it, and invite them to add to it.
      Text(_l10n.yearReviewAboutTitle, style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        review.name.isEmpty
            ? _l10n.yearReviewAboutBodyNoName
            : _l10n.yearReviewAboutBody(review.name),
        style: muted,
      ),
      if (review.soFar) ...[
        const SizedBox(height: 12),
        Text(_l10n.yearReviewOwnCardHint('${review.year}'), style: muted),
      ],
      const SizedBox(height: 24),
      // The add hub signs visitors in itself, then returns them to adding.
      CustomButton(
        onPressed: () => context.go('/explore?tab=add'),
        text: _l10n.yearReviewAddSpot,
        icon: Icons.add_location_alt_outlined,
      ),
      const SizedBox(height: 12),
      CustomButton(
        onPressed: () => _openMap(review),
        text: _l10n.yearReviewOpenMap,
        icon: Icons.map_outlined,
        isOutlined: true,
      ),
      const SizedBox(height: 12),
      _FlushStart(
        child: Wrap(
          spacing: 8,
          children: [
            // The card is public: anyone can pass it on, no sign-in needed.
            TextButton.icon(
              onPressed: _sharing == null
                  ? () => _shareCard(review, YearReviewCardFormat.story)
                  : null,
              icon: const Icon(Icons.ios_share, size: 20),
              label: Text(_l10n.yearReviewShareThisCard),
            ),
            TextButton.icon(
              onPressed: () => context.push(
                '/user/${Uri.encodeComponent(review.username ?? review.userId)}',
              ),
              icon: const Icon(Icons.person_outline, size: 20),
              label: Text(
                review.name.isEmpty
                    ? _l10n.yearReviewSeeProfileNoName
                    : _l10n.yearReviewSeeProfile(review.name),
              ),
            ),
            // Owners signed out in a mail browser can sign in to see the page
            // as their own. Signed in as someone else, it's not them.
            if (!signedIn)
              TextButton.icon(
                onPressed: () => context.push(
                  '/login?redirectTo=${Uri.encodeComponent(review.pagePath)}',
                ),
                icon: const Icon(Icons.login, size: 20),
                label: Text(_l10n.yearReviewIsThisYou),
              ),
          ],
        ),
      ),
    ];
  }
}

/// Text buttons pad their icon 12px in from the start; shifting them back
/// lines the icon up with the headings and buttons above, while the hover
/// and focus highlight keeps its padding.
class _FlushStart extends StatelessWidget {
  const _FlushStart({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Transform.translate(
        offset: Offset(rtl ? 12 : -12, 0),
        child: child,
      ),
    );
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
                    ? const _NoPhoto()
                    : CachedNetworkImage(
                        imageUrl: frame.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => ColoredBox(
                          color: colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (context, url, error) => const _NoPhoto(),
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

/// Thumbnail stand-in for a spot without a photo, or one that failed.
class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.place_outlined, color: colorScheme.onSurfaceVariant),
    );
  }
}

class _NoReview extends StatelessWidget {
  const _NoReview({
    required this.year,
    required this.ownPrivate,
    required this.onOpenMap,
    required this.onOpenSettings,
  });

  final int year;

  /// The signed-in owner's own private page: explain and offer Settings.
  final bool ownPrivate;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenSettings;

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
              ownPrivate ? Icons.lock_outline : Icons.add_location_alt_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              ownPrivate
                  ? l10n.yearReviewOwnPrivateTitle
                  : l10n.yearReviewNotFoundTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              ownPrivate
                  ? l10n.yearReviewOwnPrivateBody('$year')
                  : l10n.yearReviewNotFoundBody('$year'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (ownPrivate) ...[
              CustomButton(
                onPressed: onOpenSettings,
                text: l10n.yearReviewOpenSettings,
                icon: Icons.settings_outlined,
              ),
              const SizedBox(height: 12),
            ],
            CustomButton(
              onPressed: onOpenMap,
              text: l10n.yearReviewOpenMap,
              icon: Icons.map_outlined,
              isOutlined: ownPrivate,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry, required this.onOpenMap});

  final VoidCallback onRetry;
  final VoidCallback onOpenMap;

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
          CustomButton(onPressed: onRetry, text: l10n.yearReviewRetry),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: onOpenMap,
            icon: const Icon(Icons.map_outlined, size: 20),
            label: Text(l10n.yearReviewOpenMap),
          ),
        ],
      ),
    );
  }
}
