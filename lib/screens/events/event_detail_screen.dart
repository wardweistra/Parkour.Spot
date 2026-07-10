import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../constants/spot_detail_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../models/parkour_event.dart';
import '../../models/spot.dart';
import '../../models/spot_list.dart';
import '../../services/spot_list_service.dart';
import '../../services/admin_events_service.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/spot_service.dart';
import '../../services/search_state_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/event_report_service.dart';
import '../../utils/browser_timezone_utils.dart';
import '../../utils/event_location_utils.dart';
import '../../utils/event_schedule_utils.dart';
import '../../utils/location_permission_utils.dart';
import '../../utils/map_recentering_mixin.dart';
import '../../utils/event_suggestion_utils.dart';
import '../../utils/marker_icon_utils.dart';
import '../../utils/image_preparation.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/location_info_box.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_config.dart';
import '../../widgets/spot_form/location_section.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_screen.dart';
import '../../services/web_share_service.dart';
import '../../utils/share_link_text.dart';
import '../../widgets/admin/admin_image_urls_overview_dialog.dart';
import '../../widgets/detail_action_menu_item.dart';
import '../../widgets/detail_image_carousel.dart';
import '../../widgets/event_detail_provenance_line.dart';
import '../../widgets/event_detail_when_block.dart';
import '../../widgets/event_duplicate_report_dialog.dart';
import '../../widgets/event_selection_dialog.dart';
import '../../widgets/moderator_action_fields.dart';
import '../../services/url_service.dart';
import '../../widgets/detail_duplicate_relationship.dart';
import '../../widgets/detail_external_link_tile.dart';
import '../../widgets/spot_detail_quick_action_chip.dart';
import '../../widgets/resized_spot_image.dart';
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
      final e = await admin.getEventById(widget.eventId);
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

  String? _duplicateEventSourceLabel(ParkourEvent event) {
    final sourceName = event.eventSourceName?.trim();
    if (sourceName != null && sourceName.isNotEmpty) {
      return sourceName;
    }
    final sourceId = event.eventSourceId?.trim();
    if (sourceId != null && sourceId.isNotEmpty) {
      return sourceId;
    }
    return null;
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
      final text = ShareLinkText.clipboardText(ShareLinkKind.event, label, url);

      final outcome = await WebShareService.tryShareLink(
        text: ShareLinkText.shareLabel(ShareLinkKind.event, label),
        url: url,
      );
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

  String? _eventSuggestionBlockedReason(
    ParkourEvent event,
    AppLocalizations l10n,
  ) {
    return switch (eventSuggestionBlockedReasonKey(event)) {
      'eventDetailCannotSuggestForDuplicate' =>
        l10n.eventDetailCannotSuggestForDuplicate,
      'eventDetailUnableSuggestNow' => l10n.eventDetailUnableSuggestNow,
      _ => null,
    };
  }

  Future<void> _showSuggestPhotoDialog() async {
    final event = _event;
    if (event == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final blockedReason = _eventSuggestionBlockedReason(event, l10n);
    if (blockedReason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blockedReason), backgroundColor: Colors.red),
      );
      return;
    }

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _SuggestEventPhotoDialog(event: event),
    );
    if (!mounted) return;
    if (submitted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.eventDetailThanksPhotoSuggestion),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showSuggestEditDialog() async {
    final event = _event;
    if (event == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final blockedReason = _eventSuggestionBlockedReason(event, l10n);
    if (blockedReason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blockedReason), backgroundColor: Colors.red),
      );
      return;
    }

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _SuggestEventEditDialog(event: event),
    );
    if (!mounted) return;
    if (submitted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.eventDetailThanksEditSuggestion),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showFlagDuplicateDialog() async {
    final event = _event;
    if (event == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final blockedReason = _eventSuggestionBlockedReason(event, l10n);
    if (blockedReason != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(blockedReason), backgroundColor: Colors.red),
      );
      return;
    }

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => EventDuplicateReportDialog(event: event),
    );
    if (!mounted) return;
    if (submitted == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.eventDetailThanksDuplicateSuggestion),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildShareActionRow(
    AppLocalizations l10n,
    ParkourEvent event,
    bool hasDupLink,
    bool isAdmin,
    bool isModeratorOnly,
    bool hasStaffAccess,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _eventEditMenuButton(
              l10n: l10n,
              event: event,
              hasDupLink: hasDupLink,
              isAdmin: isAdmin,
              isModeratorOnly: isModeratorOnly,
              hasStaffAccess: hasStaffAccess,
            ),
            const SizedBox(width: 8),
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

  String _eventMenuSuggestSubtitle(
    AppLocalizations l10n,
    ParkourEvent event, {
    required bool isPhoto,
  }) {
    return switch (eventSuggestionBlockedReasonKey(event)) {
      null =>
        isPhoto
            ? l10n.eventDetailMenuSuggestPhotoSubtitleYes
            : l10n.eventDetailMenuSuggestEditSubtitleYes,
      'eventDetailCannotSuggestForDuplicate' =>
        isPhoto
            ? l10n.eventDetailMenuSuggestPhotoSubtitleNo
            : l10n.eventDetailMenuSuggestEditSubtitleNo,
      _ => l10n.eventDetailMenuSuggestBlockedUnavailable,
    };
  }

  String _eventMenuFlagDuplicateSubtitle(
    AppLocalizations l10n,
    ParkourEvent event,
  ) {
    return switch (eventSuggestionBlockedReasonKey(event)) {
      null => l10n.eventDetailMenuFlagDuplicateSubtitleYes,
      'eventDetailCannotSuggestForDuplicate' =>
        l10n.eventDetailMenuFlagDuplicateSubtitleNo,
      _ => l10n.eventDetailMenuSuggestBlockedUnavailable,
    };
  }

  Widget _eventEditMenuButton({
    required AppLocalizations l10n,
    required ParkourEvent event,
    required bool hasDupLink,
    required bool isAdmin,
    required bool isModeratorOnly,
    required bool hasStaffAccess,
  }) {
    final theme = Theme.of(context);
    final isExternalEvent = !event.isNativeEvent;
    final shouldDisableEdit = isExternalEvent && isModeratorOnly;
    final suggestionBlockedReason = _eventSuggestionBlockedReason(event, l10n);
    final canSuggest = suggestionBlockedReason == null;
    final suggestPhotoSubtitle = _eventMenuSuggestSubtitle(
      l10n,
      event,
      isPhoto: true,
    );
    final suggestEditSubtitle = _eventMenuSuggestSubtitle(
      l10n,
      event,
      isPhoto: false,
    );
    final flagDuplicateSubtitle = _eventMenuFlagDuplicateSubtitle(l10n, event);

    return PopupMenuButton<_EventEditMenuAction>(
      position: PopupMenuPosition.under,
      tooltip: l10n.spotDetailEditReportTooltip,
      borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
      splashRadius: 20,
      onSelected: (action) =>
          _onEditMenuAction(context, action, event, isAdmin, isModeratorOnly),
      itemBuilder: (ctx) {
        final items = <PopupMenuEntry<_EventEditMenuAction>>[
          PopupMenuItem<_EventEditMenuAction>(
            value: _EventEditMenuAction.suggestPhoto,
            enabled: canSuggest,
            child: DetailActionMenuItem(
              icon: Icons.add_photo_alternate_outlined,
              title: l10n.eventDetailQuickActionSuggestPhoto,
              subtitle: suggestPhotoSubtitle,
              enabled: canSuggest,
            ),
          ),
          PopupMenuItem<_EventEditMenuAction>(
            value: _EventEditMenuAction.suggestEdit,
            enabled: canSuggest,
            child: DetailActionMenuItem(
              icon: Icons.edit_note_outlined,
              title: l10n.eventDetailQuickActionSuggestEdit,
              subtitle: suggestEditSubtitle,
              enabled: canSuggest,
            ),
          ),
          PopupMenuItem<_EventEditMenuAction>(
            value: _EventEditMenuAction.flagDuplicate,
            enabled: canSuggest,
            child: DetailActionMenuItem(
              icon: Icons.copy_all_outlined,
              title: l10n.eventDetailMenuFlagDuplicate,
              subtitle: flagDuplicateSubtitle,
              enabled: canSuggest,
            ),
          ),
        ];

        if (hasStaffAccess) {
          items.add(const PopupMenuDivider());
          items.add(
            PopupMenuItem<_EventEditMenuAction>(
              value: _EventEditMenuAction.editEvent,
              enabled: !shouldDisableEdit,
              child: DetailActionMenuItem(
                icon: Icons.edit,
                title: l10n.eventDetailAdminEditEvent,
                subtitle: shouldDisableEdit
                    ? l10n.eventDetailMenuEditEventSubtitleNative
                    : l10n.eventDetailMenuEditEventSubtitleMod,
                enabled: !shouldDisableEdit,
              ),
            ),
          );

          if (isExternalEvent) {
            items.add(
              PopupMenuItem<_EventEditMenuAction>(
                value: _EventEditMenuAction.createNativeEvent,
                child: DetailActionMenuItem(
                  icon: Icons.add_circle_outline,
                  title: l10n.eventDetailMenuCreateNative,
                  subtitle: l10n.eventDetailMenuCreateNativeSubtitle,
                ),
              ),
            );
          }

          items.add(
            PopupMenuItem<_EventEditMenuAction>(
              value: _EventEditMenuAction.markDuplicate,
              enabled: !hasDupLink,
              child: DetailActionMenuItem(
                icon: Icons.copy_all,
                title: l10n.spotDetailMenuMarkDuplicate,
                subtitle: hasDupLink
                    ? l10n.spotDetailMenuMarkDuplicateSubtitleDup
                    : l10n.spotDetailMenuMarkDuplicateSubtitleMod,
                enabled: !hasDupLink,
              ),
            ),
          );

          if (hasDupLink) {
            items.add(
              PopupMenuItem<_EventEditMenuAction>(
                value: _EventEditMenuAction.removeDuplicate,
                child: DetailActionMenuItem(
                  icon: Icons.clear,
                  title: l10n.spotDetailMenuRemoveDuplicateStatus,
                  subtitle: l10n.spotDetailMenuRemoveDuplicateSubtitle,
                ),
              ),
            );
          }

          if (isAdmin && event.imageUrls.isNotEmpty) {
            items.add(
              PopupMenuItem<_EventEditMenuAction>(
                value: _EventEditMenuAction.viewImageUrls,
                child: DetailActionMenuItem(
                  icon: Icons.photo_library_outlined,
                  title: l10n.spotDetailMenuImageUrls,
                  subtitle: l10n.spotDetailMenuImageUrlsSubtitle,
                ),
              ),
            );
          }
        }

        return items;
      },
      child: SpotDetailQuickActionChip(
        icon: Icons.edit_outlined,
        iconColor: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        label: l10n.spotDetailQuickActionEdit,
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

  Future<void> _onEditMenuAction(
    BuildContext context,
    _EventEditMenuAction action,
    ParkourEvent event,
    bool isAdmin,
    bool isModeratorOnly,
  ) async {
    switch (action) {
      case _EventEditMenuAction.suggestPhoto:
        await _showSuggestPhotoDialog();
        return;
      case _EventEditMenuAction.suggestEdit:
        await _showSuggestEditDialog();
        return;
      case _EventEditMenuAction.flagDuplicate:
        await _showFlagDuplicateDialog();
        return;
      case _EventEditMenuAction.editEvent:
        await _onStaffMenu(
          context,
          _EventStaffAction.editEvent,
          event,
          isAdmin,
          isModeratorOnly,
        );
        return;
      case _EventEditMenuAction.createNativeEvent:
        await _onStaffMenu(
          context,
          _EventStaffAction.createNativeEvent,
          event,
          isAdmin,
          isModeratorOnly,
        );
        return;
      case _EventEditMenuAction.markDuplicate:
        await _onStaffMenu(
          context,
          _EventStaffAction.markDuplicate,
          event,
          isAdmin,
          isModeratorOnly,
        );
        return;
      case _EventEditMenuAction.removeDuplicate:
        await _onStaffMenu(
          context,
          _EventStaffAction.removeDuplicate,
          event,
          isAdmin,
          isModeratorOnly,
        );
        return;
      case _EventEditMenuAction.viewImageUrls:
        if (event.imageUrls.isEmpty) return;
        await showAdminImageUrlsOverviewDialog(
          context,
          imageUrls: event.imageUrls,
          entityLabel: event.title,
          showSpotsApiUrls: true,
        );
        return;
    }
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
          builder: (c) => EventSelectionDialog(
            currentEventId: id,
            referenceStartAt: event.startAt,
            referenceEndAt: event.endAt,
          ),
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
              actions: const [],
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
                        _buildShareActionRow(
                          l10n,
                          event,
                          hasDupLink,
                          isAdmin,
                          isModeratorOnly,
                          hasStaffAccess,
                        ),
                        const SizedBox(height: SpotDetailUi.detailTitleGap),
                        ..._buildEventMainContent(context, event, l10n),
                        if (showLinkedDuplicates) ...[
                          DetailLinkedDuplicatesSection(
                            heading: l10n.spotDetailAlsoBasedOn,
                            loadingLabel: l10n.spotDetailLoading,
                            loading: _loadingDuplicates,
                            items: _duplicateEvents
                                .where((e) => e.id?.trim().isNotEmpty == true)
                                .map(
                                  (e) => DetailDuplicateLinkItem(
                                    id: e.id!,
                                    title: e.title,
                                    subtitle: _duplicateEventSourceLabel(e),
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
      final spotsHeading = hasLinkedSpotLists
          ? l10n.eventDetailEventSpotLocationsLabel
          : l10n.eventDetailEventSpotsLabel;
      widgets.addAll([
        _detailSectionHeading(context, spotsHeading),
        const SizedBox(height: SpotDetailUi.detailLabelGap),
        _LinkedSpotsSection(
          spotIds: event.spotIds,
          emptyLabel: l10n.eventDetailNoEventSpotLocations,
        ),
      ]);
    }

    if (hasLinkedSpotLists) {
      if (hasLinkedSpots) {
        widgets.add(const SizedBox(height: SpotDetailUi.detailSectionGap));
      }
      widgets.addAll([
        _detailSectionHeading(context, l10n.eventDetailEventSpotsLabel),
        const SizedBox(height: SpotDetailUi.detailLabelGap),
        _LinkedSpotListsSection(
          spotListIds: event.spotListIds,
          emptyLabel: l10n.eventDetailNoEventSpots,
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

class _SuggestEventPhotoDialog extends StatefulWidget {
  const _SuggestEventPhotoDialog({required this.event});

  final ParkourEvent event;

  @override
  State<_SuggestEventPhotoDialog> createState() =>
      _SuggestEventPhotoDialogState();
}

class _SuggestEventPhotoDialogState extends State<_SuggestEventPhotoDialog> {
  final TextEditingController _emailController = TextEditingController();
  final List<Uint8List> _selectedImageBytes = <Uint8List>[];
  bool _submitting = false;
  String? _error;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _emailController.text =
        auth.userProfile?.email.trim() ?? auth.currentUser?.email?.trim() ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _validEmail(String value) => _emailRegex.hasMatch(value);

  Future<void> _pickImagesFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (pickedFiles.isEmpty || !mounted) return;

      for (final pickedFile in pickedFiles) {
        if (_selectedImageBytes.length >=
            EventReportService.maxSuggestedPhotos) {
          break;
        }
        final bytes = await pickedFile.readAsBytes();
        final prepared = await prepareImageForUpload(bytes);
        _selectedImageBytes.add(prepared.bytes);
      }
      if (mounted) setState(() {});
    } on ImagePreparationException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      if (_selectedImageBytes.length >= EventReportService.maxSuggestedPhotos) {
        return;
      }
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );
      if (pickedFile == null || !mounted) return;
      final bytes = await pickedFile.readAsBytes();
      final prepared = await prepareImageForUpload(bytes);
      setState(() => _selectedImageBytes.add(prepared.bytes));
    } on ImagePreparationException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    final isLoggedIn = auth.isAuthenticated && auth.userProfile != null;
    final trimmedEmail = _emailController.text.trim();
    if (!isLoggedIn) {
      if (trimmedEmail.isEmpty) {
        setState(() => _error = l10n.spotDetailEmailRequired);
        return;
      }
      if (!_validEmail(trimmedEmail)) {
        setState(() => _error = l10n.spotDetailEmailInvalid);
        return;
      }
    }
    if (_selectedImageBytes.isEmpty) {
      setState(() => _error = l10n.eventDetailSuggestPhotosPickRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final eventService = context.read<EventReportService>();
      final uploadedUrls = await eventService.uploadSuggestedEventPhotos(
        _selectedImageBytes,
      );
      final contactEmail = isLoggedIn
          ? (trimmedEmail.isNotEmpty
                ? trimmedEmail
                : auth.userProfile!.email.trim())
          : trimmedEmail;
      final ok = await eventService.submitEventPhotoSuggestion(
        targetEventId: widget.event.id!,
        targetEventTitle: widget.event.title,
        startAt: widget.event.startAt,
        endAt: widget.event.endAt,
        isDateOnly: widget.event.isDateOnly,
        timeZone: widget.event.timeZone,
        existingSpotIds: widget.event.spotIds,
        existingSpotListIds: widget.event.spotListIds,
        suggestedPhotoUrls: uploadedUrls,
        reporterUserId: auth.currentUser?.uid,
        reporterName:
            auth.userProfile?.displayName ??
            auth.currentUser?.displayName ??
            auth.currentUser?.email,
        reporterEmail: contactEmail.isEmpty ? null : contactEmail,
      );

      if (!mounted) return;
      if (!ok) {
        setState(() => _error = l10n.eventDetailSuggestPhotosSubmitFailed);
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.eventDetailSuggestPhotosSubmitError('$e'));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final auth = context.read<AuthService>();
    final isLoggedIn = auth.isAuthenticated && auth.userProfile != null;
    return AlertDialog(
      title: Text(l10n.eventDetailSuggestPhotosTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.eventDetailSuggestPhotosIntro),
              const SizedBox(height: 12),
              if (!isLoggedIn) ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (_error != null) {
                      setState(() => _error = null);
                    }
                  },
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    labelText: l10n.spotDetailReportEmailLabel,
                    hintText: l10n.spotDetailReportEmailLabel,
                    helperText: l10n.spotDetailSuggestPhotosEmailHelper,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.mail,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _emailController.text.isNotEmpty
                              ? l10n.spotDetailReportReachOutAt(
                                  _emailController.text,
                                )
                              : l10n.spotDetailReportReachOutAccount,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_selectedImageBytes.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_selectedImageBytes.length, (index) {
                    final bytes = _selectedImageBytes[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            bytes,
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: _submitting
                                  ? null
                                  : () => setState(
                                      () => _selectedImageBytes.removeAt(index),
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              child: const Padding(
                                padding: EdgeInsets.all(2),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickImagesFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(l10n.addSpotGalleryButton),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _submitting ? null : _takePhoto,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: Text(l10n.addSpotCameraButton),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.addEventMaxPhotos(EventReportService.maxSuggestedPhotos),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(l10n.profileCancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.spotDetailSubmit),
        ),
      ],
    );
  }
}

class _SuggestEventEditDialog extends StatefulWidget {
  const _SuggestEventEditDialog({required this.event});

  final ParkourEvent event;

  @override
  State<_SuggestEventEditDialog> createState() =>
      _SuggestEventEditDialogState();
}

class _SuggestEventEditDialogState extends State<_SuggestEventEditDialog>
    with MapRecenteringMixin {
  final TextEditingController _emailController = TextEditingController();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _websiteController;
  late final TextEditingController _locationAddressController;
  final TextEditingController _scheduleDisplayController =
      TextEditingController();
  late final List<String> _timeZoneOptions;
  late final String _originalTimeZoneSelection;
  String? _originalNormalizedTimeZone;
  bool _timeZoneManuallySet = false;
  late final String _browserTimeZone;
  int _timeZoneLookupGeneration = 0;
  late bool _suggestedIsDateOnly;
  late String _selectedTimeZone;
  late DateTime _suggestedStartAt;
  DateTime? _suggestedEndAt;
  late List<Spot> _suggestedLinkedSpots;
  LatLng? _suggestedLocation;
  Position? _currentPosition;
  late LatLng _mapFallbackCenter;
  String? _suggestedAddress;
  String? _suggestedCity;
  String? _suggestedCountryCode;
  String? _resolvedAddressInput;
  bool _locationCleared = false;
  bool _isGeocoding = false;
  bool _isGettingLocation = false;
  bool _isSatelliteView = false;
  bool _isLocationPermissionDenied = false;
  bool _isSchedulePickerOpen = false;
  bool _scheduleDisplayInitialized = false;
  SearchStateService? _searchStateServiceRef;
  bool _submitting = false;
  String? _error;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  LatLng get _displayLocationForMap {
    if (_suggestedLocation != null) return _suggestedLocation!;
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }
    return _mapFallbackCenter;
  }

  List<Spot> get _mapDisplaySpots => List<Spot>.from(_suggestedLinkedSpots);

  List<LatLng> _mapMarkerLocations() {
    final locations = <LatLng>[];
    if (_suggestedLocation != null) {
      locations.add(_suggestedLocation!);
    }
    for (final spot in _mapDisplaySpots) {
      if (spotHasCoordinates(spot)) {
        locations.add(LatLng(spot.latitude, spot.longitude));
      }
    }
    if (locations.isNotEmpty) return locations;

    if (_currentPosition != null) {
      return [
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      ];
    }
    return [_mapFallbackCenter];
  }

  void _recenterMapForDisplay() {
    recenterMapForLocationsAfterBuild(_mapMarkerLocations());
  }

  @override
  void initState() {
    super.initState();
    _browserTimeZone = detectIanaTimeZone();
    _mapFallbackCenter = const LatLng(
      AppConfig.defaultMapCenterLat,
      AppConfig.defaultMapCenterLng,
    );
    final auth = context.read<AuthService>();
    _emailController.text =
        auth.userProfile?.email.trim() ?? auth.currentUser?.email?.trim() ?? '';
    _titleController = TextEditingController(text: widget.event.title.trim());
    _descriptionController = TextEditingController(
      text: widget.event.description?.trim() ?? '',
    );
    _websiteController = TextEditingController(
      text: widget.event.websiteUrl?.trim() ?? '',
    );
    final originalAddress = widget.event.address?.trim();
    _locationAddressController = TextEditingController(
      text: originalAddress?.isNotEmpty == true ? originalAddress : '',
    );
    _timeZoneOptions = EventScheduleUtils.availableTimeZoneIds();
    _originalNormalizedTimeZone = EventScheduleUtils.normalizeTimeZone(
      widget.event.timeZone,
    );
    _originalTimeZoneSelection =
        _originalNormalizedTimeZone ?? _browserTimeZone;
    _selectedTimeZone = _originalTimeZoneSelection;
    if (!_timeZoneOptions.contains(_selectedTimeZone)) {
      _timeZoneOptions.insert(0, _selectedTimeZone);
    }
    _suggestedIsDateOnly = widget.event.isDateOnly;
    _suggestedStartAt = widget.event.startAt;
    _suggestedEndAt = widget.event.endAt;
    _suggestedLinkedSpots = widget.event.spotIds
        .map(
          (id) => Spot(
            id: id,
            name: id,
            description: '',
            latitude: 0,
            longitude: 0,
          ),
        )
        .toList(growable: true);
    if (widget.event.latitude != null && widget.event.longitude != null) {
      _suggestedLocation = LatLng(
        widget.event.latitude!,
        widget.event.longitude!,
      );
    }
    _suggestedAddress = originalAddress?.isNotEmpty == true
        ? originalAddress
        : null;
    _resolvedAddressInput = _suggestedAddress;
    _suggestedCity = widget.event.city;
    _suggestedCountryCode = widget.event.countryCode;
    _loadSuggestedLinkedSpots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchStateServiceRef = Provider.of<SearchStateService>(
        context,
        listen: false,
      );
      _searchStateServiceRef!.addListener(_onSearchStateChanged);
      setState(() => _isSatelliteView = _searchStateServiceRef!.isSatellite);
      _recenterMapForDisplay();
      _syncTimeZoneFromLocation();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_scheduleDisplayInitialized) {
      _scheduleDisplayInitialized = true;
      _syncScheduleDisplayControllers();
    }
    _recenterMapForDisplay();
  }

  void _onSearchStateChanged() {
    if (!mounted) return;
    final searchState = _searchStateServiceRef;
    if (searchState == null) return;
    setState(() => _isSatelliteView = searchState.isSatellite);
  }

  @override
  void dispose() {
    _searchStateServiceRef?.removeListener(_onSearchStateChanged);
    _emailController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _locationAddressController.dispose();
    _scheduleDisplayController.dispose();
    super.dispose();
  }

  bool _validEmail(String value) => _emailRegex.hasMatch(value);

  bool _validWebsite(String value) {
    final parsed = Uri.tryParse(value);
    return parsed != null &&
        parsed.hasAuthority &&
        (parsed.scheme == 'http' || parsed.scheme == 'https');
  }

  DateTime _displayInSelectedTimeZone(DateTime value) {
    return EventScheduleUtils.toDisplayDateTime(
      value,
      timeZone: _selectedTimeZone,
    );
  }

  String _timeZoneLabel(String value) {
    return EventScheduleUtils.formatTimeZoneLabel(
      value,
      referenceUtc: _suggestedStartAt,
    );
  }

  String _timeZoneShortLabel(String value) {
    return EventScheduleUtils.formatTimeZoneShortLabel(
      value,
      referenceUtc: _suggestedStartAt,
    );
  }

  void _syncScheduleDisplayControllers() {
    _scheduleDisplayController.text = EventScheduleUtils.formatSummaryLine(
      context,
      startAt: _suggestedStartAt,
      endAt: _suggestedEndAt,
      isDateOnly: _suggestedIsDateOnly,
      timeZone: _selectedTimeZone,
    );
  }

  Future<void> _withSchedulePickerLock(Future<void> Function() fn) async {
    _isSchedulePickerOpen = true;
    try {
      await fn();
    } finally {
      _isSchedulePickerOpen = false;
    }
  }

  DateTime _endAfterStartUtc({required DateTime startAtUtc}) {
    if (_suggestedIsDateOnly) {
      final startLocal = _displayInSelectedTimeZone(startAtUtc);
      final nextLocalDate = DateTime(
        startLocal.year,
        startLocal.month,
        startLocal.day,
      ).add(const Duration(days: 1));
      return EventScheduleUtils.dateEndToUtc(
        nextLocalDate,
        timeZone: _selectedTimeZone,
      );
    }

    return startAtUtc.add(const Duration(hours: 1));
  }

  InputDecoration _outlineFieldDecoration(
    ThemeData theme, {
    required String labelText,
    String? hintText,
  }) {
    final scheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(12);
    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      border: border(scheme.outline),
      enabledBorder: border(scheme.outline.withValues(alpha: 0.5)),
      focusedBorder: border(scheme.primary, width: 2),
      errorBorder: border(scheme.error),
      focusedErrorBorder: border(scheme.error, width: 2),
      filled: true,
      fillColor: scheme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.7)),
      hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.5)),
    );
  }

  Future<void> _loadSuggestedLinkedSpots() async {
    if (widget.event.spotIds.isEmpty) return;
    final spotService = context.read<SpotService>();
    final spots = await Future.wait(
      widget.event.spotIds.map((id) async {
        final spot = await spotService.getSpotById(id);
        return spot ??
            Spot(id: id, name: id, description: '', latitude: 0, longitude: 0);
      }),
    );
    if (!mounted) return;
    setState(() {
      _suggestedLinkedSpots = spots.toList(growable: true);
    });
    _recenterMapForDisplay();
    _syncTimeZoneFromLocation();
  }

  List<String> _normalizedSpotIds(Iterable<String?> ids) {
    final normalized = ids
        .whereType<String>()
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    normalized.sort();
    return normalized;
  }

  bool _sameSpotIds(List<String> a, List<String> b) {
    final normalizedA = _normalizedSpotIds(a);
    final normalizedB = _normalizedSpotIds(b);
    if (normalizedA.length != normalizedB.length) return false;
    for (var i = 0; i < normalizedA.length; i++) {
      if (normalizedA[i] != normalizedB[i]) return false;
    }
    return true;
  }

  bool _linkedSpotsChanged() {
    return !_sameSpotIds(
      _suggestedLinkedSpots.map((spot) => spot.id).whereType<String>().toList(),
      widget.event.spotIds,
    );
  }

  bool _hasOriginalLocationData() {
    return widget.event.latitude != null ||
        widget.event.longitude != null ||
        (widget.event.address?.trim().isNotEmpty ?? false) ||
        (widget.event.city?.trim().isNotEmpty ?? false) ||
        (widget.event.countryCode?.trim().isNotEmpty ?? false);
  }

  bool _locationChanged() {
    if (_locationCleared && _hasOriginalLocationData()) return true;
    final location = _suggestedLocation;
    if (location == null) return false;
    if (widget.event.latitude == null || widget.event.longitude == null) {
      return true;
    }
    if (location.latitude != widget.event.latitude ||
        location.longitude != widget.event.longitude) {
      return true;
    }
    return (_suggestedAddress?.trim() ?? '') !=
            (widget.event.address?.trim() ?? '') ||
        (_suggestedCity?.trim() ?? '') != (widget.event.city?.trim() ?? '') ||
        (_suggestedCountryCode?.trim().toUpperCase() ?? '') !=
            (widget.event.countryCode?.trim().toUpperCase() ?? '');
  }

  bool _typedAddressNeedsResolution() {
    final typed = _locationAddressController.text.trim();
    if (typed.isEmpty) return false;
    return typed != _resolvedAddressInput || _suggestedLocation == null;
  }

  Future<void> _getCurrentLocation({bool setAsPickedPin = true}) async {
    if (_isSchedulePickerOpen) return;
    setState(() => _isGettingLocation = true);

    final permission = await LocationPermissionUtils.checkAndRequestPermission(
      context: context,
      showErrorMessages: setAsPickedPin,
    );
    final isPermissionGranted = LocationPermissionUtils.isPermissionGranted(
      permission,
    );

    if (mounted) {
      setState(() => _isLocationPermissionDenied = !isPermissionGranted);
    }

    if (!isPermissionGranted) {
      if (mounted) setState(() => _isGettingLocation = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentPosition = position;
        if (setAsPickedPin) {
          _suggestedLocation = latLng;
          _locationCleared = false;
        }
        _isLocationPermissionDenied = false;
      });
      _recenterMapForDisplay();
      if (setAsPickedPin) {
        _syncTimeZoneFromLocation();
      }
      await _geocodeLocation(latLng);
    } catch (_) {
      // Best-effort current location lookup.
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _syncTimeZoneFromLocation() async {
    if (!mounted || _timeZoneManuallySet) return;

    final generation = ++_timeZoneLookupGeneration;
    final coordinates = resolveEventTimezoneCoordinates(
      pickedLocation: _suggestedLocation,
      linkedSpots: _suggestedLinkedSpots,
      linkedSpotListSpots: const [],
    );

    if (coordinates == null) {
      if (!mounted || generation != _timeZoneLookupGeneration) return;
      setState(() {
        _selectedTimeZone = _browserTimeZone;
        _syncScheduleDisplayControllers();
      });
      return;
    }

    try {
      final geocodingService = context.read<GeocodingService>();
      final rawTimeZone = await geocodingService.lookupTimeZone(
        coordinates.latitude,
        coordinates.longitude,
      );
      final normalized = EventScheduleUtils.normalizeTimeZone(rawTimeZone);
      if (!mounted || generation != _timeZoneLookupGeneration) return;
      if (normalized == null) return;
      setState(() {
        _selectedTimeZone = normalized;
        if (!_timeZoneOptions.contains(normalized)) {
          _timeZoneOptions.insert(0, normalized);
        }
        _syncScheduleDisplayControllers();
      });
    } catch (_) {
      // Best-effort timezone lookup.
    }
  }

  Future<void> _geocodeLocation(LatLng location) async {
    setState(() => _isGeocoding = true);
    try {
      final result = await context
          .read<GeocodingService>()
          .geocodeCoordinatesDetails(location.latitude, location.longitude);
      if (!mounted) return;
      setState(() {
        _suggestedAddress = result['address'];
        _suggestedCity = result['city'];
        _suggestedCountryCode = result['countryCode'];
        final address = _suggestedAddress?.trim();
        if (address != null && address.isNotEmpty) {
          _locationAddressController.text = address;
          _resolvedAddressInput = address;
        } else {
          _locationAddressController.clear();
          _resolvedAddressInput = null;
        }
      });
    } catch (_) {
      // Best-effort reverse geocoding for map-picked coordinates.
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<bool> _resolveTypedAddress() async {
    final l10n = AppLocalizations.of(context)!;
    final typedAddress = _locationAddressController.text.trim();
    if (typedAddress.isEmpty) {
      setState(() => _error = l10n.addEventAddressRequiredToResolve);
      return false;
    }

    setState(() {
      _isGeocoding = true;
      _error = null;
    });
    try {
      final geocodingService = context.read<GeocodingService>();
      final result = await geocodingService.reverseGeocodeAddress(typedAddress);
      if (!mounted) return false;
      final latitude = result?['latitude'] as double?;
      final longitude = result?['longitude'] as double?;
      if (latitude == null || longitude == null) {
        setState(() => _error = l10n.addEventAddressNotFound);
        return false;
      }
      final formattedAddress = (result?['address'] as String?)?.trim();
      final acceptedAddress = typedAddress.isNotEmpty
          ? typedAddress
          : (formattedAddress?.isNotEmpty == true ? formattedAddress! : '');
      setState(() {
        _suggestedLocation = LatLng(latitude, longitude);
        _suggestedAddress = acceptedAddress;
        _suggestedCity = result?['city'] as String?;
        _suggestedCountryCode = result?['countryCode'] as String?;
        _locationAddressController.text = acceptedAddress;
        _resolvedAddressInput = acceptedAddress;
        _locationCleared = false;
        _currentPosition = null;
        _error = null;
      });
      _recenterMapForDisplay();
      _syncTimeZoneFromLocation();
      return true;
    } catch (_) {
      if (mounted) setState(() => _error = l10n.addEventAddressNotFound);
      return false;
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  Future<void> _pickLocationOnMap() async {
    if (_isSchedulePickerOpen) return;
    final result = await ExploreEntityPickerScreen.show(
      context,
      config: ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.locationOnly,
        initialLocation: _suggestedLocation,
        usageTip: LocationPickerUsageTip.addEvent,
      ),
    );
    final latLng = result?.location;
    if (latLng == null || !mounted) return;
    setState(() {
      _suggestedLocation = latLng;
      _suggestedAddress = null;
      _suggestedCity = null;
      _suggestedCountryCode = null;
      _resolvedAddressInput = null;
      _locationAddressController.clear();
      _locationCleared = false;
      _currentPosition = null;
      _error = null;
    });
    _recenterMapForDisplay();
    await _geocodeLocation(latLng);
    _syncTimeZoneFromLocation();
  }

  Future<void> _linkSpotOnMap() async {
    final result = await ExploreEntityPickerScreen.show(
      context,
      config: ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.spotsOnly,
        initialCenter: _suggestedLocation,
      ),
    );
    final spot = result?.spot;
    if (spot == null || !mounted) return;
    if (_suggestedLinkedSpots.any((s) => s.id == spot.id)) return;
    setState(() {
      _suggestedLinkedSpots.add(spot);
      _error = null;
    });
    _recenterMapForDisplay();
    _syncTimeZoneFromLocation();
  }

  void _clearLocation() {
    setState(() {
      _suggestedLocation = null;
      _currentPosition = null;
      _suggestedAddress = null;
      _suggestedCity = null;
      _suggestedCountryCode = null;
      _resolvedAddressInput = null;
      _locationAddressController.clear();
      _locationCleared = true;
      _error = null;
    });
    _recenterMapForDisplay();
    _syncTimeZoneFromLocation();
  }

  Widget _buildLocationAddressSuffixIcon({
    required AppLocalizations l10n,
    required bool fieldsEnabled,
    required bool hasSelectedPin,
  }) {
    if (_isGeocoding) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final needsResolve = _typedAddressNeedsResolution();
    final showSearch = needsResolve || !hasSelectedPin;
    final showClear = hasSelectedPin;

    Widget searchButton() => IconButton(
      icon: const Icon(Icons.search),
      tooltip: l10n.addEventUseAddressButton,
      onPressed: fieldsEnabled ? _resolveTypedAddress : null,
    );

    Widget clearButton() => IconButton(
      icon: const Icon(Icons.clear),
      tooltip: l10n.addEventClearLocationTooltip,
      onPressed: fieldsEnabled ? _clearLocation : null,
    );

    if (showSearch && showClear) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [searchButton(), clearButton()],
      );
    }
    if (showSearch) return searchButton();
    return clearButton();
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    DateTime? minUtc,
    String? dateHelpText,
    String? timeHelpText,
    String? dateCancelText,
    String? timeCancelText,
  }) async {
    final displayInitial = _displayInSelectedTimeZone(initial);
    final displayMin = minUtc == null ? null : _displayInSelectedTimeZone(minUtc);
    final pickedDate = await showDatePicker(
      context: context,
      helpText: dateHelpText,
      cancelText: dateCancelText,
      initialDate: displayInitial,
      firstDate: displayMin != null
          ? DateTime(displayMin.year, displayMin.month, displayMin.day)
          : DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate == null || !mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      helpText: timeHelpText,
      cancelText: timeCancelText,
      initialTime: TimeOfDay.fromDateTime(displayInitial),
    );
    if (pickedTime == null || !mounted) return null;

    return EventScheduleUtils.localDateTimeToUtc(
      DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      ),
      timeZone: _selectedTimeZone,
    );
  }

  Future<DateTime?> _pickStartSchedule(AppLocalizations l10n) async {
    if (_suggestedIsDateOnly) {
      final initialDate = _displayInSelectedTimeZone(_suggestedStartAt);
      final pickedDate = await showDatePicker(
        context: context,
        helpText: l10n.addEventSchedulePickStartDate,
        initialDate: DateTime(
          initialDate.year,
          initialDate.month,
          initialDate.day,
        ),
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );
      if (pickedDate == null || !mounted) return null;
      return EventScheduleUtils.dateStartToUtc(
        pickedDate,
        timeZone: _selectedTimeZone,
      );
    }

    return _pickDateTime(
      initial: _suggestedStartAt,
      dateHelpText: l10n.addEventSchedulePickStartDate,
      timeHelpText: l10n.addEventSchedulePickStartTime,
    );
  }

  Future<({DateTime? value, bool cancelled})> _pickEndSchedule(
    AppLocalizations l10n, {
    required DateTime startAtUtc,
    DateTime? initialEndUtc,
  }) async {
    final initialEnd =
        initialEndUtc ?? _endAfterStartUtc(startAtUtc: startAtUtc);

    if (_suggestedIsDateOnly) {
      final initialDate = _displayInSelectedTimeZone(initialEnd);
      final minDate = _displayInSelectedTimeZone(startAtUtc);
      final pickedDate = await showDatePicker(
        context: context,
        helpText: l10n.addEventSchedulePickEndDateOptional,
        cancelText: l10n.addEventScheduleSkipEnd,
        initialDate: DateTime(
          initialDate.year,
          initialDate.month,
          initialDate.day,
        ),
        firstDate: DateTime(
          minDate.year,
          minDate.month,
          minDate.day,
        ),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );
      if (pickedDate == null || !mounted) {
        return (value: null, cancelled: true);
      }
      return (
        value: EventScheduleUtils.dateEndToUtc(
          pickedDate,
          timeZone: _selectedTimeZone,
        ),
        cancelled: false,
      );
    }

    final picked = await _pickDateTime(
      initial: initialEnd,
      minUtc: startAtUtc,
      dateHelpText: l10n.addEventSchedulePickEndDateOptional,
      timeHelpText: l10n.addEventSchedulePickEndTimeOptional,
      dateCancelText: l10n.addEventScheduleSkipEnd,
      timeCancelText: l10n.addEventScheduleSkipEnd,
    );
    if (picked == null || !mounted) {
      return (value: null, cancelled: true);
    }

    final clamped = picked.isBefore(startAtUtc)
        ? _endAfterStartUtc(startAtUtc: startAtUtc)
        : picked;
    return (value: clamped, cancelled: false);
  }

  Future<void> _pickScheduleFromStart() async {
    await _withSchedulePickerLock(() async {
      final l10n = AppLocalizations.of(context)!;
      final newStart = await _pickStartSchedule(l10n);
      if (newStart == null || !mounted) return;

      final preservedEnd =
          _suggestedEndAt != null && !_suggestedEndAt!.isBefore(newStart)
          ? _suggestedEndAt
          : null;
      final endResult = await _pickEndSchedule(
        l10n,
        startAtUtc: newStart,
        initialEndUtc: preservedEnd,
      );
      if (!mounted) return;

      setState(() {
        _suggestedStartAt = newStart;
        _suggestedEndAt = endResult.cancelled ? null : endResult.value;
        _syncScheduleDisplayControllers();
        _error = null;
      });
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    final isLoggedIn = auth.isAuthenticated && auth.userProfile != null;
    final trimmedEmail = _emailController.text.trim();
    if (!isLoggedIn) {
      if (trimmedEmail.isEmpty) {
        setState(() => _error = l10n.spotDetailEmailRequired);
        return;
      }
      if (!_validEmail(trimmedEmail)) {
        setState(() => _error = l10n.spotDetailEmailInvalid);
        return;
      }
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = l10n.addEventTitleRequired);
      return;
    }
    final description = _descriptionController.text.trim();
    final website = _websiteController.text.trim();
    if (website.isNotEmpty && !_validWebsite(website)) {
      setState(() => _error = l10n.addEventWebsiteInvalid);
      return;
    }

    final originalTitle = widget.event.title.trim();
    final originalDescription = widget.event.description?.trim() ?? '';
    final originalWebsite = widget.event.websiteUrl?.trim() ?? '';
    final originalTimeZone = _originalNormalizedTimeZone;

    final suggestedTitle = title != originalTitle ? title : null;
    final suggestedDescription =
        description.isNotEmpty && description != originalDescription
        ? description
        : null;
    final suggestedWebsiteUrl = website.isNotEmpty && website != originalWebsite
        ? website
        : null;
    final suggestedIsDateOnly = _suggestedIsDateOnly != widget.event.isDateOnly
        ? _suggestedIsDateOnly
        : null;
    final suggestedTimeZone =
        _timeZoneManuallySet && _selectedTimeZone != originalTimeZone
        ? _selectedTimeZone
        : null;

    var normalizedSuggestedStartAt = _suggestedStartAt.toUtc();
    var normalizedSuggestedEndAt = _suggestedEndAt?.toUtc();
    final effectiveIsDateOnly = suggestedIsDateOnly ?? widget.event.isDateOnly;
    final effectiveTimeZone =
        suggestedTimeZone ?? originalTimeZone ?? _originalTimeZoneSelection;
    if (effectiveIsDateOnly) {
      final displayStart = EventScheduleUtils.toDisplayDateTime(
        normalizedSuggestedStartAt,
        timeZone: effectiveTimeZone,
      );
      normalizedSuggestedStartAt = EventScheduleUtils.dateStartToUtc(
        displayStart,
        timeZone: effectiveTimeZone,
      );
      if (normalizedSuggestedEndAt != null) {
        final displayEnd = EventScheduleUtils.toDisplayDateTime(
          normalizedSuggestedEndAt,
          timeZone: effectiveTimeZone,
        );
        normalizedSuggestedEndAt = EventScheduleUtils.dateEndToUtc(
          displayEnd,
          timeZone: effectiveTimeZone,
        );
      }
    }

    final suggestedStartAt =
        !normalizedSuggestedStartAt.isAtSameMomentAs(
          widget.event.startAt.toUtc(),
        )
        ? normalizedSuggestedStartAt
        : null;
    final suggestedEndAt =
        (normalizedSuggestedEndAt != null &&
            !(widget.event.endAt != null &&
                normalizedSuggestedEndAt.isAtSameMomentAs(
                  widget.event.endAt!.toUtc(),
                )))
        ? normalizedSuggestedEndAt
        : null;

    final effectiveStartAt = suggestedStartAt ?? widget.event.startAt.toUtc();
    final effectiveEndAt = suggestedEndAt ?? widget.event.endAt?.toUtc();
    if (effectiveEndAt != null && effectiveEndAt.isBefore(effectiveStartAt)) {
      setState(() => _error = l10n.addEventEndBeforeStart);
      return;
    }

    if (_typedAddressNeedsResolution() && !await _resolveTypedAddress()) {
      return;
    }
    if (!mounted) return;

    final suggestedSpotIds = _linkedSpotsChanged()
        ? _suggestedLinkedSpots
              .map((spot) => spot.id)
              .whereType<String>()
              .toList(growable: false)
        : null;
    final suggestedLocationRemoved =
        _locationCleared &&
        _hasOriginalLocationData() &&
        _suggestedLocation == null;
    final suggestedLatitude = _locationChanged() && !suggestedLocationRemoved
        ? _suggestedLocation?.latitude
        : null;
    final suggestedLongitude = _locationChanged() && !suggestedLocationRemoved
        ? _suggestedLocation?.longitude
        : null;

    if (suggestedTitle == null &&
        suggestedDescription == null &&
        suggestedWebsiteUrl == null &&
        suggestedIsDateOnly == null &&
        suggestedTimeZone == null &&
        suggestedStartAt == null &&
        suggestedEndAt == null &&
        suggestedSpotIds == null &&
        suggestedLatitude == null &&
        suggestedLongitude == null &&
        !suggestedLocationRemoved) {
      setState(() => _error = l10n.eventDetailSuggestEditNoChanges);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final contactEmail = isLoggedIn
          ? (trimmedEmail.isNotEmpty
                ? trimmedEmail
                : auth.userProfile!.email.trim())
          : trimmedEmail;
      final ok = await context
          .read<EventReportService>()
          .submitEventEditSuggestion(
            targetEventId: widget.event.id!,
            targetEventTitle: widget.event.title,
            startAt: widget.event.startAt,
            endAt: widget.event.endAt,
            isDateOnly: widget.event.isDateOnly,
            timeZone: widget.event.timeZone,
            existingSpotIds: widget.event.spotIds,
            existingSpotListIds: widget.event.spotListIds,
            latitude: widget.event.latitude,
            longitude: widget.event.longitude,
            address: widget.event.address,
            city: widget.event.city,
            countryCode: widget.event.countryCode,
            suggestedTitle: suggestedTitle,
            suggestedDescription: suggestedDescription,
            suggestedWebsiteUrl: suggestedWebsiteUrl,
            suggestedIsDateOnly: suggestedIsDateOnly,
            suggestedTimeZone: suggestedTimeZone,
            suggestedStartAt: suggestedStartAt,
            suggestedEndAt: suggestedEndAt,
            suggestedSpotIds: suggestedSpotIds,
            suggestedLatitude: suggestedLatitude,
            suggestedLongitude: suggestedLongitude,
            suggestedAddress:
                suggestedLatitude != null && suggestedLongitude != null
                ? _suggestedAddress
                : null,
            suggestedCity:
                suggestedLatitude != null && suggestedLongitude != null
                ? _suggestedCity
                : null,
            suggestedCountryCode:
                suggestedLatitude != null && suggestedLongitude != null
                ? _suggestedCountryCode
                : null,
            suggestedLocationRemoved: suggestedLocationRemoved,
            reporterUserId: auth.currentUser?.uid,
            reporterName:
                auth.userProfile?.displayName ??
                auth.currentUser?.displayName ??
                auth.currentUser?.email,
            reporterEmail: contactEmail.isEmpty ? null : contactEmail,
          );

      if (!mounted) return;
      if (!ok) {
        setState(() => _error = l10n.eventDetailSuggestEditSubmitFailed);
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = l10n.eventDetailSuggestEditSubmitError('$e'));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _buildEventBasicsSection(
    AppLocalizations l10n,
    bool fieldsEnabled,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomTextField(
              controller: _titleController,
              labelText: l10n.addEventTitleLabel,
              prefixIcon: Icons.event_outlined,
              textCapitalization: TextCapitalization.words,
              enabled: fieldsEnabled,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _descriptionController,
              labelText: l10n.addEventDescriptionLabel,
              prefixIcon: Icons.description_outlined,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              enabled: fieldsEnabled,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _websiteController,
              labelText: l10n.addEventWebsiteLabel,
              hintText: l10n.addEventWebsiteHint,
              prefixIcon: Icons.link,
              keyboardType: TextInputType.url,
              enabled: fieldsEnabled,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhereSection(AppLocalizations l10n, ThemeData theme) {
    final fieldsEnabled = !_submitting && !_isGeocoding;
    final hasSelectedPin = _suggestedLocation != null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.addEventWhereSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.addEventLocationSectionHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _submitting ? null : _linkSpotOnMap,
                icon: const Icon(Icons.add_location_alt_outlined, size: 18),
                label: Text(l10n.addEventLinkSpotButton),
              ),
            ),
            if (_suggestedLinkedSpots.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _suggestedLinkedSpots
                    .map(
                      (spot) => Chip(
                        avatar: const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                        ),
                        label: Text(
                          l10n.addEventLinkedSpotLabel(
                            spot.name.isNotEmpty ? spot.name : (spot.id ?? ''),
                          ),
                        ),
                        onDeleted: _submitting
                            ? null
                            : () {
                                setState(() {
                                  _suggestedLinkedSpots.removeWhere(
                                    (s) => s.id == spot.id,
                                  );
                                  _error = null;
                                });
                                _recenterMapForDisplay();
                                _syncTimeZoneFromLocation();
                              },
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            SpotLocationSection(
              embedded: true,
              showRequiredIndicator: false,
              showSelectedPin: hasSelectedPin,
              showLocationDetails: false,
              mapHeroTagPrefix: 'suggestEventEdit',
              linkedSpots: _mapDisplaySpots,
              currentLocation: _displayLocationForMap,
              address: null,
              countryCode: null,
              isGettingLocation: _isGettingLocation,
              isGeocoding: false,
              isSatelliteView: _isSatelliteView,
              isLocationPermissionDenied: _isLocationPermissionDenied,
              onRefreshLocation: () => _getCurrentLocation(setAsPickedPin: true),
              onPickOnMap: _pickLocationOnMap,
              onToggleSatellite: (value) {
                if (_isSchedulePickerOpen) return;
                setState(() => _isSatelliteView = value);
                final searchState = Provider.of<SearchStateService>(
                  context,
                  listen: false,
                );
                searchState.setSatellite(value);
              },
              onMapCreated: onMapCreated,
            ),
            if (!hasSelectedPin) ...[
              const SizedBox(height: 8),
              Text(
                l10n.addEventLocationNotSet,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            CustomTextField(
              controller: _locationAddressController,
              labelText: l10n.addEventAddressLabel,
              hintText: l10n.addEventAddressHint,
              prefixIcon: Icons.place_outlined,
              keyboardType: TextInputType.streetAddress,
              textInputAction: TextInputAction.search,
              enabled: fieldsEnabled,
              onChanged: (value) {
                setState(() {
                  if (value.trim().isEmpty) {
                    _suggestedAddress = null;
                    _resolvedAddressInput = null;
                    if (_suggestedLocation == null) _locationCleared = true;
                  } else {
                    _locationCleared = false;
                  }
                  _error = null;
                });
              },
              onFieldSubmitted: (_) {
                if (fieldsEnabled) _resolveTypedAddress();
              },
              suffixIconWidget: _buildLocationAddressSuffixIcon(
                l10n: l10n,
                fieldsEnabled: fieldsEnabled,
                hasSelectedPin: hasSelectedPin,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhenSection(AppLocalizations l10n, ThemeData theme) {
    final fieldsEnabled = !_submitting;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.addEventWhenSectionTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _suggestedIsDateOnly,
              title: Text(l10n.addEventAllDay),
              onChanged: fieldsEnabled
                  ? (value) {
                      setState(() {
                        _suggestedIsDateOnly = value;
                        _syncScheduleDisplayControllers();
                        _error = null;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 8),
            CustomTextField(
              controller: _scheduleDisplayController,
              labelText: l10n.addEventScheduleLabel,
              prefixIcon: Icons.date_range_outlined,
              readOnly: true,
              enabled: fieldsEnabled,
              onTap: fieldsEnabled ? _pickScheduleFromStart : null,
              suffixIcon: _suggestedEndAt == null ? Icons.edit_calendar : null,
              suffixIconWidget: _suggestedEndAt == null
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          tooltip: l10n.addEventClearEndTooltip,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          onPressed: fieldsEnabled
                              ? () => setState(() {
                                  _suggestedEndAt = null;
                                  _syncScheduleDisplayControllers();
                                  _error = null;
                                })
                              : null,
                        ),
                        const Icon(Icons.edit_calendar),
                        const SizedBox(width: 8),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedTimeZone,
              decoration: _outlineFieldDecoration(
                theme,
                labelText: l10n.addEventTimezoneLabel,
              ),
              selectedItemBuilder: (context) {
                return _timeZoneOptions
                    .map(
                      (value) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _timeZoneShortLabel(value),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    )
                    .toList();
              },
              items: _timeZoneOptions
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        _timeZoneLabel(value),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: fieldsEnabled
                  ? (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedTimeZone = value;
                        _timeZoneManuallySet = true;
                        _syncScheduleDisplayControllers();
                        _error = null;
                      });
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final auth = context.read<AuthService>();
    final isLoggedIn = auth.isAuthenticated && auth.userProfile != null;
    final fieldsEnabled = !_submitting;
    return AlertDialog(
      title: Text(l10n.eventDetailSuggestEditTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.eventDetailSuggestEditIntro),
              const SizedBox(height: 16),
              if (!isLoggedIn) ...[
                CustomTextField(
                  controller: _emailController,
                  labelText: l10n.spotDetailReportEmailLabel,
                  hintText: l10n.spotDetailReportEmailLabel,
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  enabled: fieldsEnabled,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.spotDetailSuggestEditEmailHelper,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.mail,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _emailController.text.isNotEmpty
                              ? l10n.spotDetailReportReachOutAt(
                                  _emailController.text,
                                )
                              : l10n.spotDetailReportReachOutAccount,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _buildEventBasicsSection(l10n, fieldsEnabled),
              const SizedBox(height: 16),
              _buildWhereSection(l10n, theme),
              const SizedBox(height: 16),
              _buildWhenSection(l10n, theme),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(l10n.profileCancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.spotDetailSubmit),
        ),
      ],
    );
  }
}

enum _EventStaffAction {
  editEvent,
  createNativeEvent,
  markDuplicate,
  removeDuplicate,
}

enum _EventEditMenuAction {
  suggestPhoto,
  suggestEdit,
  flagDuplicate,
  editEvent,
  createNativeEvent,
  markDuplicate,
  removeDuplicate,
  viewImageUrls,
}

class _EventSpotListPreview {
  const _EventSpotListPreview({
    required this.list,
    required this.previewSpots,
    required this.totalSpotCount,
  });

  final SpotList list;
  final List<Spot> previewSpots;
  final int totalSpotCount;
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
  static const int _previewSpotLimit = 4;

  Future<List<_EventSpotListPreview>>? _listsFuture;

  @override
  void initState() {
    super.initState();
    _listsFuture = _loadListPreviews();
  }

  @override
  void didUpdateWidget(covariant _LinkedSpotListsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spotListIds.join(',') != widget.spotListIds.join(',')) {
      _listsFuture = _loadListPreviews();
    }
  }

  Future<List<_EventSpotListPreview>> _loadListPreviews() async {
    final spotListService = context.read<SpotListService>();
    final spotService = context.read<SpotService>();
    final lists = await Future.wait(
      widget.spotListIds.map(spotListService.getSpotListById),
    );

    final previews = <_EventSpotListPreview>[];
    for (final list in lists.whereType<SpotList>()) {
      final spotIds = list.effectiveSpotIds;
      final previewSpots = <Spot>[];
      for (final spotId in spotIds.take(_previewSpotLimit)) {
        final spot = await spotService.getSpotById(spotId);
        if (spot != null) {
          previewSpots.add(spot);
        }
      }
      previews.add(
        _EventSpotListPreview(
          list: list,
          previewSpots: previewSpots,
          totalSpotCount: spotIds.length,
        ),
      );
    }
    return previews;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return FutureBuilder<List<_EventSpotListPreview>>(
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
        final previews = snapshot.data ?? const <_EventSpotListPreview>[];
        if (previews.isEmpty) {
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
          children: previews.asMap().entries.map((entry) {
            final index = entry.key;
            final preview = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                top: index > 0 ? SpotDetailUi.detailSubsectionGap : 0,
              ),
              child: _EventSpotListCard(preview: preview, l10n: l10n),
            );
          }).toList(),
        );
      },
    );
  }
}

class _EventSpotListCard extends StatelessWidget {
  const _EventSpotListCard({required this.preview, required this.l10n});

  final _EventSpotListPreview preview;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final list = preview.list;
    final listId = list.id;
    final description = list.description?.trim();
    final remainingSpots = preview.totalSpotCount - preview.previewSpots.length;

    return Container(
      width: double.infinity,
      padding: SpotDetailUi.detailCardPadding,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.map_outlined, color: colors.primary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.exploreSpotCountShort(preview.totalSpotCount),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.8),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (preview.previewSpots.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...preview.previewSpots.map(
              (spot) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: colors.primary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        spot.name,
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (remainingSpots > 0)
              Padding(
                padding: const EdgeInsets.only(left: 24, top: 2),
                child: Text(
                  l10n.eventDetailEventSpotListMoreSpots(remainingSpots),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (listId != null)
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/list/$listId'),
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: Text(l10n.eventDetailEventSpotListViewAll),
                ),
              if (listId != null)
                OutlinedButton.icon(
                  onPressed: () => context.go('/explore?listId=$listId'),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(l10n.eventDetailEventSpotListSeeOnMap),
                ),
            ],
          ),
        ],
      ),
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
    final l10n = AppLocalizations.of(context)!;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: spots.asMap().entries.map((entry) {
            final index = entry.key;
            final spot = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                top: index > 0 ? SpotDetailUi.detailSubsectionGap : 0,
              ),
              child: _EventLinkedSpotCard(spot: spot, l10n: l10n),
            );
          }).toList(),
        );
      },
    );
  }
}

class _EventLinkedSpotCard extends StatelessWidget {
  const _EventLinkedSpotCard({required this.spot, required this.l10n});

  final Spot spot;
  final AppLocalizations l10n;

  String? _locationLine() {
    final address = spot.address?.trim();
    if (address != null && address.isNotEmpty) return address;

    final city = spot.city?.trim();
    final country = spot.countryCode?.trim().toUpperCase();
    if (city != null &&
        city.isNotEmpty &&
        country != null &&
        country.isNotEmpty) {
      return '$city, $country';
    }
    if (city != null && city.isNotEmpty) return city;
    if (country != null && country.isNotEmpty) return country;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final spotId = spot.id;
    final description = spot.description.trim();
    final locationLine = _locationLine();
    final imageUrl = spot.imageUrls?.isNotEmpty == true
        ? spot.imageUrls!.first
        : null;

    return Container(
      width: double.infinity,
      padding: SpotDetailUi.detailCardPadding,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
        border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: ResizedSpotImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: 72,
                      height: 72,
                    ),
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.place_outlined,
                    color: colors.primary,
                    size: 28,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (locationLine != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        locationLine,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.7),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.8),
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (spotId != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () {
                    final url = UrlService.generateNavigationUrl(
                      spotId,
                      countryCode: spot.countryCode,
                      city: spot.city,
                    );
                    context.push(url);
                  },
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.eventDetailEventSpotViewDetails),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/explore?locateSpotId=$spotId'),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: Text(l10n.eventDetailEventSpotListSeeOnMap),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
