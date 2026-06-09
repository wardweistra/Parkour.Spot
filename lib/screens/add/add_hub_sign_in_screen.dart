import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/spot_detail_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/custom_button.dart';
import 'add_hub_panels.dart';

class AddHubSignInScreen extends StatelessWidget {
  const AddHubSignInScreen({super.key});

  static const _redirectPath = '/explore?tab=add';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const SizedBox.shrink(),
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: scheme.surface,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: SpotDetailUi.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.all(SpotDetailUi.contentHorizontalPadding),
            children: [
              Text(
                l10n.addHubHeading,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.addHubSubtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 640;
                  return AddHubPanelLayout(
                    equalHeight: isWide,
                    spotPanel: AddHubSpotPanel(fillHeight: isWide),
                    eventPanel: AddHubEventPanel(fillHeight: isWide),
                  );
                },
              ),
              const SizedBox(height: 24),
              _SignInCallout(
                onSignIn: () => context.go(
                  '/login?redirectTo=${Uri.encodeComponent(_redirectPath)}',
                ),
                onCreateAccount: () => context.go(
                  '/login?mode=signup&redirectTo=${Uri.encodeComponent(_redirectPath)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInCallout extends StatelessWidget {
  const _SignInCallout({
    required this.onSignIn,
    required this.onCreateAccount,
  });

  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              l10n.addHubSignInTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.addHubSignInSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: CustomButton(
                  onPressed: onSignIn,
                  text: l10n.profileSignInButton,
                  width: double.infinity,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: scheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.profileOrDivider,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: scheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: CustomButton(
                  onPressed: onCreateAccount,
                  text: l10n.profileCreateAccount,
                  width: double.infinity,
                  isOutlined: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
