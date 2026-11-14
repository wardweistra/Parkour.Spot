/// Paths under `https://parkour.spot` that Hosting answers with something
/// other than the Flutter app: Firebase reserved URLs (`/__/auth/action` for
/// email verification and password reset), Cloud Function rewrites from
/// `firebase.json`, and static files.
///
/// The Android app is the verified App Links handler for the whole host, so
/// these URLs reach the app too. They must not be sent to the router.
bool isNonAppLinkPath(String path) {
  final p = path.toLowerCase();
  if (_exactPaths.contains(p)) return true;
  return _prefixes.any(p.startsWith);
}

const _exactPaths = {
  '/mcp',
  '/sitemap.xml',
  '/robots.txt',
  '/manifest.json',
  '/favicon.ico',
};

const _prefixes = [
  '/__/',
  '/api/',
  '/calendar/',
  '/mcp/',
  '/sitemaps/',
  '/.well-known/',
];
