import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../utils/external_launch.dart';

/// Shared memorial not-found body for missing spots, events, profiles, and lists.
///
/// Shows the Vauxhall Maze RIP shrine, an entity-specific title, shared lede,
/// primary recovery action, and a quiet contact link.
class EntityNotFoundView extends StatelessWidget {
  static const String _contactEmail = 'parkour.spot@wardweistra.nl';
  static const String _shrineAsset = 'assets/images/spots/vauxhall-maze.webp';

  /// Local shrine materials (match About 404 memorial; not general product chrome).
  static const Color _shrineTerracotta = Color(0xFF8F4F3A);
  static const Color _shrineMatte = Color(0xFFF3EEE6);
  static const Color _shrineInk = Color(0xFF2A2623);

  final String title;
  final String? subtitle;
  final String primaryActionLabel;
  final VoidCallback onPrimaryAction;

  const EntityNotFoundView({
    super.key,
    required this.title,
    this.subtitle,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.hasBoundedHeight
                  ? constraints.maxHeight - 32
                  : 0,
              maxWidth: 420,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Shrine(
                    l10n: l10n,
                    reduceMotion: reduceMotion,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '404',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: Color.lerp(
                        scheme.primary,
                        const Color(0xFF6E6A66),
                        0.22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    l10n.entityNotFoundLede,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: onPrimaryAction,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(primaryActionLabel),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        l10n.entityNotFoundContactPrefix,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () => launchExternalUri(
                          context,
                          Uri(
                            scheme: 'mailto',
                            path: _contactEmail,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(l10n.entityNotFoundContactLink),
                      ),
                      Text(
                        '.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Shrine extends StatelessWidget {
  final AppLocalizations l10n;
  final bool reduceMotion;

  const _Shrine({
    required this.l10n,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frame = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 14),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(
                    EntityNotFoundView._shrineMatte,
                    Colors.white,
                    0.08,
                  )!,
                  EntityNotFoundView._shrineMatte,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: EntityNotFoundView._shrineInk.withValues(alpha: 0.08),
                  offset: const Offset(0, 1),
                  blurRadius: 1,
                ),
                BoxShadow(
                  color: EntityNotFoundView._shrineInk.withValues(alpha: 0.16),
                  offset: const Offset(0, 18),
                  blurRadius: 40,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(1),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.asset(
                  EntityNotFoundView._shrineAsset,
                  fit: BoxFit.cover,
                  semanticLabel: l10n.entityNotFoundShrineAlt,
                ),
              ),
            ),
          ),
          Container(
            height: 2,
            width: double.infinity,
            color: EntityNotFoundView._shrineTerracotta.withValues(alpha: 0.35),
          ),
        ],
      ),
    );

    return Column(
      children: [
        Transform.rotate(
          angle: reduceMotion ? 0 : -0.024, // ~-1.4deg
          child: frame,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.entityNotFoundShrineRip,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: EntityNotFoundView._shrineTerracotta,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.entityNotFoundShrineName,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: EntityNotFoundView._shrineInk,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          l10n.entityNotFoundShrineMeta,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: EntityNotFoundView._shrineInk.withValues(alpha: 0.78),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
