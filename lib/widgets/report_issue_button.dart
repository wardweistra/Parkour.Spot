import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ReportIssueButton extends StatelessWidget {
  final String url;
  final String label;

  const ReportIssueButton({
    super.key,
    required this.url,
    this.label = 'Report an issue',
  });

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _launchUrl(url),
        icon: const FaIcon(
          FontAwesomeIcons.bug,
          size: 18,
        ),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF24292e), // GitHub brand color
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

