import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class InstagramButton extends StatelessWidget {
  final String handle;
  final String? label;

  const InstagramButton({
    super.key,
    required this.handle,
    this.label,
  });

  Future<void> _launchInstagramProfile(String handle) async {
    // Remove @ symbol if present and clean the handle
    final cleanHandle = handle.replaceFirst('@', '');
    
    // Try Instagram app first, then fall back to web
    final instagramAppUrl = 'instagram://user?username=$cleanHandle';
    final instagramWebUrl = 'https://www.instagram.com/$cleanHandle/';
    
    final Uri appUri = Uri.parse(instagramAppUrl);
    final Uri webUri = Uri.parse(instagramWebUrl);
    
    if (await canLaunchUrl(appUri)) {
      // Try to launch Instagram app
      await launchUrl(appUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(webUri)) {
      // Fall back to web version
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? handle;
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _launchInstagramProfile(handle),
        icon: const FaIcon(
          FontAwesomeIcons.instagram,
          size: 18,
        ),
        label: Text(displayLabel),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE4405F), // Instagram brand color
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

