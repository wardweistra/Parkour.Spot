class User {
  final String id;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String? username;
  final String? instagramUrl;
  final bool isPublicProfile;

  /// When true, the built-in "added by you" list is listed on the public profile.
  final bool isAddedSpotsListPublic;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final DateTime? lastActiveAt;
  final List<String>? favoriteSpots;
  final List<String>? wantToVisit;
  final List<String>? visited;
  final bool isEmailVerified;
  final bool isAdmin;
  final bool isModerator;
  final Map<String, bool>? featureAccess;
  final bool shareLastKnownLocationForAlerts;
  final bool notifyNewSpotsNearby;
  final bool notifyCheckInsNearby;
  final bool notifyTrainingPlansNearby;
  final bool notifyTrainingPlanCheckInReminders;
  final String? preferredLanguageCode;
  final bool isLanguageExplicitlySet;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoURL,
    this.username,
    this.instagramUrl,
    this.isPublicProfile = true,
    this.isAddedSpotsListPublic = false,
    this.createdAt,
    this.lastLoginAt,
    this.lastActiveAt,
    this.favoriteSpots,
    this.wantToVisit,
    this.visited,
    this.isEmailVerified = false,
    this.isAdmin = false,
    this.isModerator = false,
    this.featureAccess,
    this.shareLastKnownLocationForAlerts = true,
    this.notifyNewSpotsNearby = true,
    this.notifyCheckInsNearby = true,
    this.notifyTrainingPlansNearby = true,
    this.notifyTrainingPlanCheckInReminders = true,
    this.preferredLanguageCode,
    this.isLanguageExplicitlySet = false,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoURL: map['photoURL'],
      username: map['username'],
      instagramUrl: map['instagramUrl'],
      isPublicProfile: map['isPublicProfile'] ?? true,
      isAddedSpotsListPublic: map['isAddedSpotsListPublic'] == true,
      createdAt: map['createdAt']?.toDate(),
      lastLoginAt: map['lastLoginAt']?.toDate(),
      lastActiveAt: map['lastActiveAt']?.toDate(),
      favoriteSpots: map['favoriteSpots'] != null
          ? List<String>.from(map['favoriteSpots'])
          : null,
      wantToVisit: map['wantToVisit'] != null
          ? List<String>.from(map['wantToVisit'])
          : null,
      visited: map['visited'] != null
          ? List<String>.from(map['visited'])
          : null,
      isEmailVerified: map['isEmailVerified'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      isModerator: map['isModerator'] ?? false,
      featureAccess: map['featureAccess'] != null
          ? Map<String, bool>.from(map['featureAccess'])
          : null,
      shareLastKnownLocationForAlerts:
          map['shareLastKnownLocationForAlerts'] is bool
          ? map['shareLastKnownLocationForAlerts'] as bool
          : true,
      notifyNewSpotsNearby: map['notifyNewSpotsNearby'] is bool
          ? map['notifyNewSpotsNearby'] as bool
          : true,
      notifyCheckInsNearby: map['notifyCheckInsNearby'] is bool
          ? map['notifyCheckInsNearby'] as bool
          : true,
      notifyTrainingPlansNearby: map['notifyTrainingPlansNearby'] is bool
          ? map['notifyTrainingPlansNearby'] as bool
          : true,
      notifyTrainingPlanCheckInReminders:
          map['notifyTrainingPlanCheckInReminders'] is bool
          ? map['notifyTrainingPlanCheckInReminders'] as bool
          : true,
      preferredLanguageCode: map['preferredLanguageCode'] as String?,
      isLanguageExplicitlySet: map['isLanguageExplicitlySet'] is bool
          ? map['isLanguageExplicitlySet'] as bool
          : false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'username': username,
      'instagramUrl': instagramUrl,
      'isPublicProfile': isPublicProfile,
      'isAddedSpotsListPublic': isAddedSpotsListPublic,
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
      'lastActiveAt': lastActiveAt,
      'favoriteSpots': favoriteSpots,
      'wantToVisit': wantToVisit,
      'visited': visited,
      'isEmailVerified': isEmailVerified,
      'isAdmin': isAdmin,
      'isModerator': isModerator,
      'featureAccess': featureAccess,
      'shareLastKnownLocationForAlerts': shareLastKnownLocationForAlerts,
      'notifyNewSpotsNearby': notifyNewSpotsNearby,
      'notifyCheckInsNearby': notifyCheckInsNearby,
      'notifyTrainingPlansNearby': notifyTrainingPlansNearby,
      'notifyTrainingPlanCheckInReminders': notifyTrainingPlanCheckInReminders,
      'preferredLanguageCode': preferredLanguageCode,
      'isLanguageExplicitlySet': isLanguageExplicitlySet,
    };
  }

  static const _omit = Object();

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    Object? photoURL = _omit,
    String? username,
    Object? instagramUrl = _omit,
    bool? isPublicProfile,
    bool? isAddedSpotsListPublic,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    DateTime? lastActiveAt,
    List<String>? favoriteSpots,
    List<String>? wantToVisit,
    List<String>? visited,
    bool? isEmailVerified,
    bool? isAdmin,
    bool? isModerator,
    Map<String, bool>? featureAccess,
    bool? shareLastKnownLocationForAlerts,
    bool? notifyNewSpotsNearby,
    bool? notifyCheckInsNearby,
    bool? notifyTrainingPlansNearby,
    bool? notifyTrainingPlanCheckInReminders,
    Object? preferredLanguageCode = _omit,
    bool? isLanguageExplicitlySet,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL == _omit ? this.photoURL : photoURL as String?,
      username: username ?? this.username,
      instagramUrl: instagramUrl == _omit
          ? this.instagramUrl
          : instagramUrl as String?,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
      isAddedSpotsListPublic:
          isAddedSpotsListPublic ?? this.isAddedSpotsListPublic,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      favoriteSpots: favoriteSpots ?? this.favoriteSpots,
      wantToVisit: wantToVisit ?? this.wantToVisit,
      visited: visited ?? this.visited,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isAdmin: isAdmin ?? this.isAdmin,
      isModerator: isModerator ?? this.isModerator,
      featureAccess: featureAccess ?? this.featureAccess,
      shareLastKnownLocationForAlerts:
          shareLastKnownLocationForAlerts ??
          this.shareLastKnownLocationForAlerts,
      notifyNewSpotsNearby: notifyNewSpotsNearby ?? this.notifyNewSpotsNearby,
      notifyCheckInsNearby: notifyCheckInsNearby ?? this.notifyCheckInsNearby,
      notifyTrainingPlansNearby:
          notifyTrainingPlansNearby ?? this.notifyTrainingPlansNearby,
      notifyTrainingPlanCheckInReminders:
          notifyTrainingPlanCheckInReminders ??
          this.notifyTrainingPlanCheckInReminders,
      preferredLanguageCode: preferredLanguageCode == _omit
          ? this.preferredLanguageCode
          : preferredLanguageCode as String?,
      isLanguageExplicitlySet:
          isLanguageExplicitlySet ?? this.isLanguageExplicitlySet,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, displayName: $displayName)';
  }
}
