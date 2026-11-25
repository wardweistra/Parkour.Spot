/// One person's yearly review, from the `getYearReview` callable
/// (`functions/lib/year-review-request.js`).
class YearReview {
  const YearReview({
    required this.userId,
    required this.year,
    required this.name,
    required this.sentence,
    required this.soFar,
    required this.frames,
    required this.moreCount,
    required this.pagePath,
    required this.storyPath,
    required this.squarePath,
    this.username,
  });

  final String userId;
  final String? username;
  final String name;
  final int year;

  /// The card's sentence in the owner's language (describes the card image).
  final String sentence;

  /// True until the year is over: numbers still change.
  final bool soFar;

  /// Spots shown on the card, most meaningful first.
  final List<YearReviewFrame> frames;

  /// Spots with photos beyond [frames].
  final int moreCount;

  final String pagePath;
  final String storyPath;
  final String squarePath;

  /// `@username`, or the uid for people without a username.
  String get handle =>
      username != null && username!.isNotEmpty ? '@$username' : userId;

  static YearReview? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    final userId = map['userId'];
    final year = map['year'];
    final storyPath = map['storyPath'];
    final squarePath = map['squarePath'];
    final pagePath = map['pagePath'];
    if (userId is! String ||
        year is! num ||
        storyPath is! String ||
        squarePath is! String ||
        pagePath is! String) {
      return null;
    }
    final rawFrames = map['frames'];
    return YearReview(
      userId: userId,
      username: map['username'] is String ? map['username'] as String : null,
      name: map['name'] is String ? map['name'] as String : '',
      year: year.toInt(),
      sentence: map['sentence'] is String ? map['sentence'] as String : '',
      soFar: map['soFar'] == true,
      frames: rawFrames is List
          ? rawFrames
                .whereType<Map>()
                .map(
                  (f) => YearReviewFrame.fromMap(Map<String, dynamic>.from(f)),
                )
                .whereType<YearReviewFrame>()
                .toList()
          : const [],
      moreCount: map['moreCount'] is num
          ? (map['moreCount'] as num).toInt()
          : 0,
      pagePath: pagePath,
      storyPath: storyPath,
      squarePath: squarePath,
    );
  }
}

/// Why a spot is on someone's yearly review.
enum YearReviewFrameKind {
  spotAdded,
  photosAdded,
  spotImproved,
  checkIn,
  rated,
}

class YearReviewFrame {
  const YearReviewFrame({
    required this.spotId,
    required this.kind,
    required this.name,
    this.city,
    this.imageUrl,
    this.date,
  });

  final String spotId;
  final YearReviewFrameKind kind;
  final String name;
  final String? city;
  final String? imageUrl;
  final DateTime? date;

  static YearReviewFrame? fromMap(Map<String, dynamic> map) {
    final spotId = map['spotId'];
    final kind = _parseKind(map['kind']);
    if (spotId is! String || spotId.isEmpty || kind == null) return null;
    String? text(String key) {
      final value = map[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final rawDate = text('date');
    return YearReviewFrame(
      spotId: spotId,
      kind: kind,
      name: text('name') ?? '',
      city: text('city'),
      imageUrl: text('imageUrl'),
      date: rawDate == null ? null : DateTime.tryParse(rawDate),
    );
  }

  static YearReviewFrameKind? _parseKind(Object? raw) {
    switch (raw) {
      case 'spotsAdded':
        return YearReviewFrameKind.spotAdded;
      case 'photosAdded':
        return YearReviewFrameKind.photosAdded;
      case 'spotsImproved':
        return YearReviewFrameKind.spotImproved;
      case 'checkIns':
        return YearReviewFrameKind.checkIn;
      case 'ratings':
        return YearReviewFrameKind.rated;
      default:
        return null;
    }
  }
}
