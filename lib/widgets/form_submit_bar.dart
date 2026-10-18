import 'package:flutter/material.dart';

import 'custom_button.dart';
import 'image_processing_banner.dart';

/// Submit control that keeps busy status next to the button the user just tapped.
class FormSubmitBar extends StatelessWidget {
  const FormSubmitBar({
    super.key,
    required this.onPressed,
    required this.idleText,
    required this.loadingText,
    this.isLoading = false,
    this.blockReason,
    this.icon,
  });

  final VoidCallback? onPressed;
  final String idleText;
  final String loadingText;
  final bool isLoading;
  final String? blockReason;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isLoading) ...[
          ImageProcessingBanner(message: loadingText, showSpinner: false),
          const SizedBox(height: 12),
        ] else if (blockReason != null) ...[
          Text(
            blockReason!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
        ],
        CustomButton(
          onPressed: onPressed,
          text: isLoading ? loadingText : idleText,
          isLoading: isLoading,
          icon: icon,
          width: double.infinity,
        ),
      ],
    );
  }
}
