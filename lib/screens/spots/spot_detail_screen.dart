import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../models/spot.dart';
import '../../services/spot_service.dart';
import '../../services/spot_report_service.dart';
import '../../services/auth_service.dart';
import '../../services/url_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/sync_source_service.dart';
import '../../services/search_state_service.dart';
import '../../widgets/source_details_dialog.dart';
import '../../widgets/spot_selection_dialog.dart';
import '../../constants/spot_attributes.dart';
import '../../services/snackbar_service.dart';
import '../../utils/image_url_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/audit_log_service.dart';
import 'package:web/web.dart' as web;

class SpotDetailScreen extends StatefulWidget {
  final Spot spot;

  const SpotDetailScreen({super.key, required this.spot});

  @override
  State<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

enum _SpotMenuAction { login, report, edit, delete, markAsDuplicate, toggleHide }

class _SpotDetailScreenState extends State<SpotDetailScreen> {
  double _userRating = 0;
  double _previousRating = 0; // Track the user's previous rating
  bool _hasRated = false;
  int _currentImageIndex = 0;
  int _currentVideoIndex = 0;
  late final ScrollController _scrollController;
  late final PageController _videoPageController;
  bool _isSatelliteView = false;
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

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _videoPageController = PageController();
    _currentSpot = widget.spot; // Initialize current spot
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

    // Initialize satellite view from SearchStateService
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchStateServiceRef = Provider.of<SearchStateService>(context, listen: false);
      _searchStateServiceRef!.addListener(_onSearchStateChanged);
      setState(() {
        _isSatelliteView = _searchStateServiceRef!.isSatellite;
      });
    });
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
    
    setState(() {
      _isSatelliteView = searchState.isSatellite;
    });
  }

  @override
  void dispose() {
    // Reset document title to default when leaving spot page
    if (kIsWeb) {
      web.document.title = 'Parkour·Spot';
    }
    _scrollController.dispose();
    _videoPageController.dispose();
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
      final originalSpot = await spotService.getSpotById(widget.spot.duplicateOf!);
      
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

  void _showExternalSpotInfo() async {
    if (widget.spot.spotSource == null) return;

    try {
      final syncSourceService = Provider.of<SyncSourceService>(
        context,
        listen: false,
      );

      // Ensure sources are loaded before trying to find the specific source
      if (syncSourceService.sources.isEmpty && !syncSourceService.isLoading) {
        await syncSourceService.fetchSyncSources(includeInactive: false);
      }

      // Find the source by ID
      final source = syncSourceService.sources.firstWhere(
        (s) => s.id == widget.spot.spotSource,
        orElse: () => throw Exception('Source not found'),
      );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => SourceDetailsDialog(source: source),
      );
    } catch (e) {
      // Fallback to simple info dialog if source not found
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.source, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              const Text('External Spot'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This spot comes from an external source.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'External spots:',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              ...[
                '• May not have all features of native spots',
                '• Could be removed if the source is unavailable',
                '• May have limited editing capabilities',
                '• Data accuracy depends on the original source',
              ].map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              if (widget.spot.spotSourceName != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Source: ${widget.spot.spotSourceName}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    }
  }

  void _copySpotToClipboard() async {
    try {
      final url = UrlService.generateSpotUrl(
        widget.spot.id!,
        countryCode: widget.spot.countryCode,
        city: widget.spot.city,
      );
      final text = '${widget.spot.name.trim()} 👉 $url';

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

  void _onMenuActionSelected(_SpotMenuAction action) {
    switch (action) {
      case _SpotMenuAction.login:
        context.go(
          '/login?redirectTo=${Uri.encodeComponent('/spot/${widget.spot.id}')}',
        );
        break;
      case _SpotMenuAction.report:
        _showReportSpotDialog();
        break;
      case _SpotMenuAction.edit:
        if (widget.spot.id != null) {
          context.push('/spot/${widget.spot.id}/edit', extra: widget.spot);
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
      case _SpotMenuAction.toggleHide:
        _toggleSpotHidden();
        break;
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
      barrierDismissible: false,
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
              actions: [
                // External spot badge
                if (widget.spot.spotSource != null) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate max width: screen width minus back button, share button, and other actions
                      final screenWidth = MediaQuery.of(context).size.width;
                      // Reserve space for back button (~56px), share button (~56px), other actions (~100px), and padding
                      // Use 50% of screen width with a minimum of 100px to prevent overlap on small screens
                      // On wide screens, allow more space for longer source names
                      final reservedSpace = 200.0; // Back button + share + other actions + padding
                      final maxWidth = (screenWidth - reservedSpace).clamp(100.0, double.infinity);
                      
                      return GestureDetector(
                        onTap: _showExternalSpotInfo,
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: maxWidth,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.spot.folderName != null
                                ? '${widget.spot.spotSourceName ?? widget.spot.spotSource!} - ${widget.spot.folderName!}'
                                : widget.spot.spotSourceName ??
                                      widget.spot.spotSource!,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                // Locate button
                CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.my_location, color: Colors.white),
                    onPressed: _locateSpotOnMap,
                    tooltip: 'Locate on map',
                  ),
                ),
                const SizedBox(width: 8),
                // Share button for all users
                CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: _copySpotToClipboard,
                  ),
                ),
                const SizedBox(width: 8),
                
                Consumer<AuthService>(
                  builder: (context, authService, child) {
                    if (authService.isLoading) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                      );
                    }

                    final bool hasStaffAccess =
                        authService.isAuthenticated &&
                        authService.userProfile != null &&
                        (authService.isAdmin || authService.isModerator);
                    final bool canDeleteSpot =
                        authService.isAuthenticated &&
                        authService.userProfile != null &&
                        authService.isAdmin;

                    return PopupMenuButton<_SpotMenuAction>(
                      position: PopupMenuPosition.under,
                      tooltip: 'More actions',
                      icon: CircleAvatar(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        child: const Icon(Icons.more_vert, color: Colors.white),
                      ),
                      onSelected: _onMenuActionSelected,
                      itemBuilder: (menuContext) {
                        final theme = Theme.of(menuContext);
                        final List<PopupMenuEntry<_SpotMenuAction>> items = [
                          if (!authService.isAuthenticated) ...[
                            PopupMenuItem<_SpotMenuAction>(
                              value: _SpotMenuAction.login,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.login,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
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
                                        'Sign in to rate and favorite',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    Text(
                                      'Help us review this spot',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
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
                            items.addAll([
                              PopupMenuItem<_SpotMenuAction>(
                                value: _SpotMenuAction.edit,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Edit spot',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        Text(
                                          'Moderator only',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem<_SpotMenuAction>(
                                value: _SpotMenuAction.markAsDuplicate,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.copy_all,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Mark as duplicate',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        Text(
                                          'Moderator only',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _spot.hidden ? 'Unhide spot' : 'Hide spot',
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        Text(
                                          'Moderator only',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
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
                              items.add(
                                PopupMenuItem<_SpotMenuAction>(
                                  value: _SpotMenuAction.delete,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Delete spot',
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.red,
                                                ),
                                          ),
                                          Text(
                                            'Admin only',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme.colorScheme.onSurface
                                                      .withValues(alpha: 0.6),
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
                    );
                  },
                ),
                const SizedBox(width: 16),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildImageCarousel(),
              ),
            ),

            // Content using SliverList
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Rating
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _spot.name,
                            style: Theme.of(context).textTheme.headlineMedium
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
                                        ?.copyWith(fontWeight: FontWeight.bold),
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

                    const SizedBox(height: 16),

                    // Hidden spot indicator
                    if (_spot.hidden)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_off,
                              color: Colors.orange.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'This spot is hidden from public view',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Description
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _spot.description.trim().isEmpty
                          ? 'No description provided'
                          : _spot.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontStyle: _spot.description.trim().isEmpty
                            ? FontStyle.italic
                            : FontStyle.normal,
                        color: _spot.description.trim().isEmpty
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6)
                            : null,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // YouTube Videos Section - show clickable thumbnails, with carousel when multiple
                    if (widget.spot.youtubeVideoIds != null &&
                        widget.spot.youtubeVideoIds!.isNotEmpty) ...[
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Builder(
                            builder: (context) {
                              final videoIds = widget.spot.youtubeVideoIds!;
                              if (videoIds.length == 1) {
                                final id = videoIds.first;
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    onTap: () async {
                                      final uri = Uri.parse(
                                        'https://www.youtube.com/watch?v=$id',
                                      );
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Image.network(
                                            'https://img.youtube.com/vi/$id/hqdefault.jpg',
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                          Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
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
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // Multiple videos -> carousel
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: PageView.builder(
                                        controller: _videoPageController,
                                        itemCount: videoIds.length,
                                        onPageChanged: (i) {
                                          setState(() {
                                            _currentVideoIndex = i;
                                          });
                                        },
                                        itemBuilder: (context, index) {
                                          final id = videoIds[index];
                                          return InkWell(
                                            onTap: () async {
                                              final uri = Uri.parse(
                                                'https://www.youtube.com/watch?v=$id',
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
                                                Image.network(
                                                  'https://img.youtube.com/vi/$id/hqdefault.jpg',
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                ),
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
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                  // Left arrow
                                  if (!MobileDetectionService.isMobileDevice)
                                    Positioned(
                                      left: 8,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: GestureDetector(
                                          onTap: () {
                                            final prev = _currentVideoIndex - 1;
                                            final target = prev < 0
                                                ? videoIds.length - 1
                                                : prev;
                                            _videoPageController.animateToPage(
                                              target,
                                              duration: const Duration(
                                                milliseconds: 250,
                                              ),
                                              curve: Curves.easeOut,
                                            );
                                          },
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.6,
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withValues(
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

                                  // Right arrow
                                  if (!MobileDetectionService.isMobileDevice)
                                    Positioned(
                                      right: 8,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: GestureDetector(
                                          onTap: () {
                                            final next =
                                                (_currentVideoIndex + 1) %
                                                videoIds.length;
                                            _videoPageController.animateToPage(
                                              next,
                                              duration: const Duration(
                                                milliseconds: 250,
                                              ),
                                              curve: Curves.easeOut,
                                            );
                                          },
                                          child: Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.6,
                                              ),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white.withValues(
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

                                  // Dots indicator
                                  Positioned(
                                    bottom: 8,
                                    left: 0,
                                    right: 0,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(videoIds.length, (
                                        index,
                                      ) {
                                        final isActive =
                                            index == _currentVideoIndex;
                                        return AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          margin: const EdgeInsets.symmetric(
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
                                              color: Colors.white.withValues(
                                                alpha: 0.3,
                                              ),
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
                      const SizedBox(height: 24),
                    ],

                    // Location Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Location',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Standard',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: !_isSatelliteView
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.6),
                                      ),
                                ),
                                Switch(
                                  value: _isSatelliteView,
                                  onChanged: (value) {
                                    setState(() {
                                      _isSatelliteView = value;
                                    });
                                    final searchState = Provider.of<SearchStateService>(context, listen: false);
                                    searchState.setSatellite(value);
                                  },
                                ),
                                Text(
                                  'Satellite',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: _isSatelliteView
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.6),
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Small map widget (web-safe placeholder on web)
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
                          GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                widget.spot.latitude,
                                widget.spot.longitude,
                              ),
                              zoom: 16,
                            ),
                            mapType: _isSatelliteView
                                ? MapType.satellite
                                : MapType.normal,
                            markers: {
                              Marker(
                                markerId: MarkerId(widget.spot.id ?? 'spot'),
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
                          ),
                          Positioned.fill(
                            child: PointerInterceptor(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _openInMaps(),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
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
                                      'Tap to open map',
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

                    const SizedBox(height: 16),

                    // Location Information
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Location Details',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text:
                                      '${widget.spot.latitude.toStringAsFixed(6)}, ${widget.spot.longitude.toStringAsFixed(6)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurface,
                                      ),
                                ),
                                if (widget.spot.address != null) ...[
                                  TextSpan(
                                    text: '\n${widget.spot.address}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                          height: 1.3,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
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
                                chips: widget.spot.spotFeatures!.map((feature) {
                                  return _buildFeatureChip(feature);
                                }).toList(),
                              ),
                            );
                          }

                          // Access Section
                          if (widget.spot.spotAccess != null) {
                            sections.add(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Access',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: sections[0]),
                                    const SizedBox(width: 16),
                                    Expanded(child: sections[1]),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: sections[0]),
                                    const SizedBox(width: 16),
                                    Expanded(child: sections[1]),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                _buildAccessChip(widget.spot.spotAccess!),
                                const SizedBox(height: 24),
                              ],

                              // Facilities
                              if (widget.spot.spotFacilities != null &&
                                  widget.spot.spotFacilities!.isNotEmpty) ...[
                                () {
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
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary,
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
                                                  AlwaysStoppedAnimation<Color>(
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
                                                      .withValues(alpha: 0.7),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                // Rating widget
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              },
                            );
                          }

                          // Show rating widget if user rating is already loaded
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rate this spot',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  ...List.generate(5, (index) {
                                    return GestureDetector(
                                      onTap: () =>
                                          _submitRatingDirectly(index + 1.0),
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
                        } else {
                          // Show login prompt for unauthenticated users
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
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
                                      const SizedBox(height: 8),
                                      Text(
                                        'Login to rate this spot and help other parkour enthusiasts',
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
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () {
                                                context.go(
                                                  '/login?redirectTo=${Uri.encodeComponent('/spot/${widget.spot.id}')}',
                                                );
                                              },
                                              icon: const Icon(Icons.login),
                                              label: const Text(
                                                'Login to Rate',
                                              ),
                                            ),
                                          ),
                                        ],
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

                    // Additional Info
                    if (widget.spot.createdBy != null ||
                        widget.spot.createdByName != null ||
                        widget.spot.createdAt != null ||
                        widget.spot.duplicateOf != null ||
                        _duplicateSpots.isNotEmpty ||
                        _isLoadingDuplicates) ...[
                      Text(
                        'Additional Information',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (widget.spot.duplicateOf != null || _originalSpot != null) ...[
                        GestureDetector(
                          onTap: _isLoadingOriginalSpot
                              ? null
                              : () {
                                  if (_originalSpot != null) {
                                    final navigationUrl = UrlService.generateNavigationUrl(
                                      _originalSpot!.id!,
                                      countryCode: _originalSpot!.countryCode,
                                      city: _originalSpot!.city,
                                    );
                                    context.go(navigationUrl);
                                  } else {
                                    // Fallback to simple spot ID route
                                    context.go('/spot/${widget.spot.duplicateOf}');
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
                                      color: Theme.of(context).colorScheme.primary,
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
                      if (widget.spot.duplicateOf == null && _originalSpot == null) ...[
                        if (_isLoadingDuplicates)
                          ListTile(
                            leading: Icon(
                              Icons.copy_all,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            title: const Text('Also based on'),
                            subtitle: const Text('Loading...'),
                            contentPadding: EdgeInsets.zero,
                          )
                        else if (_duplicateSpots.isNotEmpty) ...[
                          ListTile(
                            leading: Icon(
                              Icons.copy_all,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                            title: Text(
                              'Also based on (${_duplicateSpots.length})',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                          ..._duplicateSpots.map((duplicate) {
                            return GestureDetector(
                              onTap: () {
                                final navigationUrl = UrlService.generateNavigationUrl(
                                  duplicate.id!,
                                  countryCode: duplicate.countryCode,
                                  city: duplicate.city,
                                );
                                context.go(navigationUrl);
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(left: 48.0),
                                child: ListTile(
                                  leading: Icon(
                                    Icons.arrow_right,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                  title: Text(
                                    duplicate.name,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.secondary,
                                    ),
                                  ),
                                  subtitle: duplicate.spotSourceName != null || duplicate.spotSource != null
                                      ? Text(
                                          duplicate.spotSourceName ?? duplicate.spotSource ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
                                          ),
                                        )
                                      : null,
                                  contentPadding: EdgeInsets.zero,
                                  trailing: Icon(
                                    Icons.open_in_new,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                      if (widget.spot.createdBy != null ||
                          widget.spot.createdByName != null) ...[
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('Added by'),
                          subtitle: Text(
                            widget.spot.createdByName ??
                                widget.spot.createdBy ??
                                '',
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                      if (widget.spot.spotSource != null) ...[
                        GestureDetector(
                          onTap: _showExternalSpotInfo,
                          child: ListTile(
                            leading: const Icon(Icons.source),
                            title: const Text('Source'),
                            subtitle: Text(
                              widget.spot.folderName != null
                                  ? '${widget.spot.spotSourceName ?? 'Unknown Source'} - ${widget.spot.folderName!}'
                                  : widget.spot.spotSourceName ??
                                        'Unknown Source',
                            ),
                            contentPadding: EdgeInsets.zero,
                            trailing: const Icon(Icons.info_outline, size: 16),
                          ),
                        ),
                      ],
                      if (widget.spot.createdAt != null) ...[
                        ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: const Text('Created on'),
                          subtitle: Text(_formatDate(widget.spot.createdAt!)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                      if (widget.spot.updatedAt != null &&
                          widget.spot.updatedAt != widget.spot.createdAt) ...[
                        ListTile(
                          leading: const Icon(Icons.update),
                          title: const Text('Last updated'),
                          subtitle: Text(_formatDate(widget.spot.updatedAt!)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ],

                    const SizedBox(height: 32),
                  ],
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
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: CachedNetworkImage(
              key: ValueKey(_currentImageIndex),
              imageUrl: getResizedImageUrl(widget.spot.imageUrls![_currentImageIndex]),
              fit: BoxFit.cover,
              width: double.infinity,
              height: 400,
              placeholder: (context, url) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) {
                debugPrint('Image error: $error');
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Gradient overlay for better text readability
          Container(
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

          // Navigation arrows (left and right)
          if (widget.spot.imageUrls!.length > 1) ...[
            // Left arrow
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _previousImage(),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
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

            // Right arrow
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _nextImage(),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
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
      ),
    );

    if (!mounted || selectedSpotIdOrAction == null) {
      return;
    }

    final spotService = Provider.of<SpotService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    // Handle "Create Native Spot" action
    if (selectedSpotIdOrAction == 'CREATE_NATIVE') {
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
          authService.userProfile?.displayName ?? authService.currentUser!.email ?? authService.currentUser!.uid,
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
        final userName = authService.userProfile?.displayName ?? authService.currentUser!.displayName ?? authService.currentUser!.email;
        
        final success = await spotService.markSpotAsDuplicate(
          widget.spot.id!,
          nativeSpotId,
          transferPhotos: false, // Already copied to native spot
          transferYoutubeLinks: false, // Already copied to native spot
          userId: userId,
          userName: userName,
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

          _showSuccessSnack('Native spot created and current spot marked as duplicate.');
        } else {
          final error = spotService.error ?? 'Failed to mark spot as duplicate';
          _showErrorSnack(error);
        }
      } catch (e) {
        if (!mounted) return;
        _showErrorSnack('Error creating native spot: $e');
      }
      return;
    }

    // Handle normal duplicate marking flow
    final selectedSpotId = selectedSpotIdOrAction;

    // Check if duplicate spot has photos or YouTube links to transfer
    final hasPhotos = widget.spot.imageUrls != null && widget.spot.imageUrls!.isNotEmpty;
    final hasYoutubeLinks = widget.spot.youtubeVideoIds != null && widget.spot.youtubeVideoIds!.isNotEmpty;

    // Show confirmation dialog with transfer options
    final Map<String, bool>? result = await showDialog<Map<String, bool>>(
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

    // Mark the spot as duplicate
    try {
      // Get user info for audit logging (moderator action)
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      final userName = authService.userProfile?.displayName ?? authService.currentUser?.displayName ?? authService.currentUser?.email;

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

  Future<void> _toggleSpotHidden() async {
    if (_spot.id == null) {
      if (!mounted) return;
      _showErrorSnack('Unable to hide/unhide this spot right now.');
      return;
    }

    final spotService = Provider.of<SpotService>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);

    // Check if user is authenticated and is a moderator
    if (!authService.isAuthenticated || (!authService.isModerator && !authService.isAdmin)) {
      if (!mounted) return;
      _showErrorSnack('Only moderators can hide/unhide spots.');
      return;
    }

    final newHiddenState = !_spot.hidden;
    final userId = authService.currentUser?.uid;
    final userName = authService.userProfile?.displayName ?? authService.currentUser?.displayName ?? authService.currentUser?.email;

    try {
      final success = await spotService.setSpotHidden(
        _spot.id!,
        newHiddenState,
        userId: userId,
        userName: userName,
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

        _showSuccessSnack(newHiddenState ? 'Spot hidden successfully.' : 'Spot unhidden successfully.');
      } else {
        final error = spotService.error ?? 'Failed to ${newHiddenState ? 'hide' : 'unhide'} spot';
        _showErrorSnack(error);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnack('Error ${newHiddenState ? 'hiding' : 'unhiding'} spot: $e');
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
        firestore.collection('ratings').where('spotId', isEqualTo: spotId).count().get(),
        firestore.collection('spotReports').where('spotId', isEqualTo: spotId).count().get(),
        firestore.collection('spots').where('duplicateOf', isEqualTo: spotId).count().get(),
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

    final canDelete = ratingsCount == 0 && spotReportsCount == 0 && duplicateSpotsCount == 0;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              if (ratingsCount > 0 || spotReportsCount > 0 || duplicateSpotsCount > 0) ...[
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
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: canDelete
                ? () async {
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
                      final userId = authService.userProfile?.id ?? authService.currentUser?.uid;
                      final userName = authService.userProfile?.displayName ?? 
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
                            metadata: {
                              'spotName': spotName,
                              'ratingsCount': capturedRatingsCount,
                              'spotReportsCount': capturedSpotReportsCount,
                              'duplicateSpotsCount': capturedDuplicateSpotsCount,
                            },
                          );
                        } catch (auditError) {
                          debugPrint('Error creating audit log entry: $auditError');
                          // Don't fail the deletion if audit logging fails
                        }

                        // Now check if mounted for UI operations
                        if (!mounted) return;
                        
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
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
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Failed to delete spot'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
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
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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
  String? duplicateSpotError;
  bool isSubmitting = false;
  Spot? _selectedDuplicateSpot;
  String? _duplicateOfSpotId;

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
    final reportService = Provider.of<SpotReportService>(dialogContext, listen: false);
    final bool isLoggedIn = authService.isAuthenticated && authService.userProfile != null;
    final String otherCategoryLabel = SpotReportService.defaultCategories.last;
    final bool otherSelected = selectedCategory == otherCategoryLabel;
    final bool duplicateSpotSelected = selectedCategory == 'Duplicate spot';

    return WillPopScope(
      onWillPop: () async => !isSubmitting,
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
                    // Clear duplicate spot selection if "Duplicate spot" is deselected
                    if (value != 'Duplicate spot') {
                      _selectedDuplicateSpot = null;
                      _duplicateOfSpotId = null;
                      duplicateSpotError = null;
                    }
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
                    color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
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
              if (duplicateSpotSelected) ...[
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
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await showDialog<String>(
                        context: dialogContext,
                        builder: (context) => SpotSelectionDialog(
                          currentSpotId: widget.spot.id,
                          allowExternalSources: true, // Allow external sources for reports
                        ),
                      );
                      if (result != null && mounted) {
                        setState(() {
                          _duplicateOfSpotId = result;
                          duplicateSpotError = null; // Clear error when spot is selected
                        });
                        // Fetch the spot details to display
                        final spotService = Provider.of<SpotService>(context, listen: false);
                        final spot = await spotService.getSpotById(result);
                        if (mounted && spot != null) {
                          setState(() {
                            _selectedDuplicateSpot = spot;
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('Select duplicate spot'),
                  ),
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
                                if (_selectedDuplicateSpot!.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _selectedDuplicateSpot!.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
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
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
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
            onPressed: isSubmitting ? null : () => Navigator.of(dialogContext).pop(false),
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
                      duplicateSpotError = null;
                    });

                    if (selectedCategory == null) {
                      setState(() {
                        categoryError = 'Please select a category.';
                      });
                      return;
                    }

                    // Validate duplicate spot selection if "Duplicate spot" is selected
                    if (selectedCategory == 'Duplicate spot' && _duplicateOfSpotId == null) {
                      setState(() {
                        duplicateSpotError = 'Please select the spot this is a duplicate of.';
                      });
                      return;
                    }

                    final trimmedOther = otherController.text.trim();
                    if (otherSelected && trimmedOther.isEmpty) {
                      setState(() {
                        otherDescriptionError = 'Please describe the issue when selecting Other.';
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
                            : authService.userProfile?.email ?? authService.currentUser?.email ?? '')
                        : trimmedEmail;

                    final success = await reportService.submitSpotReport(
                      spotId: widget.spot.id!,
                      spotName: widget.spot.name,
                      categories: [selectedCategory!],
                      otherCategory: otherSelected ? trimmedOther : null,
                      details: trimmedDetails.isEmpty ? null : trimmedDetails,
                      contactEmail: trimmedContactEmail.isEmpty ? null : trimmedContactEmail,
                      reporterUserId: authService.userProfile?.id,
                      reporterName: reporterName,
                      reporterEmail: authService.userProfile?.email ?? authService.currentUser?.email,
                      spotCountryCode: widget.spot.countryCode,
                      spotCity: widget.spot.city,
                      duplicateOfSpotId: _duplicateOfSpotId,
                    );

                    if (success) {
                      if (mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    } else {
                      setState(() {
                        isSubmitting = false;
                        submissionError = 'Could not send your report. Please try again.';
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
      case 'Duplicate spot':
        return 'This spot is a duplicate of another spot already in the database. Please select the original spot below.';
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
  State<_DuplicateTransferDialog> createState() => _DuplicateTransferDialogState();
}

class _DuplicateTransferDialogState extends State<_DuplicateTransferDialog> {
  bool _transferPhotos = false;
  bool _transferYoutubeLinks = false;
  bool _overwriteName = false;
  bool _overwriteDescription = false;
  bool _overwriteLocation = false;
  bool _overwriteSpotAttributes = false;

  bool get _hasName => widget.spot.name.isNotEmpty;
  bool get _hasDescription => widget.spot.description.isNotEmpty;
  bool get _hasLocation {
    return (widget.spot.latitude != 0.0 && widget.spot.longitude != 0.0) ||
        (widget.spot.address != null && widget.spot.address!.isNotEmpty) ||
        (widget.spot.city != null && widget.spot.city!.isNotEmpty) ||
        (widget.spot.countryCode != null && widget.spot.countryCode!.isNotEmpty);
  }
  bool get _hasSpotAttributes {
    return (widget.spot.spotAccess != null && widget.spot.spotAccess!.isNotEmpty) ||
        (widget.spot.spotFeatures != null && widget.spot.spotFeatures!.isNotEmpty) ||
        (widget.spot.spotFacilities != null && widget.spot.spotFacilities!.isNotEmpty) ||
        (widget.spot.goodFor != null && widget.spot.goodFor!.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final hasTransferOptions = widget.hasPhotos || widget.hasYoutubeLinks;
    final hasOverwriteOptions = _hasName || _hasDescription || _hasLocation || _hasSpotAttributes;

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
          }),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
