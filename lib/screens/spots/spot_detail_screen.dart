import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../models/spot.dart';
import '../../models/spot_check_in.dart';
import '../../models/spot_training_plan.dart';
import '../../widgets/spot_check_in_dialog.dart';
import '../../widgets/add_to_spot_list_dialog.dart';
import '../../widgets/spot_training_plan_dialog.dart';
import '../../widgets/spot_duplicate_changes_dialog.dart';
import '../../utils/spot_duplicate_review.dart';
import '../../utils/spot_check_in_flow.dart';
import '../../services/spot_service.dart';
import '../../services/spot_report_service.dart';
import '../../services/auth_service.dart';
import '../../services/event_map_service.dart';
import '../../services/admin_events_service.dart';
import '../../services/url_service.dart';
import '../../services/web_share_service.dart';
import '../../utils/share_link_text.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/search_state_service.dart';
import '../../widgets/admin/admin_image_urls_overview_dialog.dart';
import '../../widgets/source_details_dialog.dart';
import '../../widgets/spot_selection_dialog.dart';
import '../../widgets/moderator_action_fields.dart';
import '../../widgets/location_info_box.dart';
import '../../constants/spot_attributes.dart';
import '../../constants/spot_detail_ui.dart';
import '../../services/geocoding_service.dart';
import '../../widgets/spot_form/attributes_section.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_config.dart';
import '../../widgets/explore_entity_picker/explore_entity_picker_screen.dart';
import '../../services/snackbar_service.dart';
import '../../services/spot_list_service.dart';
import '../../services/spot_tracking_service.dart';
import '../../services/spot_check_in_service.dart';
import '../../services/spot_training_plan_service.dart';
import '../../utils/marker_icon_utils.dart';
import '../../utils/upcoming_linked_events_utils.dart';
import '../../widgets/linked_upcoming_event_panel.dart';
import '../../utils/resized_spot_image_provider.dart';
import '../../widgets/no_images_placeholder.dart';
import '../../widgets/resized_spot_image.dart';
import '../../widgets/spot_detail_community_section.dart';
import '../../widgets/spot_detail_quick_action_chip.dart';
import '../../utils/image_preparation.dart';
import '../../utils/image_picker_utils.dart';
import '../../utils/ui_yield.dart';
import '../../widgets/image_processing_banner.dart';
import '../../widgets/memory_image_preview.dart';
import '../../services/user_profile_service.dart';
import '../../services/jumpflix_service.dart';
import '../../utils/relative_date_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/audit_log_service.dart';
import 'package:web/web.dart' as web;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../l10n/app_localizations.dart';

String _spotDetailReportCategoryLabel(AppLocalizations l10n, String category) {
  switch (category) {
    case 'Spot closed or removed':
      return l10n.spotDetailReportCategoryClosed;
    case 'Inaccurate location or details':
      return l10n.spotDetailReportCategoryInaccurate;
    case 'Unsafe conditions':
      return l10n.spotDetailReportCategoryUnsafe;
    case 'Not a spot':
      return l10n.spotDetailReportCategoryNotASpot;
    case 'Other':
      return l10n.spotDetailReportCategoryOther;
    default:
      return category;
  }
}

String _spotDetailReportCategoryDescription(
  AppLocalizations l10n,
  String category,
) {
  switch (category) {
    case 'Spot closed or removed':
      return l10n.spotDetailReportCategoryClosedDesc;
    case 'Inaccurate location or details':
      return l10n.spotDetailReportCategoryInaccurateDesc;
    case 'Unsafe conditions':
      return l10n.spotDetailReportCategoryUnsafeDesc;
    case 'Not a spot':
      return l10n.spotDetailReportCategoryNotASpotDesc;
    case 'Other':
      return l10n.spotDetailReportCategoryOtherDesc;
    default:
      return '';
  }
}

/// Max characters of description to show in the video overlay.
const int _videoDescriptionPreviewLength = 80;

/// Unified carousel item for YouTube and Jumpflix videos.
class _CarouselVideoItem {
  const _CarouselVideoItem({
    this.thumbnailUrl,
    required this.launchUrl,
    this.preferContain = false,
    this.brandLogoAsset,
    this.brandLabel,
    this.brandSubtitle,
    this.brandDescription,
    this.useYoutubeIcon = false,
  });
  final String? thumbnailUrl;
  final String launchUrl;

  /// When true, use BoxFit.contain (e.g. portrait posters); else BoxFit.cover.
  final bool preferContain;

  /// Asset path for brand logo (e.g. Jumpflix). When null and useYoutubeIcon, use FontAwesome YouTube icon.
  final String? brandLogoAsset;
  final String? brandLabel;

  /// Optional label above the title (e.g. "As seen in" for Jumpflix).
  final String? brandSubtitle;

  /// Optional description preview (e.g. first N chars of Jumpflix video description).
  final String? brandDescription;
  final bool useYoutubeIcon;
}

class SpotDetailScreen extends StatefulWidget {
  final Spot spot;
  final int? initialImageIndex;

  const SpotDetailScreen({
    super.key,
    required this.spot,
    this.initialImageIndex,
  });

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

enum _SpotMenuAction {
  login,
  reportAsDuplicate,
  suggestPhoto,
  suggestEdit,
  report,
  createEvent,
  edit,
  delete,
  markAsDuplicate,
  createNativeSpot,
  toggleHide,
  removeDuplicateStatus,
  reviewDuplicateChanges,
  triggerResize,
  viewImageUrls,
}

enum _SpotSaveMenuAction {
  toggleWantToVisit,
  toggleVisited,
  openWantToVisitList,
  openVisitedList,
  addToCustomList,
  login,
}

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  static const String _fallbackDocumentTitle = 'Parkour·Spot';
  double _userRating = 0;
  double _previousRating = 0; // Track the user's previous rating
  bool _hasRated = false;
  int _currentImageIndex = 0;
  int _currentVideoIndex = 0;
  late final ScrollController _scrollController;
  late final PageController _videoPageController;
  late final ValueNotifier<bool> _isSatelliteViewNotifier;
  SearchStateService? _searchStateServiceRef;
  BitmapDescriptor? _spotMapPinIcon;

  // Rating aggregates from a live Firestore listener on the spot document.
  Map<String, dynamic>? _cachedRatingStats;
  bool _isLoadingRatingStats = false;
  StreamSubscription<Map<String, dynamic>>? _ratingStatsSubscription;

  // Track expanded sections for chip overflow
  final Map<String, bool> _expandedSections = {};

  // Original spot if this is a duplicate
  Spot? _originalSpot;
  bool _isLoadingOriginalSpot = false;

  // Duplicate spots if this is an original
  List<Spot> _duplicateSpots = [];
  bool _isLoadingDuplicates = false;

  // Current spot (can be updated after operations like hide/unhide)
  Spot? _currentSpot;
  String _exploreDocumentTitle = _fallbackDocumentTitle;

  /// Cached future for Jumpflix videos (avoids refetch on rebuild).
  Future<List<JumpflixVideo>>? _jumpflixVideosFuture;
  Future<LinkedSpotEvents>? _upcomingSpotEventsFuture;

  // Getter for the current spot (falls back to widget.spot if not updated)
  Spot get _spot => _currentSpot ?? widget.spot;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _exploreDocumentTitle = AppLocalizations.of(
        context,
      )!.exploreMetaDefaultTitle;
    } catch (_) {
      _exploreDocumentTitle = _fallbackDocumentTitle;
    }
  }

  void _showSuccessSnack(String message) {
    // Use global messenger to avoid context churn issues
    Future.microtask(() {
      SnackbarService.showSuccess(message);
    });
  }

  void _showErrorSnack(String message) {
    Future.microtask(() {
      SnackbarService.showError(message);
    });
  }

  Future<void> _showCheckInDialog() async {
    final spotId = _spot.id;
    if (spotId == null) return;
    await runSpotCheckInFlow(
      context,
      l10n: _l10n,
      spotId: spotId,
      spotName: _spot.name,
      fixedTrainingPlan: null,
      onExtendInsteadEdit: _handleEditCheckIn,
      showSuccess: _showSuccessSnack,
      showError: _showErrorSnack,
      successMessage: _l10n.spotDetailCheckInSuccess,
    );
  }

  Future<void> _runCheckInFromTrainingPlan(SpotTrainingPlan plan) async {
    final spotId = _spot.id;
    if (spotId == null) return;
    if (plan.spotId != spotId) return;
    await runSpotCheckInFlow(
      context,
      l10n: _l10n,
      spotId: spotId,
      spotName: _spot.name,
      fixedTrainingPlan: plan,
      onExtendInsteadEdit: _handleEditCheckIn,
      showSuccess: _showSuccessSnack,
      showError: _showErrorSnack,
      successMessage: _l10n.spotDetailCheckInSuccess,
    );
  }

  Future<void> _handleEditCheckIn(SpotCheckIn c) async {
    final svc = Provider.of<SpotCheckInService>(context, listen: false);
    final stillHereEligible = await svc.stillHereEligibleForUser(c);
    if (!mounted) return;
    final result = await showSpotCheckInDialog(
      context,
      existingCheckIn: c,
      stillHereEligible: stillHereEligible,
    );
    if (result == null || !mounted) return;

    if (result is SpotCheckInDialogDeleted) {
      final ok = await svc.deleteCheckIn(c.id);
      if (!mounted) return;
      if (ok) {
        _showSuccessSnack(_l10n.spotDetailCheckInRemoved);
      } else {
        _showErrorSnack(svc.error ?? _l10n.spotDetailCheckInDeleteFailed);
      }
      return;
    }

    if (result is! SpotCheckInDialogSaved) return;

    final ok = await svc.updateCheckIn(
      c.id,
      checkedInAt: result.checkedInAt!,
      isPrivate: result.isPrivate,
      expectedEndAt: result.expectedEndAt,
      comment: result.comment,
    );
    if (!mounted) return;
    if (ok) {
      _showSuccessSnack(_l10n.spotDetailCheckInUpdated);
    } else {
      _showErrorSnack(svc.error ?? _l10n.spotDetailCheckInUpdateFailed);
    }
  }

  Future<void> _showTrainingPlanDialog() async {
    final spotId = _spot.id;
    if (spotId == null) return;
    final svc = Provider.of<SpotTrainingPlanService>(context, listen: false);
    final existing = await svc.fetchMyActivePlanAtSpot(spotId);
    if (!mounted) return;
    final result = await showSpotTrainingPlanDialog(
      context,
      existingPlan: existing,
    );
    if (result == null || !mounted) return;
    if (result is SpotTrainingPlanDialogOpenCheckIn) {
      await _runCheckInFromTrainingPlan(result.plan);
      return;
    }
    if (result is SpotTrainingPlanDialogDeleted) {
      if (existing != null) {
        final ok = await svc.deletePlan(existing.id);
        if (!mounted) return;
        if (ok) {
          _showSuccessSnack(_l10n.spotDetailTrainingPlanRemoved);
        } else {
          _showErrorSnack(
            svc.error ?? _l10n.spotDetailTrainingPlanDeleteFailed,
          );
        }
      }
      return;
    }
    if (result is! SpotTrainingPlanDialogSaved) return;
    final ok = await svc.upsertPlan(
      spotId: spotId,
      plannedStartAt: result.plannedStartAt,
      plannedEndAt: result.plannedEndAt,
      isPrivate: result.isPrivate,
      comment: result.comment,
      spotName: _spot.name,
    );
    if (!mounted) return;
    if (ok) {
      _showSuccessSnack(
        existing != null
            ? _l10n.spotDetailTrainingPlanUpdated
            : _l10n.spotDetailTrainingPlanSaved,
      );
    } else {
      _showErrorSnack(svc.error ?? _l10n.spotDetailTrainingPlanFailed);
    }
  }

  Future<void> _handleEditTrainingPlan(SpotTrainingPlan p) async {
    final svc = Provider.of<SpotTrainingPlanService>(context, listen: false);
    final result = await showSpotTrainingPlanDialog(context, existingPlan: p);
    if (result == null || !mounted) return;
    if (result is SpotTrainingPlanDialogOpenCheckIn) {
      await _runCheckInFromTrainingPlan(result.plan);
      return;
    }
    if (result is SpotTrainingPlanDialogDeleted) {
      final ok = await svc.deletePlan(p.id);
      if (!mounted) return;
      if (ok) {
        _showSuccessSnack(_l10n.spotDetailTrainingPlanRemoved);
      } else {
        _showErrorSnack(svc.error ?? _l10n.spotDetailTrainingPlanDeleteFailed);
      }
      return;
    }
    if (result is! SpotTrainingPlanDialogSaved) return;
    final ok = await svc.upsertPlan(
      spotId: p.spotId,
      plannedStartAt: result.plannedStartAt,
      plannedEndAt: result.plannedEndAt,
      isPrivate: result.isPrivate,
      comment: result.comment,
      spotName: p.spotName ?? _spot.name,
    );
    if (!mounted) return;
    if (ok) {
      _showSuccessSnack(_l10n.spotDetailTrainingPlanUpdated);
    } else {
      _showErrorSnack(svc.error ?? _l10n.spotDetailTrainingPlanFailed);
    }
  }

  Future<void> _joinTrainingPlanFromCommunity(
    SpotTrainingPlan sourcePlan,
  ) async {
    final spotId = _spot.id;
    if (spotId == null) return;
    final svc = Provider.of<SpotTrainingPlanService>(context, listen: false);
    final existing = await svc.fetchMyActivePlanAtSpot(spotId);
    if (existing != null || !mounted) return;
    final result = await showSpotTrainingPlanDialog(
      context,
      initialPlannedStartAt: sourcePlan.plannedStartAt,
      initialPlannedEndAt: sourcePlan.plannedEndAt,
    );
    if (result == null || !mounted) return;
    if (result is SpotTrainingPlanDialogOpenCheckIn) {
      await _runCheckInFromTrainingPlan(result.plan);
      return;
    }
    if (result is! SpotTrainingPlanDialogSaved) return;
    final ok = await svc.upsertPlan(
      spotId: spotId,
      plannedStartAt: result.plannedStartAt,
      plannedEndAt: result.plannedEndAt,
      isPrivate: result.isPrivate,
      comment: result.comment,
      spotName: _spot.name,
    );
    if (!mounted) return;
    if (ok) {
      _showSuccessSnack(_l10n.spotDetailTrainingPlanSaved);
    } else {
      _showErrorSnack(svc.error ?? _l10n.spotDetailTrainingPlanFailed);
    }
  }

  /// Navigate to user profile, preferring username if available
  Future<void> _navigateToUserProfile(String userId) async {
    try {
      final userProfileService = Provider.of<UserProfileService>(
        context,
        listen: false,
      );
      final user = await userProfileService.getUserProfile(userId);

      // Use username if available, otherwise fall back to user ID
      final identifier = user?.username?.isNotEmpty == true
          ? user!.username!
          : userId;

      if (mounted) {
        context.push('/user/$identifier');
      }
    } catch (e) {
      // If fetching fails, fall back to user ID
      if (mounted) {
        context.push('/user/$userId');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _videoPageController = PageController();
    _isSatelliteViewNotifier = ValueNotifier<bool>(false);
    _currentSpot = widget.spot; // Initialize current spot
    // Initialize image index from parameter or default to 0
    _currentImageIndex =
        widget.initialImageIndex != null &&
            widget.initialImageIndex! >= 0 &&
            widget.spot.imageUrls != null &&
            widget.initialImageIndex! < widget.spot.imageUrls!.length
        ? widget.initialImageIndex!
        : 0;
    _loadRatingStatsSubscription();
    // Note: User rating will be loaded when auth state is restored via FutureBuilder

    // Update document title for web (after first frame: Localizations is not
    // available during initState).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateDocumentTitle();
    });
    _loadSpotMapPinIcon();

    // Load original spot if this is a duplicate
    if (widget.spot.duplicateOf != null) {
      _loadOriginalSpot();
    }

    // Load duplicate spots if this is an original (not a duplicate itself)
    if (widget.spot.duplicateOf == null && widget.spot.id != null) {
      _loadDuplicateSpots();
    }

    // We no longer initialize embedded YouTube players; thumbnails/links only

    if (widget.spot.id != null) {
      _jumpflixVideosFuture = Provider.of<JumpflixService>(
        context,
        listen: false,
      ).getJumpflixVideosForSpot(widget.spot.id!);
      _upcomingSpotEventsFuture = _loadUpcomingSpotEvents(widget.spot.id!);
    } else {
      _jumpflixVideosFuture = Future<List<JumpflixVideo>>.value([]);
      _upcomingSpotEventsFuture = Future<LinkedSpotEvents>.value(
        const LinkedSpotEvents(),
      );
    }

    // Initialize satellite view from SearchStateService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchStateServiceRef = Provider.of<SearchStateService>(
        context,
        listen: false,
      );
      _searchStateServiceRef!.addListener(_onSearchStateChanged);
      _isSatelliteViewNotifier.value = _searchStateServiceRef!.isSatellite;
    });
  }

  Future<void> _loadSpotMapPinIcon() async {
    final BitmapDescriptor icon =
        await MarkerIconUtils.loadNormalSelectedMapPin();
    if (mounted) {
      setState(() => _spotMapPinIcon = icon);
    }
  }

  @override
  void didUpdateWidget(SpotDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spot.id != widget.spot.id) {
      _userRating = 0;
      _previousRating = 0;
      _hasRated = false;
      _cachedRatingStats = null;
      _isLoadingRatingStats = false;
      _ratingStatsSubscription?.cancel();
      _ratingStatsSubscription = null;
      if (widget.spot.id != null) {
        _loadRatingStatsSubscription();
        _jumpflixVideosFuture = Provider.of<JumpflixService>(
          context,
          listen: false,
        ).getJumpflixVideosForSpot(widget.spot.id!);
        _upcomingSpotEventsFuture = _loadUpcomingSpotEvents(widget.spot.id!);
      } else {
        _jumpflixVideosFuture = Future<List<JumpflixVideo>>.value([]);
        _upcomingSpotEventsFuture = Future<LinkedSpotEvents>.value(
          const LinkedSpotEvents(),
        );
      }
    }
  }

  Future<LinkedSpotEvents> _loadUpcomingSpotEvents(String spotId) async {
    final mapService = Provider.of<EventMapService>(context, listen: false);
    final eventsService = Provider.of<AdminEventsService>(
      context,
      listen: false,
    );
    final pinsFuture = mapService.getUpcomingPinsForSpot(spotId);
    final eventsFuture = eventsService.getEventsForSpot(spotId);
    final pins = await pinsFuture;
    final events = await eventsFuture;
    return mergeAndPartitionLinkedEvents(
      fromPins: upcomingLinkedEventsFromPins(pins),
      fromEvents: upcomingLinkedEventsFromParkourEvents(events),
    );
  }

  String _formatSpotDocumentTitle(Spot s, AppLocalizations l10n) {
    final brand = l10n.exploreMetaDefaultTitle;
    final parts = <String>[];
    final city = s.city?.trim();
    if (city != null && city.isNotEmpty) parts.add(city);
    final cc = s.countryCode?.trim();
    if (cc != null && cc.isNotEmpty) parts.add(cc.toUpperCase());
    final loc = parts.join(', ');
    if (loc.isEmpty) return '${s.name} - $brand';
    return '${s.name} · $loc - $brand';
  }

  void _updateDocumentTitle() {
    if (kIsWeb) {
      web.document.title = _formatSpotDocumentTitle(_spot, _l10n);
    }
  }

  void _onSearchStateChanged() {
    if (!mounted) return;
    final searchState = _searchStateServiceRef;
    if (searchState == null) return;

    _isSatelliteViewNotifier.value = searchState.isSatellite;
  }

  @override
  void dispose() {
    // Reset document title to default when leaving spot page
    if (kIsWeb) {
      web.document.title = _exploreDocumentTitle;
    }
    _scrollController.dispose();
    _videoPageController.dispose();
    _isSatelliteViewNotifier.dispose();
    _searchStateServiceRef?.removeListener(_onSearchStateChanged);
    _ratingStatsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadOriginalSpot() async {
    if (widget.spot.duplicateOf == null) return;

    setState(() {
      _isLoadingOriginalSpot = true;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final originalSpot = await spotService.getSpotById(
        widget.spot.duplicateOf!,
      );

      if (mounted) {
        setState(() {
          _originalSpot = originalSpot;
          _isLoadingOriginalSpot = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOriginalSpot = false;
        });
      }
    }
  }

  Future<void> _loadDuplicateSpots() async {
    if (widget.spot.id == null) return;

    setState(() {
      _isLoadingDuplicates = true;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final duplicates = await spotService.getDuplicatesOfSpot(widget.spot.id!);

      if (mounted) {
        setState(() {
          _duplicateSpots = duplicates;
          _isLoadingDuplicates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDuplicates = false;
        });
      }
    }
  }

  void _showExternalSpotInfo() {
    if (widget.spot.spotSource == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          SourceDetailsDialog(sourceId: widget.spot.spotSource!),
    );
  }

  Widget _buildMergedSourceInfo() {
    final l10n = _l10n;
    final List<TextSpan> textSpans = [];
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final bool hideCreatorAttribution = _spot.createdFromCreateNative;
    final String? createdByName = hideCreatorAttribution
        ? null
        : _spot.createdByName;
    final String? createdById = hideCreatorAttribution ? null : _spot.createdBy;
    bool hasPreviousContent = false;

    // Check if there will be an updated date part (to determine if we should use commas)
    final bool willHaveUpdatedDate =
        _spot.hasTrustedUpdatedAt &&
        ((_spot.createdAt != null && _spot.updatedAt != _spot.createdAt) ||
            _spot.createdAt == null);

    // Created by
    if (createdById != null || createdByName != null) {
      final createdBy = createdByName ?? createdById ?? '';

      // Add created date if available
      if (_spot.createdAt != null) {
        final createdDateText = _formatRelativeDate(_spot.createdAt!, l10n);
        textSpans.add(
          TextSpan(
            text: l10n.spotDetailSpotCreatedOnDateBy(createdDateText),
            style: textStyle,
          ),
        );
      } else {
        textSpans.add(
          TextSpan(text: l10n.spotDetailSpotCreatedBy, style: textStyle),
        );
      }

      // Make creator name clickable if we have a user ID
      if (createdById != null) {
        textSpans.add(
          TextSpan(
            text: createdBy,
            style: textStyle?.copyWith(color: theme.colorScheme.primary),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _navigateToUserProfile(createdById);
              },
          ),
        );
      } else {
        textSpans.add(TextSpan(text: createdBy, style: textStyle));
      }

      hasPreviousContent = true;
    } else if (_spot.createdAt != null && hideCreatorAttribution) {
      // Preserve provenance line for create-native spots while omitting creator identity.
      final createdDateText = _formatRelativeDate(_spot.createdAt!, l10n);
      textSpans.add(
        TextSpan(
          text: _stripCreatorSuffix(
            l10n.spotDetailSpotCreatedOnDateBy(createdDateText),
          ),
          style: textStyle,
        ),
      );
      hasPreviousContent = true;
    }

    // Source and folder
    if (_spot.spotSource != null) {
      if (hasPreviousContent) {
        textSpans.add(TextSpan(text: ' / ', style: textStyle));
      }

      final sourceName = _spot.spotSourceName ?? l10n.spotDetailUnknownSource;

      // Add created date if available and no createdBy (imported spots)
      if (!hasPreviousContent && _spot.createdAt != null) {
        final createdDateText = _formatRelativeDate(_spot.createdAt!, l10n);
        textSpans.add(
          TextSpan(
            text: l10n.spotDetailSpotImportedOnDateFrom(createdDateText),
            style: textStyle,
          ),
        );
      } else {
        textSpans.add(
          TextSpan(text: l10n.spotDetailSpotImportedFrom, style: textStyle),
        );
      }

      // Make source name clickable
      textSpans.add(
        TextSpan(
          text: sourceName,
          style: textStyle?.copyWith(color: theme.colorScheme.primary),
          recognizer: TapGestureRecognizer()..onTap = _showExternalSpotInfo,
        ),
      );

      if (_spot.folderName != null) {
        textSpans.add(
          TextSpan(text: l10n.spotDetailFromFolder, style: textStyle),
        );
        textSpans.add(TextSpan(text: _spot.folderName!, style: textStyle));
      }

      hasPreviousContent = true;
    }

    // Contributors (filter out the createdBy user)
    bool hasContributors = false;
    if (_spot.contributors != null && _spot.contributors!.isNotEmpty) {
      // Filter out contributors that match the createdBy user
      final filteredContributors = _spot.contributors!.where((c) {
        final userName = c['userName'];
        final userId = c['userId'];
        // Exclude if userName matches createdByName or userId matches createdBy
        return userName != createdByName && userId != createdById;
      }).toList();

      if (filteredContributors.isNotEmpty) {
        final improvedByPrefix = hasPreviousContent
            ? (willHaveUpdatedDate
                  ? l10n.spotDetailImprovedByAfterComma
                  : l10n.spotDetailImprovedByAfterAnd)
            : _trimLeadingContributorPrefix(
                l10n.spotDetailImprovedByAfterComma,
              );
        textSpans.add(TextSpan(text: improvedByPrefix, style: textStyle));

        // Add each contributor name as a clickable link
        for (int i = 0; i < filteredContributors.length; i++) {
          final contributor = filteredContributors[i];
          final rawName = contributor['userName'];
          final userName = rawName == null || rawName.toString().trim().isEmpty
              ? l10n.spotDetailUnknownUser
              : rawName.toString().trim();
          final userId = contributor['userId'];

          if (i > 0) {
            if (i == filteredContributors.length - 1) {
              textSpans.add(
                TextSpan(text: l10n.spotDetailListJoinAnd, style: textStyle),
              );
            } else {
              textSpans.add(
                TextSpan(text: l10n.spotDetailListJoinComma, style: textStyle),
              );
            }
          }

          // Make contributor name clickable if we have a user ID
          if (userId != null) {
            textSpans.add(
              TextSpan(
                text: userName,
                style: textStyle?.copyWith(color: theme.colorScheme.primary),
                recognizer: TapGestureRecognizer()
                  ..onTap = () {
                    _navigateToUserProfile(userId);
                  },
              ),
            );
          } else {
            textSpans.add(TextSpan(text: userName, style: textStyle));
          }
        }

        hasContributors = true;
      }
    }

    // Last updated date (only if trusted and different from created date)
    bool hasUpdatedDate = false;
    if (_spot.hasTrustedUpdatedAt &&
        _spot.createdAt != null &&
        _spot.updatedAt != _spot.createdAt) {
      final updatedDateText = _formatRelativeDate(_spot.updatedAt!, l10n);
      textSpans.add(
        TextSpan(
          text: (hasPreviousContent || hasContributors)
              ? l10n.spotDetailLastUpdatedAfterCommaAnd(updatedDateText)
              : l10n.spotDetailLastUpdatedAfterAnd(updatedDateText),
          style: textStyle,
        ),
      );
      hasUpdatedDate = true;
    } else if (_spot.hasTrustedUpdatedAt && _spot.createdAt == null) {
      // If no created date but there's a trusted updated date
      final updatedDateText = _formatRelativeDate(_spot.updatedAt!, l10n);
      textSpans.add(
        TextSpan(
          text: (hasPreviousContent || hasContributors)
              ? l10n.spotDetailLastUpdatedAfterCommaAnd(updatedDateText)
              : l10n.spotDetailLastUpdatedAfterAnd(updatedDateText),
          style: textStyle,
        ),
      );
      hasUpdatedDate = true;
    }

    // Add period at the end if we have content but no updated date
    if (!hasUpdatedDate && (hasContributors || hasPreviousContent)) {
      textSpans.add(TextSpan(text: '.', style: textStyle));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 12),
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(style: textStyle, children: textSpans),
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeDate(DateTime date, AppLocalizations l10n) {
    return formatRelativeDateInDays(date, l10n);
  }

  String _trimLeadingContributorPrefix(String value) {
    return value.replaceFirst(RegExp(r'^[\s,]+'), '');
  }

  String _stripCreatorSuffix(String value) {
    final trimmed = value.trimRight();
    return trimmed.replaceFirst(
      RegExp(r'\s+(by|par|por|von|door|da)$', caseSensitive: false),
      '',
    );
  }

  void _copySpotToClipboard() async {
    try {
      final l10n = _l10n;
      final url = UrlService.generateSpotUrl(
        widget.spot.id!,
        countryCode: widget.spot.countryCode,
        city: widget.spot.city,
      );
      final label = widget.spot.name.trim();
      final text = ShareLinkText.clipboardText(ShareLinkKind.spot, label, url);

      final outcome = await WebShareService.tryShareLink(
        text: ShareLinkText.shareLabel(ShareLinkKind.spot, label),
        url: url,
      );
      if (outcome == WebShareOutcome.shared ||
          outcome == WebShareOutcome.cancelled) {
        return;
      }

      await Clipboard.setData(ClipboardData(text: text));

      SnackbarService.showClipboardCopied(l10n.spotCardCopiedToClipboard);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailCopySpotFailed('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyAddressToClipboard() async {
    if (_spot.address == null || _spot.address!.isEmpty) return;

    try {
      await Clipboard.setData(ClipboardData(text: _spot.address!));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailAddressCopiedToClipboard),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailCopyAddressFailed('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _locateSpotOnMap() {
    if (_spot.id != null) {
      context.go('/explore?locateSpotId=${_spot.id}');
    }
  }

  String _spotRatingRedirectUrl() {
    try {
      final routerState = GoRouterState.of(context);
      return routerState.uri.toString();
    } catch (e) {
      if (widget.spot.id != null &&
          widget.spot.countryCode != null &&
          widget.spot.city != null) {
        return '/${widget.spot.countryCode!.toLowerCase()}/${Uri.encodeComponent(widget.spot.city!.toLowerCase().replaceAll(' ', '-'))}/${widget.spot.id}';
      }
      return '/explore';
    }
  }

  String _ratingSheetCommunitySummaryString() {
    if (_isLoadingRatingStats) {
      return _l10n.spotDetailLoading;
    }
    final stats = _cachedRatingStats;
    final count = stats != null ? stats['ratingCount'] as int : 0;
    if (count > 0 && stats != null) {
      final avg = (stats['averageRating'] as num).toDouble();
      return '${avg.toStringAsFixed(1)} ★ ($count)';
    }
    return _l10n.spotDetailHeaderNoRatingsYet;
  }

  void _showSpotRatingSheet() {
    if (_spot.id == null) return;
    final redirectUrl = _spotRatingRedirectUrl();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset),
            child: Consumer<AuthService>(
              builder: (context, auth, _) {
                if (auth.isLoading) {
                  return const SizedBox(
                    height: 160,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (!auth.isAuthenticated) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _l10n.spotDetailRateThisSpot,
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _ratingSheetCommunitySummaryString(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _l10n.spotDetailSignInToRateSubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            context.go(
                              '/login?redirectTo=${Uri.encodeComponent(redirectUrl)}',
                            );
                          },
                          child: Text(_l10n.spotDetailSignInButton),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            context.go(
                              '/login?mode=signup&redirectTo=${Uri.encodeComponent(redirectUrl)}',
                            );
                          },
                          child: Text(_l10n.spotDetailCreateAccountButton),
                        ),
                      ],
                    ),
                  );
                }
                if (auth.userProfile == null) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _l10n.spotDetailCouldNotLoadProfile,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _l10n.spotDetailRefreshPageToRate,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  );
                }
                return _SpotRatingUserRatingLoader(
                  loadUserRating: _loadUserRatingFuture,
                  builder: (ctx) {
                    return StatefulBuilder(
                      builder: (context, setModalState) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _l10n.spotDetailRateThisSpot,
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _ratingSheetCommunitySummaryString(),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: List.generate(5, (index) {
                                final filled = index < _userRating;
                                return IconButton(
                                  onPressed: () {
                                    _submitRatingDirectly(
                                      index + 1.0,
                                      refreshModal: () => setModalState(() {}),
                                    );
                                  },
                                  icon: Icon(
                                    filled ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 40,
                                  ),
                                  tooltip: '${index + 1}',
                                );
                              }),
                            ),
                            if (_hasRated) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () {
                                    _clearRatingDirectly(
                                      refreshModal: () => setModalState(() {}),
                                    );
                                  },
                                  child: Text(_l10n.spotDetailClearRating),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _spotDetailRatingQuickChip() {
    if (_isLoadingRatingStats) {
      return SpotDetailQuickActionChip(
        icon: Icons.star_outline,
        iconColor: Colors.amber.withValues(alpha: 0.85),
        label: _l10n.spotDetailQuickActionRate,
        showSpinner: true,
      );
    }
    final stats = _cachedRatingStats;
    final count = stats != null ? stats['ratingCount'] as int : 0;
    if (count > 0 && stats != null) {
      final avg = (stats['averageRating'] as num).toDouble();
      final theme = Theme.of(context);
      final baseLabel = theme.textTheme.labelLarge;
      final cs = theme.colorScheme;
      return SpotDetailQuickActionChip(
        icon: Icons.star,
        iconColor: Colors.amber,
        label: '',
        labelWidget: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: avg.toStringAsFixed(1), style: baseLabel),
              TextSpan(
                text: ' ($count)',
                style: baseLabel?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: cs.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        showSpinner: false,
      );
    }
    return SpotDetailQuickActionChip(
      icon: Icons.star_border,
      iconColor: Colors.amber.withValues(alpha: 0.85),
      label: _l10n.spotDetailQuickActionRate,
      showSpinner: false,
    );
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/explore');
    }
  }

  Widget _spotDetailBackButton() {
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

  void _openInMaps() async {
    try {
      final zoom = _searchStateServiceRef?.zoom;
      final isSatellite = _searchStateServiceRef?.isSatellite ?? false;
      await UrlService.openLocationInMaps(
        widget.spot.latitude,
        widget.spot.longitude,
        zoom: zoom,
        isSatellite: isSatellite,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailOpenMapsFailed('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _spotDetailAuthQuickActionControl({
    required bool stripBottomPadding,
    required bool compactQuickActions,
  }) {
    final bottom = stripBottomPadding ? 0.0 : 12.0;
    final showChipLabel = !compactQuickActions;
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isLoading) {
          return Padding(
            padding: EdgeInsets.only(bottom: bottom),
            child: SpotDetailQuickActionChip(
              icon: Icons.edit_outlined,
              iconColor: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.38),
              label: _l10n.spotDetailLoading,
              showSpinner: true,
              showLabel: showChipLabel,
            ),
          );
        }
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: _buildSpotActionsPopupMenu(
            authService: authService,
            tooltip: _l10n.spotDetailEditReportTooltip,
            compactQuickActions: compactQuickActions,
          ),
        );
      },
    );
  }

  Widget _buildSpotActionsPopupMenu({
    required AuthService authService,
    String? tooltip,
    required bool compactQuickActions,
  }) {
    final menuTooltip = tooltip ?? _l10n.spotDetailMoreActionsTooltip;
    final popup = PopupMenuButton<_SpotMenuAction>(
      position: PopupMenuPosition.under,
      tooltip: menuTooltip,
      borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
      splashRadius: 20,
      onSelected: _onMenuActionSelected,
      itemBuilder: (menuContext) {
        final l10n = AppLocalizations.of(menuContext)!;
        final theme = Theme.of(menuContext);
        final bool hasStaffAccess =
            authService.isAuthenticated &&
            authService.userProfile != null &&
            (authService.isAdmin || authService.isModerator);
        final bool canDeleteSpot =
            authService.isAuthenticated &&
            authService.userProfile != null &&
            authService.isAdmin;
        final List<PopupMenuEntry<_SpotMenuAction>> items = [
          if (!authService.isAuthenticated) ...[
            PopupMenuItem<_SpotMenuAction>(
              value: _SpotMenuAction.login,
              child: Row(
                children: [
                  Icon(Icons.login, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.spotDetailMenuLogin,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        l10n.spotDetailMenuLoginSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
          ],
          PopupMenuItem<_SpotMenuAction>(
            value: _SpotMenuAction.reportAsDuplicate,
            enabled: _spot.duplicateOf == null,
            child: Row(
              children: [
                Icon(
                  Icons.copy_all,
                  color: _spot.duplicateOf == null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.spotDetailMenuFlagDuplicate,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _spot.duplicateOf == null
                            ? null
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              ),
                      ),
                    ),
                    Text(
                      _spot.duplicateOf == null
                          ? l10n.spotDetailMenuFlagDuplicateSubtitleYes
                          : l10n.spotDetailMenuFlagDuplicateSubtitleNo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuItem<_SpotMenuAction>(
            value: _SpotMenuAction.suggestPhoto,
            enabled: _spot.duplicateOf == null,
            child: Row(
              children: [
                Icon(
                  Icons.add_photo_alternate,
                  color: _spot.duplicateOf == null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.spotDetailMenuSuggestPhoto,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _spot.duplicateOf == null
                            ? null
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              ),
                      ),
                    ),
                    Text(
                      _spot.duplicateOf == null
                          ? l10n.spotDetailMenuSuggestPhotoSubtitleYes
                          : l10n.spotDetailMenuSuggestPhotoSubtitleNo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuItem<_SpotMenuAction>(
            value: _SpotMenuAction.suggestEdit,
            enabled: _spot.duplicateOf == null,
            child: Row(
              children: [
                Icon(
                  Icons.edit_note,
                  color: _spot.duplicateOf == null
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.spotDetailMenuSuggestEdit,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _spot.duplicateOf == null
                            ? null
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              ),
                      ),
                    ),
                    Text(
                      _spot.duplicateOf == null
                          ? l10n.spotDetailMenuSuggestEditSubtitleYes
                          : l10n.spotDetailMenuSuggestEditSubtitleNo,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuItem<_SpotMenuAction>(
            value: _SpotMenuAction.report,
            child: Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.spotDetailMenuReportSpot,
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      l10n.spotDetailMenuReportSpotSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (authService.isAuthenticated && _spot.id != null)
            PopupMenuItem<_SpotMenuAction>(
              value: _SpotMenuAction.createEvent,
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.spotDetailMenuCreateEvent,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        l10n.spotDetailMenuCreateEventSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ];

        if (hasStaffAccess && _spot.id != null) {
          // Check if this is a spot from a source and user is moderator (not admin)
          final isSpotFromSource = _spot.spotSource != null;
          final isModeratorOnly =
              authService.isModerator && !authService.isAdmin;
          final shouldDisableEdit = isSpotFromSource && isModeratorOnly;

          // Check if spot is already marked as duplicate
          final isAlreadyDuplicate = _spot.duplicateOf != null;

          items.add(const PopupMenuDivider());
          items.addAll([
            PopupMenuItem<_SpotMenuAction>(
              value: _SpotMenuAction.edit,
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
                          l10n.spotDetailMenuEditSpot,
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
                              ? l10n.spotDetailMenuEditSpotSubtitleNative
                              : l10n.spotDetailMenuEditSpotSubtitleMod,
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
            PopupMenuItem<_SpotMenuAction>(
              value: _SpotMenuAction.markAsDuplicate,
              enabled: !isAlreadyDuplicate,
              child: Row(
                children: [
                  Icon(
                    Icons.copy_all,
                    color: isAlreadyDuplicate
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                        : theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.spotDetailMenuMarkDuplicate,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isAlreadyDuplicate
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.38,
                                )
                              : null,
                        ),
                      ),
                      Text(
                        isAlreadyDuplicate
                            ? l10n.spotDetailMenuMarkDuplicateSubtitleDup
                            : l10n.spotDetailMenuMarkDuplicateSubtitleMod,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Remove duplicate status menu item (only when spot is marked as duplicate)
            if (isAlreadyDuplicate)
              PopupMenuItem<_SpotMenuAction>(
                value: _SpotMenuAction.removeDuplicateStatus,
                child: Row(
                  children: [
                    Icon(
                      Icons.clear,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.spotDetailMenuRemoveDuplicateStatus,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          l10n.spotDetailMenuRemoveDuplicateSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (isAlreadyDuplicate && _spot.hasDuplicatePendingChanges)
              PopupMenuItem<_SpotMenuAction>(
                value: _SpotMenuAction.reviewDuplicateChanges,
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.spotDuplicateChangesMenuItem,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          l10n.spotDuplicateChangesMenuSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            // Create native spot menu item (only for spots from external sources)
            if (isSpotFromSource)
              PopupMenuItem<_SpotMenuAction>(
                value: _SpotMenuAction.createNativeSpot,
                child: Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.spotDetailMenuCreateNative,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          l10n.spotDetailMenuCreateNativeSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            PopupMenuItem<_SpotMenuAction>(
              value: _SpotMenuAction.toggleHide,
              child: Row(
                children: [
                  Icon(
                    _spot.hidden ? Icons.visibility : Icons.visibility_off,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _spot.hidden
                            ? l10n.spotDetailMenuUnhideSpot
                            : l10n.spotDetailMenuHideSpot,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        _spot.hidden
                            ? l10n.spotDetailMenuUnhideSpotSubtitle
                            : l10n.spotDetailMenuHideSpotSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]);

          if (canDeleteSpot) {
            items.add(const PopupMenuDivider());
            items.add(
              PopupMenuItem<_SpotMenuAction>(
                value: _SpotMenuAction.delete,
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.spotDetailMenuDeleteSpot,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          l10n.spotDetailMenuDeleteSubtitleAdmin,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
          if (authService.isAdmin &&
              _spot.imageUrls != null &&
              _spot.imageUrls!.isNotEmpty) {
            items.add(
              PopupMenuItem<_SpotMenuAction>(
                value: _SpotMenuAction.viewImageUrls,
                child: Row(
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.spotDetailMenuImageUrls,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          l10n.spotDetailMenuImageUrlsSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            items.add(
              PopupMenuItem<_SpotMenuAction>(
                value: _SpotMenuAction.triggerResize,
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_fix_high,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.spotDetailMenuTriggerResize,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          l10n.spotDetailMenuTriggerResizeSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        }

        return items;
      },
      child: SpotDetailQuickActionChip(
        icon: Icons.edit_outlined,
        iconColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.75),
        label: _l10n.spotDetailQuickActionEdit,
        showLabel: !compactQuickActions,
      ),
    );
    return popup;
  }

  void _onMenuActionSelected(_SpotMenuAction action) async {
    switch (action) {
      case _SpotMenuAction.login:
        context.go(
          '/login?redirectTo=${Uri.encodeComponent('/spot/${widget.spot.id}')}',
        );
        break;
      case _SpotMenuAction.reportAsDuplicate:
        _showReportDuplicateDialog();
        break;
      case _SpotMenuAction.suggestPhoto:
        _showSuggestPhotoDialog();
        break;
      case _SpotMenuAction.suggestEdit:
        _showSuggestEditDialog();
        break;
      case _SpotMenuAction.report:
        _showReportSpotDialog();
        break;
      case _SpotMenuAction.createEvent:
        final spotId = _spot.id;
        if (spotId == null) break;
        context.push(
          Uri(
            path: '/events/add',
            queryParameters: {'spotId': spotId, 'spotName': _spot.name},
          ).toString(),
          extra: _spot,
        );
        break;
      case _SpotMenuAction.edit:
        final authService = Provider.of<AuthService>(context, listen: false);
        final isSpotFromSource = widget.spot.spotSource != null;
        final isModeratorOnly = authService.isModerator && !authService.isAdmin;

        // Prevent moderators from editing spot-source spots
        if (isSpotFromSource && isModeratorOnly) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_l10n.spotDetailExternalSourceCannotEdit),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: _l10n.spotDetailOk,
                  onPressed: () {},
                ),
              ),
            );
          }
          break;
        }

        if (widget.spot.id != null) {
          // Get current route location and append /edit to maintain route structure
          final routerState = GoRouterState.of(context);
          final currentLocation = routerState.uri.path;
          // Ensure we have a clean path (remove trailing slash if present)
          final cleanPath = currentLocation.endsWith('/')
              ? currentLocation.substring(0, currentLocation.length - 1)
              : currentLocation;
          final editPath = '$cleanPath/edit';

          // Delay navigation to ensure PopupMenu fully closes before navigation
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!mounted) return;
            context.push(editPath);
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n.spotDetailUnableEditNow),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
      case _SpotMenuAction.delete:
        final authService = Provider.of<AuthService>(context, listen: false);
        if (authService.isAdmin) {
          _showDeleteDialog();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_l10n.spotDetailOnlyAdminsDelete),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;
      case _SpotMenuAction.markAsDuplicate:
        _showMarkAsDuplicateDialog();
        break;
      case _SpotMenuAction.createNativeSpot:
        final result = await _showCreateNativeSpotConfirmationDialog();
        if (result != null && result['confirmed'] == true && mounted) {
          _createNativeSpot(
            reportId: result['reportId'] as String?,
            notes: result['notes'] as String?,
          );
        }
        break;
      case _SpotMenuAction.toggleHide:
        final result = await _showHideSpotConfirmationDialog();
        if (result != null && result['confirmed'] == true && mounted) {
          _toggleSpotHidden(
            reportId: result['reportId'] as String?,
            notes: result['notes'] as String?,
          );
        }
        break;
      case _SpotMenuAction.removeDuplicateStatus:
        final result = await _showRemoveDuplicateStatusConfirmationDialog();
        if (result != null && result['confirmed'] == true && mounted) {
          _removeDuplicateStatus(
            reportId: result['reportId'] as String?,
            notes: result['notes'] as String?,
          );
        }
        break;
      case _SpotMenuAction.reviewDuplicateChanges:
        await _reviewDuplicateChanges();
        break;
      case _SpotMenuAction.triggerResize:
        _triggerResizeForSpot();
        break;
      case _SpotMenuAction.viewImageUrls:
        final urls = _spot.imageUrls;
        if (urls == null || urls.isEmpty) break;
        await showAdminImageUrlsOverviewDialog(
          context,
          imageUrls: urls,
          entityLabel: _spot.name,
          showSpotsApiUrls: true,
        );
        break;
    }
  }

  Future<void> _reviewDuplicateChanges({
    bool dismissWithoutDialog = false,
  }) async {
    final ok = await reviewSpotDuplicateChanges(
      context: context,
      duplicateSpot: _spot,
      dismissWithoutDialog: dismissWithoutDialog,
    );
    if (!ok || !mounted) return;
    final spotId = _spot.id;
    if (spotId == null) return;
    final reloaded = await Provider.of<SpotService>(
      context,
      listen: false,
    ).getSpotById(spotId);
    if (reloaded != null && mounted) {
      setState(() {
        _currentSpot = reloaded;
      });
      _updateDocumentTitle();
    }
  }

  Future<void> _triggerResizeForSpot() async {
    final spotId = _spot.id;
    if (spotId == null) return;

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final data = await spotService.triggerResizeForSpot(spotId);

      if (!mounted) return;
      final total = (data['total'] as num?)?.toInt() ?? 0;
      final triggered = (data['triggered'] as num?)?.toInt() ?? 0;
      final verified = (data['verified'] as num?)?.toInt() ?? 0;
      final failed = (data['failed'] as num?)?.toInt() ?? 0;

      final l10n = _l10n;
      if (total == 0) {
        _showSuccessSnack(l10n.spotDetailResizeAllHaveVersions);
      } else {
        final failedPart = failed > 0
            ? l10n.spotDetailResizeFailedPart(failed)
            : '';
        _showSuccessSnack(
          l10n.spotDetailResizeSummary(triggered, verified, failedPart),
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnack(_l10n.spotDetailResizeTriggerFailed('$e'));
    }
  }

  Future<void> _showReportDuplicateDialog() async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.spotDetailUnableFlagDuplicate),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _ReportDuplicateDialog(spot: widget.spot),
    );

    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.spotDetailThanksDuplicateReport),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showSuggestPhotoDialog() async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.spotDetailUnableSuggestPhotos),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.spot.duplicateOf != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.spotDetailCannotSuggestPhotosDuplicate),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _SuggestPhotoDialog(spot: widget.spot),
    );

    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.spotDetailThanksPhotoSuggestion),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showSuggestEditDialog() async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.spotDetailUnableSuggestEdits),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.spot.duplicateOf != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.spotDetailCannotSuggestEditsDuplicate),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _SuggestEditDialog(spot: _spot),
    );

    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.spotDetailThanksEditSuggestion),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showReportSpotDialog() async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.spotDetailUnableReportNow),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _ReportSpotDialog(spot: widget.spot),
    );

    if (!mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.spotDetailThanksReportSubmitted),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showAddToListDialog() async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.spotDetailUnableAddToList),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final spotListService = Provider.of<SpotListService>(
      context,
      listen: false,
    );
    final lists = await spotListService.getUserSpotLists();
    final spotId = widget.spot.id!;

    // Check which lists already contain this spot
    final listsWithSpot = lists
        .where((list) => list.effectiveSpotIds.contains(spotId))
        .toList();
    final availableLists = lists
        .where((list) => !list.effectiveSpotIds.contains(spotId))
        .toList();

    if (!mounted) return;

    final result = await showDialog<AddToSpotListDialogResult>(
      context: context,
      builder: (dialogContext) => AddToSpotListDialog(
        lists: availableLists,
        listsWithSpot: listsWithSpot,
        addSpot: (listId, {sectionId}) {
          if (sectionId == null) {
            return spotListService.addSpotToList(listId, spotId);
          }
          return spotListService.addSpotToSection(listId, sectionId, spotId);
        },
        addToNewSection: (listId, {sectionTitle}) {
          return spotListService.addSpotToNewSection(
            listId,
            spotId,
            sectionTitle: sectionTitle,
          );
        },
        createList: ({required name, required visibility}) {
          return spotListService.createSpotList(name, visibility: visibility);
        },
        onOpenList: (listId) => dialogContext.push('/list/$listId'),
        errorMessage: () => spotListService.error,
      ),
    );

    if (!mounted) return;
    if (result != null) {
      if (result.created) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailListCreatedAndAdded),
            backgroundColor: Colors.green,
          ),
        );
      } else if (result.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error!), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailSpotAddedToList),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentInset = SpotDetailUi.contentHorizontalInset(context);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _previousImage();
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _nextImage();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Sliver App Bar with collapsing toolbar
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
                child: _spotDetailBackButton(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _buildImageCarousel(),
              ),
            ),

            // Content using SliverList
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
                                Icons.place_outlined,
                                size: 28,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Expanded(
                              child: SelectableText(
                                _spot.name,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Save: want to visit / been here + optional custom list (guests see login CTA)
                        if (_spot.id != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final compactQuickActions =
                                    constraints.maxWidth <
                                    SpotDetailUi
                                        .quickActionsCompactLayoutMaxWidth;
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _spotDetailAuthQuickActionControl(
                                        stripBottomPadding: true,
                                        compactQuickActions:
                                            compactQuickActions,
                                      ),
                                      const SizedBox(width: 8),
                                      _SpotSaveMenu(
                                        spotId: _spot.id!,
                                        onAddToCustomList: _showAddToListDialog,
                                        stripBottomPadding: true,
                                        compactQuickActions:
                                            compactQuickActions,
                                      ),
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: _l10n.spotDetailRatingTooltip,
                                        child: Semantics(
                                          button: true,
                                          label: _l10n.spotDetailRatingTooltip,
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              SpotDetailUi.surfaceRadius,
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    SpotDetailUi.surfaceRadius,
                                                  ),
                                              onTap: _showSpotRatingSheet,
                                              child:
                                                  _spotDetailRatingQuickChip(),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: _l10n.spotDetailShareTooltip,
                                        child: Semantics(
                                          button: true,
                                          label: _l10n.spotDetailShareTooltip,
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              SpotDetailUi.surfaceRadius,
                                            ),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    SpotDetailUi.surfaceRadius,
                                                  ),
                                              onTap: _copySpotToClipboard,
                                              child: SpotDetailQuickActionChip(
                                                icon: Icons.share_outlined,
                                                iconColor: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.75),
                                                label: _l10n
                                                    .spotDetailQuickActionShare,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinkedUpcomingEventPanel(
                            eventsFuture: _upcomingSpotEventsFuture,
                            margin: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 12),
                          SpotDetailCommunitySection(
                            spotId: _spot.id!,
                            spotDisplayName: _spot.name,
                            countryCode: _spot.countryCode,
                            city: _spot.city,
                            onNewCheckIn: _showCheckInDialog,
                            onEditCheckIn: _handleEditCheckIn,
                            onNewTrainingPlan: _showTrainingPlanDialog,
                            onEditTrainingPlan: _handleEditTrainingPlan,
                            onJoinTrainingPlan: _joinTrainingPlanFromCommunity,
                            onLoginRequired: () => context.go(
                              '/login?redirectTo=${Uri.encodeComponent('/spot/${_spot.id!}')}',
                            ),
                          ),
                        ],

                        // Hidden spot banner
                        if (_spot.hidden || widget.spot.spotSourceRemoved)
                          const SizedBox(height: 16),
                        if (_spot.hidden)
                          Container(
                            margin: EdgeInsets.only(
                              bottom: widget.spot.spotSourceRemoved ? 0 : 16,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.error.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.visibility_off,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _l10n.spotDetailHiddenBanner,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onErrorContainer,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Spot source removed banner
                        if (widget.spot.spotSourceRemoved)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .errorContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.error.withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _l10n.spotDetailSourceRemovedBanner(
                                      widget.spot.spotSourceName ??
                                          _l10n
                                              .spotDetailSourceRemovedUnknownSource,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onErrorContainer,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Description
                        SelectableText(
                          _spot.description.trim().isEmpty
                              ? _l10n.spotCardNoDescription
                              : _spot.description,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontStyle: _spot.description.trim().isEmpty
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                color: _spot.description.trim().isEmpty
                                    ? Theme.of(context).colorScheme.onSurface
                                          .withValues(alpha: 0.6)
                                    : null,
                              ),
                        ),

                        const SizedBox(height: 24),

                        // Attributes Grid Section
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWideScreen = constraints.maxWidth > 600;
                            final hasAnyAttributes =
                                widget.spot.goodFor != null &&
                                    widget.spot.goodFor!.isNotEmpty ||
                                widget.spot.spotFeatures != null &&
                                    widget.spot.spotFeatures!.isNotEmpty ||
                                widget.spot.spotAccess != null ||
                                widget.spot.spotFacilities != null &&
                                    widget.spot.spotFacilities!.isNotEmpty;

                            if (!hasAnyAttributes) {
                              return const SizedBox.shrink();
                            }

                            if (isWideScreen) {
                              // Dynamic grid layout based on available sections
                              final sections = <Widget>[];

                              // Good For Section
                              if (widget.spot.goodFor != null &&
                                  widget.spot.goodFor!.isNotEmpty) {
                                sections.add(
                                  _buildExpandableChipSection(
                                    title: _l10n.exploreGoodForSegment,
                                    chips: widget.spot.goodFor!.map((skill) {
                                      return _buildGoodForChip(skill);
                                    }).toList(),
                                  ),
                                );
                              }

                              // Features Section
                              if (widget.spot.spotFeatures != null &&
                                  widget.spot.spotFeatures!.isNotEmpty) {
                                sections.add(
                                  _buildExpandableChipSection(
                                    title: _l10n.spotDetailSectionFeatures,
                                    chips: widget.spot.spotFeatures!.map((
                                      feature,
                                    ) {
                                      return _buildFeatureChip(feature);
                                    }).toList(),
                                  ),
                                );
                              }

                              // Access Section
                              if (widget.spot.spotAccess != null) {
                                sections.add(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _l10n.spotDetailSectionAccess,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      _buildAccessChip(widget.spot.spotAccess!),
                                    ],
                                  ),
                                );
                              }

                              // Facilities Section
                              if (widget.spot.spotFacilities != null &&
                                  widget.spot.spotFacilities!.isNotEmpty) {
                                // Separate available and unavailable facilities
                                final availableFacilities = <Widget>[];
                                final unavailableFacilities = <Widget>[];

                                for (final entry
                                    in widget.spot.spotFacilities!.entries) {
                                  final chip = _buildFacilityChip(
                                    entry.key,
                                    entry.value,
                                  );
                                  if (entry.value == 'yes') {
                                    availableFacilities.add(chip);
                                  } else if (entry.value == 'no') {
                                    unavailableFacilities.add(chip);
                                  }
                                }

                                // Combine: available first, then unavailable
                                final allFacilityChips = [
                                  ...availableFacilities,
                                  ...unavailableFacilities,
                                ];

                                sections.add(
                                  _buildExpandableChipSection(
                                    title: _l10n.spotDetailSectionFacilities,
                                    chips: allFacilityChips,
                                  ),
                                );
                              }

                              // Build dynamic layout based on number of sections
                              if (sections.length == 1) {
                                // Single column, full width
                                return Column(
                                  children: [
                                    sections[0],
                                    const SizedBox(height: 24),
                                  ],
                                );
                              } else if (sections.length == 2) {
                                // Two columns, side by side
                                return Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: sections[0]),
                                        const SizedBox(width: 16),
                                        Expanded(child: sections[1]),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                );
                              } else if (sections.length == 3) {
                                // Two rows: first row has 2 sections, second row has 1 section
                                return Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: sections[0]),
                                        const SizedBox(width: 16),
                                        Expanded(child: sections[1]),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: sections[2]),
                                        const SizedBox(width: 16),
                                        const Expanded(
                                          child: SizedBox(),
                                        ), // Empty space
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                );
                              } else if (sections.length == 4) {
                                // Full 2x2 grid
                                return Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: sections[0]),
                                        const SizedBox(width: 16),
                                        Expanded(child: sections[1]),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: sections[2]),
                                        const SizedBox(width: 16),
                                        Expanded(child: sections[3]),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                );
                              }

                              // Fallback (shouldn't happen)
                              return const SizedBox.shrink();
                            } else {
                              // Single column for narrow screens
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Good For
                                  if (widget.spot.goodFor != null &&
                                      widget.spot.goodFor!.isNotEmpty) ...[
                                    _buildExpandableChipSection(
                                      title: _l10n.exploreGoodForSegment,
                                      chips: widget.spot.goodFor!.map((skill) {
                                        return _buildGoodForChip(skill);
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 24),
                                  ],

                                  // Features
                                  if (widget.spot.spotFeatures != null &&
                                      widget.spot.spotFeatures!.isNotEmpty) ...[
                                    _buildExpandableChipSection(
                                      title: _l10n.spotDetailSectionFeatures,
                                      chips: widget.spot.spotFeatures!.map((
                                        feature,
                                      ) {
                                        return _buildFeatureChip(feature);
                                      }).toList(),
                                    ),
                                    const SizedBox(height: 24),
                                  ],

                                  // Access
                                  if (widget.spot.spotAccess != null) ...[
                                    Text(
                                      _l10n.spotDetailSectionAccess,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    _buildAccessChip(widget.spot.spotAccess!),
                                    const SizedBox(height: 24),
                                  ],

                                  // Facilities
                                  if (widget.spot.spotFacilities != null &&
                                      widget
                                          .spot
                                          .spotFacilities!
                                          .isNotEmpty) ...[
                                    () {
                                      // Separate available and unavailable facilities
                                      final availableFacilities = <Widget>[];
                                      final unavailableFacilities = <Widget>[];

                                      for (final entry
                                          in widget
                                              .spot
                                              .spotFacilities!
                                              .entries) {
                                        final chip = _buildFacilityChip(
                                          entry.key,
                                          entry.value,
                                        );
                                        if (entry.value == 'yes') {
                                          availableFacilities.add(chip);
                                        } else if (entry.value == 'no') {
                                          unavailableFacilities.add(chip);
                                        }
                                      }

                                      // Combine: available first, then unavailable
                                      final allFacilityChips = [
                                        ...availableFacilities,
                                        ...unavailableFacilities,
                                      ];

                                      return _buildExpandableChipSection(
                                        title:
                                            _l10n.spotDetailSectionFacilities,
                                        chips: allFacilityChips,
                                      );
                                    }(),
                                    const SizedBox(height: 24),
                                  ],
                                ],
                              );
                            }
                          },
                        ),

                        // Merged Created by / Source / Contributors section
                        if ((!_spot.createdFromCreateNative &&
                                (_spot.createdBy != null ||
                                    _spot.createdByName != null)) ||
                            (_spot.createdFromCreateNative &&
                                _spot.createdAt != null) ||
                            _spot.spotSource != null ||
                            (_spot.contributors != null &&
                                _spot.contributors!.isNotEmpty)) ...[
                          const SizedBox(height: 24),
                          _buildMergedSourceInfo(),
                          const SizedBox(height: 24),
                        ] else
                          const SizedBox(height: 24),

                        // Videos Section - YouTube + Jumpflix thumbnails, carousel when multiple
                        if ((_spot.youtubeVideoIds != null &&
                                _spot.youtubeVideoIds!.isNotEmpty) ||
                            _spot.id != null) ...[
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 900),
                              child: FutureBuilder<List<JumpflixVideo>>(
                                future:
                                    _jumpflixVideosFuture ??
                                    Future<List<JumpflixVideo>>.value([]),
                                builder: (context, jumpflixSnapshot) {
                                  final l10n = AppLocalizations.of(context)!;
                                  if (jumpflixSnapshot.hasError) {
                                    debugPrint(
                                      l10n.spotDetailJumpflixFetchFailed(
                                        '${jumpflixSnapshot.error}',
                                      ),
                                    );
                                  }
                                  final youtubeIds =
                                      _spot.youtubeVideoIds ?? [];
                                  final jumpflixVideos =
                                      jumpflixSnapshot.data ?? [];
                                  final youtubeItems = youtubeIds
                                      .map(
                                        (id) => _CarouselVideoItem(
                                          thumbnailUrl:
                                              'https://img.youtube.com/vi/$id/hqdefault.jpg',
                                          launchUrl:
                                              'https://www.youtube.com/watch?v=$id',
                                          useYoutubeIcon: true,
                                          brandLabel:
                                              l10n.spotDetailBrandYoutube,
                                        ),
                                      )
                                      .toList();
                                  final jumpflixItems = jumpflixVideos.map((v) {
                                    final baseUri = Uri.tryParse(v.url);
                                    final launchUrl = baseUri != null
                                        ? baseUri
                                              .replace(
                                                queryParameters: {
                                                  ...baseUri.queryParameters,
                                                  'utm_source': 'parkourspot',
                                                  'utm_medium': 'referral',
                                                  'utm_campaign':
                                                      'spot-video-carousel',
                                                  if (_spot.id != null)
                                                    'utm_content':
                                                        'spot-${_spot.id}',
                                                },
                                              )
                                              .toString()
                                        : v.url;
                                    final descPreview = v.description.isNotEmpty
                                        ? (v.description.length <=
                                                  _videoDescriptionPreviewLength
                                              ? v.description
                                              : '${v.description.substring(0, _videoDescriptionPreviewLength)}…')
                                        : null;
                                    return _CarouselVideoItem(
                                      thumbnailUrl: v.thumbnailUrl,
                                      launchUrl: launchUrl,
                                      preferContain: true,
                                      brandLogoAsset:
                                          'assets/images/jumpflix-logo.webp',
                                      brandLabel: v.title.isNotEmpty
                                          ? v.title
                                          : l10n.spotDetailBrandJumpflix,
                                      brandSubtitle:
                                          l10n.spotDetailBrandAsSeenIn,
                                      brandDescription: descPreview,
                                    );
                                  }).toList();
                                  final items = [
                                    ...jumpflixItems,
                                    ...youtubeItems,
                                  ];

                                  if (items.isEmpty) {
                                    if (jumpflixSnapshot.connectionState ==
                                            ConnectionState.waiting &&
                                        (_spot.youtubeVideoIds == null ||
                                            _spot.youtubeVideoIds!.isEmpty)) {
                                      return AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  }

                                  Widget buildThumbnail(
                                    _CarouselVideoItem item,
                                  ) {
                                    final thumb = item.thumbnailUrl;
                                    return thumb != null && thumb.isNotEmpty
                                        ? Image.network(
                                            thumb,
                                            fit: item.preferContain
                                                ? BoxFit.contain
                                                : BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          )
                                        : Container(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            child: Icon(
                                              Icons.movie,
                                              size: 64,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                          );
                                  }

                                  Widget buildBrandOverlay(
                                    _CarouselVideoItem item,
                                  ) {
                                    final hasLogo =
                                        item.brandLogoAsset != null &&
                                        item.brandLogoAsset!.isNotEmpty;
                                    final hasLabel =
                                        item.brandLabel != null &&
                                        item.brandLabel!.isNotEmpty;
                                    final hasSubtitle =
                                        item.brandSubtitle != null &&
                                        item.brandSubtitle!.isNotEmpty;
                                    final hasDescription =
                                        item.brandDescription != null &&
                                        item.brandDescription!.isNotEmpty;
                                    if (!hasLogo &&
                                        !item.useYoutubeIcon &&
                                        !hasLabel &&
                                        !hasSubtitle &&
                                        !hasDescription) {
                                      return const SizedBox.shrink();
                                    }
                                    return Positioned(
                                      left: 8,
                                      bottom: 8,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 280,
                                        ),
                                        child: Material(
                                          color: Colors.black.withValues(
                                            alpha: 0.65,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                if (hasSubtitle) ...[
                                                  Text(
                                                    item.brandSubtitle!,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.8,
                                                          ),
                                                      fontSize: 10,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                ],
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    if (item.useYoutubeIcon)
                                                      FaIcon(
                                                        FontAwesomeIcons
                                                            .youtube,
                                                        color: Colors.white,
                                                        size: 20,
                                                      )
                                                    else if (hasLogo)
                                                      Image.asset(
                                                        item.brandLogoAsset!,
                                                        height: 20,
                                                        fit: BoxFit.contain,
                                                        errorBuilder:
                                                            (
                                                              _,
                                                              error,
                                                              stackTrace,
                                                            ) =>
                                                                const SizedBox.shrink(),
                                                      ),
                                                    if ((item.useYoutubeIcon ||
                                                            hasLogo) &&
                                                        hasLabel)
                                                      const SizedBox(width: 8),
                                                    if (hasLabel)
                                                      Expanded(
                                                        child: Text(
                                                          item.brandLabel!,
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 12,
                                                              ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                                if (hasDescription) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    item.brandDescription!,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.9,
                                                          ),
                                                      fontSize: 11,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  if (items.length == 1) {
                                    final item = items.first;
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: () async {
                                          final uri = Uri.parse(item.launchUrl);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(
                                              uri,
                                              mode: LaunchMode
                                                  .externalApplication,
                                            );
                                          }
                                        },
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              buildThumbnail(item),
                                              Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 40,
                                                ),
                                              ),
                                              buildBrandOverlay(item),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final itemCount = items.length;
                                  final safeIndex = _currentVideoIndex.clamp(
                                    0,
                                    itemCount - 1,
                                  );
                                  if (safeIndex != _currentVideoIndex) {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) {
                                            setState(() {
                                              _currentVideoIndex = safeIndex;
                                            });
                                          }
                                        });
                                  }

                                  return Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: PageView.builder(
                                            controller: _videoPageController,
                                            itemCount: itemCount,
                                            onPageChanged: (i) {
                                              setState(() {
                                                _currentVideoIndex = i;
                                              });
                                            },
                                            itemBuilder: (context, index) {
                                              final item = items[index];
                                              return InkWell(
                                                onTap: () async {
                                                  final uri = Uri.parse(
                                                    item.launchUrl,
                                                  );
                                                  if (await canLaunchUrl(uri)) {
                                                    await launchUrl(
                                                      uri,
                                                      mode: LaunchMode
                                                          .externalApplication,
                                                    );
                                                  }
                                                },
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    buildThumbnail(item),
                                                    Container(
                                                      width: 64,
                                                      height: 64,
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(
                                                        Icons.play_arrow,
                                                        color: Colors.white,
                                                        size: 40,
                                                      ),
                                                    ),
                                                    buildBrandOverlay(item),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),

                                      if (!MobileDetectionService
                                          .isMobileDevice)
                                        Positioned(
                                          left: 8,
                                          top: 0,
                                          bottom: 0,
                                          child: Center(
                                            child: Material(
                                              color: Colors.black.withValues(
                                                alpha: 0.6,
                                              ),
                                              shape: const CircleBorder(),
                                              child: InkWell(
                                                onTap: () {
                                                  final prev =
                                                      _currentVideoIndex - 1;
                                                  final target = prev < 0
                                                      ? itemCount - 1
                                                      : prev;
                                                  _videoPageController
                                                      .animateToPage(
                                                        target,
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 250,
                                                            ),
                                                        curve: Curves.easeOut,
                                                      );
                                                },
                                                customBorder:
                                                    const CircleBorder(),
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.chevron_left,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                      if (!MobileDetectionService
                                          .isMobileDevice)
                                        Positioned(
                                          right: 8,
                                          top: 0,
                                          bottom: 0,
                                          child: Center(
                                            child: Material(
                                              color: Colors.black.withValues(
                                                alpha: 0.6,
                                              ),
                                              shape: const CircleBorder(),
                                              child: InkWell(
                                                onTap: () {
                                                  final next =
                                                      (_currentVideoIndex + 1) %
                                                      itemCount;
                                                  _videoPageController
                                                      .animateToPage(
                                                        next,
                                                        duration:
                                                            const Duration(
                                                              milliseconds: 250,
                                                            ),
                                                        curve: Curves.easeOut,
                                                      );
                                                },
                                                customBorder:
                                                    const CircleBorder(),
                                                child: Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    border: Border.all(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.3,
                                                          ),
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.chevron_right,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                      Positioned(
                                        bottom: 8,
                                        left: 0,
                                        right: 0,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: List.generate(itemCount, (
                                            index,
                                          ) {
                                            final isActive =
                                                index == _currentVideoIndex;
                                            return AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 3,
                                                  ),
                                              width: isActive ? 8 : 6,
                                              height: isActive ? 8 : 6,
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? Colors.white
                                                    : Colors.white54,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Location Section - Small map widget (web-safe placeholder on web)
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              ValueListenableBuilder<bool>(
                                valueListenable: _isSatelliteViewNotifier,
                                builder: (context, isSatellite, child) {
                                  return GoogleMap(
                                    initialCameraPosition: CameraPosition(
                                      target: LatLng(
                                        widget.spot.latitude,
                                        widget.spot.longitude,
                                      ),
                                      zoom: 16,
                                    ),
                                    mapType: isSatellite
                                        ? MapType.hybrid
                                        : MapType.normal,
                                    markers: {
                                      Marker(
                                        markerId: MarkerId(
                                          widget.spot.id ?? 'spot',
                                        ),
                                        position: LatLng(
                                          widget.spot.latitude,
                                          widget.spot.longitude,
                                        ),
                                        icon:
                                            _spotMapPinIcon ??
                                            BitmapDescriptor.defaultMarker,
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
                                      onTap: _locateSpotOnMap,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              // Map Type Toggle Button - Floating Action Button
                              Positioned(
                                bottom: 24,
                                right: 10,
                                child: PointerInterceptor(
                                  child: ValueListenableBuilder<bool>(
                                    valueListenable: _isSatelliteViewNotifier,
                                    builder: (context, isSatellite, child) {
                                      return FloatingActionButton(
                                        onPressed: () {
                                          _isSatelliteViewNotifier.value =
                                              !isSatellite;
                                          final searchState =
                                              Provider.of<SearchStateService>(
                                                context,
                                                listen: false,
                                              );
                                          searchState.setSatellite(
                                            _isSatelliteViewNotifier.value,
                                          );
                                        },
                                        heroTag: 'mapTypeToggleFab',
                                        mini: true,
                                        tooltip: isSatellite
                                            ? _l10n.spotDetailMapSwitchToMap
                                            : _l10n
                                                  .spotDetailMapSwitchToSatellite,
                                        child: Icon(
                                          isSatellite
                                              ? Icons.map
                                              : Icons.terrain,
                                        ),
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
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
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
                                          _l10n.spotDetailMapLocateOnMap,
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

                        // Location Information
                        LocationInfoBox(
                          latitude: widget.spot.latitude,
                          longitude: widget.spot.longitude,
                          address: widget.spot.address,
                          countryCode: widget.spot.countryCode,
                          onOpenInMaps: _openInMaps,
                          onCopyAddress: _copyAddressToClipboard,
                        ),

                        const SizedBox(height: 24),

                        // Additional Info
                        if (widget.spot.createdBy != null ||
                            widget.spot.createdByName != null ||
                            widget.spot.createdAt != null ||
                            widget.spot.duplicateOf != null ||
                            _spot.hasDuplicatePendingChanges ||
                            _duplicateSpots.isNotEmpty ||
                            _isLoadingDuplicates) ...[
                          if (widget.spot.duplicateOf != null ||
                              _originalSpot != null) ...[
                            Builder(
                              builder: (context) {
                                final authService = Provider.of<AuthService>(
                                  context,
                                );
                                final hasStaffAccess =
                                    authService.isAuthenticated &&
                                    authService.userProfile != null &&
                                    (authService.isAdmin ||
                                        authService.isModerator);
                                if (!hasStaffAccess ||
                                    !_spot.hasDuplicatePendingChanges) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  children: [
                                    SpotDuplicateChangesBanner(
                                      changedGroups:
                                          parseSpotDuplicateChangedFieldGroups(
                                            _spot.duplicateChangedFields,
                                          ),
                                      onReview: () => _reviewDuplicateChanges(),
                                      onDismiss: () => _reviewDuplicateChanges(
                                        dismissWithoutDialog: true,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                );
                              },
                            ),
                            GestureDetector(
                              onTap: _isLoadingOriginalSpot
                                  ? null
                                  : () {
                                      if (_originalSpot != null) {
                                        final navigationUrl =
                                            UrlService.generateNavigationUrl(
                                              _originalSpot!.id!,
                                              countryCode:
                                                  _originalSpot!.countryCode,
                                              city: _originalSpot!.city,
                                            );
                                        context.push(navigationUrl);
                                      } else {
                                        // Fallback to simple spot ID route
                                        context.push(
                                          '/spot/${widget.spot.duplicateOf}',
                                        );
                                      }
                                    },
                              child: ListTile(
                                leading: Icon(
                                  Icons.copy_all,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(_l10n.spotDetailDuplicateOf),
                                subtitle: _isLoadingOriginalSpot
                                    ? Text(_l10n.spotDetailLoading)
                                    : Text(
                                        _originalSpot?.name ??
                                            _l10n
                                                .spotDetailOriginalSpotFallback,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                contentPadding: EdgeInsets.zero,
                                trailing: Icon(
                                  Icons.open_in_new,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                          if (widget.spot.duplicateOf == null &&
                              _originalSpot == null) ...[
                            if (_isLoadingDuplicates)
                              ListTile(
                                leading: Icon(
                                  Icons.copy_all,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                                title: Text(_l10n.spotDetailAlsoBasedOn),
                                subtitle: Text(_l10n.spotDetailLoading),
                                contentPadding: EdgeInsets.zero,
                              )
                            else if (_duplicateSpots.isNotEmpty) ...[
                              ListTile(
                                leading: Icon(
                                  Icons.copy_all,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                                title: Text(
                                  _l10n.spotDetailAlsoBasedOn,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                              ..._duplicateSpots.map((duplicate) {
                                return GestureDetector(
                                  onTap: () {
                                    final navigationUrl =
                                        UrlService.generateNavigationUrl(
                                          duplicate.id!,
                                          countryCode: duplicate.countryCode,
                                          city: duplicate.city,
                                        );
                                    context.push(navigationUrl);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 48.0),
                                    child: ListTile(
                                      leading: Icon(
                                        Icons.arrow_right,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                      title: Text(
                                        duplicate.name,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                        ),
                                      ),
                                      subtitle:
                                          duplicate.spotSourceName != null ||
                                              duplicate.spotSource != null
                                          ? Text(
                                              duplicate.spotSourceName ??
                                                  duplicate.spotSource ??
                                                  '',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .secondary
                                                    .withValues(alpha: 0.7),
                                              ),
                                            )
                                          : null,
                                      contentPadding: EdgeInsets.zero,
                                      trailing: Icon(
                                        Icons.open_in_new,
                                        size: 16,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.secondary,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ],

                        const SizedBox(height: 32),
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

  Widget _buildImageCarousel() {
    if (widget.spot.imageUrls == null || widget.spot.imageUrls!.isEmpty) {
      return Container(
        height: 400,
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: NoImagesPlaceholder(
            label: _l10n.noImagesYet,
            layout: NoImagesPlaceholderLayout.detail,
          ),
        ),
      );
    }

    final horizontalInset = SpotDetailUi.contentHorizontalInset(context);

    return SizedBox(
      height: 400,
      width: double.infinity,
      child: Stack(
        children: [
          // Debug info
          if (kDebugMode)
            Positioned(
              top: 8,
              left: horizontalInset,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Images: ${widget.spot.imageUrls!.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    if (kIsWeb) ...[
                      Text(
                        'Mobile: ${MobileDetectionService.isMobileDevice}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                      Text(
                        'Platform: ${MobileDetectionService.preferredMapsApp}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

          // Hybrid image carousel with both swiping and arrow buttons
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openFullScreenViewer(_currentImageIndex),
            onHorizontalDragUpdate: (details) {
              // Track horizontal drag to distinguish from vertical scroll
            },
            onHorizontalDragEnd: (details) {
              // Only handle swipe if it's a significant swipe (not just a tap)
              if (details.primaryVelocity != null) {
                // Swipe left (negative velocity) = next image
                if (details.primaryVelocity! < -500) {
                  _nextImage();
                }
                // Swipe right (positive velocity) = previous image
                else if (details.primaryVelocity! > 500) {
                  _previousImage();
                }
              }
            },
            child: Material(
              color: Colors.transparent,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: ResizedSpotImage(
                  key: ValueKey(_currentImageIndex),
                  imageUrl: widget.spot.imageUrls![_currentImageIndex],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 400,
                  placeholder: (context, url) => Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) {
                    final originalUrl =
                        widget.spot.imageUrls != null &&
                            _currentImageIndex < widget.spot.imageUrls!.length
                        ? widget.spot.imageUrls![_currentImageIndex]
                        : null;
                    debugPrint('Image error: $error');
                    debugPrint('Resized URL (failed to load): $url');
                    debugPrint('Original URL (stored in spot): $originalUrl');
                    return Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _l10n.spotDetailImageFailedToLoad,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Gradient overlay for better text readability (ignores pointer events)
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Navigation arrows (left and right)
          if (widget.spot.imageUrls!.length > 1) ...[
            // Left arrow
            Positioned(
              left: horizontalInset,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => _previousImage(),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Right arrow
            Positioned(
              right: horizontalInset,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: () => _nextImage(),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Enhanced page indicators and controls
          if (widget.spot.imageUrls!.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Enhanced page indicator dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.spot.imageUrls!.length, (
                      index,
                    ) {
                      final isActive = index == _currentImageIndex;
                      return GestureDetector(
                        onTap: () {
                          // Allow tapping on dots to navigate
                          _goToImage(index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          width: isActive ? 6 : 6,
                          height: isActive ? 6 : 6,
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white : Colors.white54,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _nextImage() {
    if (_currentImageIndex < widget.spot.imageUrls!.length - 1) {
      setState(() {
        _currentImageIndex++;
      });
    } else {
      // Loop to first image
      setState(() {
        _currentImageIndex = 0;
      });
    }
  }

  void _previousImage() {
    if (_currentImageIndex > 0) {
      setState(() {
        _currentImageIndex--;
      });
    } else {
      // Loop to last image
      setState(() {
        _currentImageIndex = widget.spot.imageUrls!.length - 1;
      });
    }
  }

  void _goToImage(int index) {
    if (index >= 0 && index < widget.spot.imageUrls!.length) {
      setState(() {
        _currentImageIndex = index;
      });
    }
  }

  void _openFullScreenViewer(int initialIndex) async {
    if (widget.spot.imageUrls == null || widget.spot.imageUrls!.isEmpty) {
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenPhotoViewer(
          imageUrls: widget.spot.imageUrls!,
          initialIndex: initialIndex,
        ),
      ),
    );

    // Update the current image index if the viewer returned a new index
    if (result != null && result is int && mounted) {
      setState(() {
        _currentImageIndex = result;
      });
    }
  }

  Future<double?> _loadUserRatingFuture() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.isAuthenticated && authService.userProfile != null) {
        final spotService = Provider.of<SpotService>(context, listen: false);
        final userRating = await spotService.getUserRating(
          widget.spot.id!,
          authService.userProfile!.id,
        );
        if (mounted && userRating != null) {
          setState(() {
            _userRating = userRating;
            _previousRating = userRating; // Set the previous rating
            _hasRated = true;
          });
          return userRating;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error loading user rating: $e');
      return null;
    }
  }

  void _loadRatingStatsSubscription() {
    final spotId = widget.spot.id;
    if (spotId == null) return;

    _ratingStatsSubscription?.cancel();
    if (_cachedRatingStats == null) {
      setState(() {
        _isLoadingRatingStats = true;
      });
    }

    final spotService = Provider.of<SpotService>(context, listen: false);
    _ratingStatsSubscription = spotService
        .watchSpotRatingStats(spotId)
        .listen(
          (ratingStats) {
            if (!mounted) return;
            setState(() {
              _cachedRatingStats = ratingStats;
              _isLoadingRatingStats = false;
            });
          },
          onError: (Object error) {
            debugPrint('Error listening to rating stats: $error');
            if (!mounted) return;
            setState(() {
              _isLoadingRatingStats = false;
            });
          },
        );
  }

  /// Submits a rating directly when a star is clicked.
  /// Tapping the same star again clears the rating.
  Future<void> _submitRatingDirectly(
    double rating, {
    VoidCallback? refreshModal,
  }) async {
    void bumpModal() => refreshModal?.call();
    var savedRating = _previousRating;
    var savedHasRated = _hasRated;
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.userProfile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailMustBeLoggedInToRate),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (rating == _previousRating && _hasRated) {
        await _clearRatingDirectly(refreshModal: bumpModal);
        return;
      }

      savedRating = _previousRating;
      savedHasRated = _hasRated;

      setState(() {
        _userRating = rating;
        _hasRated = true;
      });
      bumpModal();

      final spotService = Provider.of<SpotService>(context, listen: false);
      final success = await spotService.rateSpot(
        widget.spot.id!,
        rating,
        authService.userProfile!.id,
      );

      if (success && mounted) {
        setState(() {
          _previousRating = rating;
        });
        bumpModal();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailRatingSubmitted(rating.toInt())),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        setState(() {
          _userRating = savedRating;
          _hasRated = savedHasRated;
        });
        bumpModal();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailRatingSubmitFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userRating = savedRating;
          _hasRated = savedHasRated;
        });
        bumpModal();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailRatingSubmitError('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearRatingDirectly({VoidCallback? refreshModal}) async {
    void bumpModal() => refreshModal?.call();
    if (!_hasRated) return;

    final savedRating = _previousRating;
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.userProfile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailMustBeLoggedInToRate),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        _userRating = 0;
        _hasRated = false;
        _previousRating = 0;
      });
      bumpModal();

      final spotService = Provider.of<SpotService>(context, listen: false);
      final success = await spotService.clearUserRating(
        widget.spot.id!,
        authService.userProfile!.id,
      );

      if (success && mounted) {
        bumpModal();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailRatingCleared),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        setState(() {
          _userRating = savedRating;
          _hasRated = true;
          _previousRating = savedRating;
        });
        bumpModal();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailRatingClearFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userRating = savedRating;
          _hasRated = true;
          _previousRating = savedRating;
        });
        bumpModal();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotDetailRatingSubmitError('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, dynamic>?>
  _showCreateNativeSpotConfirmationDialog() async {
    if (widget.spot.spotSource == null) {
      if (!mounted) return null;
      _showErrorSnack(_l10n.spotDetailNotExternalSource);
      return null;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      if (!mounted) return null;
      _showErrorSnack(_l10n.spotDetailMustBeLoggedInCreateNative);
      return null;
    }

    String? selectedReportId;
    final notesController = TextEditingController();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final l10n = AppLocalizations.of(dialogContext)!;
          return AlertDialog(
            title: Text(l10n.spotDetailCreateNativeDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.spotDetailCreateNativeDialogBody),
                  const SizedBox(height: 16),
                  ModeratorActionFields(
                    spotId: _spot.id,
                    notesController: notesController,
                    showReportSelector: true,
                    onReportSelected: (reportId) {
                      setState(() {
                        selectedReportId = reportId;
                      });
                    },
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
                child: Text(l10n.profileCancel),
              ),
              ElevatedButton(
                onPressed: () {
                  final notes = notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim();
                  notesController.dispose();
                  Navigator.of(dialogContext).pop({
                    'confirmed': true,
                    'reportId': selectedReportId,
                    'notes': notes,
                  });
                },
                child: Text(l10n.spotDetailCreateButton),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _createNativeSpot({String? reportId, String? notes}) async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      _showErrorSnack(_l10n.spotDetailUnableCreateNativeNow);
      return;
    }

    final spotService = Provider.of<SpotService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if user is authenticated
    if (!authService.isAuthenticated || authService.currentUser == null) {
      if (!mounted) return;
      _showErrorSnack(_l10n.spotDetailMustBeLoggedInCreateNative);
      return;
    }

    try {
      // Create native spot from current spot
      final nativeSpotId = await spotService.createNativeSpotFromExisting(
        widget.spot,
        authService.currentUser!.uid,
        authService.userProfile?.displayName ??
            authService.currentUser!.email ??
            authService.currentUser!.uid,
      );

      if (nativeSpotId == null) {
        final error =
            spotService.error ?? _l10n.spotDetailFailedCreateNativeSpot;
        _showErrorSnack(error);
        return;
      }

      // Now mark the current spot as duplicate of the newly created native spot
      // Since we're creating from the current spot, photos and YouTube links are already in the native spot
      // So we don't need to transfer them
      final userId = authService.currentUser!.uid;
      final userName =
          authService.userProfile?.displayName ??
          authService.currentUser!.displayName ??
          authService.currentUser!.email;

      final success = await spotService.markSpotAsDuplicate(
        widget.spot.id!,
        nativeSpotId,
        transferPhotos: false, // Already copied to native spot
        transferYoutubeLinks: false, // Already copied to native spot
        userId: userId,
        userName: userName,
        reportId: reportId,
        notes: notes,
      );

      if (success) {
        // Load and set the original spot locally to update UI without navigation
        try {
          final createdOriginal = await spotService.getSpotById(nativeSpotId);
          if (mounted) {
            setState(() {
              _originalSpot = createdOriginal;
            });
          }
        } catch (e) {
          // ignore fetch failure; UI already updated via success snackbar
        }

        _showSuccessSnack(_l10n.spotDetailNativeCreatedDuplicateMarked);
      } else {
        final error =
            spotService.error ?? _l10n.spotDetailFailedMarkDuplicateGeneric;
        _showErrorSnack(error);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack(_l10n.spotDetailErrorCreatingNativeSpot('$e'));
    }
  }

  Future<void> _showMarkAsDuplicateDialog() async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      _showErrorSnack(_l10n.spotDetailUnableMarkDuplicateNow);
      return;
    }

    // Check if spot is already marked as duplicate
    if (widget.spot.duplicateOf != null) {
      if (!mounted) return;
      _showErrorSnack(_l10n.spotDetailAlreadyMarkedDuplicate);
      return;
    }

    final String? selectedSpotIdOrAction = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SpotSelectionDialog(
        currentSpotId: widget.spot.id,
        currentSpot: widget.spot,
        allowExternalSources: false,
        showNearbySpots: true,
      ),
    );

    if (!mounted || selectedSpotIdOrAction == null) {
      return;
    }

    // Handle normal duplicate marking flow
    final selectedSpotId = selectedSpotIdOrAction;

    final spotService = Provider.of<SpotService>(context, listen: false);

    // Check if duplicate spot has photos or YouTube links to transfer
    final hasPhotos =
        widget.spot.imageUrls != null && widget.spot.imageUrls!.isNotEmpty;
    final hasYoutubeLinks =
        widget.spot.youtubeVideoIds != null &&
        widget.spot.youtubeVideoIds!.isNotEmpty;

    // Show confirmation dialog with transfer options
    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (confirmContext) {
        return _DuplicateTransferDialog(
          hasPhotos: hasPhotos,
          hasYoutubeLinks: hasYoutubeLinks,
          spot: widget.spot,
        );
      },
    );

    if (!mounted || result == null) return;

    final transferPhotos = result['transferPhotos'] ?? false;
    final transferYoutubeLinks = result['transferYoutubeLinks'] ?? false;
    final overwriteName = result['overwriteName'] ?? false;
    final overwriteDescription = result['overwriteDescription'] ?? false;
    final overwriteLocation = result['overwriteLocation'] ?? false;
    final overwriteSpotAttributes = result['overwriteSpotAttributes'] ?? false;
    final reportId = result['reportId'] as String?;
    final notes = result['notes'] as String?;

    // Mark the spot as duplicate
    try {
      // Get user info for audit logging (moderator action)
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      final userName =
          authService.userProfile?.displayName ??
          authService.currentUser?.displayName ??
          authService.currentUser?.email;

      final success = await spotService.markSpotAsDuplicate(
        widget.spot.id!,
        selectedSpotId,
        transferPhotos: transferPhotos,
        transferYoutubeLinks: transferYoutubeLinks,
        overwriteName: overwriteName,
        overwriteDescription: overwriteDescription,
        overwriteLocation: overwriteLocation,
        overwriteSpotAttributes: overwriteSpotAttributes,
        userId: userId,
        userName: userName,
        reportId: reportId,
        notes: notes,
      );

      if (success) {
        // Load and set the original spot locally to update UI without navigation
        try {
          final original = await spotService.getSpotById(selectedSpotId);
          if (mounted) {
            setState(() {
              _originalSpot = original;
            });
          }
        } catch (e) {
          // ignore fetch failure; UI already updated via success snackbar
        }

        _showSuccessSnack(_l10n.spotDetailSpotMarkedDuplicateSuccess);
      } else {
        final error =
            spotService.error ?? _l10n.spotDetailFailedMarkDuplicateGeneric;
        _showErrorSnack(error);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack(_l10n.spotDetailErrorMarkingDuplicateSpot('$e'));
    }
  }

  Future<Map<String, dynamic>?> _showHideSpotConfirmationDialog() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated ||
        (!authService.isModerator && !authService.isAdmin)) {
      if (!mounted) return null;
      _showErrorSnack(_l10n.spotDetailModeratorsOnlyHideUnhide);
      return null;
    }

    final isHiding = !_spot.hidden;

    String? selectedReportId;
    final notesController = TextEditingController();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final l10n = AppLocalizations.of(dialogContext)!;
          return AlertDialog(
            title: Text(
              isHiding
                  ? l10n.spotDetailHideSpotTitle
                  : l10n.spotDetailUnhideSpotTitle,
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHiding
                        ? l10n.spotDetailHideSpotMessage
                        : l10n.spotDetailUnhideSpotMessage,
                  ),
                  const SizedBox(height: 16),
                  ModeratorActionFields(
                    spotId: _spot.id,
                    notesController: notesController,
                    showReportSelector: true,
                    onReportSelected: (reportId) {
                      setState(() {
                        selectedReportId = reportId;
                      });
                    },
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
                child: Text(l10n.profileCancel),
              ),
              ElevatedButton(
                onPressed: () {
                  final notes = notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim();
                  notesController.dispose();
                  Navigator.of(dialogContext).pop({
                    'confirmed': true,
                    'reportId': selectedReportId,
                    'notes': notes,
                  });
                },
                child: Text(
                  isHiding
                      ? l10n.spotDetailActionHide
                      : l10n.spotDetailActionUnhide,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleSpotHidden({String? reportId, String? notes}) async {
    if (_spot.id == null) {
      if (!mounted) return;
      _showErrorSnack(_l10n.spotDetailUnableHideUnhideNow);
      return;
    }

    final spotService = Provider.of<SpotService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if user is authenticated and is a moderator
    if (!authService.isAuthenticated ||
        (!authService.isModerator && !authService.isAdmin)) {
      if (!mounted) return;
      _showErrorSnack(_l10n.spotDetailModeratorsOnlyHideUnhide);
      return;
    }

    final newHiddenState = !_spot.hidden;
    final userId = authService.currentUser?.uid;
    final userName =
        authService.userProfile?.displayName ??
        authService.currentUser?.displayName ??
        authService.currentUser?.email;

    try {
      final success = await spotService.setSpotHidden(
        _spot.id!,
        newHiddenState,
        userId: userId,
        userName: userName,
        reportId: reportId,
        notes: notes,
      );

      if (!mounted) return;

      if (success) {
        // Reload the spot to get the updated state
        final updatedSpot = await spotService.getSpotById(_spot.id!);
        if (updatedSpot != null && mounted) {
          setState(() {
            _currentSpot = updatedSpot;
          });
          // Update document title if spot name changed
          _updateDocumentTitle();
        }

        _showSuccessSnack(
          newHiddenState
              ? _l10n.spotDetailSpotHiddenSuccess
              : _l10n.spotDetailSpotUnhiddenSuccess,
        );
      } else {
        final error =
            spotService.error ??
            (newHiddenState
                ? _l10n.spotDetailFailedHideSpot
                : _l10n.spotDetailFailedUnhideSpot);
        _showErrorSnack(error);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack(
        newHiddenState
            ? _l10n.spotDetailErrorHidingSpot('$e')
            : _l10n.spotDetailErrorUnhidingSpot('$e'),
      );
    }
  }

  Future<Map<String, dynamic>?>
  _showRemoveDuplicateStatusConfirmationDialog() async {
    if (_spot.duplicateOf == null) {
      if (!mounted) return null;
      _showErrorSnack(_l10n.spotDetailNotMarkedAsDuplicate);
      return null;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated ||
        (!authService.isModerator && !authService.isAdmin)) {
      if (!mounted) return null;
      _showErrorSnack(_l10n.spotDetailModeratorsOnlyRemoveDuplicateStatus);
      return null;
    }

    final TextEditingController notesController = TextEditingController();
    String? selectedReportId;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final l10n = AppLocalizations.of(dialogContext)!;
            return AlertDialog(
              title: Text(l10n.spotDetailMenuRemoveDuplicateStatus),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.spotDetailRemoveDuplicateDialogBody),
                    const SizedBox(height: 16),
                    ModeratorActionFields(
                      spotId: _spot.id,
                      notesController: notesController,
                      onReportSelected: (reportId) {
                        setState(() {
                          selectedReportId = reportId;
                        });
                      },
                      showReportSelector: true,
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
                  child: Text(l10n.profileCancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    final result = {
                      'confirmed': true,
                      'reportId': selectedReportId,
                      'notes': notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                    };
                    notesController.dispose();
                    Navigator.of(dialogContext).pop(result);
                  },
                  child: Text(l10n.spotDetailRemoveButton),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeDuplicateStatus({String? reportId, String? notes}) async {
    if (_spot.id == null) {
      if (!mounted) return;
      _showErrorSnack(_l10n.spotDetailUnableRemoveDuplicateStatusNow);
      return;
    }

    final spotService = Provider.of<SpotService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if user is authenticated and is a moderator
    if (!authService.isAuthenticated ||
        (!authService.isModerator && !authService.isAdmin)) {
      if (!mounted) return;
      _showErrorSnack(_l10n.spotDetailModeratorsOnlyRemoveDuplicateStatus);
      return;
    }

    // Check if spot is actually marked as duplicate
    if (_spot.duplicateOf == null) {
      if (!mounted) return;
      _showErrorSnack(_l10n.spotDetailNotMarkedAsDuplicate);
      return;
    }

    final userId = authService.currentUser?.uid;
    final userName =
        authService.userProfile?.displayName ??
        authService.currentUser?.displayName ??
        authService.currentUser?.email;

    try {
      // Update the spot to remove duplicate status
      final updatedSpot = _spot.copyWith(
        duplicateOf: null,
        updatedAt: DateTime.now(),
      );

      final success = await spotService.updateSpot(
        updatedSpot,
        userId: userId,
        userName: userName,
        reportId: reportId,
        notes: notes,
      );

      if (!mounted) return;

      if (success) {
        // Reload the spot to get the updated state
        final reloadedSpot = await spotService.getSpotById(_spot.id!);
        if (reloadedSpot != null && mounted) {
          setState(() {
            _currentSpot = reloadedSpot;
            // Clear original spot since it's no longer a duplicate
            _originalSpot = null;
          });
          // Update document title if spot name changed
          _updateDocumentTitle();
        }

        _showSuccessSnack(_l10n.spotDetailDuplicateStatusRemovedSuccess);
      } else {
        final error =
            spotService.error ??
            _l10n.spotDetailFailedRemoveDuplicateStatusGeneric;
        _showErrorSnack(error);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack(_l10n.spotDetailErrorRemovingDuplicateStatus('$e'));
    }
  }

  Future<void> _showDeleteDialog() async {
    if (_spot.id == null) return;

    // Show loading dialog while fetching counts
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(
              AppLocalizations.of(dialogContext)!.spotDetailCheckingLinkedData,
            ),
          ],
        ),
      ),
    );

    // Fetch linked data counts
    final firestore = FirebaseFirestore.instance;
    final spotId = _spot.id!;

    int ratingsCount = 0;
    int spotReportsCount = 0;
    int duplicateSpotsCount = 0;

    try {
      // Query counts in parallel
      final results = await Future.wait([
        firestore
            .collection('ratings')
            .where('spotId', isEqualTo: spotId)
            .count()
            .get(),
        firestore
            .collection('spotReports')
            .where('spotId', isEqualTo: spotId)
            .count()
            .get(),
        firestore
            .collection('spots')
            .where('duplicateOf', isEqualTo: spotId)
            .count()
            .get(),
      ]);

      ratingsCount = results[0].count ?? 0;
      spotReportsCount = results[1].count ?? 0;
      duplicateSpotsCount = results[2].count ?? 0;
    } catch (e) {
      debugPrint('Error fetching linked data counts: $e');
      // Continue with counts as 0 if there's an error
    }

    // Close loading dialog
    if (mounted) {
      Navigator.pop(context);
    }

    final canDelete =
        ratingsCount == 0 && spotReportsCount == 0 && duplicateSpotsCount == 0;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final l10n = AppLocalizations.of(dialogContext)!;
          String? selectedReportId;
          final notesController = TextEditingController();

          return AlertDialog(
            title: Text(l10n.spotDetailDeleteSpotDialogTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.spotDetailDeleteSpotConfirmMessage),
                  const SizedBox(height: 16),
                  if (ratingsCount > 0 ||
                      spotReportsCount > 0 ||
                      duplicateSpotsCount > 0) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(l10n.spotDetailLinkedDataHeading),
                    const SizedBox(height: 8),
                    if (ratingsCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          l10n.spotDetailLinkedRatingsLine(ratingsCount),
                        ),
                      ),
                    if (spotReportsCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          l10n.spotDetailLinkedReportsLine(spotReportsCount),
                        ),
                      ),
                    if (duplicateSpotsCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          l10n.spotDetailLinkedDuplicatesLine(
                            duplicateSpotsCount,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.spotDetailResolveLinksBeforeDelete,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (canDelete) ...[
                    const SizedBox(height: 16),
                    ModeratorActionFields(
                      spotId: _spot.id,
                      notesController: notesController,
                      showReportSelector: true,
                      onReportSelected: (reportId) {
                        setState(() {
                          selectedReportId = reportId;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  notesController.dispose();
                  Navigator.pop(context);
                },
                child: Text(l10n.profileCancel),
              ),
              TextButton(
                onPressed: canDelete
                    ? () async {
                        final notes = notesController.text.trim().isEmpty
                            ? null
                            : notesController.text.trim();
                        notesController.dispose();
                        Navigator.pop(context);

                        // Capture spot data before deletion for audit logging
                        final spotId = _spot.id!;
                        final spotName = _spot.name;
                        final capturedRatingsCount = ratingsCount;
                        final capturedSpotReportsCount = spotReportsCount;
                        final capturedDuplicateSpotsCount = duplicateSpotsCount;

                        try {
                          final spotService = Provider.of<SpotService>(
                            context,
                            listen: false,
                          );
                          final authService = Provider.of<AuthService>(
                            context,
                            listen: false,
                          );

                          // Get user info for audit logging
                          final userId =
                              authService.userProfile?.id ??
                              authService.currentUser?.uid;
                          final userName =
                              authService.userProfile?.displayName ??
                              authService.currentUser?.displayName ??
                              authService.currentUser?.email;

                          final success = await spotService.deleteSpot(spotId);

                          if (success) {
                            // Log the deletion to audit log BEFORE checking mounted state
                            // This doesn't require the widget to be mounted
                            try {
                              final auditLogService = AuditLogService();
                              await auditLogService.logSpotDelete(
                                spotId: spotId,
                                userId: userId,
                                userName: userName,
                                reportId: selectedReportId,
                                metadata: {
                                  'spotName': spotName,
                                  'ratingsCount': capturedRatingsCount,
                                  'spotReportsCount': capturedSpotReportsCount,
                                  'duplicateSpotsCount':
                                      capturedDuplicateSpotsCount,
                                  if (notes != null && notes.isNotEmpty)
                                    'notes': notes,
                                },
                              );
                            } catch (auditError) {
                              debugPrint(
                                'Error creating audit log entry: $auditError',
                              );
                              // Don't fail the deletion if audit logging fails
                            }

                            // Now check if mounted for UI operations
                            if (!mounted) return;
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  _l10n.spotDetailSpotDeletedSuccess,
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );

                            // Navigate to explore immediately after successful deletion
                            // Use replace to ensure we don't go back to the deleted spot
                            if (!mounted) return;
                            context.replace('/explore');
                          } else {
                            if (!mounted) return;
                            final scaffoldMessenger = ScaffoldMessenger.of(
                              context,
                            );
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(_l10n.spotDetailFailedDeleteSpot),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        } catch (e) {
                          if (!mounted) return;
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                _l10n.spotDetailErrorDeletingSpot('$e'),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    : null,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.spotDetailMenuDeleteSpot),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAccessChip(String accessKey) {
    final icon = SpotAttributes.getIcon('access', accessKey);
    final label = SpotAttributes.getLabel('access', accessKey);
    final description = SpotAttributes.getDescription('access', accessKey);
    Color backgroundColor;
    Color textColor;

    switch (accessKey) {
      case 'public':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green.shade700;
        break;
      case 'restricted':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange.shade700;
        break;
      case 'paid':
        backgroundColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue.shade700;
        break;
      default:
        backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        textColor = Theme.of(context).colorScheme.onSurface;
    }

    return GestureDetector(
      onTap: () => _showDescriptionDialog(label, description, icon),
      child: Chip(
        avatar: Icon(icon, size: 16, color: textColor),
        label: Text(label),
        backgroundColor: backgroundColor,
        labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.normal),
      ),
    );
  }

  Widget _buildFeatureChip(String featureKey) {
    final icon = SpotAttributes.getIcon('features', featureKey);
    final label = SpotAttributes.getLabel('features', featureKey);
    final description = SpotAttributes.getDescription('features', featureKey);

    return GestureDetector(
      onTap: () => _showDescriptionDialog(label, description, icon),
      child: Chip(
        avatar: Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        label: Text(label),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.1),
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildFacilityChip(String facilityKey, String status) {
    final icon = SpotAttributes.getIcon('facilities', facilityKey);
    final label = SpotAttributes.getLabel('facilities', facilityKey);
    final description = SpotAttributes.getDescription(
      'facilities',
      facilityKey,
    );
    Color backgroundColor;
    Color textColor;
    IconData statusIcon;

    // Set colors and status icon based on status
    if (status == 'yes') {
      backgroundColor = Colors.green.withValues(alpha: 0.1);
      textColor = Colors.green.shade700;
      statusIcon = Icons.check;
    } else if (status == 'no') {
      backgroundColor = Colors.red.withValues(alpha: 0.1);
      textColor = Colors.red.shade700;
      statusIcon = Icons.close;
    } else {
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      textColor = Theme.of(context).colorScheme.onSurface;
      statusIcon = Icons.info;
    }

    return GestureDetector(
      onTap: () => _showDescriptionDialog(label, description, icon),
      child: Chip(
        avatar: Icon(icon, size: 16, color: textColor),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 4),
            Icon(statusIcon, size: 14, color: textColor),
          ],
        ),
        backgroundColor: backgroundColor,
        labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.normal),
      ),
    );
  }

  Widget _buildExpandableChipSection({
    required String title,
    required List<Widget> chips,
    int initialCount = 3,
  }) {
    if (chips.length <= initialCount) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      );
    }

    return StatefulBuilder(
      builder: (context, setState) {
        final isExpanded = _expandedSections[title] ?? false;
        final visibleChips = isExpanded
            ? chips
            : chips.take(initialCount).toList();
        final remainingCount = chips.length - initialCount;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...visibleChips,
                if (!isExpanded && remainingCount > 0)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _expandedSections[title] = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.expand_more,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _l10n.spotDetailExpandMoreCount(remainingCount),
                            style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildGoodForChip(String skillKey) {
    final icon = SpotAttributes.getIcon('goodFor', skillKey);
    final label = SpotAttributes.getLabel('goodFor', skillKey);
    final description = SpotAttributes.getDescription('goodFor', skillKey);

    return GestureDetector(
      onTap: () => _showDescriptionDialog(label, description, icon),
      child: Chip(
        avatar: Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        label: Text(label),
        backgroundColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.1),
        labelStyle: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.normal,
        ),
      ),
    );
  }

  void _showDescriptionDialog(String title, String description, IconData icon) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_l10n.spotDetailClose),
            ),
          ],
        );
      },
    );
  }
}

class _ReportDuplicateDialog extends StatefulWidget {
  final Spot spot;

  const _ReportDuplicateDialog({required this.spot});

  @override
  State<_ReportDuplicateDialog> createState() => _ReportDuplicateDialogState();
}

class _ReportDuplicateDialogState extends State<_ReportDuplicateDialog> {
  late final TextEditingController detailsController;
  late final TextEditingController emailController;
  late final TextEditingController searchController;

  String? duplicateSpotError;
  String? emailError;
  String? submissionError;
  String? searchError;
  bool isSubmitting = false;
  bool _isLoadingNearby = false;
  bool _isSearching = false;
  Spot? _selectedDuplicateSpot;
  Spot? _foundSpot;
  List<Spot> _nearbySpots = [];
  String? _duplicateOfSpotId;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    detailsController = TextEditingController();
    searchController = TextEditingController();
    emailController = TextEditingController(
      text: authService.isAuthenticated
          ? (authService.userProfile?.email ??
                authService.currentUser?.email ??
                '')
          : '',
    );
    // Load nearby spots automatically
    _loadNearbySpots();
  }

  @override
  void dispose() {
    detailsController.dispose();
    emailController.dispose();
    searchController.dispose();
    super.dispose();
  }

  /// Calculate approximate bounds for ~50 meters radius
  Map<String, double> _calculateBounds(double lat, double lng) {
    const double latOffset = 50 / 111000; // ~0.00045 degrees
    final double lngOffset =
        latOffset / (math.cos(lat * math.pi / 180.0).abs());

    return {
      'minLat': lat - latOffset,
      'maxLat': lat + latOffset,
      'minLng': lng - lngOffset,
      'maxLng': lng + lngOffset,
    };
  }

  Future<void> _loadNearbySpots() async {
    final lat = widget.spot.latitude;
    final lng = widget.spot.longitude;

    setState(() {
      _isLoadingNearby = true;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final bounds = _calculateBounds(lat, lng);

      final result = await spotService.getTopRankedSpotsInBounds(
        bounds['minLat']!,
        bounds['maxLat']!,
        bounds['minLng']!,
        bounds['maxLng']!,
        limit: 20,
        spotSource: null, // Allow all sources for duplicate reports
      );

      final spots = (result['spots'] as List<Spot>?) ?? <Spot>[];

      // Filter out the current spot
      final filteredSpots = spots.where((spot) {
        return spot.id != widget.spot.id;
      }).toList();

      if (mounted) {
        setState(() {
          _nearbySpots = filteredSpots;
          _isLoadingNearby = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading nearby spots: $e');
      if (mounted) {
        setState(() {
          _isLoadingNearby = false;
        });
      }
    }
  }

  /// Extract spot ID from input (can be URL, ID, or text containing a URL)
  String? _extractSpotId(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    final urlPattern = RegExp(
      r'(https?://[^\s<>"()]+|/[^\s<>"()]+)',
      caseSensitive: false,
    );

    final urlMatches = urlPattern.allMatches(trimmed);
    for (final match in urlMatches) {
      final urlCandidate = match.group(0);
      if (urlCandidate == null) continue;

      String? spotId;

      if (urlCandidate.startsWith('http://') ||
          urlCandidate.startsWith('https://')) {
        spotId = UrlService.extractSpotIdFromUrl(urlCandidate);
        if (spotId != null) return spotId;

        try {
          final uri = Uri.parse(urlCandidate);
          final pathSegments = uri.pathSegments;
          if (pathSegments.length == 2 && pathSegments[0] == 'spot') {
            return pathSegments[1];
          }
        } catch (_) {}
      }

      if (urlCandidate.startsWith('/')) {
        spotId = UrlService.extractSpotIdFromUrl(
          'https://parkour.spot$urlCandidate',
        );
        if (spotId != null) return spotId;

        try {
          final uri = Uri.parse('https://parkour.spot$urlCandidate');
          final pathSegments = uri.pathSegments;
          if (pathSegments.length == 2 && pathSegments[0] == 'spot') {
            return pathSegments[1];
          }
        } catch (_) {}
      }
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final spotId = UrlService.extractSpotIdFromUrl(trimmed);
      if (spotId != null) return spotId;

      try {
        final uri = Uri.parse(trimmed);
        final pathSegments = uri.pathSegments;
        if (pathSegments.length == 2 && pathSegments[0] == 'spot') {
          return pathSegments[1];
        }
      } catch (_) {}
      return null;
    }

    if (trimmed.startsWith('/')) {
      final spotId = UrlService.extractSpotIdFromUrl(
        'https://parkour.spot$trimmed',
      );
      if (spotId != null) return spotId;

      try {
        final uri = Uri.parse('https://parkour.spot$trimmed');
        final pathSegments = uri.pathSegments;
        if (pathSegments.length == 2 && pathSegments[0] == 'spot') {
          return pathSegments[1];
        }
      } catch (_) {}
      return null;
    }

    if (RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(trimmed)) {
      return trimmed;
    }

    return null;
  }

  Future<void> _searchSpot() async {
    final l10n = AppLocalizations.of(context)!;
    final input = searchController.text.trim();
    if (input.isEmpty) {
      setState(() {
        searchError = l10n.spotDetailDuplicateSearchEmpty;
        _foundSpot = null;
      });
      return;
    }

    final spotId = _extractSpotId(input);
    if (spotId == null) {
      setState(() {
        searchError = l10n.spotDetailDuplicateInvalidUrl;
        _foundSpot = null;
      });
      return;
    }

    if (spotId == widget.spot.id) {
      setState(() {
        searchError = l10n.spotDetailDuplicateCannotSelectSelf;
        _foundSpot = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      searchError = null;
      _foundSpot = null;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final spot = await spotService.getSpotById(spotId);

      if (!mounted) return;

      if (spot == null) {
        setState(() {
          searchError = l10n.spotDetailDuplicateSpotNotFound;
          _foundSpot = null;
          _isSearching = false;
        });
        return;
      }

      setState(() {
        _foundSpot = spot;
        _isSearching = false;
        searchError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        searchError = l10n.spotDetailDuplicateFailedLoadSpot('$e');
        _foundSpot = null;
        _isSearching = false;
      });
    }
  }

  void _selectSpot(Spot spot) {
    setState(() {
      _selectedDuplicateSpot = spot;
      _duplicateOfSpotId = spot.id;
      duplicateSpotError = null;
      _foundSpot = null;
      searchController.clear();
      searchError = null;
    });
  }

  Widget _buildSpotSelectionItem(
    Spot spot,
    ThemeData theme,
    BuildContext dialogContext,
  ) {
    return Card(
      child: InkWell(
        onTap: () => _selectSpot(spot),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Spot image thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: spot.imageUrls != null && spot.imageUrls!.isNotEmpty
                    ? ResizedSpotImage(
                        imageUrl: spot.imageUrls!.first,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 80,
                          height: 80,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 80,
                          height: 80,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.image_not_supported,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_not_supported,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Spot details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(spot.name, style: theme.textTheme.titleSmall),
                    if (spot.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        spot.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (spot.address != null || spot.city != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              [
                                spot.address,
                                spot.city,
                              ].whereType<String>().join(', '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext dialogContext) {
    final theme = Theme.of(dialogContext);
    final l10n = AppLocalizations.of(dialogContext)!;
    final authService = Provider.of<AuthService>(dialogContext, listen: false);
    final reportService = Provider.of<SpotReportService>(
      dialogContext,
      listen: false,
    );
    final bool isLoggedIn =
        authService.isAuthenticated && authService.userProfile != null;

    return PopScope(
      canPop: !isSubmitting,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.copy_all, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.spotDetailFlagDuplicateDialogTitle)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.spotDetailFlagDuplicateIntro,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.spotDetailFlagDuplicateWhichQuestion,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (duplicateSpotError != null) ...[
                  Text(
                    duplicateSpotError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_selectedDuplicateSpot == null) ...[
                  // Search field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: l10n.spotDetailDuplicateSearchHint,
                            prefixIcon: const Icon(Icons.link),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor:
                                theme.colorScheme.surfaceContainerHighest,
                            errorText: searchError,
                          ),
                          onSubmitted: (_) => _searchSpot(),
                          enabled: !_isSearching,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isSearching ? null : _searchSpot,
                        icon: _isSearching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(l10n.spotDetailSearch),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Nearby spots section
                  if (_isLoadingNearby)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_nearbySpots.isNotEmpty) ...[
                    Text(
                      l10n.spotDetailNearbySpotsWithin50m,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: SingleChildScrollView(
                        child: Column(
                          children: _nearbySpots.map((spot) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildSpotSelectionItem(
                                spot,
                                theme,
                                dialogContext,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Found spot from search
                  if (_foundSpot != null) ...[
                    Text(
                      l10n.spotDetailFoundSpot,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _buildSpotSelectionItem(_foundSpot!, theme, dialogContext),
                    const SizedBox(height: 16),
                  ],
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedDuplicateSpot!.name,
                                  style: theme.textTheme.titleSmall,
                                ),
                                if (_selectedDuplicateSpot!
                                    .description
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedDuplicateSpot!.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (_selectedDuplicateSpot!.id != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.spotDetailSpotIdLabel(
                                      _selectedDuplicateSpot!.id!,
                                    ),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedDuplicateSpot = null;
                                _duplicateOfSpotId = null;
                                duplicateSpotError = null;
                              });
                            },
                            tooltip: l10n.spotDetailRemoveSelectionTooltip,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: detailsController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l10n.spotDetailReportAdditionalDetails,
                    hintText: l10n.spotDetailReportAdditionalDetailsHint,
                  ),
                ),
                const SizedBox(height: 16),
                if (!isLoggedIn) ...[
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.spotDetailReportEmailLabel,
                      hintText: l10n.spotDetailReportEmailLabel,
                      helperText: l10n.spotDetailReportEmailHelper,
                      errorText: emailError,
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.2),
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
                            emailController.text.isNotEmpty
                                ? l10n.spotDetailReportReachOutAt(
                                    emailController.text,
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
                if (submissionError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    submissionError!,
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
            onPressed: isSubmitting
                ? null
                : () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profileCancel),
          ),
          FilledButton(
            onPressed: isSubmitting
                ? null
                : () async {
                    setState(() {
                      duplicateSpotError = null;
                      emailError = null;
                      submissionError = null;
                    });

                    if (_duplicateOfSpotId == null) {
                      setState(() {
                        duplicateSpotError =
                            l10n.spotDetailDuplicateReportSelectRequired;
                      });
                      return;
                    }

                    final trimmedEmail = emailController.text.trim();
                    if (!isLoggedIn) {
                      if (trimmedEmail.isEmpty) {
                        setState(() {
                          emailError = l10n.spotDetailEmailRequired;
                        });
                        return;
                      }
                      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                      if (!emailRegex.hasMatch(trimmedEmail)) {
                        setState(() {
                          emailError = l10n.spotDetailEmailInvalid;
                        });
                        return;
                      }
                    }

                    FocusScope.of(dialogContext).unfocus();
                    setState(() {
                      isSubmitting = true;
                    });

                    final trimmedDetails = detailsController.text.trim();
                    final reporterName = (() {
                      final profileName = authService.userProfile?.displayName;
                      if (profileName != null &&
                          profileName.trim().isNotEmpty) {
                        return profileName.trim();
                      }
                      final authName = authService.currentUser?.displayName;
                      if (authName != null && authName.trim().isNotEmpty) {
                        return authName.trim();
                      }
                      return null;
                    })();
                    final trimmedContactEmail = isLoggedIn
                        ? (emailController.text.trim().isNotEmpty
                              ? emailController.text.trim()
                              : authService.userProfile?.email ??
                                    authService.currentUser?.email ??
                                    '')
                        : trimmedEmail;

                    final success = await reportService.submitSpotReport(
                      spotId: widget.spot.id!,
                      spotName: widget.spot.name,
                      categories: ['Duplicate spot'],
                      details: trimmedDetails.isEmpty ? null : trimmedDetails,
                      contactEmail: trimmedContactEmail.isEmpty
                          ? null
                          : trimmedContactEmail,
                      reporterUserId: authService.userProfile?.id,
                      reporterName: reporterName,
                      reporterEmail:
                          authService.userProfile?.email ??
                          authService.currentUser?.email,
                      spotCountryCode: widget.spot.countryCode,
                      spotCity: widget.spot.city,
                      duplicateOfSpotId: _duplicateOfSpotId,
                    );

                    if (success) {
                      if (!mounted) return;
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      if (!mounted) return;
                      setState(() {
                        isSubmitting = false;
                        submissionError = l10n.spotDetailReportSendFailed;
                      });
                    }
                  },
            child: isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(dialogContext).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Text(l10n.spotDetailSubmitReport),
          ),
        ],
      ),
    );
  }
}

class _ReportSpotDialog extends StatefulWidget {
  final Spot spot;

  const _ReportSpotDialog({required this.spot});

  @override
  State<_ReportSpotDialog> createState() => _ReportSpotDialogState();
}

class _ReportSpotDialogState extends State<_ReportSpotDialog> {
  late final TextEditingController otherController;
  late final TextEditingController detailsController;
  late final TextEditingController emailController;

  String? selectedCategory;
  String? categoryError;
  String? otherDescriptionError;
  String? emailError;
  String? submissionError;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    otherController = TextEditingController();
    detailsController = TextEditingController();
    emailController = TextEditingController(
      text: authService.isAuthenticated
          ? (authService.userProfile?.email ??
                authService.currentUser?.email ??
                '')
          : '',
    );
  }

  @override
  void dispose() {
    otherController.dispose();
    detailsController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext dialogContext) {
    final l10n = AppLocalizations.of(dialogContext)!;
    final theme = Theme.of(dialogContext);
    final authService = Provider.of<AuthService>(dialogContext, listen: false);
    final reportService = Provider.of<SpotReportService>(
      dialogContext,
      listen: false,
    );
    final bool isLoggedIn =
        authService.isAuthenticated && authService.userProfile != null;
    final String otherCategoryLabel = SpotReportService.defaultCategories.last;
    final bool otherSelected = selectedCategory == otherCategoryLabel;

    return PopScope(
      canPop: !isSubmitting,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.flag_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.spotDetailReportThisSpotTitle)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.spotDetailReportIntro(widget.spot.name),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.spotDetailReportWhatWrong,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: InputDecoration(
                  labelText: l10n.spotDetailReportCategoryLabel,
                  hintText: l10n.spotDetailReportCategoryHint,
                  errorText: categoryError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                ),
                items: SpotReportService.defaultCategories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(_spotDetailReportCategoryLabel(l10n, category)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                    categoryError = null;
                    // Clear other description when switching away from "Other"
                    if (value != otherCategoryLabel) {
                      otherController.clear();
                      otherDescriptionError = null;
                    }
                  });
                },
              ),
              if (selectedCategory != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer.withValues(
                      alpha: 0.2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _spotDetailReportCategoryDescription(
                            l10n,
                            selectedCategory!,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (otherSelected) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: otherController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.spotDetailReportDescribeIssue,
                    hintText: l10n.spotDetailReportDescribeIssueHint,
                    errorText: otherDescriptionError,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: detailsController,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: l10n.spotDetailReportAdditionalDetails,
                  hintText: l10n.spotDetailReportAdditionalDetailsHint,
                ),
              ),
              const SizedBox(height: 16),
              if (!isLoggedIn) ...[
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.spotDetailReportEmailLabel,
                    hintText: l10n.spotDetailReportEmailLabel,
                    helperText: l10n.spotDetailReportEmailHelper,
                    errorText: emailError,
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
                          emailController.text.isNotEmpty
                              ? l10n.spotDetailReportReachOutAt(
                                  emailController.text,
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
              if (submissionError != null) ...[
                const SizedBox(height: 16),
                Text(
                  submissionError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSubmitting
                ? null
                : () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profileCancel),
          ),
          FilledButton(
            onPressed: isSubmitting
                ? null
                : () async {
                    setState(() {
                      categoryError = null;
                      otherDescriptionError = null;
                      emailError = null;
                      submissionError = null;
                    });

                    if (selectedCategory == null) {
                      setState(() {
                        categoryError = l10n.spotDetailReportCategoryRequired;
                      });
                      return;
                    }

                    final trimmedOther = otherController.text.trim();
                    if (otherSelected && trimmedOther.isEmpty) {
                      setState(() {
                        otherDescriptionError =
                            l10n.spotDetailReportCategoryOtherDescribe;
                      });
                      return;
                    }

                    final trimmedEmail = emailController.text.trim();
                    if (!isLoggedIn) {
                      if (trimmedEmail.isEmpty) {
                        setState(() {
                          emailError = l10n.spotDetailEmailRequired;
                        });
                        return;
                      }
                      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                      if (!emailRegex.hasMatch(trimmedEmail)) {
                        setState(() {
                          emailError = l10n.spotDetailEmailInvalid;
                        });
                        return;
                      }
                    }

                    FocusScope.of(dialogContext).unfocus();
                    setState(() {
                      isSubmitting = true;
                    });

                    final trimmedDetails = detailsController.text.trim();
                    final reporterName = (() {
                      final profileName = authService.userProfile?.displayName;
                      if (profileName != null &&
                          profileName.trim().isNotEmpty) {
                        return profileName.trim();
                      }
                      final authName = authService.currentUser?.displayName;
                      if (authName != null && authName.trim().isNotEmpty) {
                        return authName.trim();
                      }
                      return null;
                    })();
                    final trimmedContactEmail = isLoggedIn
                        ? (emailController.text.trim().isNotEmpty
                              ? emailController.text.trim()
                              : authService.userProfile?.email ??
                                    authService.currentUser?.email ??
                                    '')
                        : trimmedEmail;

                    final success = await reportService.submitSpotReport(
                      spotId: widget.spot.id!,
                      spotName: widget.spot.name,
                      categories: [selectedCategory!],
                      otherCategory: otherSelected ? trimmedOther : null,
                      details: trimmedDetails.isEmpty ? null : trimmedDetails,
                      contactEmail: trimmedContactEmail.isEmpty
                          ? null
                          : trimmedContactEmail,
                      reporterUserId: authService.userProfile?.id,
                      reporterName: reporterName,
                      reporterEmail:
                          authService.userProfile?.email ??
                          authService.currentUser?.email,
                      spotCountryCode: widget.spot.countryCode,
                      spotCity: widget.spot.city,
                    );

                    if (success) {
                      if (!mounted) return;
                      Navigator.of(dialogContext).pop(true);
                    } else {
                      if (!mounted) return;
                      setState(() {
                        isSubmitting = false;
                        submissionError = l10n.spotDetailReportSendFailed;
                      });
                    }
                  },
            child: isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(dialogContext).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Text(l10n.spotDetailSubmitReport),
          ),
        ],
      ),
    );
  }
}

class _DuplicateTransferDialog extends StatefulWidget {
  final bool hasPhotos;
  final bool hasYoutubeLinks;
  final Spot spot;

  const _DuplicateTransferDialog({
    required this.hasPhotos,
    required this.hasYoutubeLinks,
    required this.spot,
  });

  @override
  State<_DuplicateTransferDialog> createState() =>
      _DuplicateTransferDialogState();
}

class _DuplicateTransferDialogState extends State<_DuplicateTransferDialog> {
  bool _transferPhotos = false;
  bool _transferYoutubeLinks = false;
  bool _overwriteName = false;
  bool _overwriteDescription = false;
  bool _overwriteLocation = false;
  bool _overwriteSpotAttributes = false;
  final TextEditingController _notesController = TextEditingController();
  String? _selectedReportId;

  bool get _hasName => widget.spot.name.isNotEmpty;
  bool get _hasDescription => widget.spot.description.isNotEmpty;
  bool get _hasLocation {
    return (widget.spot.latitude != 0.0 && widget.spot.longitude != 0.0) ||
        (widget.spot.address != null && widget.spot.address!.isNotEmpty) ||
        (widget.spot.city != null && widget.spot.city!.isNotEmpty) ||
        (widget.spot.countryCode != null &&
            widget.spot.countryCode!.isNotEmpty);
  }

  bool get _hasSpotAttributes {
    return (widget.spot.spotAccess != null &&
            widget.spot.spotAccess!.isNotEmpty) ||
        (widget.spot.spotFeatures != null &&
            widget.spot.spotFeatures!.isNotEmpty) ||
        (widget.spot.spotFacilities != null &&
            widget.spot.spotFacilities!.isNotEmpty) ||
        (widget.spot.goodFor != null && widget.spot.goodFor!.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasTransferOptions =
        widget.hasPhotos || widget.hasYoutubeLinks || _hasSpotAttributes;
    final hasOverwriteOptions = _hasName || _hasDescription || _hasLocation;

    return AlertDialog(
      title: Text(l10n.spotDetailMarkDuplicateTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.spotDetailMarkDuplicateBody),
            if (hasTransferOptions || hasOverwriteOptions) ...[
              const SizedBox(height: 16),
              if (hasTransferOptions) ...[
                Text(
                  l10n.spotDetailMarkDuplicateAddToOriginal,
                  style: const TextStyle(),
                ),
                const SizedBox(height: 8),
                if (widget.hasPhotos)
                  CheckboxListTile(
                    title: Text(l10n.spotDetailMarkDuplicatePhotos),
                    value: _transferPhotos,
                    onChanged: (value) {
                      setState(() {
                        _transferPhotos = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (widget.hasYoutubeLinks)
                  CheckboxListTile(
                    title: Text(l10n.spotDetailMarkDuplicateYoutube),
                    value: _transferYoutubeLinks,
                    onChanged: (value) {
                      setState(() {
                        _transferYoutubeLinks = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (_hasSpotAttributes)
                  CheckboxListTile(
                    title: Text(l10n.spotDetailMarkDuplicateSpotAttributes),
                    value: _overwriteSpotAttributes,
                    onChanged: (value) {
                      setState(() {
                        _overwriteSpotAttributes = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
              if (hasOverwriteOptions) ...[
                if (hasTransferOptions) const SizedBox(height: 16),
                Text(l10n.spotDetailMarkDuplicateOverwrite),
                const SizedBox(height: 8),
                if (_hasName)
                  CheckboxListTile(
                    title: Text(l10n.spotDetailMarkDuplicateName),
                    value: _overwriteName,
                    onChanged: (value) {
                      setState(() {
                        _overwriteName = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (_hasDescription)
                  CheckboxListTile(
                    title: Text(l10n.spotDetailMarkDuplicateDescription),
                    value: _overwriteDescription,
                    onChanged: (value) {
                      setState(() {
                        _overwriteDescription = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (_hasLocation)
                  CheckboxListTile(
                    title: Text(l10n.spotDetailMarkDuplicateLocation),
                    value: _overwriteLocation,
                    onChanged: (value) {
                      setState(() {
                        _overwriteLocation = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
            ],
            const SizedBox(height: 16),
            ModeratorActionFields(
              spotId: widget.spot.id,
              notesController: _notesController,
              onReportSelected: (reportId) {
                setState(() {
                  _selectedReportId = reportId;
                });
              },
              showReportSelector: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.profileCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop({
            'transferPhotos': _transferPhotos,
            'transferYoutubeLinks': _transferYoutubeLinks,
            'overwriteName': _overwriteName,
            'overwriteDescription': _overwriteDescription,
            'overwriteLocation': _overwriteLocation,
            'overwriteSpotAttributes': _overwriteSpotAttributes,
            'reportId': _selectedReportId,
            'notes': _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          }),
          child: Text(l10n.spotDetailConfirm),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}

class _SuggestPhotoDialog extends StatefulWidget {
  final Spot spot;

  const _SuggestPhotoDialog({required this.spot});

  @override
  State<_SuggestPhotoDialog> createState() => _SuggestPhotoDialogState();
}

class _SuggestPhotoDialogState extends State<_SuggestPhotoDialog> {
  late final TextEditingController detailsController;
  late final TextEditingController emailController;
  final List<PreparedImage> _selectedImages = [];
  bool _isPreparingImages = false;
  String? _imageProgressLabel;
  bool _isUploading = false;
  bool _isSubmitting = false;
  String? _submissionError;
  String? emailError;

  @override
  void initState() {
    super.initState();
    detailsController = TextEditingController();
    final authService = Provider.of<AuthService>(context, listen: false);
    emailController = TextEditingController(
      text: authService.isAuthenticated
          ? (authService.userProfile?.email ??
                authService.currentUser?.email ??
                '')
          : '',
    );
  }

  @override
  void dispose() {
    detailsController.dispose();
    emailController.dispose();
    super.dispose();
  }

  bool get _isBusy => _isPreparingImages || _isSubmitting || _isUploading;

  Future<void> _pickImages() async {
    final l10n = AppLocalizations.of(context)!;

    List<XFile> pickedFiles;
    try {
      pickedFiles = await pickImagesFromGallery();
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.spotDetailPickImagesFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted || pickedFiles.isEmpty) return;

    setState(() {
      _isPreparingImages = true;
      _imageProgressLabel = null;
      _submissionError = null;
    });
    await yieldToUi();

    try {
      final preparedImages = await preparePickedFiles(
        pickedFiles,
        onProgress: ({required current, required total, required phase}) {
          if (!mounted) return;
          setState(() {
            _imageProgressLabel = imagePickProgressLabel(current, total);
          });
        },
      );

      if (!mounted) return;

      if (preparedImages.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(preparedImages);
        });
      }
    } on ImagePreparationException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ImagePreparationException
                  ? e.message
                  : l10n.spotDetailPickImagesFailed,
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingImages = false;
          _imageProgressLabel = null;
        });
      }
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitPhotos() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedImages.isEmpty) {
      setState(() {
        _submissionError = l10n.spotDetailSelectAtLeastOnePhoto;
      });
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final bool isLoggedIn =
        authService.isAuthenticated && authService.userProfile != null;

    final trimmedEmail = emailController.text.trim();
    if (!isLoggedIn) {
      if (trimmedEmail.isEmpty) {
        setState(() {
          emailError = l10n.spotDetailEmailRequired;
          _submissionError = null;
        });
        return;
      }
      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!emailRegex.hasMatch(trimmedEmail)) {
        setState(() {
          emailError = l10n.spotDetailEmailInvalid;
          _submissionError = null;
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
      emailError = null;
    });
    await yieldToUi();

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final reportService = Provider.of<SpotReportService>(
        context,
        listen: false,
      );

      // Upload photos to /suggestions/ path (bytes already prepared at pick time)
      setState(() {
        _isUploading = true;
      });
      await yieldToUi();

      final photoUrls = await spotService.uploadSuggestedPhotos(
        preparedPhotos: _selectedImages,
      );

      setState(() {
        _isUploading = false;
      });

      // Get reporter info
      final reporterName = (() {
        final profileName = authService.userProfile?.displayName;
        if (profileName != null && profileName.trim().isNotEmpty) {
          return profileName.trim();
        }
        final authName = authService.currentUser?.displayName;
        if (authName != null && authName.trim().isNotEmpty) {
          return authName.trim();
        }
        return null;
      })();

      final trimmedContactEmail = isLoggedIn
          ? (emailController.text.trim().isNotEmpty
                ? emailController.text.trim()
                : authService.userProfile?.email ??
                      authService.currentUser?.email ??
                      '')
          : trimmedEmail;

      // Create spot report
      final success = await reportService.submitSpotReport(
        spotId: widget.spot.id!,
        spotName: widget.spot.name,
        categories: ['Photo suggestion'],
        details: detailsController.text.trim().isEmpty
            ? null
            : detailsController.text.trim(),
        contactEmail: trimmedContactEmail.isEmpty ? null : trimmedContactEmail,
        reporterUserId: authService.userProfile?.id,
        reporterName: reporterName,
        reporterEmail:
            authService.userProfile?.email ?? authService.currentUser?.email,
        spotCountryCode: widget.spot.countryCode,
        spotCity: widget.spot.city,
        suggestedPhotoUrls: photoUrls,
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _submissionError = l10n.spotDetailSuggestPhotosSubmitFailed;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      debugPrint('Error submitting photo suggestion: $e');
      if (mounted) {
        setState(() {
          _submissionError = l10n.spotDetailSuggestPhotosSubmitError('$e');
          _isSubmitting = false;
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext dialogContext) {
    final theme = Theme.of(dialogContext);
    final l10n = AppLocalizations.of(dialogContext)!;
    final authService = Provider.of<AuthService>(dialogContext, listen: false);
    final bool isLoggedIn =
        authService.isAuthenticated && authService.userProfile != null;

    return PopScope(
      canPop: !_isBusy,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_photo_alternate, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.spotDetailSuggestPhotosTitle)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.spotDetailSuggestPhotosIntro,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                // Photo selection
                Text(
                  l10n.spotDetailSelectPhotos,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isBusy ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text(l10n.spotDetailPickPhotos),
                ),
                if (_isPreparingImages) ...[
                  const SizedBox(height: 12),
                  ImageProcessingBanner(
                    message: l10n.publicProfileProcessingImage,
                    progressLabel: _imageProgressLabel,
                  ),
                ],
                if (_isUploading) ...[
                  const SizedBox(height: 12),
                  ImageProcessingBanner(message: l10n.publicProfileUploading),
                ],
                const SizedBox(height: 16),
                // Display selected images
                if (_selectedImages.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_selectedImages.length, (index) {
                      return Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            child: MemoryImagePreview(
                              bytes: _selectedImages[index].bytes,
                              size: 100,
                              borderRadius: 8,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              color: theme.colorScheme.error,
                              onPressed: _isBusy
                                  ? null
                                  : () => _removeImage(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                // Details field
                Text(
                  l10n.spotDetailAdditionalDetailsOptional,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l10n.spotDetailAdditionalDetailsHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  enabled: !_isBusy,
                ),
                const SizedBox(height: 16),
                if (!isLoggedIn) ...[
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) {
                      if (emailError != null) {
                        setState(() => emailError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: l10n.spotDetailReportEmailLabel,
                      hintText: l10n.spotDetailReportEmailLabel,
                      helperText: l10n.spotDetailSuggestPhotosEmailHelper,
                      errorText: emailError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                    enabled: !_isBusy,
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.2),
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
                            emailController.text.isNotEmpty
                                ? l10n.spotDetailReportReachOutAt(
                                    emailController.text,
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
                if (_submissionError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _submissionError!,
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
            onPressed: _isBusy
                ? null
                : () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.profileCancel),
          ),
          ElevatedButton(
            onPressed: (_isBusy || _isUploading) ? null : _submitPhotos,
            child: (_isSubmitting || _isUploading)
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.publicProfileUploading),
                    ],
                  )
                : Text(l10n.spotDetailSubmit),
          ),
        ],
      ),
    );
  }
}

class _SuggestEditDialog extends StatefulWidget {
  final Spot spot;

  const _SuggestEditDialog({required this.spot});

  @override
  State<_SuggestEditDialog> createState() => _SuggestEditDialogState();
}

class _SuggestEditDialogState extends State<_SuggestEditDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _emailController;

  LatLng? _suggestedLatLng;
  String? _geocodedAddress;
  bool _isGeocoding = false;

  String? _selectedAccess;
  final Set<String> _selectedFeatures = {};
  final Map<String, String> _selectedFacilities = {};
  final Set<String> _selectedGoodFor = {};

  bool _isSubmitting = false;
  String? _submissionError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.spot.name);
    _descriptionController = TextEditingController(
      text: widget.spot.description,
    );
    final authService = Provider.of<AuthService>(context, listen: false);
    _emailController = TextEditingController(
      text: authService.isAuthenticated
          ? (authService.userProfile?.email ??
                authService.currentUser?.email ??
                '')
          : '',
    );
    _selectedAccess = widget.spot.spotAccess;
    _selectedFeatures.addAll(widget.spot.spotFeatures ?? []);
    _selectedFacilities.addAll(widget.spot.spotFacilities ?? {});
    _selectedGoodFor.addAll(widget.spot.goodFor ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final initial = LatLng(widget.spot.latitude, widget.spot.longitude);
    final result = await ExploreEntityPickerScreen.show(
      context,
      config: ExploreEntityPickerConfig(
        mode: ExploreEntityPickerMode.locationOnly,
        initialLocation: initial,
      ),
    );
    final picked = result?.location;
    if (picked != null && mounted) {
      setState(() {
        _suggestedLatLng = picked;
        _isGeocoding = true;
      });
      _geocodeLocation(picked.latitude, picked.longitude);
    }
  }

  Future<void> _geocodeLocation(double lat, double lng) async {
    try {
      final geocoding = Provider.of<GeocodingService>(context, listen: false);
      final details = await geocoding.geocodeCoordinatesDetails(lat, lng);
      if (mounted) {
        setState(() {
          _geocodedAddress =
              details['address'] ?? details['city'] ?? details['countryCode'];
          _isGeocoding = false;
        });
      }
    } catch (e) {
      debugPrint('Error geocoding: $e');
      if (mounted) {
        setState(() => _isGeocoding = false);
      }
    }
  }

  void _toggleFeature(String key, bool selected) {
    setState(() {
      if (selected) {
        _selectedFeatures.add(key);
      } else {
        _selectedFeatures.remove(key);
      }
    });
  }

  void _onFacilityChanged(String key, String value) {
    setState(() {
      _selectedFacilities[key] = value;
    });
  }

  void _toggleGoodFor(String key, bool selected) {
    setState(() {
      if (selected) {
        _selectedGoodFor.add(key);
      } else {
        _selectedGoodFor.remove(key);
      }
    });
  }

  bool _hasSuggestions() {
    if (_suggestedLatLng != null) return true;
    if (_nameController.text.trim() != widget.spot.name) return true;
    if (_descriptionController.text.trim() != widget.spot.description) {
      return true;
    }
    final currentGoodFor = Set<String>.from(widget.spot.goodFor ?? []);
    if (!_setEquals(_selectedGoodFor, currentGoodFor)) return true;
    final currentFeatures = Set<String>.from(widget.spot.spotFeatures ?? []);
    if (!_setEquals(_selectedFeatures, currentFeatures)) return true;
    if (_selectedAccess != widget.spot.spotAccess) return true;
    final currentFacilities = widget.spot.spotFacilities ?? {};
    if (!_mapEquals(_selectedFacilities, currentFacilities)) return true;
    return false;
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.every((x) => b.contains(x));
  }

  bool _mapEquals(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_hasSuggestions()) {
      setState(() {
        _submissionError = l10n.spotDetailSuggestEditSuggestChange;
      });
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final bool isLoggedIn =
        authService.isAuthenticated && authService.userProfile != null;

    final trimmedEmail = _emailController.text.trim();
    if (!isLoggedIn) {
      if (trimmedEmail.isEmpty) {
        setState(() {
          _emailError = l10n.spotDetailEmailRequired;
          _submissionError = null;
        });
        return;
      }
      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!emailRegex.hasMatch(trimmedEmail)) {
        setState(() {
          _emailError = l10n.spotDetailEmailInvalid;
          _submissionError = null;
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
      _emailError = null;
    });

    try {
      final reportService = Provider.of<SpotReportService>(
        context,
        listen: false,
      );

      final trimmedContactEmail = isLoggedIn
          ? (_emailController.text.trim().isNotEmpty
                ? _emailController.text.trim()
                : authService.userProfile?.email ??
                      authService.currentUser?.email ??
                      '')
          : trimmedEmail;

      final reporterName = (() {
        final profileName = authService.userProfile?.displayName;
        if (profileName != null && profileName.trim().isNotEmpty) {
          return profileName.trim();
        }
        final authName = authService.currentUser?.displayName;
        if (authName != null && authName.trim().isNotEmpty) {
          return authName.trim();
        }
        return null;
      })();

      String? suggestedName;
      if (_nameController.text.trim() != widget.spot.name) {
        suggestedName = _nameController.text.trim();
        if (suggestedName.isEmpty) suggestedName = null;
      }
      String? suggestedDescription;
      if (_descriptionController.text.trim() != widget.spot.description) {
        suggestedDescription = _descriptionController.text.trim();
      }
      double? suggestedLat;
      double? suggestedLng;
      if (_suggestedLatLng != null) {
        final loc = _suggestedLatLng!;
        suggestedLat = loc.latitude;
        suggestedLng = loc.longitude;
      }
      List<String>? suggestedGoodFor;
      final currentGoodFor = Set<String>.from(widget.spot.goodFor ?? []);
      if (!_setEquals(_selectedGoodFor, currentGoodFor) &&
          _selectedGoodFor.isNotEmpty) {
        suggestedGoodFor = _selectedGoodFor.toList();
      }
      List<String>? suggestedSpotFeatures;
      final currentFeatures = Set<String>.from(widget.spot.spotFeatures ?? []);
      if (!_setEquals(_selectedFeatures, currentFeatures) &&
          _selectedFeatures.isNotEmpty) {
        suggestedSpotFeatures = _selectedFeatures.toList();
      }
      String? suggestedSpotAccess;
      if (_selectedAccess != widget.spot.spotAccess &&
          _selectedAccess != null) {
        suggestedSpotAccess = _selectedAccess;
      }
      Map<String, String>? suggestedSpotFacilities;
      final currentFacilities = widget.spot.spotFacilities ?? {};
      if (!_mapEquals(_selectedFacilities, currentFacilities) &&
          _selectedFacilities.isNotEmpty) {
        suggestedSpotFacilities = Map.from(_selectedFacilities);
      }

      final hasAny =
          suggestedName != null ||
          suggestedDescription != null ||
          (suggestedLat != null && suggestedLng != null) ||
          (suggestedGoodFor != null && suggestedGoodFor.isNotEmpty) ||
          (suggestedSpotFeatures != null && suggestedSpotFeatures.isNotEmpty) ||
          suggestedSpotAccess != null ||
          (suggestedSpotFacilities != null &&
              suggestedSpotFacilities.isNotEmpty);

      if (!hasAny) {
        setState(() {
          _submissionError = l10n.spotDetailSuggestEditSuggestChange;
          _isSubmitting = false;
        });
        return;
      }

      final success = await reportService.submitSpotReport(
        spotId: widget.spot.id!,
        spotName: widget.spot.name,
        categories: ['Edit suggestion'],
        details: null,
        contactEmail: trimmedContactEmail.isEmpty ? null : trimmedContactEmail,
        reporterUserId: authService.userProfile?.id,
        reporterName: reporterName,
        reporterEmail:
            authService.userProfile?.email ?? authService.currentUser?.email,
        spotCountryCode: widget.spot.countryCode,
        spotCity: widget.spot.city,
        suggestedName: suggestedName,
        suggestedDescription: suggestedDescription,
        suggestedLatitude: suggestedLat,
        suggestedLongitude: suggestedLng,
        suggestedGoodFor: suggestedGoodFor,
        suggestedSpotFeatures: suggestedSpotFeatures,
        suggestedSpotAccess: suggestedSpotAccess,
        suggestedSpotFacilities: suggestedSpotFacilities,
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _submissionError = l10n.spotDetailSuggestEditSubmitFailed;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      debugPrint('Error submitting edit suggestion: $e');
      if (mounted) {
        setState(() {
          _submissionError = l10n.spotDetailSuggestEditSubmitError('$e');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final authService = Provider.of<AuthService>(context, listen: false);
    final bool isLoggedIn =
        authService.isAuthenticated && authService.userProfile != null;

    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit_note, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.spotDetailSuggestEditTitle)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.spotDetailSuggestEditIntro,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                if (!isLoggedIn) ...[
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) {
                      if (_emailError != null) {
                        setState(() => _emailError = null);
                      }
                    },
                    decoration: InputDecoration(
                      labelText: l10n.spotDetailReportEmailLabel,
                      hintText: l10n.spotDetailReportEmailLabel,
                      helperText: l10n.spotDetailSuggestEditEmailHelper,
                      errorText: _emailError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest,
                    ),
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.2),
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
                  const SizedBox(height: 16),
                ],
                Text(
                  l10n.spotDetailMarkDuplicateLocation,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _pickLocation,
                  icon: Icon(
                    _suggestedLatLng != null ? Icons.check_circle : Icons.map,
                    size: 18,
                    color: _suggestedLatLng != null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  label: Text(
                    _suggestedLatLng != null
                        ? l10n.spotDetailChangeLocationPicked
                        : l10n.spotDetailPickLocationOnMap,
                  ),
                ),
                if (_suggestedLatLng != null &&
                    (_isGeocoding || _geocodedAddress != null)) ...[
                  const SizedBox(height: 4),
                  Builder(
                    builder: (context) {
                      final loc = _suggestedLatLng!;
                      return Text(
                        _isGeocoding
                            ? l10n.spotDetailGeocoding
                            : (_geocodedAddress ??
                                  '${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  l10n.spotDetailFieldTitle,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: l10n.spotDetailFieldTitleHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  enabled: !_isSubmitting,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.spotDetailFieldDescription,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: l10n.spotDetailFieldDescriptionHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  enabled: !_isSubmitting,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.spotDetailFieldSpotAttributes,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SpotAttributesSection(
                  selectedAccess: _selectedAccess,
                  selectedFeatures: _selectedFeatures,
                  selectedFacilities: _selectedFacilities,
                  selectedGoodFor: _selectedGoodFor,
                  onAccessChanged: (v) => setState(() => _selectedAccess = v),
                  onToggleFeature: _toggleFeature,
                  onFacilityChanged: _onFacilityChanged,
                  onToggleGoodFor: _toggleGoodFor,
                ),
                if (_submissionError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _submissionError!,
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
            onPressed: _isSubmitting
                ? null
                : () => Navigator.of(context).pop(false),
            child: Text(l10n.profileCancel),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.spotDetailSubmit),
          ),
        ],
      ),
    );
  }
}

class _SpotSaveMenu extends StatelessWidget {
  final String spotId;
  final VoidCallback onAddToCustomList;

  /// When true, omit bottom padding (e.g. embedded in a horizontal strip).
  final bool stripBottomPadding;

  /// Icon-only chips when the action row is below [SpotDetailUi.quickActionsCompactLayoutMaxWidth].
  final bool compactQuickActions;

  // ignore: prefer_const_constructors_in_immutables
  _SpotSaveMenu({
    required this.spotId,
    required this.onAddToCustomList,
    this.stripBottomPadding = false,
    required this.compactQuickActions,
  });

  @override
  Widget build(BuildContext context) {
    final showChipLabel = !compactQuickActions;
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        final bottomInset = stripBottomPadding ? 0.0 : 12.0;

        if (authService.isLoading) {
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SpotDetailQuickActionChip(
                icon: Icons.bookmark_border,
                iconColor: colorScheme.onSurface.withValues(alpha: 0.38),
                label: l10n.spotDetailLoading,
                showSpinner: true,
                showLabel: showChipLabel,
              ),
            ),
          );
        }

        if (!authService.isAuthenticated) {
          final loginRedirect =
              '/login?redirectTo=${Uri.encodeComponent('/spot/$spotId')}';
          final guestMenu = PopupMenuButton<_SpotSaveMenuAction>(
            tooltip: l10n.spotDetailSaveMenuTooltip,
            position: PopupMenuPosition.under,
            borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
            splashRadius: 20,
            onSelected: (action) {
              if (action == _SpotSaveMenuAction.login && context.mounted) {
                context.go(loginRedirect);
              }
            },
            itemBuilder: (menuContext) {
              final menuTheme = Theme.of(menuContext);
              final menuL10n = AppLocalizations.of(menuContext)!;
              return <PopupMenuEntry<_SpotSaveMenuAction>>[
                PopupMenuItem<_SpotSaveMenuAction>(
                  value: _SpotSaveMenuAction.login,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        menuL10n.spotDetailSaveMenuSignInTitle,
                        style: menuTheme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        menuL10n.spotDetailSaveMenuSignInBody,
                        style: menuTheme.textTheme.bodySmall?.copyWith(
                          color: menuTheme.colorScheme.onSurface.withValues(
                            alpha: 0.85,
                          ),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.login,
                            size: 20,
                            color: menuTheme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            menuL10n.spotDetailSaveMenuLogInOrCreate,
                            style: menuTheme.textTheme.labelLarge?.copyWith(
                              color: menuTheme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ];
            },
            child: SpotDetailQuickActionChip(
              icon: Icons.bookmark_border,
              iconColor: colorScheme.onSurface.withValues(alpha: 0.75),
              label: l10n.spotDetailQuickActionSave,
              showLabel: showChipLabel,
            ),
          );
          return Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Align(alignment: Alignment.centerLeft, child: guestMenu),
          );
        }

        final wantToVisit = authService.userProfile?.wantToVisit ?? [];
        final visited = authService.userProfile?.visited ?? [];
        final inWantToVisit = wantToVisit.contains(spotId);
        final inVisited = visited.contains(spotId);
        final canUseCustomLists = authService.isAuthenticated;

        return Consumer<SpotTrackingService>(
          builder: (context, trackingService, _) {
            final isUpdating = trackingService.isLoading;

            IconData icon;
            Color? iconColor;
            String tooltip;
            if (isUpdating) {
              icon = Icons.bookmark_border;
              iconColor = colorScheme.onSurface.withValues(alpha: 0.38);
              tooltip = l10n.spotDetailSaveTooltipUpdating;
            } else if (inWantToVisit) {
              icon = Icons.bookmark;
              iconColor = colorScheme.primary;
              tooltip = l10n.spotDetailSaveTooltipWantToVisit;
            } else if (inVisited) {
              icon = Icons.check_circle;
              iconColor = colorScheme.primary;
              tooltip = l10n.spotDetailSaveTooltipBeenHere;
            } else {
              icon = Icons.bookmark_border;
              iconColor = colorScheme.onSurface.withValues(alpha: 0.6);
              tooltip = l10n.spotDetailSaveTooltipGeneric;
            }

            final saveLabel = isUpdating
                ? l10n.spotDetailSaveTooltipUpdating
                : inWantToVisit
                ? l10n.spotDetailWantToVisit
                : inVisited
                ? l10n.spotDetailBeenHere
                : l10n.spotDetailQuickActionSave;

            Future<void> handleAction(_SpotSaveMenuAction action) async {
              bool success = false;
              String message = '';

              switch (action) {
                case _SpotSaveMenuAction.login:
                  return;
                case _SpotSaveMenuAction.toggleWantToVisit:
                  if (inWantToVisit) {
                    success = await trackingService.removeFromWantToVisit(
                      spotId,
                    );
                    message = success
                        ? l10n.spotDetailRemovedFromWantToVisit
                        : l10n.spotDetailFailedToRemove;
                  } else {
                    success = await trackingService.addToWantToVisit(spotId);
                    message = success
                        ? l10n.spotDetailAddedToWantToVisit
                        : l10n.spotDetailFailedToAdd;
                  }
                  break;
                case _SpotSaveMenuAction.toggleVisited:
                  if (inVisited) {
                    success = await trackingService.removeFromVisited(spotId);
                    message = success
                        ? l10n.spotDetailRemovedFromBeenHere
                        : l10n.spotDetailFailedToRemove;
                  } else {
                    success = await trackingService.addToVisited(spotId);
                    message = success
                        ? l10n.spotDetailAddedToBeenHere
                        : l10n.spotDetailFailedToAdd;
                  }
                  break;
                case _SpotSaveMenuAction.openWantToVisitList:
                  if (context.mounted) {
                    context.push('/profile/want-to-visit');
                  }
                  return;
                case _SpotSaveMenuAction.openVisitedList:
                  if (context.mounted) {
                    context.push('/profile/visited');
                  }
                  return;
                case _SpotSaveMenuAction.addToCustomList:
                  onAddToCustomList();
                  return;
              }

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: success ? null : colorScheme.error,
                  ),
                );
              }
            }

            final saveMenu = PopupMenuButton<_SpotSaveMenuAction>(
              enabled: !isUpdating,
              tooltip: tooltip,
              position: PopupMenuPosition.under,
              borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
              splashRadius: 20,
              onSelected: (action) => handleAction(action),
              itemBuilder: (menuContext) {
                final menuTheme = Theme.of(menuContext);
                final menuL10n = AppLocalizations.of(menuContext)!;
                final primary = menuTheme.colorScheme.primary;
                return <PopupMenuEntry<_SpotSaveMenuAction>>[
                  PopupMenuItem<_SpotSaveMenuAction>(
                    value: _SpotSaveMenuAction.toggleWantToVisit,
                    child: Row(
                      children: [
                        Icon(
                          inWantToVisit
                              ? Icons.bookmark
                              : Icons.bookmark_outlined,
                          size: 20,
                          color: inWantToVisit
                              ? primary
                              : menuTheme.colorScheme.onSurface.withValues(
                                  alpha: 0.75,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            menuL10n.spotDetailWantToVisit,
                            style: menuTheme.textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: menuL10n.spotDetailViewFullListTooltip,
                          icon: Icon(
                            Icons.list_alt_outlined,
                            size: 20,
                            color: primary,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          onPressed: () {
                            Navigator.pop(
                              menuContext,
                              _SpotSaveMenuAction.openWantToVisitList,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<_SpotSaveMenuAction>(
                    value: _SpotSaveMenuAction.toggleVisited,
                    child: Row(
                      children: [
                        Icon(
                          inVisited
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          size: 20,
                          color: inVisited
                              ? primary
                              : menuTheme.colorScheme.onSurface.withValues(
                                  alpha: 0.75,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            menuL10n.spotDetailBeenHere,
                            style: menuTheme.textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: menuL10n.spotDetailViewFullListTooltip,
                          icon: Icon(
                            Icons.list_alt_outlined,
                            size: 20,
                            color: primary,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          onPressed: () {
                            Navigator.pop(
                              menuContext,
                              _SpotSaveMenuAction.openVisitedList,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  if (canUseCustomLists) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem<_SpotSaveMenuAction>(
                      value: _SpotSaveMenuAction.addToCustomList,
                      child: Row(
                        children: [
                          Icon(Icons.playlist_add, size: 20, color: primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              menuL10n.spotDetailAddToCustomList,
                              style: menuTheme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ];
              },
              child: SpotDetailQuickActionChip(
                icon: icon,
                iconColor: iconColor,
                label: saveLabel,
                showSpinner: isUpdating,
                showLabel: showChipLabel,
              ),
            );
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Align(alignment: Alignment.centerLeft, child: saveMenu),
            );
          },
        );
      },
    );
  }
}

class _FullScreenPhotoViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullScreenPhotoViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;
  static const int _virtualPageMultiplier = 1000;
  late int _virtualInitialPage;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Start at a middle position in the virtual pages to allow scrolling in both directions.
    // The virtual page must satisfy: virtualPage % length == initialIndex, otherwise we'd show
    // the wrong image (e.g. page 1000 with 7 images shows 1000%7=6, not 0).
    final length = widget.imageUrls.length;
    final basePage = (length > 0)
        ? (_virtualPageMultiplier ~/ length) * length
        : _virtualPageMultiplier;
    _virtualInitialPage = basePage + widget.initialIndex;
    _pageController = PageController(initialPage: _virtualInitialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int virtualIndex) {
    // Map virtual page index to actual image index using modulo
    final actualIndex = virtualIndex % widget.imageUrls.length;

    setState(() {
      _currentIndex = actualIndex;
    });

    // If we're getting close to the boundaries, jump to the middle to allow continuous scrolling
    // This prevents running out of pages in either direction
    final lowerBound = _virtualPageMultiplier ~/ 2;
    final upperBound = _virtualPageMultiplier * 2 - 100;
    if (virtualIndex < lowerBound || virtualIndex > upperBound) {
      // Jump to a safe middle position without animation.
      // Must use basePage + actualIndex so the modulo maps correctly.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _pageController.hasClients &&
            widget.imageUrls.isNotEmpty) {
          final length = widget.imageUrls.length;
          final basePage = (_virtualPageMultiplier ~/ length) * length;
          final newVirtualPage = basePage + actualIndex;
          _pageController.jumpToPage(newVirtualPage);
        }
      });
    }
  }

  int _getActualIndex(int virtualIndex) {
    return virtualIndex % widget.imageUrls.length;
  }

  void _goToPrevious() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToNext() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _goToPrevious();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _goToNext();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          Navigator.of(context).pop(_currentIndex);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(_currentIndex),
          ),
          title: Text(
            AppLocalizations.of(context)!.spotDetailGalleryPageIndicator(
              _currentIndex + 1,
              widget.imageUrls.length,
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        body: Stack(
          children: [
            PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int virtualIndex) {
                // Map virtual index to actual image index
                final actualIndex = _getActualIndex(virtualIndex);
                return PhotoViewGalleryPageOptions(
                  imageProvider: ResizedSpotImageProvider.fromUrl(
                    widget.imageUrls[actualIndex],
                  ),
                  initialScale: PhotoViewComputedScale.contained,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  heroAttributes: PhotoViewHeroAttributes(
                    tag: widget.imageUrls[actualIndex],
                  ),
                );
              },
              // Use a large item count to enable infinite scrolling
              itemCount: _virtualPageMultiplier * 2,
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(
                  value: event == null
                      ? 0
                      : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                ),
              ),
              pageController: _pageController,
              onPageChanged: _onPageChanged,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
            ),
            // Left navigation arrow
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black26,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 40,
                      color: Colors.white,
                    ),
                    onPressed: _goToPrevious,
                  ),
                ),
              ),
            ),
            // Right navigation arrow
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: Material(
                  color: Colors.black26,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      size: 40,
                      color: Colors.white,
                    ),
                    onPressed: _goToNext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotRatingUserRatingLoader extends StatefulWidget {
  const _SpotRatingUserRatingLoader({
    required this.loadUserRating,
    required this.builder,
  });

  final Future<double?> Function() loadUserRating;
  final Widget Function(BuildContext context) builder;

  @override
  State<_SpotRatingUserRatingLoader> createState() =>
      _SpotRatingUserRatingLoaderState();
}

class _SpotRatingUserRatingLoaderState
    extends State<_SpotRatingUserRatingLoader> {
  late final Future<double?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loadUserRating();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return widget.builder(context);
      },
    );
  }
}
