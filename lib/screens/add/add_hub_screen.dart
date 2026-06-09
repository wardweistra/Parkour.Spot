import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../constants/spot_detail_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/custom_button.dart';

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
                  final spotPanel = _SpotPathPanel(
                    onPressed: () => context.push('/spots/add'),
                  );
                  final eventPanel = _EventPathPanel(
                    onPressed: () => context.push('/events/add'),
                  );

                  if (isWide) {
                    const gap = 16.0;
                    final columnWidth = (constraints.maxWidth - gap) / 2;
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: columnWidth,
                            child: _SpotPathPanel(
                              onPressed: () => context.push('/spots/add'),
                              fillHeight: true,
                            ),
                          ),
                          const SizedBox(width: gap),
                          SizedBox(
                            width: columnWidth,
                            child: _EventPathPanel(
                              onPressed: () => context.push('/events/add'),
                              fillHeight: true,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      spotPanel,
                      const SizedBox(height: 16),
                      eventPanel,
                    ],
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

class _SpotPathPanel extends StatelessWidget {
  const _SpotPathPanel({
    required this.onPressed,
    this.fillHeight = false,
  });

  final VoidCallback onPressed;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _ContributionPathPanel(
      fillHeight: fillHeight,
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.28),
      borderColor: scheme.primary.withValues(alpha: 0.22),
      leading: _PathLeadingIcon(
        icon: Icons.add_location_alt_outlined,
        backgroundColor: scheme.primary.withValues(alpha: 0.14),
        iconColor: scheme.primary,
      ),
      title: l10n.addHubSpotTitle,
      description: l10n.addHubSpotDescription,
      badge: _PathStatusBadge(
        icon: Icons.bolt_outlined,
        label: l10n.addHubSpotPublishBadge,
        foregroundColor: scheme.onPrimaryContainer,
        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.55),
        borderColor: scheme.primary.withValues(alpha: 0.2),
      ),
      buttonText: l10n.addHubSpotButton,
      buttonIcon: Icons.add_location_alt_outlined,
      onPressed: onPressed,
    );
  }
}

class _EventPathPanel extends StatelessWidget {
  const _EventPathPanel({
    required this.onPressed,
    this.fillHeight = false,
  });

  final VoidCallback onPressed;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _ContributionPathPanel(
      fillHeight: fillHeight,
      backgroundColor: scheme.surfaceContainerLow,
      borderColor: scheme.outlineVariant.withValues(alpha: 0.55),
      leading: _PathLeadingIcon(
        icon: Icons.event_available_outlined,
        backgroundColor: scheme.secondary.withValues(alpha: 0.12),
        iconColor: scheme.secondary,
      ),
      title: l10n.addHubEventTitle,
      description: l10n.addHubEventDescription,
      badge: _PathStatusBadge(
        icon: Icons.fact_check_outlined,
        label: l10n.addHubEventModerationBadge,
        foregroundColor: scheme.onSurfaceVariant,
        backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderColor: scheme.outline.withValues(alpha: 0.35),
      ),
      buttonText: l10n.addHubEventButton,
      buttonIcon: Icons.event_available_outlined,
      onPressed: onPressed,
      isOutlinedButton: true,
    );
  }
}

class _ContributionPathPanel extends StatelessWidget {
  const _ContributionPathPanel({
    required this.backgroundColor,
    required this.borderColor,
    required this.leading,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.buttonIcon,
    required this.onPressed,
    this.badge,
    this.isOutlinedButton = false,
    this.fillHeight = false,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Widget leading;
  final String title;
  final String description;
  final Widget? badge;
  final String buttonText;
  final IconData buttonIcon;
  final VoidCallback onPressed;
  final bool isOutlinedButton;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final descriptionStyle = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface.withValues(alpha: 0.82),
      height: 1.45,
    );

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(description, style: descriptionStyle),
            ],
          ),
        ),
      ],
    );

    final footer = <Widget>[
      if (badge != null) ...[
        badge!,
        const SizedBox(height: 14),
      ],
      CustomButton(
        onPressed: onPressed,
        text: buttonText,
        icon: buttonIcon,
        width: double.infinity,
        isOutlined: isOutlinedButton,
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (fillHeight)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: 24),
                    const Spacer(),
                  ],
                ),
              )
            else ...[
              header,
              const SizedBox(height: 24),
            ],
            ...footer,
          ],
        ),
      ),
    );
  }
}

class _PathLeadingIcon extends StatelessWidget {
  const _PathLeadingIcon({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: iconColor, size: 26),
    );
  }
}

class _PathStatusBadge extends StatelessWidget {
  const _PathStatusBadge({
    required this.icon,
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
