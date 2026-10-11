import 'package:flutter/material.dart';

import '../utils/external_launch.dart';

/// Primary theme-aligned control that opens the Parkour·Spot About site.
class AboutSiteButton extends StatelessWidget {
  final String url;
  final String label;

  const AboutSiteButton({
    super.key,
    required this.url,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: () => launchExternalUri(context, Uri.parse(url)),
        icon: Icon(Icons.open_in_new, size: 18, color: scheme.onPrimaryContainer),
        label: Text(
          label,
          softWrap: true,
          textAlign: TextAlign.center,
        ),
        style: FilledButton.styleFrom(
          foregroundColor: scheme.onPrimaryContainer,
          backgroundColor: scheme.primaryContainer,
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
