import 'browser_network_probes_stub.dart'
    if (dart.library.js_interop) 'browser_network_probes_web.dart' as impl;

/// Plain `fetch` (no-cors) to [url], bypassing the Firebase SDKs. Returns a
/// short description of the response; throws when the request fails.
Future<String> browserProbeFetch(String url) => impl.probeFetch(url);

/// Opens a scratch IndexedDB database and writes one value. Returns a short
/// description; throws when IndexedDB fails. Never settles when IndexedDB is
/// wedged, so callers must apply a timeout.
Future<String> browserProbeIndexedDb() => impl.probeIndexedDb();
