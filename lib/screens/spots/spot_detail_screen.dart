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
import '../../utils/check_in_time.dart';
import '../../services/spot_service.dart';
import '../../services/spot_report_service.dart';
import '../../services/auth_service.dart';
import '../../services/url_service.dart';
import '../../services/web_share_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/search_state_service.dart';
import '../../widgets/source_details_dialog.dart';
import '../../widgets/spot_selection_dialog.dart';
import '../../widgets/moderator_action_fields.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/location_info_box.dart';
import '../../constants/spot_attributes.dart';
import '../../services/geocoding_service.dart';
import '../../widgets/spot_form/attributes_section.dart';
import 'location_picker_screen.dart';
import '../../services/snackbar_service.dart';
import '../../services/spot_list_service.dart';
import '../../services/spot_tracking_service.dart';
import '../../services/spot_check_in_service.dart';
import '../../services/feature_access_service.dart';
import '../../models/spot_list.dart';
import '../../utils/resized_spot_image_provider.dart';
import '../../widgets/resized_spot_image.dart';
import '../../widgets/spot_check_in_presence.dart';
import '../../utils/image_preparation.dart';
import '../../services/user_profile_service.dart';
import '../../services/jumpflix_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/audit_log_service.dart';
import 'package:web/web.dart' as web;
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
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
  edit,
  delete,
  markAsDuplicate,
  createNativeSpot,
  toggleHide,
  removeDuplicateStatus,
  triggerResize,
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
  double _userRating = 0;
  double _previousRating = 0; // Track the user's previous rating
  bool _hasRated = false;
  int _currentImageIndex = 0;
  int _currentVideoIndex = 0;
  late final ScrollController _scrollController;
  late final PageController _videoPageController;
  late final ValueNotifier<bool> _isSatelliteViewNotifier;
  SearchStateService? _searchStateServiceRef;

  // Add rating cache variables
  Map<String, dynamic>? _cachedRatingStats;
  bool _isLoadingRatingStats = false;

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

  /// Cached future for Jumpflix videos (avoids refetch on rebuild).
  Future<List<JumpflixVideo>>? _jumpflixVideosFuture;

  // Getter for the current spot (falls back to widget.spot if not updated)
  Spot get _spot => _currentSpot ?? widget.spot;

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
    final service = Provider.of<SpotCheckInService>(context, listen: false);
    final result = await showDialog<_CheckInDialogResult>(
      context: context,
      builder: (context) => const _SpotCheckInDialog(),
    );
    if (result == null || !mounted) return;
    final ok = await service.checkIn(
      spotId,
      isPrivate: result.isPrivate,
      expectedEndAt: result.expectedEndAt,
      comment: result.comment,
      spotName: _spot.name,
    );
    if (!mounted) return;
    if (ok) {
      _showSuccessSnack('You’re checked in');
    } else {
      _showErrorSnack(service.error ?? 'Check-in failed');
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
    _loadRatingStats(); // Load rating stats once on init
    // Note: User rating will be loaded when auth state is restored via FutureBuilder

    // Update document title for web
    _updateDocumentTitle();

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
    } else {
      _jumpflixVideosFuture = Future<List<JumpflixVideo>>.value([]);
    }

    // Initialize satellite view from SearchStateService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchStateServiceRef = Provider.of<SearchStateService>(
        context,
        listen: false,
      );
      _searchStateServiceRef!.addListener(_onSearchStateChanged);
      _isSatelliteViewNotifier.value = _searchStateServiceRef!.isSatellite;
    });
  }

  @override
  void didUpdateWidget(SpotDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spot.id != widget.spot.id) {
      if (widget.spot.id != null) {
        _jumpflixVideosFuture = Provider.of<JumpflixService>(
          context,
          listen: false,
        ).getJumpflixVideosForSpot(widget.spot.id!);
      } else {
        _jumpflixVideosFuture = Future<List<JumpflixVideo>>.value([]);
      }
    }
  }

  void _updateDocumentTitle() {
    if (kIsWeb) {
      web.document.title = '${_spot.name} - Parkour·Spot';
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
      web.document.title = 'Parkour·Spot';
    }
    _scrollController.dispose();
    _videoPageController.dispose();
    _isSatelliteViewNotifier.dispose();
    _searchStateServiceRef?.removeListener(_onSearchStateChanged);
    // No controllers to dispose
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
    final List<TextSpan> textSpans = [];
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    bool hasPreviousContent = false;

    // Check if there will be an updated date part (to determine if we should use commas)
    final bool willHaveUpdatedDate =
        (_spot.updatedAt != null &&
            _spot.createdAt != null &&
            _spot.updatedAt != _spot.createdAt) ||
        (_spot.updatedAt != null && _spot.createdAt == null);

    // Created by
    if (_spot.createdBy != null || _spot.createdByName != null) {
      final createdBy = _spot.createdByName ?? _spot.createdBy ?? '';
      final createdById = _spot.createdBy;

      // Add created date if available
      if (_spot.createdAt != null) {
        final createdDateText = _formatRelativeDate(_spot.createdAt!);
        textSpans.add(
          TextSpan(text: 'Spot created $createdDateText by ', style: textStyle),
        );
      } else {
        textSpans.add(TextSpan(text: 'Spot created by ', style: textStyle));
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
    }

    // Source and folder
    if (_spot.spotSource != null) {
      if (hasPreviousContent) {
        textSpans.add(TextSpan(text: ' / ', style: textStyle));
      }

      final sourceName = _spot.spotSourceName ?? 'Unknown Source';

      // Add created date if available and no createdBy (imported spots)
      if (!hasPreviousContent && _spot.createdAt != null) {
        final createdDateText = _formatRelativeDate(_spot.createdAt!);
        textSpans.add(
          TextSpan(
            text: 'Spot imported $createdDateText from ',
            style: textStyle,
          ),
        );
      } else {
        textSpans.add(TextSpan(text: 'Spot imported from ', style: textStyle));
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
        textSpans.add(TextSpan(text: ' from the folder ', style: textStyle));
        textSpans.add(
          TextSpan(
            text: _spot.folderName!,
            style: textStyle?.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      }

      hasPreviousContent = true;
    }

    // Contributors (filter out the createdBy user)
    bool hasContributors = false;
    if (_spot.contributors != null && _spot.contributors!.isNotEmpty) {
      final createdByName = _spot.createdByName;
      final createdBy = _spot.createdBy;

      // Filter out contributors that match the createdBy user
      final filteredContributors = _spot.contributors!.where((c) {
        final userName = c['userName'];
        final userId = c['userId'];
        // Exclude if userName matches createdByName or userId matches createdBy
        return userName != createdByName && userId != createdBy;
      }).toList();

      if (filteredContributors.isNotEmpty) {
        // Use comma if there will be an updated date part, otherwise use "and"
        final String connector = willHaveUpdatedDate ? ',' : ' and';

        textSpans.add(
          TextSpan(text: '$connector improved by ', style: textStyle),
        );

        // Add each contributor name as a clickable link
        for (int i = 0; i < filteredContributors.length; i++) {
          final contributor = filteredContributors[i];
          final userName = contributor['userName'] ?? 'Unknown';
          final userId = contributor['userId'];

          if (i > 0) {
            if (i == filteredContributors.length - 1) {
              textSpans.add(TextSpan(text: ' and ', style: textStyle));
            } else {
              textSpans.add(TextSpan(text: ', ', style: textStyle));
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

    // Last updated date (only if different from created date)
    bool hasUpdatedDate = false;
    if (_spot.updatedAt != null &&
        _spot.createdAt != null &&
        _spot.updatedAt != _spot.createdAt) {
      final updatedDateText = _formatRelativeDate(_spot.updatedAt!);
      // Use ", and" if there are previous parts, otherwise just " and"
      final String connector = (hasPreviousContent || hasContributors)
          ? ', and'
          : ' and';
      textSpans.add(
        TextSpan(
          text: '$connector last updated $updatedDateText.',
          style: textStyle,
        ),
      );
      hasUpdatedDate = true;
    } else if (_spot.updatedAt != null && _spot.createdAt == null) {
      // If no created date but there's an updated date
      final updatedDateText = _formatRelativeDate(_spot.updatedAt!);
      // Use ", and" if there are previous parts, otherwise just " and"
      final String connector = (hasPreviousContent || hasContributors)
          ? ', and'
          : ' and';
      textSpans.add(
        TextSpan(
          text: '$connector last updated $updatedDateText.',
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

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final difference = today.difference(dateOnly).inDays;

    if (difference == 0) {
      return 'today';
    } else if (difference == 1) {
      return 'yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else if (difference < 365) {
      final months = (difference / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    } else {
      final years = (difference / 365).floor();
      return years == 1 ? '1 year ago' : '$years years ago';
    }
  }

  void _copySpotToClipboard() async {
    try {
      final url = UrlService.generateSpotUrl(
        widget.spot.id!,
        countryCode: widget.spot.countryCode,
        city: widget.spot.city,
      );
      final label = widget.spot.name.trim();
      final text = '$label 👉 $url';

      final outcome = await WebShareService.tryShareLink(text: label, url: url);
      if (outcome == WebShareOutcome.shared ||
          outcome == WebShareOutcome.cancelled) {
        return;
      }

      await Clipboard.setData(ClipboardData(text: text));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spot copied to clipboard!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy spot: $e'),
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
          const SnackBar(
            content: Text('Address copied to clipboard!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy address: $e'),
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
            content: Text('Could not open maps app: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  PopupMenuButton<_SpotMenuAction> _buildSpotActionsPopupMenu({
    required AuthService authService,
    required Widget child,
    String? tooltip,
  }) {
    return PopupMenuButton<_SpotMenuAction>(
      position: PopupMenuPosition.under,
      tooltip: tooltip ?? 'More actions',
      onSelected: _onMenuActionSelected,
      itemBuilder: (menuContext) {
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
                        'Login',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Sign in first to link edits to your account',
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
                      'Flag as duplicate',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _spot.duplicateOf == null
                            ? null
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              ),
                      ),
                    ),
                    Text(
                      _spot.duplicateOf == null
                          ? 'This spot is a duplicate'
                          : 'Already marked as duplicate',
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
                      'Suggest photo',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _spot.duplicateOf == null
                            ? null
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              ),
                      ),
                    ),
                    Text(
                      _spot.duplicateOf == null
                          ? 'Submit photos for this spot'
                          : 'Cannot suggest photos for duplicates',
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
                      'Suggest an edit',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _spot.duplicateOf == null
                            ? null
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.38,
                              ),
                      ),
                    ),
                    Text(
                      _spot.duplicateOf == null
                          ? 'Propose changes to this spot'
                          : 'Cannot suggest edits for duplicates',
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
                      'Report spot',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Help us review this spot',
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
                          'Edit spot',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: shouldDisableEdit
                                ? theme.colorScheme.onSurface.withValues(
                                    alpha: 0.38,
                                  )
                                : null,
                          ),
                        ),
                        Text(
                          shouldDisableEdit
                              ? 'Create native spot first'
                              : 'Moderator only',
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
                        'Mark as duplicate',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isAlreadyDuplicate
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.38,
                                )
                              : null,
                        ),
                      ),
                      Text(
                        isAlreadyDuplicate
                            ? 'Already marked as duplicate'
                            : 'Moderator only',
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
                          'Remove duplicate status',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Moderator only',
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
                          'Create native spot',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Moderator only',
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
                        _spot.hidden ? 'Unhide spot' : 'Hide spot',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Moderator only',
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
                          'Delete spot',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          'Admin only',
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
                          'Trigger image resize',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Re-create resized versions',
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
      child: child,
    );
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
      case _SpotMenuAction.edit:
        final authService = Provider.of<AuthService>(context, listen: false);
        final isSpotFromSource = widget.spot.spotSource != null;
        final isModeratorOnly = authService.isModerator && !authService.isAdmin;

        // Prevent moderators from editing spot-source spots
        if (isSpotFromSource && isModeratorOnly) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Spots from external sources cannot be edited. '
                  'Please create a native spot first using "Mark as Duplicate" → "Create Native Spot".',
                ),
                duration: const Duration(seconds: 5),
                action: SnackBarAction(label: 'OK', onPressed: () {}),
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
            const SnackBar(
              content: Text('Unable to edit this spot right now.'),
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
            const SnackBar(
              content: Text('Only administrators can delete spots.'),
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
      case _SpotMenuAction.triggerResize:
        _triggerResizeForSpot();
        break;
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

      if (total == 0) {
        _showSuccessSnack('All images already have resized versions');
      } else {
        _showSuccessSnack(
          'Resize: $triggered triggered, $verified verified'
          '${failed > 0 ? ", $failed failed" : ""}',
        );
      }
    } catch (e) {
      if (mounted) _showErrorSnack('Failed to trigger resize: $e');
    }
  }

  Future<void> _showReportDuplicateDialog() async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to flag this spot as duplicate right now.'),
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
        const SnackBar(
          content: Text('Thanks! Your duplicate report has been submitted.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showSuggestPhotoDialog() async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to suggest photos for this spot right now.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.spot.duplicateOf != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot suggest photos for duplicate spots.'),
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
        const SnackBar(
          content: Text(
            'Thanks! Your photo suggestion has been submitted for review.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showSuggestEditDialog() async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to suggest edits for this spot right now.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.spot.duplicateOf != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot suggest edits for duplicate spots.'),
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
        const SnackBar(
          content: Text(
            'Thanks! Your edit suggestion has been submitted for review.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showReportSpotDialog() async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to report this spot right now.'),
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
        const SnackBar(
          content: Text('Thanks! Your report has been submitted.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showAddToListDialog() async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to add this spot to a list right now.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final spotListService = Provider.of<SpotListService>(
      context,
      listen: false,
    );
    final authService = Provider.of<AuthService>(context, listen: false);
    final featureAccessService = FeatureAccessService(authService);

    if (!featureAccessService.hasFeatureAccess('spotLists')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have access to spot lists.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _AddToListDialog(
        spotId: spotId,
        lists: availableLists,
        listsWithSpot: listsWithSpot,
        spotListService: spotListService,
      ),
    );

    if (!mounted) return;
    if (result != null) {
      if (result['created'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('List created and spot added!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (result['added'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Spot added to list!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (result['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] as String),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              leading: IconButton(
                onPressed: () {
                  // Check if we can pop back to a previous page
                  if (Navigator.canPop(context)) {
                    // If there's a previous page, go back to it
                    Navigator.pop(context);
                  } else {
                    // If no previous page (direct link), go to explore
                    context.go('/explore');
                  }
                },
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  shape: const CircleBorder(),
                  fixedSize: const Size(40, 40),
                  padding: EdgeInsets.zero,
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _buildImageCarousel(),
              ),
            ),

            // Content using SliverList
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Rating
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                _spot.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            // Rating display using cached data
                            _isLoadingRatingStats
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : _cachedRatingStats != null &&
                                      _cachedRatingStats!['ratingCount'] > 0
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _cachedRatingStats!['averageRating']
                                            .toStringAsFixed(1),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '(${_cachedRatingStats!['ratingCount']})',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Save: want to visit / been here + optional custom list (guests see login CTA)
                        if (_spot.id != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _SpotSaveMenu(
                                      spotId: _spot.id!,
                                      onAddToCustomList: _showAddToListDialog,
                                    ),
                                    const SizedBox(width: 8),
                                    Consumer<AuthService>(
                                      builder: (context, authService, _) {
                                        if (authService.isLoading) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: SizedBox(
                                              width: 44,
                                              height: 44,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: _buildSpotActionsPopupMenu(
                                            authService: authService,
                                            tooltip: 'Edit & report',
                                            child: SizedBox(
                                              width: 44,
                                              height: 44,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.edit_outlined,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.6),
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: Tooltip(
                                        message: 'Share',
                                        child: Material(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.6),
                                          shape: const CircleBorder(),
                                          clipBehavior: Clip.antiAlias,
                                          child: InkWell(
                                            onTap: _copySpotToClipboard,
                                            customBorder: const CircleBorder(),
                                            child: SizedBox(
                                              width: 44,
                                              height: 44,
                                              child: Icon(
                                                Icons.share,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.6),
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Consumer<AuthService>(
                                      builder: (context, authService, _) {
                                        final colorScheme = Theme.of(
                                          context,
                                        ).colorScheme;
                                        final loginRedirect =
                                            '/login?redirectTo=${Uri.encodeComponent('/spot/${_spot.id!}')}';
                                        if (authService.isLoading) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: SizedBox(
                                              width: 44,
                                              height: 44,
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.6),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: colorScheme.primary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: Tooltip(
                                            message: authService.isAuthenticated
                                                ? 'Check in'
                                                : 'Sign in to check in',
                                            child: Material(
                                              color: colorScheme
                                                  .surfaceContainerHighest
                                                  .withValues(alpha: 0.6),
                                              shape: const CircleBorder(),
                                              clipBehavior: Clip.antiAlias,
                                              child: InkWell(
                                                onTap: authService.isAuthenticated
                                                    ? _showCheckInDialog
                                                    : () =>
                                                        context.go(loginRedirect),
                                                customBorder: const CircleBorder(),
                                                child: SizedBox(
                                                  width: 44,
                                                  height: 44,
                                                  child: Icon(
                                                    Icons.place_outlined,
                                                    color: colorScheme.onSurface
                                                        .withValues(alpha: 0.6),
                                                    size: 24,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SpotCheckInPresenceStrip(
                                spotId: _spot.id!,
                                variant: SpotCheckInPresenceVariant.detail,
                                detailLeadingLabel: 'Here now',
                              ),
                            ],
                          ),

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
                                    'This spot is hidden from public view. It likely no longer exists or doesn\'t meet our policies. It will not appear in search results or on the map.',
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
                                    'This spot is no longer listed in ${widget.spot.spotSourceName ?? 'its original source'}. Details might be outdated, so double-check before visiting.',
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
                              ? 'No description provided'
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
                                    title: 'Good For',
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
                                    title: 'Features',
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
                                        'Access',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
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
                                    title: 'Facilities',
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
                                      title: 'Good For',
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
                                      title: 'Features',
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
                                      'Access',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
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
                                        title: 'Facilities',
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
                        if (_spot.createdBy != null ||
                            _spot.createdByName != null ||
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
                                  if (jumpflixSnapshot.hasError) {
                                    debugPrint(
                                      'Jumpflix fetch failed: ${jumpflixSnapshot.error}',
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
                                          brandLabel: 'YouTube',
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
                                          : 'Jumpflix',
                                      brandSubtitle: 'As seen in',
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
                                                      fontWeight:
                                                          FontWeight.w500,
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
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
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

                        // Rating Section
                        Consumer<AuthService>(
                          builder: (context, authService, child) {
                            // Wait for auth state to be restored before showing rating section
                            if (authService.isLoading) {
                              // Show subtle loading indicator while auth state is being restored
                              return SizedBox(
                                height: 80,
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Loading...',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            if (authService.isAuthenticated &&
                                authService.userProfile != null) {
                              // Load user rating when auth state is confirmed
                              if (_userRating == 0 && !_hasRated) {
                                // Use FutureBuilder to load user rating asynchronously
                                return FutureBuilder<double?>(
                                  future: _loadUserRatingFuture(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return SizedBox(
                                        height: 80,
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Loading your rating...',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }

                                    // Rating widget
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Rate this spot',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            ...List.generate(5, (index) {
                                              return GestureDetector(
                                                onTap: () =>
                                                    _submitRatingDirectly(
                                                      index + 1.0,
                                                    ),
                                                child: Icon(
                                                  index < _userRating
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: Colors.amber,
                                                  size: 32,
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                      ],
                                    );
                                  },
                                );
                              }

                              // Show rating widget if user rating is already loaded
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Rate this spot',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      ...List.generate(5, (index) {
                                        return GestureDetector(
                                          onTap: () => _submitRatingDirectly(
                                            index + 1.0,
                                          ),
                                          child: Icon(
                                            index < _userRating
                                                ? Icons.star
                                                : Icons.star_border,
                                            color: Colors.amber,
                                            size: 32,
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              );
                            } else if (authService.isAuthenticated) {
                              // Authenticated but profile not loaded (load failed)
                              return SizedBox(
                                height: 80,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Couldn't load your profile.",
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Please refresh the page to rate.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              // Show login prompt for unauthenticated users
                              // Get current location for redirect, or construct spot URL
                              String redirectUrl;
                              try {
                                final routerState = GoRouterState.of(context);
                                redirectUrl = routerState.uri.toString();
                              } catch (e) {
                                // Fallback: construct URL from spot data
                                if (widget.spot.id != null &&
                                    widget.spot.countryCode != null &&
                                    widget.spot.city != null) {
                                  redirectUrl =
                                      '/${widget.spot.countryCode!.toLowerCase()}/${Uri.encodeComponent(widget.spot.city!.toLowerCase().replaceAll(' ', '-'))}/${widget.spot.id}';
                                } else {
                                  redirectUrl = '/explore';
                                }
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.star_outline,
                                            size: 48,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withValues(alpha: 0.6),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'Sign in to rate this spot',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Sign in to rate this spot and help other parkour enthusiasts.',
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.7),
                                                ),
                                          ),
                                          const SizedBox(height: 16),
                                          Center(
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 400,
                                              ),
                                              child: CustomButton(
                                                onPressed: () {
                                                  context.go(
                                                    '/login?redirectTo=${Uri.encodeComponent(redirectUrl)}',
                                                  );
                                                },
                                                text: 'Sign In',
                                                width: double.infinity,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          // OR divider
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Divider(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                    ),
                                                child: Text(
                                                  'OR',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                      ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Divider(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .outline
                                                      .withValues(alpha: 0.3),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          Center(
                                            child: ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 400,
                                              ),
                                              child: CustomButton(
                                                onPressed: () {
                                                  context.go(
                                                    '/login?mode=signup&redirectTo=${Uri.encodeComponent(redirectUrl)}',
                                                  );
                                                },
                                                text: 'Create an Account',
                                                width: double.infinity,
                                                isOutlined: true,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              );
                            }
                          },
                        ),

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
                                            ? 'Switch to Map'
                                            : 'Switch to Satellite',
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
                                          'Locate on map',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
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
                            _duplicateSpots.isNotEmpty ||
                            _isLoadingDuplicates) ...[
                          if (widget.spot.duplicateOf != null ||
                              _originalSpot != null) ...[
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
                                title: const Text('Duplicate of'),
                                subtitle: _isLoadingOriginalSpot
                                    ? const Text('Loading...')
                                    : Text(
                                        _originalSpot?.name ?? 'Original spot',
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
                                title: const Text('Also based on'),
                                subtitle: const Text('Loading...'),
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
                                  'Also based on (${_duplicateSpots.length})',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No images available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 400,
      width: double.infinity,
      child: Stack(
        children: [
          // Debug info
          if (kDebugMode)
            Positioned(
              top: 8,
              left: 8,
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
                            'Image failed to load',
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
              left: 16,
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
              right: 16,
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

  /// Submits a rating directly when a star is clicked (only if different from previous rating)
  Future<void> _submitRatingDirectly(double rating) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.userProfile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to rate spots'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if this is the same rating as before - if so, don't submit
      if (rating == _previousRating && _hasRated) {
        // Just update the UI to show the selected star without submitting
        setState(() {
          _userRating = rating;
        });
        return;
      }

      // Store the current rating stats before submitting
      final currentRatingCount = _cachedRatingStats?['ratingCount'] ?? 0;
      final currentAverageRating = _cachedRatingStats?['averageRating'] ?? 0.0;

      // Update UI immediately for better UX
      setState(() {
        _userRating = rating;
        _hasRated = true;
        _previousRating = rating;
      });

      final spotService = Provider.of<SpotService>(context, listen: false);
      final success = await spotService.rateSpot(
        widget.spot.id!,
        rating,
        authService.userProfile!.id,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rating ${rating.toInt()} star${rating == 1 ? '' : 's'} submitted!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Refresh the spot data to show updated rating
        // Retry a few times to allow Cloud Functions to update the spot aggregates
        await _refreshSpotDataWithRetry(
          currentRatingCount,
          currentAverageRating,
        );
      } else if (mounted) {
        // Revert UI changes if submission failed
        setState(() {
          _userRating = _previousRating;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit rating. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Revert UI changes if submission failed
        setState(() {
          _userRating = _previousRating;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadRatingStats() async {
    try {
      setState(() {
        _isLoadingRatingStats = true;
      });
      final spotService = Provider.of<SpotService>(context, listen: false);
      final ratingStats = await spotService.getSpotRatingStats(widget.spot.id!);
      if (mounted) {
        setState(() {
          _cachedRatingStats = ratingStats;
          _isLoadingRatingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading rating stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingRatingStats = false;
        });
      }
    }
  }

  Future<void> _refreshSpotData() async {
    try {
      // Refresh the rating stats when a user submits a rating
      if (mounted) {
        setState(() {
          _isLoadingRatingStats = true;
        });
        await _loadRatingStats();
      }
    } catch (e) {
      debugPrint('Error refreshing spot data: $e');
    }
  }

  Future<void> _refreshSpotDataWithRetry(
    int currentRatingCount,
    double currentAverageRating,
  ) async {
    const maxRetries = 5;
    const retryDelay = Duration(milliseconds: 1000);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      await _refreshSpotData();

      // Check if the rating aggregates have changed (indicating the Cloud Function has updated the spot)
      final newRatingCount = _cachedRatingStats?['ratingCount'] ?? 0;
      final newAverageRating = _cachedRatingStats?['averageRating'] ?? 0.0;

      // Consider it updated if either count or average has changed
      final countChanged = newRatingCount != currentRatingCount;
      final averageChanged =
          (newAverageRating - currentAverageRating).abs() >
          0.01; // Allow for small floating point differences

      if (countChanged || averageChanged) {
        debugPrint(
          'Rating aggregates updated successfully. Count: $currentRatingCount -> $newRatingCount, Average: ${currentAverageRating.toStringAsFixed(2)} -> ${newAverageRating.toStringAsFixed(2)}',
        );
        break; // Success - rating aggregates have been updated
      }

      debugPrint(
        'Attempt ${attempt + 1}: Rating aggregates unchanged (Count: $newRatingCount, Average: ${newAverageRating.toStringAsFixed(2)})',
      );

      // If not the last attempt, wait before retrying
      if (attempt < maxRetries - 1) {
        await Future.delayed(retryDelay);
      }
    }

    // Always do a final refresh to ensure UI has the latest stats and rebuilds properly
    // This is important even if we didn't detect a change, as it ensures
    // the UI rebuilds with the current state (especially when going from 0 to 1 rating)
    if (mounted) {
      await _refreshSpotData();
    }
  }

  Future<Map<String, dynamic>?>
  _showCreateNativeSpotConfirmationDialog() async {
    if (widget.spot.spotSource == null) {
      if (!mounted) return null;
      _showErrorSnack('This spot is not from an external source.');
      return null;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.currentUser == null) {
      if (!mounted) return null;
      _showErrorSnack('You must be logged in to create a native spot.');
      return null;
    }

    String? selectedReportId;
    final notesController = TextEditingController();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create Native Spot'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will create a new native spot based on this spot and mark the current spot as a duplicate of it. '
                    'All spot data (name, description, location, photos, YouTube links, and attributes) will be copied to the new native spot.\n\n'
                    'Note: Admins can remove spots and duplicate links can be removed if needed.',
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
                child: const Text('Cancel'),
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
                child: const Text('Create'),
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
      _showErrorSnack('Unable to create native spot right now.');
      return;
    }

    final spotService = Provider.of<SpotService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if user is authenticated
    if (!authService.isAuthenticated || authService.currentUser == null) {
      if (!mounted) return;
      _showErrorSnack('You must be logged in to create a native spot.');
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
        final error = spotService.error ?? 'Failed to create native spot';
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

        _showSuccessSnack(
          'Native spot created and current spot marked as duplicate.',
        );
      } else {
        final error = spotService.error ?? 'Failed to mark spot as duplicate';
        _showErrorSnack(error);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack('Error creating native spot: $e');
    }
  }

  Future<void> _showMarkAsDuplicateDialog() async {
    if (widget.spot.id == null) {
      if (!mounted) return;
      _showErrorSnack('Unable to mark this spot as duplicate right now.');
      return;
    }

    // Check if spot is already marked as duplicate
    if (widget.spot.duplicateOf != null) {
      if (!mounted) return;
      _showErrorSnack('This spot is already marked as a duplicate.');
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

        _showSuccessSnack('Spot marked as duplicate.');
      } else {
        final error = spotService.error ?? 'Failed to mark spot as duplicate';
        _showErrorSnack(error);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack('Error marking spot as duplicate: $e');
    }
  }

  Future<Map<String, dynamic>?> _showHideSpotConfirmationDialog() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated ||
        (!authService.isModerator && !authService.isAdmin)) {
      if (!mounted) return null;
      _showErrorSnack('Only moderators can hide/unhide spots.');
      return null;
    }

    final isHiding = !_spot.hidden;
    final actionCapitalized = isHiding ? 'Hide' : 'Unhide';

    String? selectedReportId;
    final notesController = TextEditingController();

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('$actionCapitalized Spot'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHiding
                        ? 'This will hide the spot from public view. '
                              'Hidden spots will not appear in search results or on the map, '
                              'but the spot data will be preserved and can be unhidden later.'
                        : 'This will restore the spot to public view. '
                              'The spot will appear in search results and on the map again.',
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
                child: const Text('Cancel'),
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
                child: Text(actionCapitalized),
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
      _showErrorSnack('Unable to hide/unhide this spot right now.');
      return;
    }

    final spotService = Provider.of<SpotService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if user is authenticated and is a moderator
    if (!authService.isAuthenticated ||
        (!authService.isModerator && !authService.isAdmin)) {
      if (!mounted) return;
      _showErrorSnack('Only moderators can hide/unhide spots.');
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
              ? 'Spot hidden successfully.'
              : 'Spot unhidden successfully.',
        );
      } else {
        final error =
            spotService.error ??
            'Failed to ${newHiddenState ? 'hide' : 'unhide'} spot';
        _showErrorSnack(error);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack(
        'Error ${newHiddenState ? 'hiding' : 'unhiding'} spot: $e',
      );
    }
  }

  Future<Map<String, dynamic>?>
  _showRemoveDuplicateStatusConfirmationDialog() async {
    if (_spot.duplicateOf == null) {
      if (!mounted) return null;
      _showErrorSnack('This spot is not marked as a duplicate.');
      return null;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated ||
        (!authService.isModerator && !authService.isAdmin)) {
      if (!mounted) return null;
      _showErrorSnack('Only moderators can remove duplicate status.');
      return null;
    }

    final TextEditingController notesController = TextEditingController();
    String? selectedReportId;

    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Remove Duplicate Status'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This will remove the duplicate status from this spot. '
                      'The spot will no longer be marked as a duplicate.\n\n'
                      'Do you want to continue?',
                    ),
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
                  child: const Text('Cancel'),
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
                  child: const Text('Remove'),
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
      _showErrorSnack('Unable to remove duplicate status right now.');
      return;
    }

    final spotService = Provider.of<SpotService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if user is authenticated and is a moderator
    if (!authService.isAuthenticated ||
        (!authService.isModerator && !authService.isAdmin)) {
      if (!mounted) return;
      _showErrorSnack('Only moderators can remove duplicate status.');
      return;
    }

    // Check if spot is actually marked as duplicate
    if (_spot.duplicateOf == null) {
      if (!mounted) return;
      _showErrorSnack('This spot is not marked as a duplicate.');
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

        _showSuccessSnack('Duplicate status removed successfully.');
      } else {
        final error = spotService.error ?? 'Failed to remove duplicate status';
        _showErrorSnack(error);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack('Error removing duplicate status: $e');
    }
  }

  Future<void> _showDeleteDialog() async {
    if (_spot.id == null) return;

    // Show loading dialog while fetching counts
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Checking linked data...'),
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
          String? selectedReportId;
          final notesController = TextEditingController();

          return AlertDialog(
            title: const Text('Delete Spot'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Are you sure you want to delete this spot? This action cannot be undone.',
                  ),
                  const SizedBox(height: 16),
                  if (ratingsCount > 0 ||
                      spotReportsCount > 0 ||
                      duplicateSpotsCount > 0) ...[
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'This spot has linked data:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (ratingsCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• Ratings: $ratingsCount'),
                      ),
                    if (spotReportsCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• Spot Reports: $spotReportsCount'),
                      ),
                    if (duplicateSpotsCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• Duplicate Spots: $duplicateSpotsCount'),
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please resolve these links before deleting the spot.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
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
                child: const Text('Cancel'),
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
                              const SnackBar(
                                content: Text('Spot deleted successfully'),
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
                              const SnackBar(
                                content: Text('Failed to delete spot'),
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
                              content: Text('Error deleting spot: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    : null,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
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
        labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.w500),
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
          fontWeight: FontWeight.w500,
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
        labelStyle: TextStyle(color: textColor, fontWeight: FontWeight.w500),
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
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
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
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
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
                            '$remainingCount more',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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
          fontWeight: FontWeight.w500,
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
              child: const Text('Close'),
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
    final input = searchController.text.trim();
    if (input.isEmpty) {
      setState(() {
        searchError = 'Please enter a spot ID or URL';
        _foundSpot = null;
      });
      return;
    }

    final spotId = _extractSpotId(input);
    if (spotId == null) {
      setState(() {
        searchError = 'Invalid spot ID or URL format';
        _foundSpot = null;
      });
      return;
    }

    if (spotId == widget.spot.id) {
      setState(() {
        searchError = 'Cannot mark a spot as duplicate of itself';
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
          searchError = 'Spot not found';
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
        searchError = 'Failed to load spot: $e';
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
                    Text(
                      spot.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
            const Expanded(child: Text('Flag as duplicate')),
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
                  'This spot appears to be a duplicate of another spot. Please select the original spot below.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Which spot is this a duplicate of?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                            hintText: 'Paste spot URL or enter spot ID',
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
                        label: const Text('Search'),
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
                      'Nearby spots (within ~50m)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
                      'Found Spot',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
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
                                    'Spot ID: ${_selectedDuplicateSpot!.id}',
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
                            tooltip: 'Remove selection',
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
                  decoration: const InputDecoration(
                    labelText: 'Additional details',
                    hintText: 'Anything else we should know?',
                  ),
                ),
                const SizedBox(height: 16),
                if (!isLoggedIn) ...[
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      hintText: 'name@example.com',
                      helperText: 'We will contact you only about this report.',
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
                                ? 'We will reach out at ${emailController.text} if we need more info.'
                                : 'We will reach out using your account email if we need more info.',
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
            child: const Text('Cancel'),
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
                            'Please select the spot this is a duplicate of.';
                      });
                      return;
                    }

                    final trimmedEmail = emailController.text.trim();
                    if (!isLoggedIn) {
                      if (trimmedEmail.isEmpty) {
                        setState(() {
                          emailError = 'Please provide an email address.';
                        });
                        return;
                      }
                      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                      if (!emailRegex.hasMatch(trimmedEmail)) {
                        setState(() {
                          emailError = 'Enter a valid email address.';
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
                        submissionError =
                            'Could not send your report. Please try again.';
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
                : const Text('Submit report'),
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
            const Expanded(child: Text('Report this spot')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Let us know what is wrong with ${widget.spot.name}. Moderators will review your report shortly.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'What is happening?',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Select a category',
                  hintText: 'Choose a report category',
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
                    child: Text(category),
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
                          _getCategoryDescription(selectedCategory!),
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
                    labelText: 'Describe the issue',
                    hintText: 'Tell us what does not match reality',
                    errorText: otherDescriptionError,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: detailsController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Additional details',
                  hintText: 'Anything else we should know?',
                ),
              ),
              const SizedBox(height: 16),
              if (!isLoggedIn) ...[
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    hintText: 'name@example.com',
                    helperText: 'We will contact you only about this report.',
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
                              ? 'We will reach out at ${emailController.text} if we need more info.'
                              : 'We will reach out using your account email if we need more info.',
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
            child: const Text('Cancel'),
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
                        categoryError = 'Please select a category.';
                      });
                      return;
                    }

                    final trimmedOther = otherController.text.trim();
                    if (otherSelected && trimmedOther.isEmpty) {
                      setState(() {
                        otherDescriptionError =
                            'Please describe the issue when selecting Other.';
                      });
                      return;
                    }

                    final trimmedEmail = emailController.text.trim();
                    if (!isLoggedIn) {
                      if (trimmedEmail.isEmpty) {
                        setState(() {
                          emailError = 'Please provide an email address.';
                        });
                        return;
                      }
                      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                      if (!emailRegex.hasMatch(trimmedEmail)) {
                        setState(() {
                          emailError = 'Enter a valid email address.';
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
                        submissionError =
                            'Could not send your report. Please try again.';
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
                : const Text('Submit report'),
          ),
        ],
      ),
    );
  }

  String _getCategoryDescription(String category) {
    switch (category) {
      case 'Spot closed or removed':
        return 'The spot has been permanently closed, demolished, or removed and is no longer accessible. Please provide more details below.';
      case 'Inaccurate location or details':
        return 'The spot\'s location on the map is incorrect, or details like name, description, or address are wrong. Please provide more details below on what should be corrected.';
      case 'Unsafe conditions':
        return 'The spot has become dangerous due to structural issues, environmental hazards, or other safety concerns. Please provide more details below on what is unsafe.';
      case 'Not a spot':
        return 'Only for objective issues like spam, spots in invalid locations (e.g., middle of the sea), private residences, entire cities, or other clearly invalid entries. For subjective opinions about spot quality, please use a rating instead. Please provide more details below on why this is not a spot.';
      case 'Other':
        return 'Any other issue not covered by the categories above. Please describe the issue in the field below.';
      default:
        return '';
    }
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
    final hasTransferOptions = widget.hasPhotos || widget.hasYoutubeLinks;
    final hasOverwriteOptions =
        _hasName || _hasDescription || _hasLocation || _hasSpotAttributes;

    return AlertDialog(
      title: const Text('Mark as Duplicate'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to mark this spot as a duplicate? This action can be reversed later.',
            ),
            if (hasTransferOptions || hasOverwriteOptions) ...[
              const SizedBox(height: 16),
              if (hasTransferOptions) ...[
                const Text(
                  'Select which items to add to the original spot:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (widget.hasPhotos)
                  CheckboxListTile(
                    title: const Text('Photos'),
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
                    title: const Text('YouTube links'),
                    value: _transferYoutubeLinks,
                    onChanged: (value) {
                      setState(() {
                        _transferYoutubeLinks = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
              ],
              if (hasOverwriteOptions) ...[
                if (hasTransferOptions) const SizedBox(height: 16),
                const Text(
                  'Select which items to overwrite in the original spot (if set):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_hasName)
                  CheckboxListTile(
                    title: const Text('Name'),
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
                    title: const Text('Description'),
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
                    title: const Text('Location'),
                    value: _overwriteLocation,
                    onChanged: (value) {
                      setState(() {
                        _overwriteLocation = value ?? false;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                if (_hasSpotAttributes)
                  CheckboxListTile(
                    title: const Text('Spot attributes'),
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
          child: const Text('Cancel'),
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
          child: const Text('Confirm'),
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
  final List<Uint8List> _selectedImageBytes = [];
  bool _isUploading = false;
  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    detailsController = TextEditingController();
  }

  @override
  void dispose() {
    detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> pickedFiles = await picker.pickMultiImage(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        for (final pickedFile in pickedFiles) {
          try {
            final bytes = await pickedFile.readAsBytes();
            final prepared = await prepareImageForUpload(bytes);
            if (mounted) {
              setState(() => _selectedImageBytes.add(prepared.bytes));
            }
          } on ImagePreparationException catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(e.message), backgroundColor: Colors.red),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is ImagePreparationException
                  ? e.message
                  : 'Failed to pick images. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _selectedImageBytes.removeAt(index);
    });
  }

  Future<void> _submitPhotos() async {
    if (_selectedImageBytes.isEmpty) {
      setState(() {
        _submissionError = 'Please select at least one photo';
      });
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      setState(() {
        _submissionError =
            'You must be logged in to suggest photos. Please log in and try again.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

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

      final photoUrls = await spotService.uploadSuggestedPhotos(
        photoBytesList: _selectedImageBytes,
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

      // Create spot report
      final success = await reportService.submitSpotReport(
        spotId: widget.spot.id!,
        spotName: widget.spot.name,
        categories: ['Photo suggestion'],
        details: detailsController.text.trim().isEmpty
            ? null
            : detailsController.text.trim(),
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
          _submissionError =
              'Failed to submit photo suggestion. Please try again.';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      debugPrint('Error submitting photo suggestion: $e');
      if (mounted) {
        setState(() {
          _submissionError = 'Error submitting photo suggestion: $e';
          _isSubmitting = false;
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext dialogContext) {
    final theme = Theme.of(dialogContext);

    return PopScope(
      canPop: !_isSubmitting && !_isUploading,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_photo_alternate, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Suggest Photos')),
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
                  'Submit photos to be added to this spot. Photos will be reviewed by moderators before being added.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                // Photo selection
                Text(
                  'Select Photos',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _isSubmitting || _isUploading ? null : _pickImages,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Pick Photos'),
                ),
                const SizedBox(height: 16),
                // Display selected images
                if (_selectedImageBytes.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(_selectedImageBytes.length, (
                      index,
                    ) {
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _selectedImageBytes[index],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: theme.colorScheme.error,
                                        size: 32,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              color: theme.colorScheme.error,
                              onPressed: _isSubmitting || _isUploading
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
                  'Additional Details (Optional)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: detailsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Add any additional information about these photos...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  enabled: !_isSubmitting && !_isUploading,
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
            onPressed: (_isSubmitting || _isUploading)
                ? null
                : () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: (_isSubmitting || _isUploading) ? null : _submitPhotos,
            child: _isSubmitting || _isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
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

  LatLng? _suggestedLatLng;
  String? _geocodedAddress;
  bool _isGeocoding = false;

  String? _selectedAccess;
  final Set<String> _selectedFeatures = {};
  final Map<String, String> _selectedFacilities = {};
  final Set<String> _selectedGoodFor = {};

  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.spot.name);
    _descriptionController = TextEditingController(
      text: widget.spot.description,
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
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final initial = LatLng(widget.spot.latitude, widget.spot.longitude);
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(initialLocation: initial),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _suggestedLatLng = result;
        _isGeocoding = true;
      });
      _geocodeLocation(result.latitude, result.longitude);
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
    if (!_hasSuggestions()) {
      setState(() {
        _submissionError = 'Please suggest at least one change.';
      });
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) {
      setState(() {
        _submissionError =
            'You must be logged in to suggest edits. Please log in and try again.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final reportService = Provider.of<SpotReportService>(
        context,
        listen: false,
      );

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
          _submissionError = 'Please suggest at least one change.';
          _isSubmitting = false;
        });
        return;
      }

      final success = await reportService.submitSpotReport(
        spotId: widget.spot.id!,
        spotName: widget.spot.name,
        categories: ['Edit suggestion'],
        details: null,
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
          _submissionError =
              'Failed to submit edit suggestion. Please try again.';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      debugPrint('Error submitting edit suggestion: $e');
      if (mounted) {
        setState(() {
          _submissionError = 'Error submitting edit suggestion: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit_note, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Suggest an Edit')),
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
                  'Propose changes to this spot. Moderators will review your suggestions.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'Location',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
                        ? 'Change location (picked)'
                        : 'Pick different location on map',
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
                            ? 'Geocoding...'
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
                  'Title',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Spot title',
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
                  'Description',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Spot description',
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
                  'Spot attributes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class _CheckInDialogResult {
  const _CheckInDialogResult({
    required this.isPrivate,
    required this.expectedEndAt,
    this.comment,
  });
  final bool isPrivate;
  final DateTime expectedEndAt;
  final String? comment;
}

class _SpotCheckInDialog extends StatefulWidget {
  const _SpotCheckInDialog();

  @override
  State<_SpotCheckInDialog> createState() => _SpotCheckInDialogState();
}

class _SpotCheckInDialogState extends State<_SpotCheckInDialog> {
  /// When true, others can see this check-in on the spot (maps to `isPrivate: false`).
  bool _sharePublicly = true;
  final _commentController = TextEditingController();
  late DateTime _expectedEndAt;

  static const Duration _quarterStep = Duration(minutes: 15);

  @override
  void initState() {
    super.initState();
    _expectedEndAt = defaultExpectedEndAt(DateTime.now());
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _nudgeEndByQuarter(int sign) {
    assert(sign == 1 || sign == -1);
    final now = DateTime.now();
    final maxEnd = now.add(SpotCheckIn.maxSessionDuration);
    final next = _expectedEndAt.add(Duration(minutes: 15 * sign));
    if (sign < 0) {
      if (!next.isAfter(now)) return;
    } else {
      if (next.isAfter(maxEnd)) return;
    }
    setState(() => _expectedEndAt = next);
  }

  bool _canSubtractQuarter(DateTime now) {
    return _expectedEndAt.subtract(_quarterStep).isAfter(now);
  }

  bool _canAddQuarter(DateTime maxEnd) {
    return !_expectedEndAt.add(_quarterStep).isAfter(maxEnd);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final maxEnd = now.add(SpotCheckIn.maxSessionDuration);
    final canSub = _canSubtractQuarter(now);
    final canAdd = _canAddQuarter(maxEnd);
    final untilStr = DateFormat(
      'MMM d, y • h:mm a',
    ).format(_expectedEndAt.toLocal());
    final cs = theme.colorScheme;
    return AlertDialog(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.place_outlined,
            color: cs.primary,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Check in',
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Log that you’re training now at this spot.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Share publicly'),
              subtitle: const Text(
                'Turn off to only log this for yourself.',
              ),
              value: _sharePublicly,
              onChanged: (v) => setState(() => _sharePublicly = v),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: '15 minutes earlier',
                  onPressed: canSub ? () => _nudgeEndByQuarter(-1) : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Here until',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          untilStr,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '15 minutes later',
                  onPressed: canAdd ? () => _nudgeEndByQuarter(1) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                hintText: 'e.g. what you plan to work on',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLength: SpotCheckIn.maxCommentLength,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            final trimmed = _commentController.text.trim();
            Navigator.of(context).pop(
              _CheckInDialogResult(
                isPrivate: !_sharePublicly,
                expectedEndAt: _expectedEndAt,
                comment: trimmed.isEmpty ? null : trimmed,
              ),
            );
          },
          icon: const Icon(Icons.place_outlined),
          label: const Text('Check in'),
        ),
      ],
    );
  }
}

class _SpotSaveMenu extends StatelessWidget {
  final String spotId;
  final VoidCallback onAddToCustomList;

  const _SpotSaveMenu({required this.spotId, required this.onAddToCustomList});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        if (authService.isLoading) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 44,
                height: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (!authService.isAuthenticated) {
          final loginRedirect =
              '/login?redirectTo=${Uri.encodeComponent('/spot/$spotId')}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PopupMenuButton<_SpotSaveMenuAction>(
                tooltip: 'Save spot',
                position: PopupMenuPosition.under,
                borderRadius: BorderRadius.circular(22),
                splashRadius: 22,
                onSelected: (action) {
                  if (action == _SpotSaveMenuAction.login && context.mounted) {
                    context.go(loginRedirect);
                  }
                },
                itemBuilder: (menuContext) {
                  final menuTheme = Theme.of(menuContext);
                  return <PopupMenuEntry<_SpotSaveMenuAction>>[
                    PopupMenuItem<_SpotSaveMenuAction>(
                      value: _SpotSaveMenuAction.login,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sign in to save spots',
                            style: menuTheme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add this spot to Want to visit, Been here, or your own lists. '
                            'Log in or create a free account to get started.',
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
                                'Log in or create account',
                                style: menuTheme.textTheme.labelLarge?.copyWith(
                                  color: menuTheme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.6,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.bookmark_border,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final wantToVisit = authService.userProfile?.wantToVisit ?? [];
        final visited = authService.userProfile?.visited ?? [];
        final inWantToVisit = wantToVisit.contains(spotId);
        final inVisited = visited.contains(spotId);
        final featureAccessService = FeatureAccessService(authService);
        final hasSpotListAccess =
            authService.isAuthenticated &&
            featureAccessService.hasFeatureAccess('spotLists');

        return Consumer<SpotTrackingService>(
          builder: (context, trackingService, _) {
            final isUpdating = trackingService.isLoading;

            IconData icon;
            Color? iconColor;
            String tooltip;
            if (isUpdating) {
              icon = Icons.bookmark_border;
              iconColor = colorScheme.onSurface.withValues(alpha: 0.38);
              tooltip = 'Updating…';
            } else if (inWantToVisit) {
              icon = Icons.bookmark;
              iconColor = colorScheme.primary;
              tooltip = 'Saved: Want to visit';
            } else if (inVisited) {
              icon = Icons.check_circle;
              iconColor = colorScheme.primary;
              tooltip = 'Saved: Been here';
            } else {
              icon = Icons.bookmark_border;
              iconColor = colorScheme.onSurface.withValues(alpha: 0.6);
              tooltip = 'Save spot';
            }

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
                        ? 'Removed from Want to visit'
                        : 'Failed to remove';
                  } else {
                    success = await trackingService.addToWantToVisit(spotId);
                    message = success
                        ? 'Added to Want to visit'
                        : 'Failed to add';
                  }
                  break;
                case _SpotSaveMenuAction.toggleVisited:
                  if (inVisited) {
                    success = await trackingService.removeFromVisited(spotId);
                    message = success
                        ? 'Removed from Been here'
                        : 'Failed to remove';
                  } else {
                    success = await trackingService.addToVisited(spotId);
                    message = success ? 'Added to Been here' : 'Failed to add';
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

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PopupMenuButton<_SpotSaveMenuAction>(
                  enabled: !isUpdating,
                  tooltip: tooltip,
                  position: PopupMenuPosition.under,
                  borderRadius: BorderRadius.circular(22),
                  splashRadius: 22,
                  onSelected: (action) => handleAction(action),
                  itemBuilder: (menuContext) {
                    final menuTheme = Theme.of(menuContext);
                    final primary = menuTheme.colorScheme.primary;
                    return <PopupMenuEntry<_SpotSaveMenuAction>>[
                      PopupMenuItem<_SpotSaveMenuAction>(
                        value: _SpotSaveMenuAction.toggleWantToVisit,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: inWantToVisit
                                  ? Icon(Icons.check, size: 20, color: primary)
                                  : null,
                            ),
                            Expanded(
                              child: Text(
                                'Want to visit',
                                style: menuTheme.textTheme.bodyMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'View full list',
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
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: inVisited
                                  ? Icon(Icons.check, size: 20, color: primary)
                                  : null,
                            ),
                            Expanded(
                              child: Text(
                                'Been here',
                                style: menuTheme.textTheme.bodyMedium,
                              ),
                            ),
                            IconButton(
                              tooltip: 'View full list',
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
                      if (hasSpotListAccess) ...[
                        const PopupMenuDivider(),
                        PopupMenuItem<_SpotSaveMenuAction>(
                          value: _SpotSaveMenuAction.addToCustomList,
                          child: Row(
                            children: [
                              Icon(
                                Icons.playlist_add,
                                size: 20,
                                color: menuTheme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Add to custom list',
                                      style: menuTheme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    Text(
                                      'Choose or create a list',
                                      style: menuTheme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: menuTheme
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.6),
                                            fontSize: 11,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ];
                  },
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: isUpdating
                          ? Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              ),
                            )
                          : Icon(icon, color: iconColor, size: 24),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AddToListDialog extends StatefulWidget {
  final String spotId;
  final List<SpotList> lists;
  final List<SpotList> listsWithSpot;
  final SpotListService spotListService;

  const _AddToListDialog({
    required this.spotId,
    required this.lists,
    required this.listsWithSpot,
    required this.spotListService,
  });

  @override
  State<_AddToListDialog> createState() => _AddToListDialogState();
}

class _AddToListDialogState extends State<_AddToListDialog> {
  final Set<String> _selectedListIds = {};
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  SpotListVisibility _newListVisibility = SpotListVisibility.unlisted;
  bool _showCreateForm = false;
  bool _isCreating = false;
  bool _isAdding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createListAndAdd() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('List name cannot be empty')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    final listId = await widget.spotListService.createSpotList(
      _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      visibility: _newListVisibility,
    );

    if (!mounted) return;

    if (listId != null) {
      // Add spot to the newly created list
      setState(() {
        _isCreating = false;
        _isAdding = true;
      });

      final success = await widget.spotListService.addSpotToList(
        listId,
        widget.spotId,
      );

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop({'created': true, 'added': true});
      } else {
        setState(() {
          _isAdding = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.spotListService.error ?? 'Failed to add spot to list',
            ),
          ),
        );
      }
    } else {
      setState(() {
        _isCreating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.spotListService.error ?? 'Failed to create list',
          ),
        ),
      );
    }
  }

  Future<void> _addToSelectedLists() async {
    if (_selectedListIds.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isAdding = true;
    });

    bool allSuccess = true;
    String? errorMessage;
    final selectedLists = widget.lists
        .where((l) => l.id != null && _selectedListIds.contains(l.id!))
        .toList();

    for (final list in selectedLists) {
      if (list.hasAdvancedOrganization) {
        final sectionResult = await _showSectionPickerForList(list);
        if (sectionResult == null) continue; // User cancelled
        if (sectionResult['cancelled'] == true) continue;
        final sectionIds = sectionResult['sectionIds'] as List<String>? ?? [];
        final note = sectionResult['note'] as String?;
        final addToNewSection = sectionResult['newSection'] == true;
        final newSectionTitle = sectionResult['newSectionTitle'] as String?;

        for (final sectionId in sectionIds) {
          final success = await widget.spotListService.addSpotToSection(
            list.id!,
            sectionId,
            widget.spotId,
            note: note,
          );
          if (!success) {
            allSuccess = false;
            errorMessage =
                widget.spotListService.error ??
                'Failed to add spot to some lists';
            break;
          }
        }
        if (allSuccess && addToNewSection) {
          final success = await widget.spotListService.addSpotToNewSection(
            list.id!,
            widget.spotId,
            sectionTitle: newSectionTitle?.isEmpty == true
                ? null
                : newSectionTitle,
            note: note,
          );
          if (!success) {
            allSuccess = false;
            errorMessage =
                widget.spotListService.error ??
                'Failed to add spot to some lists';
          }
        }
      } else {
        final success = await widget.spotListService.addSpotToList(
          list.id!,
          widget.spotId,
        );
        if (!success) {
          allSuccess = false;
          errorMessage =
              widget.spotListService.error ??
              'Failed to add spot to some lists';
          break;
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _isAdding = false;
    });

    if (allSuccess) {
      Navigator.of(context).pop({'added': true});
    } else {
      Navigator.of(
        context,
      ).pop({'error': errorMessage ?? 'Failed to add spot to lists'});
    }
  }

  Future<Map<String, dynamic>?> _showSectionPickerForList(SpotList list) async {
    final selectedSectionIds = <String>{};
    bool addToNewSection = false;
    final noteController = TextEditingController();
    final newSectionTitleController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final hasSelection = selectedSectionIds.isNotEmpty || addToNewSection;
          return AlertDialog(
            title: Text('Add to ${list.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select sections:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(list.sections ?? []).map(
                    (section) => CheckboxListTile(
                      title: Text(
                        section.title?.trim().isEmpty != false
                            ? 'Section (${section.entries.length} spots)'
                            : section.title!,
                      ),
                      value: selectedSectionIds.contains(section.id),
                      onChanged: (value) {
                        setDialogState(() {
                          if (value == true) {
                            selectedSectionIds.add(section.id);
                          } else {
                            selectedSectionIds.remove(section.id);
                          }
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Add to new section'),
                    value: addToNewSection,
                    onChanged: (value) {
                      setDialogState(() => addToNewSection = value ?? false);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (addToNewSection) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: newSectionTitleController,
                      decoration: const InputDecoration(
                        labelText: 'Section name (optional)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, {'cancelled': true}),
                child: const Text('Skip'),
              ),
              TextButton(
                onPressed: hasSelection
                    ? () => Navigator.pop(context, {
                        'sectionIds': selectedSectionIds.toList(),
                        'newSection': addToNewSection,
                        'newSectionTitle': addToNewSection
                            ? newSectionTitleController.text.trim()
                            : null,
                        'note': noteController.text.trim().isEmpty
                            ? null
                            : noteController.text.trim(),
                      })
                    : null,
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );

    noteController.dispose();
    newSectionTitleController.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add to List'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_showCreateForm) ...[
                if (widget.listsWithSpot.isNotEmpty) ...[
                  Text(
                    'Already in these lists:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.listsWithSpot.map(
                    (list) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              list.name,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          if (list.id != null)
                            IconButton(
                              tooltip: 'View full list',
                              icon: Icon(
                                Icons.list_alt_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              onPressed: _isAdding
                                  ? null
                                  : () {
                                      context.push('/list/${list.id}');
                                    },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (widget.lists.isEmpty) ...[
                  Text(
                    'You don\'t have any lists yet. Create one to get started!',
                    style: theme.textTheme.bodyMedium,
                  ),
                ] else ...[
                  Text(
                    'Select lists to add this spot to:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...widget.lists.map(
                    (list) => CheckboxListTile(
                      title: Text(list.name),
                      subtitle:
                          list.description != null &&
                              list.description!.isNotEmpty
                          ? Text(
                              list.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            )
                          : null,
                      value: _selectedListIds.contains(list.id),
                      onChanged: _isAdding
                          ? null
                          : (value) {
                              setState(() {
                                if (value == true && list.id != null) {
                                  _selectedListIds.add(list.id!);
                                } else if (list.id != null) {
                                  _selectedListIds.remove(list.id);
                                }
                              });
                            },
                      secondary: list.id == null
                          ? null
                          : IconButton(
                              tooltip: 'View full list',
                              icon: Icon(
                                Icons.list_alt_outlined,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              onPressed: _isAdding
                                  ? null
                                  : () {
                                      context.push('/list/${list.id}');
                                    },
                            ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isAdding
                      ? null
                      : () {
                          setState(() {
                            _showCreateForm = true;
                          });
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Create New List'),
                ),
              ] else ...[
                Text(
                  'Create New List',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'List Name',
                    hintText: 'e.g., My Favorite Spots',
                  ),
                  autofocus: true,
                  enabled: !_isCreating && !_isAdding,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Add a description for this list',
                  ),
                  maxLines: 3,
                  enabled: !_isCreating && !_isAdding,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SpotListVisibility>(
                  initialValue: _newListVisibility,
                  decoration: const InputDecoration(labelText: 'Visibility'),
                  items: SpotListVisibility.values
                      .map(
                        (visibility) => DropdownMenuItem<SpotListVisibility>(
                          value: visibility,
                          child: Text(visibility.label),
                        ),
                      )
                      .toList(),
                  onChanged: (_isCreating || _isAdding)
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _newListVisibility = value;
                          });
                        },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _newListVisibility.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: (_isCreating || _isAdding)
                      ? null
                      : () {
                          setState(() {
                            _showCreateForm = false;
                            _nameController.clear();
                            _descriptionController.clear();
                            _newListVisibility = SpotListVisibility.unlisted;
                          });
                        },
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: (_isCreating || _isAdding)
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (!_showCreateForm && widget.lists.isNotEmpty)
          ElevatedButton(
            onPressed: (_isAdding || _selectedListIds.isEmpty)
                ? null
                : _addToSelectedLists,
            child: _isAdding
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Add'),
          ),
        if (_showCreateForm)
          ElevatedButton(
            onPressed: (_isCreating || _isAdding) ? null : _createListAndAdd,
            child: (_isCreating || _isAdding)
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create & Add'),
          ),
      ],
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
            '${_currentIndex + 1} / ${widget.imageUrls.length}',
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
