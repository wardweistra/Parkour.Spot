import 'package:cloud_firestore/cloud_firestore.dart';

/// One public recent trainer on [SpotTrainingStats.recentPeople].
class SpotRecentTrainer {
  const SpotRecentTrainer({
    required this.userId,
    required this.lastCheckedInAt,
    this.displayName,
    this.photoURL,
  });

  final String userId;
  final DateTime lastCheckedInAt;
  final String? displayName;
  final String? photoURL;

  factory SpotRecentTrainer.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return SpotRecentTrainer(
        userId: '',
        lastCheckedInAt: DateTime.fromMillisecondsSinceEpoch(0),
      );
    }
    final userId = (data['userId'] as String?)?.trim() ?? '';
    return SpotRecentTrainer(
      userId: userId,
      displayName: _trimmed(data['displayName']),
      photoURL: _trimmed(data['photoURL']),
      lastCheckedInAt: _parseDate(data['lastCheckedInAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String? _trimmed(Object? value) {
    if (value is! String) return null;
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  static DateTime? _parseDate(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Public 90-day check-in volume + recent public trainers for a spot
/// (`spotTrainingStats/{spotId}`).
class SpotTrainingStats {
  const SpotTrainingStats({
    this.checkInCount = 0,
    this.peopleCount = 0,
    this.windowDays = 90,
    this.recentPeople = const [],
  });

  static const SpotTrainingStats empty = SpotTrainingStats();

  /// All check-ins in the window (public + private).
  final int checkInCount;

  /// Unique users in the window (public + private).
  final int peopleCount;

  final int windowDays;

  /// Public trainers only, most recent first (capped server-side).
  final List<SpotRecentTrainer> recentPeople;

  bool get hasVolume => checkInCount > 0 && peopleCount > 0;

  bool get hasRecentPeople => recentPeople.isNotEmpty;

  factory SpotTrainingStats.fromMap(Map<String, dynamic>? data) {
    if (data == null) return SpotTrainingStats.empty;
    final rawPeople = data['recentPeople'];
    final people = <SpotRecentTrainer>[];
    if (rawPeople is List) {
      for (final item in rawPeople) {
        if (item is Map<String, dynamic>) {
          final person = SpotRecentTrainer.fromMap(item);
          if (person.userId.isNotEmpty) people.add(person);
        } else if (item is Map) {
          final person = SpotRecentTrainer.fromMap(
            Map<String, dynamic>.from(item),
          );
          if (person.userId.isNotEmpty) people.add(person);
        }
      }
    }
    return SpotTrainingStats(
      checkInCount: _nonNegativeInt(data['checkInCount']),
      peopleCount: _nonNegativeInt(data['peopleCount']),
      windowDays: _positiveInt(data['windowDays'], fallback: 90),
      recentPeople: people,
    );
  }

  factory SpotTrainingStats.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (!doc.exists) return SpotTrainingStats.empty;
    return SpotTrainingStats.fromMap(doc.data());
  }

  static int _nonNegativeInt(Object? value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is num) {
      final asInt = value.toInt();
      return asInt < 0 ? 0 : asInt;
    }
    return 0;
  }

  static int _positiveInt(Object? value, {required int fallback}) {
    final n = _nonNegativeInt(value);
    return n > 0 ? n : fallback;
  }
}
