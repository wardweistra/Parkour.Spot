import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/material.dart';

/// Compact country flag for cards and location rows.
///
/// Loads a Flagcdn PNG for the ISO 3166-1 alpha-2 code. SVG flags from
/// `country_flags` paint with `jovial_svg` [CustomPaint] paths, which trip a
/// Flutter 3.47 Skwasm crash when many flags appear or scroll
/// (https://github.com/flutter/flutter/issues/191976). Unicode regional-
/// indicator emoji also fail on Windows (Segoe UI Emoji has no flag glyphs).
class CountryFlagBadge extends StatelessWidget {
  const CountryFlagBadge({
    super.key,
    required this.countryCode,
    this.height = 20,
    this.width = 30,
  });

  final String countryCode;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final cc = isoAlpha2CountryCode(countryCode);
    if (cc == null) {
      return SizedBox(height: height, width: width);
    }
    final pixelWidth = MediaQuery.devicePixelRatioOf(context) >= 2 ? 80 : 40;
    final url = 'https://flagcdn.com/w$pixelWidth/$cc.png';
    return SizedBox(
      height: height,
      width: width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          imageRenderMethodForWeb: ImageRenderMethodForWeb.HttpGet,
          placeholder: (context, url) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          errorWidget: (context, url, error) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  cc.toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lowercase ISO 3166-1 alpha-2 code, or null if invalid.
///
/// Subdivision suffixes after a hyphen are ignored (`GB-ENG` → `gb`).
@visibleForTesting
String? isoAlpha2CountryCode(String countryCode) {
  final base = countryCode.trim().toUpperCase().split('-').first;
  if (base.length != 2) {
    return null;
  }
  final first = base.codeUnitAt(0);
  final second = base.codeUnitAt(1);
  const asciiA = 0x41;
  const asciiZ = 0x5A;
  if (first < asciiA || first > asciiZ || second < asciiA || second > asciiZ) {
    return null;
  }
  return base.toLowerCase();
}

/// Flagcdn PNG URL for [countryCode], or null if the code is invalid.
@visibleForTesting
String? flagCdnPngUrl(String countryCode) {
  final cc = isoAlpha2CountryCode(countryCode);
  if (cc == null) {
    return null;
  }
  return 'https://flagcdn.com/w40/$cc.png';
}
