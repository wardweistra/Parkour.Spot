class User {
  final String id;
  final String email;
  final String? displayName;
  final String? photoURL;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final List<String>? favoriteSpots;
  final bool isEmailVerified;
  final bool isAdmin;
  final bool isModerator;

  User({
    required this.id,
    required this.email,
    this.displayName,
    this.photoURL,
    this.createdAt,
    this.lastLoginAt,
    this.favoriteSpots,
    this.isEmailVerified = false,
    this.isAdmin = false,
    this.isModerator = false,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      photoURL: map['photoURL'],
      createdAt: map['createdAt']?.toDate(),
      lastLoginAt: map['lastLoginAt']?.toDate(),
      favoriteSpots: map['favoriteSpots'] != null 
          ? List<String>.from(map['favoriteSpots']) 
          : null,
      isEmailVerified: map['isEmailVerified'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      isModerator: map['isModerator'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
      'favoriteSpots': favoriteSpots,
      'isEmailVerified': isEmailVerified,
      'isAdmin': isAdmin,
      'isModerator': isModerator,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoURL,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    List<String>? favoriteSpots,
    bool? isEmailVerified,
    bool? isAdmin,
    bool? isModerator,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      favoriteSpots: favoriteSpots ?? this.favoriteSpots,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isAdmin: isAdmin ?? this.isAdmin,
      isModerator: isModerator ?? this.isModerator,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, displayName: $displayName)';
  }
}
