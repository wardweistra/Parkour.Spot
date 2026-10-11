import 'package:flutter/material.dart';

import '../utils/external_launch.dart';

class ReportIssueButton extends StatelessWidget {
  final String url;
  final String label;

  const ReportIssueButton({
    super.key,
    required this.url,
    this.label = 'Report an issue',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => launchExternalUri(context, Uri.parse(url)),
        icon: Icon(Icons.bug_report_outlined, size: 20, color: scheme.primary),
        label: Text(
          label,
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
