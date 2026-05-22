import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import '../../constants/spot_detail_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/parkour_event.dart';
import '../../models/spot.dart';
import '../../models/spot_list.dart';
import '../../services/spot_list_service.dart';
import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/spot_service.dart';
import '../../services/search_state_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../utils/marker_icon_utils.dart';
import '../../widgets/location_info_box.dart';
import '../../services/web_share_service.dart';
import '../../widgets/detail_image_carousel.dart';
import '../../widgets/event_detail_provenance_line.dart';
import '../../widgets/event_detail_when_block.dart';
import '../../widgets/event_selection_dialog.dart';
import '../../widgets/moderator_action_fields.dart';
import '../../services/url_service.dart';
import '../../widgets/detail_duplicate_relationship.dart';
import '../../widgets/detail_external_link_tile.dart';
import '../../widgets/spot_detail_quick_action_chip.dart';
import '../../utils/web_meta_utils.dart';

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

  late final ValueNotifier<bool> _isSatelliteViewNotifier;
  BitmapDescriptor? _eventMapPinIcon;
  SearchStateService? _searchStateServiceRef;

  @override
  void initState() {
    super.initState();
    _isSatelliteViewNotifier = ValueNotifier<bool>(false);
    _loadEventMapPinIcon();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchStateServiceRef = Provider.of<SearchStateService>(
        context,
        listen: false,
      );
      _searchStateServiceRef!.addListener(_onSearchStateChanged);
      _isSatelliteViewNotifier.value = _searchStateServiceRef!.isSatellite;
    });
    _loadEvent();
  }

  @override
  void didUpdateWidget(covariant EventDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId) {
      _loadEvent();
    }
  }

  @override
  void dispose() {
    _searchStateServiceRef?.removeListener(_onSearchStateChanged);
    _isSatelliteViewNotifier.dispose();
    if (kIsWeb) {
      WebMetaUtils.resetPageMeta();
    }
    super.dispose();
  }

  void _onSearchStateChanged() {
    if (!mounted) return;
    final isSatellite = _searchStateServiceRef?.isSatellite ?? false;
    if (_isSatelliteViewNotifier.value != isSatellite) {
      _isSatelliteViewNotifier.value = isSatellite;
    }
  }

  Future<void> _loadEventMapPinIcon() async {
    final icon = await MarkerIconUtils.loadEventMapPin();
    if (mounted) {
      setState(() => _eventMapPinIcon = icon);
    }
  }

  String _eventMetaTitle(ParkourEvent event) => '${event.title} - Parkour·Spot';

  String _eventMetaDescription(ParkourEvent event) {
    final eventDescription = event.description?.trim();
    final baseDescription =
        eventDescription != null && eventDescription.isNotEmpty
        ? WebMetaUtils.clipForMeta(eventDescription)
        : 'View details, location, and linked spots for ${event.title} on Parkour·Spot';
    return '$baseDescription — ${WebMetaUtils.defaultDescription}';
  }

  void _updateEventPageMeta(ParkourEvent event) {
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WebMetaUtils.updatePageMeta(
        _eventMetaTitle(event),
        _eventMetaDescription(event),
      );
    });
  }

  void _resetEventPageMeta() {
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WebMetaUtils.resetPageMeta();
    });
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
      final e = await admin.getEventById(
        widget.eventId,
        throwOnFetchError: true,
      );
      if (!mounted) return;
      if (e == null) {
        setState(() {
          _loading = false;
          _event = null;
        });
        _resetEventPageMeta();
        return;
      }
      setState(() {
        _event = e;
        _loading = false;
      });
      _updateEventPageMeta(e);
      _attachDuplicateContext(e);
    } catch (e, st) {
      debugPrint('EventDetailScreen._loadEvent: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = true;
      });
      _resetEventPageMeta();
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
                      iconColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.75),
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

  Widget _staffMenuButton(
    AppLocalizations l10n,
    ParkourEvent event,
    bool hasDupLink,
    bool isAdmin,
    bool isModeratorOnly,
  ) {
    final isExternalEvent = !event.isNativeEvent;
    final shouldDisableEdit = isExternalEvent && isModeratorOnly;
    return PopupMenuButton<_EventStaffAction>(
      tooltip: isAdmin
          ? l10n.eventDetailAdminMenuTooltip
          : l10n.eventDetailStaffMenuTooltip,
      onSelected: (action) =>
          _onStaffMenu(context, action, event, isAdmin, isModeratorOnly),
      itemBuilder: (ctx) {
        final theme = Theme.of(ctx);
        final items = <PopupMenuEntry<_EventStaffAction>>[
          PopupMenuItem(
            value: _EventStaffAction.editEvent,
            enabled: !shouldDisableEdit,
            child: Row(
              children: [
                Icon(
                  Icons.edit,
                  color: shouldDisableEdit
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                      : theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.eventDetailAdminEditEvent,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: shouldDisableEdit
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.38,
                                )
                              : null,
                        ),
                      ),
                      Text(
                        shouldDisableEdit
                            ? l10n.eventDetailMenuEditEventSubtitleNative
                            : l10n.eventDetailMenuEditEventSubtitleMod,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ];
        if (isExternalEvent) {
          items.add(
            PopupMenuItem(
              value: _EventStaffAction.createNativeEvent,
              child: Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l10n.eventDetailMenuCreateNative)),
                ],
              ),
            ),
          );
        }
        items.add(
          PopupMenuItem(
            value: _EventStaffAction.markDuplicate,
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
        );
        if (hasDupLink) {
          items.add(
            PopupMenuItem(
              value: _EventStaffAction.removeDuplicate,
              child: Text(l10n.spotDetailMenuRemoveDuplicateStatus),
            ),
          );
        }
        return items;
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

  Future<void> _onStaffMenu(
    BuildContext context,
    _EventStaffAction action,
    ParkourEvent event,
    bool isAdmin,
    bool isModeratorOnly,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    final hasStaffAccess =
        auth.isAuthenticated &&
        auth.userProfile != null &&
        (auth.isAdmin || auth.isModerator);
    if (!hasStaffAccess) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventDetailMarkDuplicateStaffOnly)),
      );
      return;
    }
    final id = event.id;
    if (id == null) return;

    switch (action) {
      case _EventStaffAction.createNativeEvent:
        final result = await _showCreateNativeEventConfirmationDialog(event);
        if (result != null && result['confirmed'] == true && mounted) {
          await _createNativeEvent(event);
        }
        return;
      case _EventStaffAction.editEvent:
        final isExternalEvent = !event.isNativeEvent;
        if (isExternalEvent && isModeratorOnly) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.eventDetailExternalSourceCannotEdit),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: l10n.spotDetailOk,
                onPressed: () {},
              ),
            ),
          );
          return;
        }
        if (!isAdmin && !context.read<AuthService>().isModerator) return;
        final updated = await context.push<bool>('/admin/events/$id/edit');
        if (updated == true && mounted) {
          await _loadEvent();
        }
        return;
      case _EventStaffAction.markDuplicate:
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
      case _EventStaffAction.removeDuplicate:
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
                admin.error ?? l10n.eventDetailMarkDuplicateNotFoundOrInvalid,
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
    final isModeratorOnly = auth.isModerator && !auth.isAdmin;
    final hasStaffAccess =
        auth.isAuthenticated &&
        auth.userProfile != null &&
        (auth.isAdmin || auth.isModerator);
    final dupId = event.duplicateOf?.trim();
    final hasDupLink = dupId != null && dupId.isNotEmpty;
    final showDuplicateCallout =
        hasDupLink || _loadingOriginal || _originalEvent != null;
    final showLinkedDuplicates =
        !hasDupLink && (_loadingDuplicates || _duplicateEvents.isNotEmpty);

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
                if (hasStaffAccess)
                  Padding(
                    padding: EdgeInsets.only(right: contentInset),
                    child: _staffMenuButton(
                      l10n,
                      event,
                      hasDupLink,
                      isAdmin,
                      isModeratorOnly,
                    ),
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
                padding: const EdgeInsets.all(
                  SpotDetailUi.contentHorizontalPadding,
                ),
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
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ),
                          ],
                        ),
                        if (showDuplicateCallout) ...[
                          const SizedBox(
                            height: SpotDetailUi.detailSubsectionGap,
                          ),
                          DetailDuplicateOfCallout(
                            bannerTitle: l10n.eventDetailDuplicateBannerTitle,
                            bannerBody: l10n.eventDetailDuplicateBannerBody,
                            loadingLabel: l10n.spotDetailLoading,
                            originalFallback:
                                l10n.eventDetailOriginalEventFallback,
                            loading: _loadingOriginal,
                            originalTitle: _originalEvent?.title,
                            onOpenOriginal: _loadingOriginal
                                ? null
                                : () {
                                    final targetId =
                                        _originalEvent?.id ?? dupId;
                                    if (targetId != null &&
                                        targetId.isNotEmpty) {
                                      context.push('/event/$targetId');
                                    }
                                  },
                          ),
                        ],
                        _buildShareActionRow(l10n),
                        const SizedBox(height: SpotDetailUi.detailTitleGap),
                        ..._buildEventMainContent(context, event, l10n),
                        if (showLinkedDuplicates) ...[
                          DetailLinkedDuplicatesSection(
                            heading: l10n.eventDetailLinkedDuplicatesHeading,
                            loadingLabel: l10n.spotDetailLoading,
                            loading: _loadingDuplicates,
                            items: _duplicateEvents
                                .where((e) => e.id?.trim().isNotEmpty == true)
                                .map(
                                  (e) => DetailDuplicateLinkItem(
                                    id: e.id!,
                                    title: e.title,
                                    subtitle: e.eventSourceName?.trim(),
                                  ),
                                )
                                .toList(),
                            onOpenItem: (id) => context.push('/event/$id'),
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
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
    final hasLinkedSpotLists = event.spotListIds.isNotEmpty;
    final hasWhereSection =
        hasLinkedSpots || hasLinkedSpotLists || hasLocation || hasAddress;

    final hostLabel = hasWebsite
        ? UrlService.displayHttpUrlHost(websiteUrl)
        : null;

    final widgets = <Widget>[
      EventDetailWhenBlock(
        startAt: event.startAt,
        endAt: event.endAt,
        isDateOnly: event.isDateOnly,
        timeZone: event.timeZone,
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

    if (hasLinkedSpotLists) {
      if (hasLinkedSpots) {
        widgets.add(const SizedBox(height: SpotDetailUi.detailSectionGap));
      }
      widgets.addAll([
        _detailSectionHeading(context, l10n.eventDetailLinkedSpotListsLabel),
        const SizedBox(height: SpotDetailUi.detailLabelGap),
        _LinkedSpotListsSection(
          spotListIds: event.spotListIds,
          emptyLabel: l10n.eventDetailNoLinkedSpotLists,
        ),
      ]);
    }

    if (hasLocation || hasAddress) {
      if (hasLinkedSpots || hasLinkedSpotLists) {
        widgets.add(const SizedBox(height: SpotDetailUi.detailSectionGap));
      }
      widgets.addAll([
        _detailSectionHeading(context, l10n.eventDetailLocationLabel),
        const SizedBox(height: SpotDetailUi.detailLabelGap),
        ..._buildDirectLocationSection(context, event, l10n),
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

  List<Widget> _buildDirectLocationSection(
    BuildContext context,
    ParkourEvent event,
    AppLocalizations l10n,
  ) {
    final hasLocation = event.latitude != null && event.longitude != null;
    final hasAddress = event.address?.trim().isNotEmpty == true;
    final colors = Theme.of(context).colorScheme;
    final widgets = <Widget>[];

    if (hasLocation) {
      widgets.addAll([
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
            border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: _isSatelliteViewNotifier,
                builder: (context, isSatellite, child) {
                  return GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(event.latitude!, event.longitude!),
                      zoom: 16,
                    ),
                    mapType: isSatellite ? MapType.hybrid : MapType.normal,
                    markers: {
                      Marker(
                        markerId: MarkerId(event.id ?? 'event'),
                        position: LatLng(event.latitude!, event.longitude!),
                        icon:
                            _eventMapPinIcon ?? BitmapDescriptor.defaultMarker,
                        anchor: const Offset(0.5, 1.0),
                        onTap: null,
                        consumeTapEvents: true,
                        infoWindow: InfoWindow.noText,
                      ),
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    liteModeEnabled: kIsWeb,
                    compassEnabled: false,
                    zoomGesturesEnabled: false,
                    scrollGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    indoorViewEnabled: false,
                    trafficEnabled: false,
                  );
                },
              ),
              Positioned.fill(
                child: PointerInterceptor(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _locateEventOnMap,
                      borderRadius: BorderRadius.circular(
                        SpotDetailUi.surfaceRadius,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                right: 10,
                child: PointerInterceptor(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _isSatelliteViewNotifier,
                    builder: (context, isSatellite, child) {
                      return FloatingActionButton(
                        onPressed: () {
                          _isSatelliteViewNotifier.value = !isSatellite;
                          final searchState = Provider.of<SearchStateService>(
                            context,
                            listen: false,
                          );
                          searchState.setSatellite(
                            _isSatelliteViewNotifier.value,
                          );
                        },
                        heroTag: 'eventDetailMapTypeToggleFab',
                        mini: true,
                        tooltip: isSatellite
                            ? l10n.spotDetailMapSwitchToMap
                            : l10n.spotDetailMapSwitchToSatellite,
                        child: Icon(isSatellite ? Icons.map : Icons.terrain),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: PointerInterceptor(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          MobileDetectionService.isMobileDevice
                              ? Icons.phone_android
                              : Icons.touch_app,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.spotDetailMapLocateOnMap,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LocationInfoBox(
          latitude: event.latitude!,
          longitude: event.longitude!,
          address: hasAddress ? event.address!.trim() : null,
          countryCode: event.countryCode,
          onOpenInMaps: () => _openInMaps(event.latitude!, event.longitude!),
          onCopyAddress: hasAddress
              ? () => _copyAddressToClipboard(event.address!.trim())
              : null,
        ),
      ]);
    } else if (hasAddress) {
      widgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
          ),
          child: GestureDetector(
            onTap: () => _copyAddressToClipboard(event.address!.trim()),
            child: SelectableText(
              event.address!.trim(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colors.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  void _locateEventOnMap() {
    final id = _event?.id;
    if (id != null && id.isNotEmpty) {
      context.go('/explore?locateEventId=$id');
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    try {
      final zoom = _searchStateServiceRef?.zoom;
      final isSatellite = _searchStateServiceRef?.isSatellite ?? false;
      await UrlService.openLocationInMaps(
        lat,
        lng,
        zoom: zoom,
        isSatellite: isSatellite,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.spotDetailOpenMapsFailed('$e'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyAddressToClipboard(String address) async {
    if (address.isEmpty) return;

    try {
      await Clipboard.setData(ClipboardData(text: address));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.spotDetailAddressCopiedToClipboard,
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.spotDetailCopyAddressFailed('$e'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?> _showCreateNativeEventConfirmationDialog(
    ParkourEvent event,
  ) async {
    if (event.isNativeEvent) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.eventDetailNotExternalSource,
          ),
        ),
      );
      return null;
    }

    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated || auth.currentUser == null) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.eventDetailMustBeLoggedInCreateNative,
          ),
        ),
      );
      return null;
    }

    final notesController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        final dialogL10n = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(dialogL10n.eventDetailCreateNativeDialogTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dialogL10n.eventDetailCreateNativeDialogBody),
                const SizedBox(height: 16),
                ModeratorActionFields(
                  spotId: null,
                  notesController: notesController,
                  showReportSelector: false,
                  onReportSelected: (_) {},
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                notesController.dispose();
                Navigator.of(dialogContext).pop(null);
              },
              child: Text(dialogL10n.profileCancel),
            ),
            ElevatedButton(
              onPressed: () {
                notesController.dispose();
                Navigator.of(dialogContext).pop({'confirmed': true});
              },
              child: Text(dialogL10n.spotDetailCreateButton),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNativeEvent(ParkourEvent event) async {
    final l10n = AppLocalizations.of(context)!;
    final eventId = event.id;
    if (eventId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventDetailUnableCreateNativeNow)),
      );
      return;
    }

    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated || auth.currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.eventDetailMustBeLoggedInCreateNative)),
      );
      return;
    }

    final admin = context.read<AdminEventsService>();
    final userId = auth.currentUser!.uid;

    try {
      final nativeEventId = await admin.createNativeEventFromExisting(
        event,
        userId,
      );

      if (nativeEventId == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(admin.error ?? l10n.eventDetailFailedCreateNative),
          ),
        );
        return;
      }

      final success = await admin.markEventAsDuplicate(
        duplicateEventId: eventId,
        nativeOriginalEventId: nativeEventId,
      );

      if (!mounted) return;

      if (success) {
        try {
          final createdOriginal = await admin.getEventById(nativeEventId);
          if (mounted && createdOriginal != null) {
            setState(() => _originalEvent = createdOriginal);
          }
        } catch (_) {
          // UI refresh below still runs
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.eventDetailNativeCreatedDuplicateMarked)),
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.eventDetailFailedCreateNative}: $e')),
      );
    }
  }
}

enum _EventStaffAction {
  editEvent,
  createNativeEvent,
  markDuplicate,
  removeDuplicate,
}

class _LinkedSpotListsSection extends StatefulWidget {
  const _LinkedSpotListsSection({
    required this.spotListIds,
    required this.emptyLabel,
  });

  final List<String> spotListIds;
  final String emptyLabel;

  @override
  State<_LinkedSpotListsSection> createState() =>
      _LinkedSpotListsSectionState();
}

class _LinkedSpotListsSectionState extends State<_LinkedSpotListsSection> {
  Future<List<SpotList>>? _listsFuture;

  @override
  void initState() {
    super.initState();
    _listsFuture = _loadLists();
  }

  @override
  void didUpdateWidget(covariant _LinkedSpotListsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spotListIds.join(',') != widget.spotListIds.join(',')) {
      _listsFuture = _loadLists();
    }
  }

  Future<List<SpotList>> _loadLists() async {
    final spotListService = context.read<SpotListService>();
    final lists = await Future.wait(
      widget.spotListIds.map(spotListService.getSpotListById),
    );
    return lists.whereType<SpotList>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return FutureBuilder<List<SpotList>>(
      future: _listsFuture,
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
        final lists = snapshot.data ?? const <SpotList>[];
        if (lists.isEmpty) {
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: lists.map((list) {
            final listId = list.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: listId == null
                    ? null
                    : () => context.push('/list/$listId'),
                borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
                child: Container(
                  width: double.infinity,
                  padding: SpotDetailUi.detailCardPadding,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(
                      SpotDetailUi.surfaceRadius,
                    ),
                    border: SpotDetailUi.outlineBorder(colors),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.list, color: colors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              list.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              '${list.visibility.label} · ${list.spotCount} spots',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colors.onSurface.withValues(
                                      alpha: 0.65,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      if (listId != null)
                        Icon(
                          Icons.chevron_right,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _LinkedSpotsSection extends StatefulWidget {
  const _LinkedSpotsSection({required this.spotIds, required this.emptyLabel});

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
                borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
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
                                  style: Theme.of(context).textTheme.bodySmall
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
