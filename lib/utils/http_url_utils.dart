import 'package:validators/validators.dart' show isURL;

/// HTTP/HTTPS URL normalization and display helpers (no Flutter imports — safe for VM tests).

String _lowercaseHttpScheme(String url) {
  final idx = url.indexOf('://');
  if (idx <= 0) {
    return url;
  }
  final scheme = url.substring(0, idx).toLowerCase();
  if (scheme == 'http' || scheme == 'https') {
    return '$scheme://${url.substring(idx + 3)}';
  }
  return url;
}

/// True if [input] is a non-empty string that normalizes to an http(s) URL.
bool isValidHttpOrHttpsUrl(String input) {
  return normalizeHttpOrHttpsUrl(input) != null;
}

/// Normalizes user input to an `http` or `https` URL using the [validators]
/// package (validator.js-style `isURL`), then Dart [Uri] canonicalization.
String? normalizeHttpOrHttpsUrl(String input) {
  final raw = input.trim();
  if (raw.isEmpty) {
    return null;
  }
  final lower = raw.toLowerCase();
  final withScheme = lower.startsWith('http://') || lower.startsWith('https://')
      ? raw
      : 'https://$raw';
  final schemeFixed = _lowercaseHttpScheme(withScheme);
  // DNS hosts are case-insensitive; [validators] FQDN checks expect lower-case labels.
  final uri0 = Uri.tryParse(schemeFixed);
  final forValidation = (uri0 != null &&
          uri0.host.isNotEmpty &&
          (uri0.scheme == 'http' || uri0.scheme == 'https'))
      ? uri0.replace(host: uri0.host.toLowerCase()).toString()
      : schemeFixed;
  if (!isURL(
    forValidation,
    protocols: const ['http', 'https'],
    requireProtocol: true,
  )) {
    return null;
  }
  final uri = Uri.tryParse(forValidation);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty ||
      !uri.hasAuthority) {
    return null;
  }
  return uri.toString();
}

/// Host (and non-default port) suitable for UI, e.g. `example.com` or `[::1]:8080`.
String displayHttpUrlHost(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) {
    return url;
  }
  final host = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  if (uri.hasPort) {
    final defaultPort = uri.scheme == 'https' ? 443 : 80;
    if (uri.port != defaultPort) {
      return '$host:${uri.port}';
    }
  }
  return host;
}
