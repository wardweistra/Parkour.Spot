import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/spot_detail_ui.dart';
import '../../l10n/app_localizations.dart';
import 'add_hub_panels.dart';

class AddHubScreen extends StatelessWidget {
  const AddHubScreen({super.key});

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
                    spotPanel: AddHubSpotPanel(
                      fillHeight: isWide,
                      onPressed: () => context.push('/spots/add'),
                    ),
                    eventPanel: AddHubEventPanel(
                      fillHeight: isWide,
                      onPressed: () => context.push('/events/add'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
