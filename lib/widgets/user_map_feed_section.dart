import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/user_map_feed_service.dart';

/// Subscribe-to-map block for My spots and My sessions.
class UserMapFeedSection extends StatefulWidget {
  const UserMapFeedSection({super.key});

  @override
  State<UserMapFeedSection> createState() => _UserMapFeedSectionState();
}

class _UserMapFeedSectionState extends State<UserMapFeedSection> {
  bool _busy = false;
  final UserMapFeedService _mapFeedService = UserMapFeedService();

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  void _showFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_l10n.myMapFeedFailed),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<String?> _feedUrlOrNull() async {
    try {
      return await _mapFeedService.getOrCreateFeedUrl();
    } catch (e) {
      if (mounted) _showFailed();
      return null;
    }
  }

  Future<void> _copyLink() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await _feedUrlOrNull();
      if (url == null || !mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.myMapFeedCopied)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _showFailed();
    }
  }

  Future<void> _openGoogleMyMaps() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await _feedUrlOrNull();
      if (url == null || !mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.myMapFeedCopiedForImport)),
      );
      await _launchExternal(UserMapFeedService.toGoogleMyMapsUrl());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRegenerateLink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10n.myMapFeedRegenerateTitle),
          content: Text(
            l10n.myMapFeedRegenerateBody,
            style: TextStyle(color: scheme.error),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.profileCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.myMapFeedRegenerateConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    if (_busy) return;
    setState(() => _busy = true);
    try {
      final url = await _mapFeedService.regenerateFeedUrl();
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.myMapFeedCopied)),
      );
    } catch (e) {
      if (!mounted) return;
      _showFailed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actionStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      visualDensity: VisualDensity.compact,
    );
    final primaryStyle = FilledButton.styleFrom(
      minimumSize: const Size(0, 40),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      visualDensity: VisualDensity.compact,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _l10n.myMapFeedTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _l10n.myMapFeedDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton(
                    style: primaryStyle,
                    onPressed: _busy ? null : _openGoogleMyMaps,
                    child: _busy
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : Text(_l10n.myMapFeedOpenGoogleMyMaps),
                  ),
                  OutlinedButton(
                    style: actionStyle,
                    onPressed: _busy ? null : _copyLink,
                    child: Text(_l10n.myMapFeedCopyUrl),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _confirmRegenerateLink,
                    child: Text(_l10n.myMapFeedRegenerate),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
