import 'auth_service.dart';

/// Service for checking user feature access.
/// 
/// Features are stored as a `Map<String, bool>` in the user's profile,
/// where the key is the feature name and the value indicates access.
class FeatureAccessService {
  final AuthService _authService;

  FeatureAccessService(this._authService);

  /// Check if the current user has access to a specific feature.
  /// 
  /// Returns `false` if:
  /// - User is not authenticated
  /// - User profile is not loaded
  /// - Feature doesn't exist in the featureAccess map
  /// - Feature access is explicitly set to `false`
  /// 
  /// Returns `true` only if the feature exists in the map and is `true`.
  bool hasFeatureAccess(String featureName) {
    final userProfile = _authService.userProfile;
    
    // No access if user is not authenticated or profile not loaded
    if (!_authService.isAuthenticated || userProfile == null) {
      return false;
    }

    // No access if featureAccess map is null or empty
    final featureAccess = userProfile.featureAccess;
    if (featureAccess == null || featureAccess.isEmpty) {
      return false;
    }

    // Check if feature exists and is true
    return featureAccess[featureName] == true;
  }

  /// Get the current user's feature access map.
  /// Returns null if user is not authenticated or profile not loaded.
  Map<String, bool>? getFeatureAccess() {
    final userProfile = _authService.userProfile;
    
    if (!_authService.isAuthenticated || userProfile == null) {
      return null;
    }

    return userProfile.featureAccess;
  }
}

