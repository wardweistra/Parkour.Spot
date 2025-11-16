import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class EmailButton extends StatelessWidget {
  final String email;
  final String? label;

  const EmailButton({
    super.key,
    required this.email,
    this.label,
  });

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? email;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _launchEmail(email),
        icon: const FaIcon(
          FontAwesomeIcons.envelope,
          size: 18,
        ),
        label: Text(displayLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4285F4), // Email/Gmail brand color
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

