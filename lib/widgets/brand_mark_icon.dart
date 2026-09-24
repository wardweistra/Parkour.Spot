import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Monochrome brand mark loaded from an SVG asset.
///
/// Font Awesome 11 brand glyphs (FontAwesomeBrands) fail to render on
/// Flutter web/WASM — they show as a missing-glyph box. Solid/regular FA
/// icons still work; keep those on FaIcon.
class BrandMarkIcon extends StatelessWidget {
  const BrandMarkIcon({
    super.key,
    required this.asset,
    this.size = 18,
    this.color,
  });

  static const instagram = 'assets/images/brands/instagram.svg';
  static const github = 'assets/images/brands/github.svg';
  static const youtube = 'assets/images/brands/youtube.svg';

  final String asset;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? IconTheme.of(context).color ?? Colors.white;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }
}
