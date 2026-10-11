import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'brand_mark_icon.dart';
import '../utils/external_launch.dart';

class InstagramButton extends StatelessWidget {
  final String handle;
  final String? label;

  /// When false, renders as an outlined theme button (for quieter stacks).
  /// Defaults to the Instagram brand fill used on profiles and source cards.
  final bool filled;

  const InstagramButton({
    super.key,
    required this.handle,
    this.label,
    this.filled = true,
  });

  static const Color _brandPink = Color(0xFFE4405F);

  Future<void> _launchInstagramProfile(
    BuildContext context,
    String handle,
  ) async {
    final cleanHandle = handle.replaceFirst('@', '');
    final appUri = Uri.parse('instagram://user?username=$cleanHandle');
    final webUri = Uri.parse('https://www.instagram.com/$cleanHandle/');

    try {
      if (await canLaunchUrl(appUri)) {
        final launched = await launchUrl(
          appUri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      }
    } catch (_) {
      // Fall through to web.
    }

    if (!context.mounted) return;
    await launchExternalUri(context, webUri);
  }

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? handle;
    final scheme = Theme.of(context).colorScheme;

    if (!filled) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _launchInstagramProfile(context, handle),
          icon: const BrandMarkIcon(
            asset: BrandMarkIcon.instagram,
            color: _brandPink,
          ),
          label: Text(
            displayLabel,
            softWrap: true,
            textAlign: TextAlign.center,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: scheme.primary,
            side: BorderSide(color: scheme.primary.withValues(alpha: 0.55)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _launchInstagramProfile(context, handle),
        icon: const BrandMarkIcon(asset: BrandMarkIcon.instagram),
        label: Text(
          displayLabel,
          softWrap: true,
          textAlign: TextAlign.center,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _brandPink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
