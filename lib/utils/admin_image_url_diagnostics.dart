import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'image_url_utils.dart';

/// Firebase Storage error when a resized object does not exist.
const storageObjectNotFoundCode = 'object-not-found';

/// Per-image diagnostics for admin image URL overview.
class AdminImageUrlDiagnostic {
  const AdminImageUrlDiagnostic({
    required this.index,
    required this.originalUrl,
    required this.spotsApiUrl,
    this.pathInfo,
    this.expected1200x1200Url,
    this.expected1200x630Url,
    this.exists1200x1200 = false,
    this.exists1200x630 = false,
    this.actualResizedDownloadUrl,
    this.firstExistingResizedPath,
  });

  final int index;
  final String originalUrl;
  final String spotsApiUrl;
  final ResizedPathInfo? pathInfo;
  final String? expected1200x1200Url;
  final String? expected1200x630Url;
  final bool exists1200x1200;
  final bool exists1200x630;
  final String? actualResizedDownloadUrl;
  final String? firstExistingResizedPath;

  bool get isResizable => pathInfo != null;

  /// Builds URL fields without storage I/O (for tests and sync preview).
  static AdminImageUrlDiagnostic fromUrl({
    required int index,
    required String originalUrl,
  }) {
    final pathInfo = getResizedPathInfo(originalUrl);
    return AdminImageUrlDiagnostic(
      index: index,
      originalUrl: originalUrl,
      spotsApiUrl: getResizedImageUrlForApi(originalUrl),
      pathInfo: pathInfo,
      expected1200x1200Url: getExpectedResizedImageUrl(originalUrl, '1200x1200'),
      expected1200x630Url: getExpectedResizedImageUrl(originalUrl, '1200x630'),
    );
  }
}

/// Checks whether a storage object exists at [path].
Future<bool> storageObjectExistsAtPath(
  FirebaseStorage storage,
  String path,
) async {
  try {
    await storage.ref().child(path).getMetadata();
    return true;
  } on FirebaseException catch (e) {
    if (e.code != storageObjectNotFoundCode) {
      debugPrint('Storage error checking $path: ${e.code}');
    }
    return false;
  }
}

/// Returns download URL for the first existing path in [paths], or null.
Future<String?> downloadUrlForFirstExistingPath(
  FirebaseStorage storage,
  List<String> paths,
) async {
  for (final path in paths) {
    if (!await storageObjectExistsAtPath(storage, path)) continue;
    try {
      return await storage.ref().child(path).getDownloadURL();
    } on FirebaseException catch (e) {
      debugPrint('Storage getDownloadURL failed for $path: ${e.code}');
    }
  }
  return null;
}

/// Loads diagnostics for each Firestore [imageUrls] entry, including storage checks.
Future<List<AdminImageUrlDiagnostic>> loadAdminImageUrlDiagnostics(
  List<String> imageUrls, {
  FirebaseStorage? storage,
}) async {
  final resolvedStorage = storage ?? FirebaseStorage.instance;
  final results = <AdminImageUrlDiagnostic>[];

  for (var i = 0; i < imageUrls.length; i++) {
    final originalUrl = imageUrls[i].trim();
    if (originalUrl.isEmpty) continue;

    final base = AdminImageUrlDiagnostic.fromUrl(
      index: i + 1,
      originalUrl: originalUrl,
    );
    final info = base.pathInfo;

    var exists1200x1200 = false;
    var exists1200x630 = false;
    String? actualDownloadUrl;
    String? firstExistingPath;

    if (info != null) {
      for (final candidatePath in info.resizedPathCandidates) {
        final exists = await storageObjectExistsAtPath(
          resolvedStorage,
          candidatePath,
        );
        if (exists) {
          firstExistingPath ??= candidatePath;
          if (candidatePath.endsWith('_1200x1200.webp')) {
            exists1200x1200 = true;
          } else if (candidatePath.endsWith('_1200x630.webp')) {
            exists1200x630 = true;
          }
        }
        await Future<void>.delayed(Duration.zero);
      }

      if (firstExistingPath != null) {
        actualDownloadUrl = await downloadUrlForFirstExistingPath(
          resolvedStorage,
          info.resizedPathCandidates,
        );
      }
    }

    results.add(
      AdminImageUrlDiagnostic(
        index: base.index,
        originalUrl: base.originalUrl,
        spotsApiUrl: base.spotsApiUrl,
        pathInfo: base.pathInfo,
        expected1200x1200Url: base.expected1200x1200Url,
        expected1200x630Url: base.expected1200x630Url,
        exists1200x1200: exists1200x1200,
        exists1200x630: exists1200x630,
        actualResizedDownloadUrl: actualDownloadUrl,
        firstExistingResizedPath: firstExistingPath,
      ),
    );

    await Future<void>.delayed(Duration.zero);
  }

  return results;
}
