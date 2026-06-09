import 'package:flutter/material.dart';

import '../../constants/spot_detail_ui.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/custom_button.dart';

/// Side-by-side or stacked layout for the spot and event contribution panels.
class AddHubPanelLayout extends StatelessWidget {
  const AddHubPanelLayout({
    super.key,
    required this.spotPanel,
    required this.eventPanel,
    this.equalHeight = false,
  });

  final Widget spotPanel;
  final Widget eventPanel;
  final bool equalHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 640;

        if (isWide && equalHeight) {
          const gap = 16.0;
          final columnWidth = (constraints.maxWidth - gap) / 2;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: columnWidth, child: spotPanel),
                const SizedBox(width: gap),
                SizedBox(width: columnWidth, child: eventPanel),
              ],
            ),
          );
        }

        if (isWide) {
          const gap = 16.0;
          final columnWidth = (constraints.maxWidth - gap) / 2;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: columnWidth, child: spotPanel),
              const SizedBox(width: gap),
              SizedBox(width: columnWidth, child: eventPanel),
            ],
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
    );
  }
}

class AddHubSpotPanel extends StatelessWidget {
  const AddHubSpotPanel({
    super.key,
    this.onPressed,
    this.fillHeight = false,
  });

  final VoidCallback? onPressed;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return AddHubContributionPanel(
      fillHeight: fillHeight,
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.28),
      borderColor: scheme.primary.withValues(alpha: 0.22),
      leading: AddHubPathLeadingIcon(
        icon: Icons.add_location_alt_outlined,
        backgroundColor: scheme.primary.withValues(alpha: 0.14),
        iconColor: scheme.primary,
      ),
      title: l10n.addHubSpotTitle,
      description: l10n.addHubSpotDescription,
      badge: AddHubPathStatusBadge(
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

class AddHubEventPanel extends StatelessWidget {
  const AddHubEventPanel({
    super.key,
    this.onPressed,
    this.fillHeight = false,
  });

  final VoidCallback? onPressed;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return AddHubContributionPanel(
      fillHeight: fillHeight,
      backgroundColor: scheme.surfaceContainerLow,
      borderColor: scheme.outlineVariant.withValues(alpha: 0.55),
      leading: AddHubPathLeadingIcon(
        icon: Icons.event_available_outlined,
        backgroundColor: scheme.secondary.withValues(alpha: 0.12),
        iconColor: scheme.secondary,
      ),
      title: l10n.addHubEventTitle,
      description: l10n.addHubEventDescription,
      badge: AddHubPathStatusBadge(
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

class AddHubContributionPanel extends StatelessWidget {
  const AddHubContributionPanel({
    super.key,
    required this.backgroundColor,
    required this.borderColor,
    required this.leading,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.buttonIcon,
    this.onPressed,
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
  final VoidCallback? onPressed;
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
      if (badge != null) badge!,
      if (onPressed != null) ...[
        if (badge != null) const SizedBox(height: 14),
        CustomButton(
          onPressed: onPressed,
          text: buttonText,
          icon: buttonIcon,
          width: double.infinity,
          isOutlined: isOutlinedButton,
        ),
      ],
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
              if (footer.isNotEmpty) const SizedBox(height: 24),
            ],
            ...footer,
          ],
        ),
      ),
    );
  }
}

class AddHubPathLeadingIcon extends StatelessWidget {
  const AddHubPathLeadingIcon({
    super.key,
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

class AddHubPathStatusBadge extends StatelessWidget {
  const AddHubPathStatusBadge({
    super.key,
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
