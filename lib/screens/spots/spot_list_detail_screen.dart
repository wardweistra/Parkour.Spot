import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import '../../models/spot_list.dart';
import '../../models/spot.dart';
import '../../services/spot_list_service.dart';
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../services/feature_access_service.dart';
import '../../services/search_state_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../widgets/spot_card.dart';
import '../../services/snackbar_service.dart';
import '../../utils/marker_icon_utils.dart';
import '../../utils/web_meta_utils.dart';
import '../../utils/map_bounds_utils.dart';
import '../../services/url_service.dart';
import '../../services/web_share_service.dart';
import '../../services/user_profile_service.dart';
import '../../constants/spot_detail_ui.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/spot_detail_quick_action_chip.dart';
import '../../widgets/spot_list_save_button.dart';
import 'package:flutter/services.dart';
import 'spot_list_advanced_organization_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/spot_list_localization.dart';
import '../../utils/relative_date_localization.dart';

enum _ListManageMenuAction { listSettings, organize, delete }

class SpotListDetailScreen extends StatefulWidget {
  final String listId;

  const SpotListDetailScreen({super.key, required this.listId});

  @override
  State<SpotListDetailScreen> createState() => _SpotListDetailScreenState();
}

class _SpotListDetailScreenState extends State<SpotListDetailScreen> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  SpotList? _list;
  List<Spot> _spots = [];
  bool _isLoading = true;
  String? _error;
  bool _isSatelliteView = false;
  GoogleMapController? _mapController;
  BitmapDescriptor? _spotHighlightedIcon; // Black icon for spots in list
  BitmapDescriptor? _spotSelectedHighlightedIcon; // Grey icon for selected spot
  Spot? _selectedSpot; // Currently selected/highlighted spot
  final ScrollController _scrollController = ScrollController();
  String? _creatorName;

  @override
  void initState() {
    super.initState();
    _loadList();
    _loadSpotIcons();
  }

  @override
  void dispose() {
    if (kIsWeb) {
      WebMetaUtils.resetPageMeta();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSpotIcons() async {
    try {
      // Black icon for spots in list (matching highlighted style from Explore)
      final BitmapDescriptor highlightedIcon =
          await MarkerIconUtils.createMarkerIcon(
            size: 22,
            fillColor: Colors.black,
          );
      // Grey icon for selected spot (matching selectedHighlighted style from Explore)
      final BitmapDescriptor selectedHighlightedIcon =
          await MarkerIconUtils.createMarkerIcon(
            size: 22,
            fillColor: Colors.grey.shade400,
          );
      if (mounted) {
        setState(() {
          _spotHighlightedIcon = highlightedIcon;
          _spotSelectedHighlightedIcon = selectedHighlightedIcon;
        });
      }
    } catch (_) {
      // Ignore icon errors silently
    }
  }

  Future<void> _loadList() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final spotListService = Provider.of<SpotListService>(
      context,
      listen: false,
    );
    final list = await spotListService.getSpotListById(widget.listId);

    if (list == null) {
      setState(() {
        _isLoading = false;
        _error = _l10n.spotListDetailListNotFoundOrNotAccessible;
      });
      return;
    }

    setState(() {
      _list = list;
    });

    // Load creator display name
    if (list.createdBy.isNotEmpty) {
      final userProfileService = Provider.of<UserProfileService>(
        context,
        listen: false,
      );
      final user = await userProfileService.getUserProfile(list.createdBy);
      if (mounted) {
        setState(() {
          _creatorName =
              user?.displayName ??
              user?.username ??
              _l10n.spotDetailUnknownUser;
        });
      }
    }

    // Load spots (use effectiveSpotIds for advanced lists)
    final spotIdsToLoad = list.effectiveSpotIds;
    if (spotIdsToLoad.isNotEmpty) {
      await _loadSpots(spotIdsToLoad);
    } else {
      setState(() {
        _isLoading = false;
        _spots = [];
      });
    }
  }

  Future<void> _loadSpots(List<String> spotIds) async {
    final spotService = Provider.of<SpotService>(context, listen: false);
    final List<Spot> loadedSpots = [];

    for (final spotId in spotIds) {
      final spot = await spotService.getSpotById(spotId);
      if (spot != null) {
        loadedSpots.add(spot);
      }
    }

    setState(() {
      _spots = loadedSpots;
      _isLoading = false;
    });

    // Fit bounds after spots are loaded
    if (loadedSpots.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitBounds();
      });
    }
  }

  Future<void> _openAdvancedOrganizationScreen() async {
    if (_list == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => SpotListAdvancedOrganizationScreen(
          listName: _list!.name,
          listId: widget.listId,
          list: _list!,
        ),
      ),
    );
    if (mounted && result == true) {
      await _loadList();
    }
  }

  Future<void> _deleteList() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_l10n.spotListDetailDeleteListTitle),
        content: Text(
          _l10n.spotListDetailDeleteListConfirmation(_list?.name ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_l10n.profileCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(_l10n.spotListDetailDeleteAction),
          ),
        ],
      ),
    );

    if (shouldDelete == true && _list?.id != null) {
      if (!mounted) return;
      final spotListService = Provider.of<SpotListService>(
        context,
        listen: false,
      );
      final success = await spotListService.deleteSpotList(_list!.id!);

      if (success) {
        SnackbarService.showSuccess(_l10n.spotListDetailListDeleted);
        if (!mounted) return;
        context.pop();
      } else {
        SnackbarService.showError(
          spotListService.error ?? _l10n.spotListDetailFailedToDeleteList,
        );
      }
    }
  }

  Widget _buildSpotsList() {
    if (_spots.isEmpty &&
        (_list?.hasAdvancedOrganization != true ||
            _list!.sections!.every((s) => s.entries.isEmpty))) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _l10n.spotListDetailNoSpotsInThisList,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _l10n.publicProfileAddSpotsFromSpotDetailPages,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    if (_list?.hasAdvancedOrganization == true && _list!.sections != null) {
      return _buildSectionsList();
    }

    return _buildFlatSpotsList();
  }

  Map<String, Spot> get _spotById => {
    for (final s in _spots)
      if (s.id != null) s.id!: s,
  };

  Widget _buildSectionsList() {
    final theme = Theme.of(context);
    final spotById = _spotById;
    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = screenWidth >= 600;

    final sectionWidgets = <Widget>[];
    for (final section in _list!.sections!) {
      if (section.entries.isEmpty) continue;
      final hasTitle =
          section.title != null && section.title!.trim().isNotEmpty;
      final hasBody = section.text != null && section.text!.trim().isNotEmpty;
      sectionWidgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasTitle)
                Text(section.title!, style: theme.textTheme.titleLarge),
              if (hasTitle && hasBody) const SizedBox(height: 10),
              if (hasBody)
                Text(
                  section.text!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              if (hasTitle || hasBody)
                SizedBox(height: hasBody ? 16 : 12)
              else
                const SizedBox(height: 8),
              if (useGrid)
                _buildSectionGrid(section, spotById)
              else
                _buildSectionList(section, spotById),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sectionWidgets,
    );
  }

  Widget _buildSectionGrid(
    SpotListSection section,
    Map<String, Spot> spotById,
  ) {
    final entries = section.entries;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 480,
        mainAxisExtent: 440,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final spot = spotById[entry.spotId];
        if (spot == null) return const SizedBox.shrink();
        return SpotCard(
          spot: spot,
          customNote: entry.note,
          showCheckInPresence: true,
          onTapWithImageIndex: (imageIndex) {
            if (spot.id != null) {
              final baseUrl = UrlService.generateNavigationUrl(
                spot.id!,
                countryCode: spot.countryCode,
                city: spot.city,
              );
              final url = imageIndex > 0
                  ? '$baseUrl?imageIndex=$imageIndex'
                  : baseUrl;
              context.push(url);
            }
          },
          onLocate: () => _locateSpot(spot),
          onRemove: null,
        );
      },
    );
  }

  Widget _buildSectionList(
    SpotListSection section,
    Map<String, Spot> spotById,
  ) {
    final entries = section.entries;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final spot = spotById[entry.spotId];
        if (spot == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SpotCard(
            spot: spot,
            customNote: entry.note,
            showCheckInPresence: true,
            onTapWithImageIndex: (imageIndex) {
              if (spot.id != null) {
                final baseUrl = UrlService.generateNavigationUrl(
                  spot.id!,
                  countryCode: spot.countryCode,
                  city: spot.city,
                );
                final url = imageIndex > 0
                    ? '$baseUrl?imageIndex=$imageIndex'
                    : baseUrl;
                context.push(url);
              }
            },
            onLocate: () => _locateSpot(spot),
            onRemove: null,
          ),
        );
      },
    );
  }

  Widget _buildFlatSpotsList() {
    if (_spots.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final useGrid = screenWidth >= 600;

    if (useGrid) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 480,
          mainAxisExtent: 440,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _spots.length,
        itemBuilder: (context, index) {
          final spot = _spots[index];
          return SpotCard(
            spot: spot,
            showCheckInPresence: true,
            onTapWithImageIndex: (imageIndex) {
              if (spot.id != null) {
                final baseUrl = UrlService.generateNavigationUrl(
                  spot.id!,
                  countryCode: spot.countryCode,
                  city: spot.city,
                );
                final url = imageIndex > 0
                    ? '$baseUrl?imageIndex=$imageIndex'
                    : baseUrl;
                context.push(url);
              }
            },
            onLocate: () => _locateSpot(spot),
            onRemove: null,
          );
        },
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _spots.length,
      itemBuilder: (context, index) {
        final spot = _spots[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SpotCard(
            spot: spot,
            showCheckInPresence: true,
            onTapWithImageIndex: (imageIndex) {
              if (spot.id != null) {
                final baseUrl = UrlService.generateNavigationUrl(
                  spot.id!,
                  countryCode: spot.countryCode,
                  city: spot.city,
                );
                final url = imageIndex > 0
                    ? '$baseUrl?imageIndex=$imageIndex'
                    : baseUrl;
                context.push(url);
              }
            },
            onLocate: () => _locateSpot(spot),
            onRemove: null,
          ),
        );
      },
    );
  }

  Future<void> _editList() async {
    if (_list == null) return;

    final nameController = TextEditingController(text: _list!.name);
    final descriptionController = TextEditingController(
      text: _list!.description ?? '',
    );
    final moreInfoUrlController = TextEditingController(
      text: _list!.moreInfoUrl ?? '',
    );
    SpotListVisibility selectedVisibility = _list!.visibility;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_l10n.spotListDetailEditListTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: _l10n.spotDetailListNameLabel,
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: _l10n.spotDetailListDescriptionLabel,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: moreInfoUrlController,
                  decoration: InputDecoration(
                    labelText: _l10n.spotListDetailMoreInfoLinkLabel,
                    hintText: _l10n.spotListDetailMoreInfoLinkHint,
                    helperText: _l10n.spotListDetailMoreInfoLinkHelper,
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SpotListVisibility>(
                  initialValue: selectedVisibility,
                  decoration: InputDecoration(
                    labelText: _l10n.spotDetailVisibilityLabel,
                  ),
                  items: SpotListVisibility.values
                      .map(
                        (visibility) => DropdownMenuItem<SpotListVisibility>(
                          value: visibility,
                          child: Text(visibility.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      selectedVisibility = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    selectedVisibility.description,
                    style: Theme.of(dialogContext).textTheme.bodySmall
                        ?.copyWith(
                          color: Theme.of(
                            dialogContext,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_l10n.profileCancel),
            ),
            TextButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text(_l10n.spotDetailListNameEmpty)),
                  );
                  return;
                }
                final link = moreInfoUrlController.text.trim();
                if (link.isNotEmpty &&
                    !UrlService.isValidHttpOrHttpsUrl(link)) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        _l10n.spotListDetailMoreInfoLinkValidationError,
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(_l10n.spotListDetailSave),
            ),
          ],
        ),
      ),
    );

    if (result == true && _list?.id != null) {
      if (!mounted) return;
      final spotListService = Provider.of<SpotListService>(
        context,
        listen: false,
      );
      var success = await spotListService.updateSpotList(
        _list!.id!,
        name: nameController.text.trim(),
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
        visibility: selectedVisibility,
        moreInfoUrl: moreInfoUrlController.text,
      );

      if (!mounted) return;
      if (success) {
        SnackbarService.showSuccess(_l10n.spotListDetailListUpdated);
        await _loadList();
      } else {
        SnackbarService.showError(
          spotListService.error ?? _l10n.spotListDetailFailedToUpdateList,
        );
      }
    }
  }

  bool _canManageList() {
    if (_list == null) return false;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return false;

    final userId = authService.currentUser?.uid;
    if (userId == null || _list!.createdBy != userId) return false;

    final featureAccessService = FeatureAccessService(authService);
    return featureAccessService.hasFeatureAccess('spotLists');
  }

  /// Show save affordance for guests and non-owners (not for the list creator).
  bool _shouldShowListSaveButton() {
    if (_list == null) return false;
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated) return true;
    return authService.currentUser?.uid != _list!.createdBy;
  }

  String _visibilitySummary(SpotListVisibility visibility) {
    return spotListVisibilitySummary(_l10n, visibility);
  }

  String _formatRelativeDate(DateTime date) =>
      formatRelativeDateInDays(date, _l10n);

  Future<void> _navigateToUserProfile(String userId) async {
    try {
      final userProfileService = Provider.of<UserProfileService>(
        context,
        listen: false,
      );
      final user = await userProfileService.getUserProfile(userId);
      final identifier = user?.username?.isNotEmpty == true
          ? user!.username!
          : userId;
      if (mounted) {
        context.push('/user/$identifier');
      }
    } catch (e) {
      if (mounted) {
        SnackbarService.showError(_l10n.spotListDetailCouldNotOpenProfile);
      }
    }
  }

  Widget _buildProvenanceSentence({bool compactTop = false}) {
    if (_list == null) return const SizedBox.shrink();

    final list = _list!;
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final visibilityLabel = _visibilitySummary(list.visibility);
    final createdDateText = _formatRelativeDate(list.createdAt);
    final creatorName = _creatorName;
    final hasCreator = list.createdBy.isNotEmpty;
    final hasUpdated = list.updatedAt != list.createdAt;
    final updatedDateText = hasUpdated
        ? _formatRelativeDate(list.updatedAt)
        : null;

    final List<InlineSpan> children = [];

    // "{Visibility} list created {X} ago"
    String createdPart = _l10n.spotListDetailCreatedPart(
      visibilityLabel,
      createdDateText,
    );
    if (hasCreator) {
      createdPart += _l10n.spotListDetailCreatedBySuffix;
    } else {
      createdPart += '.';
    }
    children.add(TextSpan(text: createdPart, style: textStyle));

    // Creator name (clickable if we have userId)
    if (hasCreator) {
      final name = creatorName ?? _l10n.spotDetailUnknownUser;
      children.add(
        TextSpan(
          text: name,
          style: textStyle?.copyWith(color: theme.colorScheme.primary),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _navigateToUserProfile(list.createdBy),
        ),
      );
    }

    // ", and last updated {X}."
    if (hasCreator) {
      if (hasUpdated && updatedDateText != null) {
        children.add(
          TextSpan(
            text: _l10n.spotListDetailLastUpdatedPart(updatedDateText),
            style: textStyle,
          ),
        );
      } else {
        children.add(TextSpan(text: '.', style: textStyle));
      }
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, compactTop ? 6 : 12, 16, 0),
      margin: EdgeInsets.only(top: compactTop ? 2 : 8),
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
              text: TextSpan(style: textStyle, children: children),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreInfoLinkRow() {
    final url = _list?.moreInfoUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final hostLabel = UrlService.displayHttpUrlHost(url);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: textStyle,
                children: [
                  TextSpan(text: _l10n.spotListDetailMoreInformationOn),
                  TextSpan(
                    text: hostLabel,
                    style: textStyle?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () =>
                          UrlService.openHttpOrHttpsUrl(url, context),
                  ),
                  TextSpan(text: '.', style: textStyle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Copy list URL to clipboard (same style as spot detail page)
  void _copyListToClipboard() async {
    if (_list?.id == null || _list?.name == null) return;

    try {
      const baseUrl = 'https://parkour.spot';
      final url = '$baseUrl/list/${_list!.id}';
      final label = _list!.name.trim();
      final text = '$label 👉 $url';

      final outcome = await WebShareService.tryShareLink(text: label, url: url);
      if (outcome == WebShareOutcome.shared ||
          outcome == WebShareOutcome.cancelled) {
        return;
      }

      await Clipboard.setData(ClipboardData(text: text));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotListDetailCopiedToClipboard),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.spotListDetailCopyFailed(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _onListManageMenuSelected(_ListManageMenuAction action) {
    switch (action) {
      case _ListManageMenuAction.listSettings:
        _editList();
        break;
      case _ListManageMenuAction.organize:
        _openAdvancedOrganizationScreen();
        break;
      case _ListManageMenuAction.delete:
        _deleteList();
        break;
    }
  }

  // Calculate bounds to fit all spots with 5% margin
  LatLngBounds? _calculateBounds() {
    return calculateBoundsForSpots(_spots);
  }

  // Build markers for all spots
  Set<Marker> _buildMarkers() {
    return _spots.map((spot) {
      final bool isSelected = _selectedSpot?.id != null
          ? _selectedSpot!.id == spot.id
          : _selectedSpot?.name == spot.name;

      // Use grey icon for selected spot, black for others (matching Explore page style)
      final BitmapDescriptor icon = kIsWeb
          ? (isSelected
                ? (_spotSelectedHighlightedIcon ??
                      BitmapDescriptor.defaultMarker)
                : (_spotHighlightedIcon ?? BitmapDescriptor.defaultMarker))
          : (isSelected
                ? (_spotSelectedHighlightedIcon ??
                      BitmapDescriptor.defaultMarker)
                : (_spotHighlightedIcon ?? BitmapDescriptor.defaultMarker));

      return Marker(
        markerId: MarkerId(spot.id ?? spot.name),
        position: LatLng(spot.latitude, spot.longitude),
        icon: icon,
        onTap: null,
        consumeTapEvents: true,
        infoWindow: InfoWindow.noText,
      );
    }).toSet();
  }

  // Locate a spot: scroll to map and highlight it
  Future<void> _locateSpot(Spot spot) async {
    // Scroll to top to show the map
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }

    // Select the spot and refresh markers to show grey highlight
    if (mounted) {
      setState(() {
        _selectedSpot = spot;
      });
    }
  }

  // Navigate to explore page with list highlighted
  void _showListOnMap() {
    if (_list?.id != null) {
      context.go('/explore?listId=${_list!.id}');
    }
  }

  // Get initial camera position based on bounds
  CameraPosition? _getInitialCameraPosition() {
    final bounds = _calculateBounds();
    if (bounds == null) return null;

    // Calculate center
    final centerLat =
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2;
    final centerLng =
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2;

    // Calculate approximate zoom level based on bounds
    final latDiff = bounds.northeast.latitude - bounds.southwest.latitude;
    final lngDiff = bounds.northeast.longitude - bounds.southwest.longitude;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    // Approximate zoom calculation (this is a rough estimate)
    double zoom = 10.0;
    if (maxDiff > 0.1) {
      zoom = 8.0;
    } else if (maxDiff > 0.05) {
      zoom = 9.0;
    } else if (maxDiff > 0.01) {
      zoom = 11.0;
    } else if (maxDiff > 0.005) {
      zoom = 12.0;
    } else {
      zoom = 13.0;
    }

    return CameraPosition(target: LatLng(centerLat, centerLng), zoom: zoom);
  }

  // Fit map to show all markers with bounds
  Future<void> _fitBounds() async {
    if (_mapController == null) return;

    final bounds = _calculateBounds();
    if (bounds == null) return;

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50.0), // 50px padding
    );
  }

  Widget _buildMap() {
    if (_spots.isEmpty) {
      return const SizedBox.shrink();
    }

    final initialCameraPosition = _getInitialCameraPosition();
    if (initialCameraPosition == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: initialCameraPosition,
            mapType: _isSatelliteView ? MapType.hybrid : MapType.normal,
            markers: _buildMarkers(),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              // Fit bounds after map is created
              _fitBounds();
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
                  onTap: _showListOnMap,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Map Type Toggle Button
          Positioned(
            bottom: 24,
            right: 10,
            child: PointerInterceptor(
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _isSatelliteView = !_isSatelliteView;
                  });
                  final searchState = Provider.of<SearchStateService>(
                    context,
                    listen: false,
                  );
                  searchState.setSatellite(_isSatelliteView);
                },
                heroTag: 'mapTypeToggleFab',
                mini: true,
                tooltip: _isSatelliteView
                    ? _l10n.spotDetailMapSwitchToMap
                    : _l10n.spotDetailMapSwitchToSatellite,
                child: Icon(_isSatelliteView ? Icons.map : Icons.terrain),
              ),
            ),
          ),
          // Hint text
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
                      _l10n.spotListDetailHighlightListOnMap,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Save (when applicable), List settings, Share — matches spot detail action row.
  Widget _buildListActionsRow() {
    if (_list?.id == null) return const SizedBox.shrink();

    return Consumer<AuthService>(
      builder: (context, _, _) {
        final items = <Widget>[];

        if (_shouldShowListSaveButton()) {
          items.add(SpotListSaveButton(listId: widget.listId));
        }
        if (_canManageList()) {
          items.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PopupMenuButton<_ListManageMenuAction>(
                position: PopupMenuPosition.under,
                tooltip: _l10n.spotListDetailEditListTooltip,
                borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
                splashRadius: 20,
                onSelected: _onListManageMenuSelected,
                itemBuilder: (menuContext) {
                  final theme = Theme.of(menuContext);
                  final primary = theme.colorScheme.primary;
                  return <PopupMenuEntry<_ListManageMenuAction>>[
                    PopupMenuItem<_ListManageMenuAction>(
                      value: _ListManageMenuAction.listSettings,
                      child: Row(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            color: primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _l10n.spotListDetailMenuListSettings,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<_ListManageMenuAction>(
                      value: _ListManageMenuAction.organize,
                      child: Row(
                        children: [
                          Icon(Icons.folder, color: primary, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _l10n.spotListDetailMenuOrganizeList,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem<_ListManageMenuAction>(
                      value: _ListManageMenuAction.delete,
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _l10n.spotListDetailMenuDeleteList,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
                child: SpotDetailQuickActionChip(
                  icon: Icons.edit_outlined,
                  iconColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.75),
                  label: _l10n.spotDetailQuickActionEdit,
                ),
              ),
            ),
          );
        }
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Tooltip(
              message: _l10n.spotDetailShareTooltip,
              child: Semantics(
                button: true,
                label: _l10n.spotDetailShareTooltip,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
                    onTap: _copyListToClipboard,
                    child: SpotDetailQuickActionChip(
                      icon: Icons.share_outlined,
                      iconColor: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.75),
                      label: _l10n.spotDetailQuickActionShare,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        if (items.isEmpty) return const SizedBox.shrink();

        final children = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          if (i > 0) children.add(const SizedBox(width: 8));
          children.add(items[i]);
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: children,
            ),
          ),
        );
      },
    );
  }

  void _handleBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      // No previous page (direct link) - go to explore
      context.go('/explore');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return PageScaffold(
        title: _list?.name ?? _l10n.spotListDetailPageTitle,
        onBack: _handleBack,
        scrollable: false,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      if (kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) WebMetaUtils.resetPageMeta();
        });
      }
      return PageScaffold(
        title: _list?.name ?? _l10n.spotListDetailPageTitle,
        onBack: _handleBack,
        scrollable: false,
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
              Text(_error!, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _handleBack,
                child: Text(_l10n.spotDetailRouteGoToExplore),
              ),
            ],
          ),
        ),
      );
    }

    if (_list == null) {
      if (kIsWeb) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) WebMetaUtils.resetPageMeta();
        });
      }
      return PageScaffold(
        title: _l10n.spotListDetailPageTitle,
        onBack: _handleBack,
        scrollable: false,
        body: Center(child: Text(_l10n.spotListDetailListNotFound)),
      );
    }

    if (kIsWeb) {
      final listName = _list!.name;
      final spotCount = _list!.spotIds.length;
      final baseDescription =
          _list!.description != null && _list!.description!.trim().isNotEmpty
          ? WebMetaUtils.clipForMeta(_list!.description!.trim())
          : _l10n.spotListDetailMetaDescriptionFallback(spotCount);
      final description =
          '$baseDescription — ${WebMetaUtils.defaultDescription}';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          WebMetaUtils.updatePageMeta('$listName - Parkour·Spot', description);
        }
      });
    }

    return PageScaffold(
      title: _list!.name,
      onBack: _handleBack,
      scrollable: false,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Map showing all spots
            if (_spots.isNotEmpty) _buildMap(),
            _buildListActionsRow(),
            // List info header
            if (_list!.description != null && _list!.description!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _list!.description!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            _buildMoreInfoLinkRow(),
            _buildProvenanceSentence(
              compactTop:
                  _list!.moreInfoUrl != null && _list!.moreInfoUrl!.isNotEmpty,
            ),
            // Spots list
            _buildSpotsList(),
          ],
        ),
      ),
    );
  }
}
