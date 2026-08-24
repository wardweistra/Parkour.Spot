import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/spot.dart';
import '../../models/user.dart' as app_user;
import '../../services/spot_service.dart';
import '../../services/auth_service.dart';
import '../../services/snackbar_service.dart';
import '../../services/url_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/spots_added_by_user.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/spot_card.dart';
import '../../l10n/app_localizations.dart';

export '../../utils/spots_added_by_user.dart' show SpotTrackingListType;

class SpotTrackingListScreen extends StatefulWidget {
  final SpotTrackingListType type;

  /// When set, load this user's added-spots list (public profile route).
  final String? profileUserIdOrUsername;

  const SpotTrackingListScreen({
    super.key,
    required this.type,
    this.profileUserIdOrUsername,
  });

  @override
  State<SpotTrackingListScreen> createState() => _SpotTrackingListScreenState();
}

class _SpotTrackingListScreenState extends State<SpotTrackingListScreen> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  List<Spot> _spots = [];
  bool _isLoading = true;
  String? _error;
  List<String>? _lastLoadedSpotIds;
  bool _isOwner = false;
  String? _addedListOwnerName;
  bool _isUpdatingPublic = false;

  bool get _isAddedList => widget.type == SpotTrackingListType.added;

  bool get _isOwnerAddedRoute =>
      _isAddedList &&
      (widget.profileUserIdOrUsername == null ||
          widget.profileUserIdOrUsername!.isEmpty);

  @override
  void initState() {
    super.initState();
    _loadSpots();
  }

  bool _listEquals(List<String> a, List<String>? b) {
    if (b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _isSameUserLookup(app_user.User profile, String lookup) {
    if (lookup == profile.id) return true;
    final username = profile.username?.trim().toLowerCase();
    return username != null &&
        username.isNotEmpty &&
        username == lookup.toLowerCase();
  }

  List<String> _trackingSpotIds(AuthService authService) {
    switch (widget.type) {
      case SpotTrackingListType.wantToVisit:
        return authService.userProfile?.wantToVisit ?? [];
      case SpotTrackingListType.visited:
        return authService.userProfile?.visited ?? [];
      case SpotTrackingListType.added:
        final userId = authService.currentUser?.uid;
        return userId == null ? const [] : [userId];
    }
  }

  Future<void> _loadSpots() async {
    final authService = Provider.of<AuthService>(context, listen: false);

    if (_isAddedList) {
      await _loadAddedSpots(authService);
      return;
    }

    final spotIds = _trackingSpotIds(authService);
    _lastLoadedSpotIds = List<String>.from(spotIds);

    if (spotIds.isEmpty) {
      setState(() {
        _spots = [];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final spotService = Provider.of<SpotService>(context, listen: false);
    final List<Spot> loadedSpots = [];

    for (final spotId in spotIds) {
      final spot = await spotService.getSpotById(spotId);
      if (spot != null) {
        loadedSpots.add(spot);
      }
    }

    if (mounted) {
      setState(() {
        _spots = loadedSpots;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAddedSpots(AuthService authService) async {
    final lookup = widget.profileUserIdOrUsername?.trim();
    final currentUserId = authService.currentUser?.uid;
    final ownProfile = authService.userProfile;

    String? targetUserId;
    var isOwner = false;
    String? ownerName;

    if (lookup == null || lookup.isEmpty) {
      if (currentUserId == null) {
        _lastLoadedSpotIds = const [];
        setState(() {
          _spots = [];
          _isLoading = false;
          _error = null;
          _isOwner = false;
          _addedListOwnerName = null;
        });
        return;
      }
      targetUserId = currentUserId;
      isOwner = true;
      ownerName = ownProfile?.displayName ?? ownProfile?.username;
    } else {
      if (currentUserId != null &&
          ownProfile != null &&
          _isSameUserLookup(ownProfile, lookup)) {
        targetUserId = currentUserId;
        isOwner = true;
        ownerName = ownProfile.displayName ?? ownProfile.username;
      } else {
        final userProfileService = Provider.of<UserProfileService>(
          context,
          listen: false,
        );
        final targetProfile = await userProfileService.getUserProfile(
          lookup,
          currentUserId: currentUserId,
        );
        if (!mounted) return;
        if (targetProfile == null) {
          _lastLoadedSpotIds = [lookup];
          setState(() {
            _spots = [];
            _isLoading = false;
            _error = _l10n.spotListDetailListNotFoundOrNotAccessible;
            _isOwner = false;
            _addedListOwnerName = null;
          });
          return;
        }
        targetUserId = targetProfile.id;
        isOwner = currentUserId != null && currentUserId == targetProfile.id;
        ownerName = targetProfile.displayName ?? targetProfile.username;
        if (!targetProfile.isAddedSpotsListPublic && !isOwner) {
          _lastLoadedSpotIds = [targetUserId];
          setState(() {
            _spots = [];
            _isLoading = false;
            _error = _l10n.spotListDetailListNotFoundOrNotAccessible;
            _isOwner = false;
            _addedListOwnerName = ownerName;
          });
          return;
        }
      }
    }

    _lastLoadedSpotIds = [targetUserId];
    setState(() {
      _isLoading = true;
      _error = null;
      _isOwner = isOwner;
      _addedListOwnerName = ownerName;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final loadedSpots = await spotService.getSpotsAddedByUser(targetUserId);
      if (!mounted) return;
      setState(() {
        _spots = loadedSpots;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _l10n.spotListsHubCouldNotLoad;
      });
    }
  }

  String get _title {
    switch (widget.type) {
      case SpotTrackingListType.wantToVisit:
        return _l10n.spotDetailWantToVisit;
      case SpotTrackingListType.visited:
        return _l10n.publicProfileBeenTo;
      case SpotTrackingListType.added:
        if (_isOwner || _isOwnerAddedRoute) {
          return _l10n.spotListsHubAddedByYou;
        }
        final name = _addedListOwnerName?.trim();
        if (name != null && name.isNotEmpty) {
          return _l10n.publicProfileAddedByUser(name);
        }
        return _l10n.spotListsHubAddedByYou;
    }
  }

  IconData get _emptyIcon {
    switch (widget.type) {
      case SpotTrackingListType.wantToVisit:
        return Icons.bookmark_border;
      case SpotTrackingListType.visited:
        return Icons.check_circle_outline;
      case SpotTrackingListType.added:
        return Icons.add_location_alt_outlined;
    }
  }

  String? get _emptyHint {
    switch (widget.type) {
      case SpotTrackingListType.added:
        return _isOwner || _isOwnerAddedRoute
            ? _l10n.spotTrackingAddedEmptyHint
            : null;
      case SpotTrackingListType.wantToVisit:
      case SpotTrackingListType.visited:
        return _l10n.publicProfileAddSpotsFromSpotDetailPages;
    }
  }

  void _checkProfileAndReload(AuthService authService) {
    if (_isAddedList && !_isOwnerAddedRoute) {
      return;
    }
    // When navigating directly or refreshing, AuthService may load the profile
    // after initState. Re-load spots when the profile becomes available with
    // spot IDs we haven't loaded yet.
    final spotIds = _trackingSpotIds(authService);
    if (spotIds.isNotEmpty &&
        !_listEquals(spotIds, _lastLoadedSpotIds) &&
        !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSpots();
      });
    }
  }

  Future<void> _setAddedListPublic(bool isPublic) async {
    if (_isUpdatingPublic) return;
    setState(() => _isUpdatingPublic = true);
    final authService = context.read<AuthService>();
    final success = await authService.updateAddedSpotsListPublic(isPublic);
    if (!mounted) return;
    setState(() => _isUpdatingPublic = false);
    if (!success) {
      SnackbarService.showError(_l10n.spotTrackingAddedVisibilityUpdateFailed);
    }
  }

  Widget _buildSpotsBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_spots.isEmpty) {
      final hint = _emptyHint;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _emptyIcon,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                _l10n.spotTrackingNoSpotsInList(_title),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              if (hint != null) ...[
                const SizedBox(height: 8),
                Text(
                  hint,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadSpots,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useGrid = constraints.maxWidth >= 600;
          if (useGrid) {
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 480,
                mainAxisExtent: 440,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _spots.length,
              itemBuilder: (context, i) {
                final spot = _spots[i];
                return SpotCard(
                  spot: spot,
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
                );
              },
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _spots.length,
            itemBuilder: (context, i) {
              final spot = _spots[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SpotCard(
                  spot: spot,
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        _checkProfileAndReload(authService);

        final needsSignIn = _isOwnerAddedRoute && !authService.isAuthenticated;
        if (needsSignIn) {
          return PageScaffold(
            title: _title,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _l10n.spotTrackingSignInToViewList(_title),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(
                      '/login?redirectTo=${Uri.encodeComponent(spotTrackingListRoutePath(widget.type))}',
                    ),
                    child: Text(_l10n.profileSignInButton),
                  ),
                ],
              ),
            ),
          );
        }

        final showPublicToggle =
            _isAddedList &&
            authService.isAuthenticated &&
            (_isOwnerAddedRoute || _isOwner);
        final isPublic =
            authService.userProfile?.isAddedSpotsListPublic ?? false;

        return PageScaffold(
          title: _title,
          scrollable: false,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showPublicToggle)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_l10n.spotListEditVisibilityPublic),
                  subtitle: Text(
                    isPublic
                        ? _l10n.spotListEditVisibilityPublicHelp
                        : _l10n.spotListEditVisibilityPrivateHelp,
                  ),
                  value: isPublic,
                  onChanged: _isUpdatingPublic ? null : _setAddedListPublic,
                ),
              Expanded(child: _buildSpotsBody()),
            ],
          ),
        );
      },
    );
  }
}
