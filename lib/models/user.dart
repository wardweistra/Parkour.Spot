class User {
  final String id;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String? username;
  final String? instagramUrl;
  final bool isPublicProfile;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final DateTime? lastActiveAt;
  final List<String>? favoriteSpots;
  final bool isEmailVerified;
  final bool isAdmin;
  final bool isModerator;
  final Map<String, bool>? featureAccess;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoURL,
    this.username,
    this.instagramUrl,
    this.isPublicProfile = true,
    this.createdAt,
    this.lastLoginAt,
    this.lastActiveAt,
    this.favoriteSpots,
    this.isEmailVerified = false,
    this.isAdmin = false,
    this.isModerator = false,
    this.featureAccess,
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
      createdAt: map['createdAt']?.toDate(),
      lastLoginAt: map['lastLoginAt']?.toDate(),
      lastActiveAt: map['lastActiveAt']?.toDate(),
      favoriteSpots: map['favoriteSpots'] != null 
          ? List<String>.from(map['favoriteSpots']) 
          : null,
      isEmailVerified: map['isEmailVerified'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      isModerator: map['isModerator'] ?? false,
      featureAccess: map['featureAccess'] != null
          ? Map<String, bool>.from(map['featureAccess'])
          : null,
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
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
      'lastActiveAt': lastActiveAt,
      'favoriteSpots': favoriteSpots,
      'isEmailVerified': isEmailVerified,
      'isAdmin': isAdmin,
      'isModerator': isModerator,
      'featureAccess': featureAccess,
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
    DateTime? createdAt,
    DateTime? lastLoginAt,
    DateTime? lastActiveAt,
    List<String>? favoriteSpots,
    bool? isEmailVerified,
    bool? isAdmin,
    bool? isModerator,
    Map<String, bool>? featureAccess,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL == _omit ? this.photoURL : photoURL as String?,
      username: username ?? this.username,
      instagramUrl: instagramUrl == _omit ? this.instagramUrl : instagramUrl as String?,
      isPublicProfile: isPublicProfile ?? this.isPublicProfile,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      favoriteSpots: favoriteSpots ?? this.favoriteSpots,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isAdmin: isAdmin ?? this.isAdmin,
      isModerator: isModerator ?? this.isModerator,
      featureAccess: featureAccess ?? this.featureAccess,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, displayName: $displayName)';
  }
}
