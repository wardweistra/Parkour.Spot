import 'path_url_strategy_stub.dart'
    if (dart.library.js_interop) 'path_url_strategy_web.dart' as impl;

/// Enables path-based URLs on web; no-op on native.
void configurePathUrlStrategy() => impl.configurePathUrlStrategy();
