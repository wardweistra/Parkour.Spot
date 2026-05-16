import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web/web.dart' as web;

import '../../constants/spot_detail_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/parkour_event.dart';
import '../../models/spot.dart';
import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/spot_service.dart';
import '../../services/web_share_service.dart';
import '../../widgets/detail_image_carousel.dart';
import '../../widgets/event_detail_provenance_line.dart';
import '../../widgets/event_detail_when_block.dart';
import '../../widgets/event_selection_dialog.dart';
import '../../services/url_service.dart';
import '../../widgets/detail_external_link_tile.dart';
import '../../widgets/spot_detail_quick_action_chip.dart';

/// Event detail page; loads the document from Firestore by [eventId].
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final GlobalKey<DetailImageCarouselState> _carouselKey =
      GlobalKey<DetailImageCarouselState>();

  ParkourEvent? _event;
  bool _loading = true;
  bool _loadError = false;

  ParkourEvent? _originalEvent;
  bool _loadingOriginal = false;
  List<ParkourEvent> _duplicateEvents = const [];
  bool _loadingDuplicates = false;

  @override
  void initState() {
    super.initState();
    _loadEvent();
  }

  @override
  void didUpdateWidget(covariant EventDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      _loadEvent();
    }
  }

  Future<void> _loadEvent() async {
    setState(() {
      _loading = true;
      _loadError = false;
      _event = null;
      _originalEvent = null;
      _duplicateEvents = const [];
      _loadingOriginal = false;
      _loadingDuplicates = false;
    });

    final admin = context.read<AdminEventsService>();
    try {
      final e = await admin.getEventById(widget.eventId);
      if (!mounted) return;
      if (e == null) {
        setState(() {
          _loading = false;
          _event = null;
        });
        return;
      }
      setState(() {
        _event = e;
        _loading = false;
      });
      if (kIsWeb) {
        final l10n = AppLocalizations.of(context);
        final brand = l10n?.exploreMetaDefaultTitle ?? 'Parkour·Spot';
        web.document.title = '${e.title} - $brand';
      }
      _attachDuplicateContext(e);
    } catch (e, st) {
      debugPrint('EventDetailScreen._loadEvent: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
    }
  }

  void _attachDuplicateContext(ParkourEvent e) {
    final dup = e.duplicateOf?.trim();
    if (dup != null && dup.isNotEmpty) {
      _loadOriginal(dup);
    } else if (e.id != null) {
      _loadDuplicates(e.id!);
    }
  }

  Future<void> _loadOriginal(String originalId) async {
    setState(() => _loadingOriginal = true);
    final admin = context.read<AdminEventsService>();
    try {
      final o = await admin.getEventById(originalId);
      if (!mounted) return;
      setState(() {
        _originalEvent = o;
        _loadingOriginal = false;
      });
    } catch (e, st) {
      debugPrint('EventDetailScreen._loadOriginal: $e\n$st');
      if (!mounted) return;
      setState(() => _loadingOriginal = false);
    }
  }

  Future<void> _loadDuplicates(String eventId) async {
    setState(() => _loadingDuplicates = true);
    final admin = context.read<AdminEventsService>();
    try {
      final list = await admin.getEventsDuplicating(eventId);
      if (!mounted) return;
      setState(() {
        _duplicateEvents = list;
        _loadingDuplicates = false;
      });
    } catch (e, st) {
      debugPrint('EventDetailScreen._loadDuplicates: $e\n$st');
      if (!mounted) return;
      setState(() => _loadingDuplicates = false);
    }
  }

  Future<void> _reloadAfterMutation() async {
    await _loadEvent();
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/explore');
    }
  }

  Future<void> _shareEvent() async {
    final event = _event;
    final id = event?.id;
    if (id == null) return;

    try {
      final l10n = AppLocalizations.of(context)!;
      final url = UrlService.generateEventUrl(id);
      final label = event!.title.trim();
      final text = l10n.spotCardShareClipboardText(label, url);

      final outcome = await WebShareService.tryShareLink(text: label, url: url);
      if (outcome == WebShareOutcome.shared ||
          outcome == WebShareOutcome.cancelled) {
        return;
      }

      await Clipboard.setData(ClipboardData(text: text));

      if (!mounted) return;
      SnackbarService.showClipboardCopied(l10n.eventDetailCopiedToClipboard);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.eventDetailShareFailed('$e'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildShareActionRow(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Tooltip(
              message: l10n.spotDetailShareTooltip,
              child: Semantics(
                button: true,
                label: l10n.spotDetailShareTooltip,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    SpotDetailUi.surfaceRadius,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      SpotDetailUi.surfaceRadius,
                    ),
                    onTap: _shareEvent,
                    child: SpotDetailQuickActionChip(
                      icon: Icons.share_outlined,
                      iconColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.75),
                      label: l10n.spotDetailQuickActionShare,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backButton() {
    return IconButton(
      onPressed: _goBack,
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        fixedSize: const Size(
          SpotDetailUi.appBarButtonSize,
          SpotDetailUi.appBarButtonSize,
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _adminMenuButton(
    AppLocalizations l10n,
    ParkourEvent event,
    bool hasDupLink,
  ) {
    return PopupMenuButton<_EventAdminAction>(
      tooltip: l10n.eventDetailAdminMenuTooltip,
      onSelected: (action) => _onAdminMenu(context, action, event),
      itemBuilder: (ctx) {
        final theme = Theme.of(ctx);
        return [
          PopupMenuItem(
            value: _EventAdminAction.markDuplicate,
            enabled: !hasDupLink,
            child: Text(
              l10n.spotDetailMenuMarkDuplicate,
              style: TextStyle(
                color: hasDupLink
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                    : null,
              ),
            ),
          ),
          if (hasDupLink)
            PopupMenuItem(
              value: _EventAdminAction.removeDuplicate,
              child: Text(l10n.spotDetailMenuRemoveDuplicateStatus),
            ),
        ];
      },
      icon: Container(
        width: SpotDetailUi.appBarButtonSize,
        height: SpotDetailUi.appBarButtonSize,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_vert, color: Colors.white, size: 22),
      ),
    );
  }

  Future<void> _onAdminMenu(
    BuildContext context,
    _EventAdminAction action,
    ParkourEvent event,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated || !auth.isAdmin) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventDetailMarkDuplicateAdminOnly)),
      );
      return;
    }
    final id = event.id;
    if (id == null) return;

    switch (action) {
      case _EventAdminAction.markDuplicate:
        final originalId = await showDialog<String>(
          context: context,
          builder: (c) => EventSelectionDialog(currentEventId: id),
        );
        if (!context.mounted || originalId == null) return;
        final admin = context.read<AdminEventsService>();
        final origEvent = await admin.getEventById(originalId);
        if (!context.mounted || origEvent == null) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n.spotDetailMenuMarkDuplicate),
            content: Text(
              l10n.eventDetailMarkDuplicateConfirmBody(origEvent.title),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.profileCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(l10n.spotDetailConfirm),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        final ok = await admin.markEventAsDuplicate(
          duplicateEventId: id,
          nativeOriginalEventId: originalId,
        );
        if (!context.mounted) return;
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.eventDetailMarkDuplicateSuccess)),
          );
          await _reloadAfterMutation();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                admin.error ?? l10n.eventDetailMarkDuplicateNotFoundOrInvalid,
              ),
            ),
          );
        }
        break;
      case _EventAdminAction.removeDuplicate:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n.spotDetailMenuRemoveDuplicateStatus),
            content: Text(l10n.eventDetailRemoveDuplicateConfirmBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(l10n.profileCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: Text(l10n.spotDetailRemoveButton),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) return;
        final admin = context.read<AdminEventsService>();
        final ok = await admin.clearEventDuplicateStatus(id);
        if (!context.mounted) return;
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.eventDetailRemoveDuplicateSuccess)),
          );
          await _reloadAfterMutation();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                admin.error ??
                    l10n.eventDetailMarkDuplicateNotFoundOrInvalid,
              ),
            ),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.eventDetailRouteErrorLoading,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.eventDetailRouteTryAgainLater,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final event = _event;
    if (event == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_busy_outlined, size: 64),
              const SizedBox(height: 16),
              Text(
                l10n.eventDetailRouteNotFound,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.go('/explore'),
                child: Text(l10n.eventDetailRouteGoToExplore),
              ),
            ],
          ),
        ),
      );
    }

    final auth = context.watch<AuthService>();
    final isAdmin = auth.isAuthenticated && auth.isAdmin;
    final dupId = event.duplicateOf?.trim();
    final hasDupLink = dupId != null && dupId.isNotEmpty;
    final showDupSection =
        hasDupLink ||
        _loadingOriginal ||
        _originalEvent != null ||
        _loadingDuplicates ||
        _duplicateEvents.isNotEmpty;

    final contentInset = SpotDetailUi.contentHorizontalInset(context);

    return DetailImageCarouselFocus(
      carouselKey: _carouselKey,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 400,
              pinned: true,
              floating: false,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leadingWidth: contentInset + SpotDetailUi.appBarButtonSize,
              leading: Padding(
                padding: EdgeInsets.only(left: contentInset),
                child: _backButton(),
              ),
              actions: [
                if (isAdmin)
                  Padding(
                    padding: EdgeInsets.only(right: contentInset),
                    child: _adminMenuButton(l10n, event, hasDupLink),
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: DetailImageCarousel(
                  key: _carouselKey,
                  imageUrls: event.imageUrls,
                  emptyLabel: l10n.noImagesYet,
                  failedLabel: l10n.spotDetailImageFailedToLoad,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(SpotDetailUi.contentHorizontalPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: SpotDetailUi.maxContentWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 10),
                              child: Icon(
                                Icons.event_available_outlined,
                                size: 28,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                event.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                            ),
                          ],
                        ),
                        _buildShareActionRow(l10n),
                        const SizedBox(height: SpotDetailUi.detailTitleGap),
                        ..._buildEventMainContent(context, event, l10n),
                        if (showDupSection) ...[
                          const SizedBox(height: SpotDetailUi.detailFooterGap),
                          _buildDuplicateSection(
                            context,
                            l10n,
                            event,
                            hasDupLink,
                            dupId,
                          ),
                        ],
                        const SizedBox(height: SpotDetailUi.detailSectionGap),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSectionHeading(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  List<Widget> _buildEventMainContent(
    BuildContext context,
    ParkourEvent event,
    AppLocalizations l10n,
  ) {
    final websiteUrl = event.websiteUrl?.trim();
    final hasWebsite = websiteUrl != null && websiteUrl.isNotEmpty;
    final hasDescription = event.description?.trim().isNotEmpty == true;
    final hasLocation = event.latitude != null && event.longitude != null;
    final hasAddress = event.address?.trim().isNotEmpty == true;
    final hasLinkedSpots = event.spotIds.isNotEmpty;
    final hasWhereSection = hasLinkedSpots || hasLocation || hasAddress;
    final colors = Theme.of(context).colorScheme;

    final hostLabel = hasWebsite
        ? UrlService.displayHttpUrlHost(websiteUrl)
        : null;

    final widgets = <Widget>[
      EventDetailWhenBlock(
        startAt: event.startAt,
        endAt: event.endAt,
        startsLabel: l10n.eventDetailStartsLabel,
        endsLabel: l10n.eventDetailEndsLabel,
        todayLabel: l10n.spotDetailDateToday,
      ),
    ];

    if (hasDescription) {
      widgets.addAll([
        const SizedBox(height: SpotDetailUi.detailSectionGap),
        Text(
          event.description!.trim(),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ]);
    }

    if (hasWebsite) {
      widgets.addAll([
        SizedBox(
          height: hasDescription
              ? SpotDetailUi.detailSubsectionGap
              : SpotDetailUi.detailSectionGap,
        ),
        DetailExternalLinkTile(
          url: websiteUrl,
          caption: l10n.detailExternalLinkCaption,
          openSemanticsLabel: l10n.detailExternalLinkOpenSemantics(hostLabel!),
        ),
      ]);
    }

    if (hasWhereSection) {
      widgets.add(const SizedBox(height: SpotDetailUi.detailSectionGap));
    }

    if (hasLinkedSpots) {
      widgets.addAll([
        _detailSectionHeading(context, l10n.eventDetailLinkedSpotsLabel),
        const SizedBox(height: SpotDetailUi.detailLabelGap),
        _LinkedSpotsSection(
          spotIds: event.spotIds,
          emptyLabel: l10n.eventDetailNoLinkedSpots,
        ),
      ]);
    }

    if (hasLocation || hasAddress) {
      if (hasLinkedSpots) {
        widgets.add(const SizedBox(height: SpotDetailUi.detailSectionGap));
      }
      widgets.addAll([
        _detailSectionHeading(context, l10n.eventDetailLocationLabel),
        const SizedBox(height: SpotDetailUi.detailLabelGap),
        Container(
          width: double.infinity,
          padding: SpotDetailUi.detailCardPadding,
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
            border: SpotDetailUi.outlineBorder(colors),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined, color: colors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      hasAddress
                          ? event.address!.trim()
                          : '${event.latitude!.toStringAsFixed(5)}, ${event.longitude!.toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasLocation) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        _openMap(event.latitude!, event.longitude!),
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(l10n.eventDetailOpenInMaps),
                  ),
                ),
              ],
            ],
          ),
        ),
      ]);
    }

    widgets.add(
      EventDetailProvenanceLine(
        key: ValueKey(event.id),
        event: event,
        footerStyle: true,
      ),
    );

    return widgets;
  }

  Widget _buildDuplicateSection(
    BuildContext context,
    AppLocalizations l10n,
    ParkourEvent event,
    bool hasDupLink,
    String? dupId,
  ) {
    final theme = Theme.of(context);
    final secondaryColor = theme.colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDupLink || _originalEvent != null || _loadingOriginal)
          GestureDetector(
            onTap: _loadingOriginal
                ? null
                : () {
                    final targetId = _originalEvent?.id ?? dupId;
                    if (targetId != null && targetId.isNotEmpty) {
                      context.push('/event/$targetId');
                    }
                  },
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.copy_all,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(l10n.spotDetailDuplicateOf),
              subtitle: _loadingOriginal
                  ? Text(l10n.spotDetailLoading)
                  : Text(
                      _originalEvent?.title ??
                          l10n.eventDetailOriginalEventFallback,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
              trailing: Icon(
                Icons.open_in_new,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        if (!hasDupLink && _originalEvent == null && !_loadingOriginal) ...[
          if (_loadingDuplicates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.copy_all,
                color: Theme.of(context).colorScheme.secondary,
              ),
              title: Text(l10n.spotDetailAlsoBasedOn),
              subtitle: Text(l10n.spotDetailLoading),
            )
          else if (_duplicateEvents.isNotEmpty) ...[
            _detailSectionHeading(context, l10n.spotDetailAlsoBasedOn),
            const SizedBox(height: SpotDetailUi.detailLabelGap),
            ..._duplicateEvents.map((dup) {
              final id = dup.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius:
                      BorderRadius.circular(SpotDetailUi.surfaceRadius),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: id == null || id.isEmpty
                        ? null
                        : () => context.push('/event/$id'),
                    child: Container(
                      width: double.infinity,
                      padding: SpotDetailUi.detailCardPadding,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          SpotDetailUi.surfaceRadius,
                        ),
                        border: SpotDetailUi.outlineBorder(
                          theme.colorScheme,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.copy_all_outlined,
                            color: secondaryColor,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dup.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: secondaryColor,
                                  ),
                                ),
                                if (dup.eventSourceName?.trim().isNotEmpty ==
                                    true)
                                  Text(
                                    dup.eventSourceName!.trim(),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: secondaryColor.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.open_in_new,
                            size: 18,
                            color: secondaryColor.withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ],
    );
  }

  Future<void> _openMap(double lat, double lng) async {
    final mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
  }
}

enum _EventAdminAction { markDuplicate, removeDuplicate }

class _LinkedSpotsSection extends StatefulWidget {
  const _LinkedSpotsSection({
    required this.spotIds,
    required this.emptyLabel,
  });

  final List<String> spotIds;
  final String emptyLabel;

  @override
  State<_LinkedSpotsSection> createState() => _LinkedSpotsSectionState();
}

class _LinkedSpotsSectionState extends State<_LinkedSpotsSection> {
  Future<List<Spot>>? _spotsFuture;

  @override
  void initState() {
    super.initState();
    _spotsFuture = _loadSpots();
  }

  @override
  void didUpdateWidget(covariant _LinkedSpotsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spotIds.join(',') != widget.spotIds.join(',')) {
      _spotsFuture = _loadSpots();
    }
  }

  Future<List<Spot>> _loadSpots() async {
    final spotService = context.read<SpotService>();
    final spots = await Future.wait(
      widget.spotIds.map(spotService.getSpotById),
    );
    return spots.whereType<Spot>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FutureBuilder<List<Spot>>(
      future: _spotsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final spots = snapshot.data ?? const <Spot>[];
        if (spots.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              widget.emptyLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.65),
              ),
            ),
          );
        }
        return Column(
          children: List.generate(spots.length, (i) {
            final spot = spots[i];
            return Padding(
              padding: EdgeInsets.only(
                top: i > 0 ? SpotDetailUi.detailSubsectionGap : 0,
              ),
              child: Material(
                color: colors.surfaceContainerLow,
                borderRadius:
                    BorderRadius.circular(SpotDetailUi.surfaceRadius),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: spot.id == null
                      ? null
                      : () => context.push('/spot/${spot.id}'),
                  child: Container(
                    width: double.infinity,
                    padding: SpotDetailUi.detailCardPadding,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        SpotDetailUi.surfaceRadius,
                      ),
                      border: SpotDetailUi.outlineBorder(colors),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          color: colors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spot.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              if ((spot.address ?? spot.city)?.isNotEmpty ==
                                  true)
                                Text(
                                  spot.address ?? spot.city ?? '',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colors.onSurface.withValues(
                                          alpha: 0.65,
                                        ),
                                      ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
