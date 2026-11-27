import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/year_review.dart';

/// Which card image to fetch or share.
enum YearReviewCardFormat { story, square }

/// Loads yearly reviews (`getYearReview`) and their card images
/// (`yearReviewCard`, served by Hosting at `/year/<year>/<user>/story.jpg`).
class YearReviewService {
  YearReviewService({FirebaseFunctions? functions, http.Client? client})
    : _functionsOverride = functions,
      _client = client ?? http.Client();

  final FirebaseFunctions? _functionsOverride;
  final http.Client _client;

  // Resolved on first use so the service can be constructed (and faked in
  // tests) before Firebase is initialised.
  FirebaseFunctions get _functions =>
      _functionsOverride ??
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  static const bool _useEmulator = bool.fromEnvironment('USE_EMULATOR');

  /// The review, or null when the profile is private or the year is empty.
  Future<YearReview?> getYearReview({
    required String userIdOrUsername,
    required int year,
  }) async {
    final result = await _functions.httpsCallable('getYearReview').call({
      'user': userIdOrUsername,
      'year': year,
    });
    final data = result.data;
    if (data is! Map || data['found'] != true || data['review'] is! Map) {
      return null;
    }
    return YearReview.fromMap(Map<String, dynamic>.from(data['review'] as Map));
  }

  /// Absolute URL of a card image.
  ///
  /// Production goes through Hosting (same origin on web, cached at the CDN);
  /// local emulator runs call the function directly.
  Uri cardUrl(YearReview review, YearReviewCardFormat format) =>
      cardUrlFor(year: review.year, handle: review.handle, format: format);

  /// Card URL from the page route alone (`@username` or uid), so the image
  /// can load while the review data is still on its way.
  Uri cardUrlFor({
    required int year,
    required String handle,
    required YearReviewCardFormat format,
  }) {
    if (_useEmulator) {
      return Uri.parse(
        'http://127.0.0.1:5001/${AppConfig.firebaseProjectId}/europe-west1/'
        'yearReviewCard',
      ).replace(
        queryParameters: {
          'user': handle.replaceFirst('@', ''),
          'year': '$year',
          'format': format.name,
        },
      );
    }
    // Handles are [A-Za-z0-9_.-] with an optional leading "@".
    return _origin().resolve('/year/$year/$handle/${format.name}.jpg');
  }

  /// Public URL of the review page, for sharing as a link.
  Uri pageUrl(YearReview review) => _origin().resolve(review.pagePath);

  /// Card image bytes, for sharing as a file.
  Future<Uint8List> fetchCard(
    YearReview review,
    YearReviewCardFormat format,
  ) async {
    final response = await _client.get(cardUrl(review, format));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Card request failed (${response.statusCode})',
      );
    }
    return response.bodyBytes;
  }

  /// File name for a downloaded or shared card.
  static String cardFileName(YearReview review, YearReviewCardFormat format) {
    final handle = (review.username ?? review.userId).replaceAll(
      RegExp(r'[^A-Za-z0-9_-]'),
      '',
    );
    return 'parkour-spot-${review.year}-$handle-${format.name}.jpg';
  }

  static Uri _origin() {
    if (kIsWeb && Uri.base.host.isNotEmpty && Uri.base.host != 'localhost') {
      return Uri(
        scheme: Uri.base.scheme,
        host: Uri.base.host,
        port: Uri.base.hasPort ? Uri.base.port : null,
      );
    }
    return Uri.parse('https://parkour.spot');
  }
}
