import 'package:flutter/material.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/services/pwa_install_service.dart';
import 'package:parkour_spot/services/mobile_detection_service.dart';
import 'package:parkour_spot/widgets/custom_button.dart';

/// A widget that shows a PWA install prompt banner
/// 
/// This widget automatically detects if installation is available and shows
/// an appropriate prompt. It respects user dismissal and only shows after
/// the user has engaged with the app.
class PwaInstallPrompt extends StatefulWidget {
  /// Whether to show as a banner (true) or dialog (false)
  final bool showAsBanner;
  
  const PwaInstallPrompt({
    super.key,
    this.showAsBanner = true,
  });

  @override
  State<PwaInstallPrompt> createState() => _PwaInstallPromptState();
}

class _PwaInstallPromptState extends State<PwaInstallPrompt> {
  final _pwaService = PwaInstallService();

  @override
  void initState() {
    super.initState();
    _pwaService.initialize();
    _pwaService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    _pwaService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleInstall() {
    // Always show instructions dialog for both iOS and Android
    _showInstallInstructions();
  }

  void _showInstallInstructions() {
    final l10n = AppLocalizations.of(context)!;
    final isIos = MobileDetectionService.isIOS;
    final deviceLabel =
        isIos ? l10n.profileInstallDeviceIphone : l10n.profileInstallDeviceAndroid;
    final step1 = isIos ? l10n.profileInstallIosStep1 : l10n.profileInstallAndroidStep1;
    final step2 = isIos ? l10n.profileInstallIosStep2 : l10n.profileInstallAndroidStep2;
    final step3 = isIos ? l10n.profileInstallIosStep3 : l10n.profileInstallAndroidStep3;
    final step4 = isIos ? l10n.profileInstallIosStep4 : l10n.profileInstallAndroidStep4;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.get_app, color: Theme.of(dialogContext).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.profileInstallDialogTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileInstallIntro(deviceLabel),
              style: Theme.of(dialogContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildInstructionStep(dialogContext, '1', step1),
            const SizedBox(height: 12),
            _buildInstructionStep(dialogContext, '2', step2),
            const SizedBox(height: 12),
            _buildInstructionStep(dialogContext, '3', step3),
            const SizedBox(height: 12),
            _buildInstructionStep(dialogContext, '4', step4),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.profileInstallGotIt),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(BuildContext context, String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Future<void> _handleDismiss() async {
    await _pwaService.dismissPrompt();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show if all conditions are met
    if (!_pwaService.shouldShowPrompt) {
      return const SizedBox.shrink();
    }

    if (widget.showAsBanner) {
      return _buildBanner();
    } else {
      return _buildDialog();
    }
  }

  Widget _buildBanner() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(
              Icons.get_app,
              color: theme.colorScheme.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.profileInstallDialogTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.profileInstallBannerSubtitle,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CustomButton(
              onPressed: _handleInstall,
              text: l10n.explorePwaBannerInstall,
              height: 36,
              width: 90,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: _handleDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialog() {
    // This would show as a dialog - you can implement this if needed
    // For now, we'll just return the banner
    return _buildBanner();
  }
}
