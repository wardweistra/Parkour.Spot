import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uni_links/uni_links.dart';

class DeepLinkService extends ChangeNotifier {
  String? _pendingSpotId;
  StreamSubscription? _linkSubscription;

  String? get pendingSpotId => _pendingSpotId;

  Future<void> initialize() async {
    try {
      final initialUri = await getInitialUri();
      _handleUri(initialUri);
    } on FormatException {
      // Ignore malformed initial URIs
    }

    _linkSubscription = uriLinkStream.listen(
      (Uri? uri) {
        _handleUri(uri);
      },
      onError: (Object error) {
        // Ignore stream errors but keep service alive
      },
    );
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;

    // Custom scheme: parkourspot://spot/<id>
    if (uri.scheme == 'parkourspot' && uri.host == 'spot' && uri.pathSegments.isNotEmpty) {
      _pendingSpotId = uri.pathSegments.first;
      notifyListeners();
      return;
    }

    // Optional App/Universal Link: https://parkourspot.app/spot/<id>
    if (uri.scheme == 'https' && uri.host == 'parkourspot.app') {
      final segments = uri.pathSegments;
      if (segments.length >= 2 && segments.first == 'spot') {
        _pendingSpotId = segments[1];
        notifyListeners();
        return;
      }
    }
  }

  String? consumePendingSpotId() {
    final id = _pendingSpotId;
    _pendingSpotId = null;
    return id;
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }
}