import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../utils/external_launch.dart';

class EmailButton extends StatelessWidget {
  final String email;
  final String? label;

  const EmailButton({
    super.key,
    required this.email,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayLabel = label ?? email;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () =>
            launchExternalUri(context, Uri.parse('mailto:$email')),
        icon: FaIcon(
          FontAwesomeIcons.envelope,
          size: 18,
          color: scheme.primary,
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
}
