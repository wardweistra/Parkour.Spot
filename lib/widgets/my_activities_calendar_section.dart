import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/mobile_detection_service.dart';
import '../services/user_calendar_feed_service.dart';

/// Shared calendar subscribe block for events, check-ins, and planned sessions.
class MyActivitiesCalendarSection extends StatefulWidget {
  const MyActivitiesCalendarSection({super.key});

  @override
  State<MyActivitiesCalendarSection> createState() =>
      _MyActivitiesCalendarSectionState();
}

class _MyActivitiesCalendarSectionState
    extends State<MyActivitiesCalendarSection> {
  bool _calendarBusy = false;
  final UserCalendarFeedService _calendarFeedService =
      UserCalendarFeedService();

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  void _showCalendarFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_l10n.myEventsCalendarFailed),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<String?> _feedUrlOrNull() async {
    try {
      return await _calendarFeedService.getOrCreateFeedUrl();
    } catch (e) {
      if (mounted) _showCalendarFailed();
      return null;
    }
  }

  Future<void> _copyCalendarLink() async {
    if (_calendarBusy) return;
    setState(() => _calendarBusy = true);
    try {
      final url = await _feedUrlOrNull();
      if (url == null || !mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.myEventsCalendarCopied)),
      );
    } finally {
      if (mounted) setState(() => _calendarBusy = false);
    }
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _showCalendarFailed();
    }
  }

  Future<void> _openMacCalendar() async {
    if (_calendarBusy) return;
    setState(() => _calendarBusy = true);
    try {
      final url = await _feedUrlOrNull();
      if (url == null || !mounted) return;
      await _launchExternal(UserCalendarFeedService.toWebcalUrl(url));
    } catch (e) {
      if (mounted) _showCalendarFailed();
    } finally {
      if (mounted) setState(() => _calendarBusy = false);
    }
  }

  Future<void> _openGoogleCalendar() async {
    if (_calendarBusy) return;
    setState(() => _calendarBusy = true);
    try {
      final url = await _feedUrlOrNull();
      if (url == null || !mounted) return;
      await _launchExternal(
        UserCalendarFeedService.toGoogleCalendarSubscribeUrl(url),
      );
    } catch (e) {
      if (mounted) _showCalendarFailed();
    } finally {
      if (mounted) setState(() => _calendarBusy = false);
    }
  }

  Future<void> _openOutlookCalendar() async {
    if (_calendarBusy) return;
    setState(() => _calendarBusy = true);
    try {
      final url = await _feedUrlOrNull();
      if (url == null || !mounted) return;
      await _launchExternal(
        UserCalendarFeedService.toOutlookCalendarSubscribeUrl(url),
      );
    } catch (e) {
      if (mounted) _showCalendarFailed();
    } finally {
      if (mounted) setState(() => _calendarBusy = false);
    }
  }

  Future<void> _confirmRegenerateCalendarLink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final scheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10n.myEventsCalendarRegenerateTitle),
          content: Text(
            l10n.myEventsCalendarRegenerateBody,
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
              child: Text(l10n.myEventsCalendarRegenerateConfirm),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    if (_calendarBusy) return;
    setState(() => _calendarBusy = true);
    try {
      final url = await _calendarFeedService.regenerateFeedUrl();
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.myEventsCalendarCopied)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.myEventsCalendarFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _calendarBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final preferMac = MobileDetectionService.supportsWebcalSubscribe;
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
    final actions = <({String label, VoidCallback? onPressed, bool primary})>[
      if (preferMac)
        (
          label: _l10n.myEventsCalendarOpenMac,
          onPressed: _calendarBusy ? null : _openMacCalendar,
          primary: true,
        ),
      (
        label: _l10n.myEventsCalendarOpenGoogle,
        onPressed: _calendarBusy ? null : _openGoogleCalendar,
        primary: !preferMac,
      ),
      (
        label: _l10n.myEventsCalendarOpenOutlook,
        onPressed: _calendarBusy ? null : _openOutlookCalendar,
        primary: false,
      ),
      (
        label: _l10n.myEventsCalendarCopyUrl,
        onPressed: _calendarBusy ? null : _copyCalendarLink,
        primary: false,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
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
                _l10n.myEventsCalendarTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _l10n.myEventsCalendarDescription,
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
                  for (final action in actions)
                    if (action.primary)
                      FilledButton(
                        style: primaryStyle,
                        onPressed: action.onPressed,
                        child: _calendarBusy
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : Text(action.label),
                      )
                    else
                      OutlinedButton(
                        style: actionStyle,
                        onPressed: action.onPressed,
                        child: Text(action.label),
                      ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _calendarBusy
                        ? null
                        : _confirmRegenerateCalendarLink,
                    child: Text(_l10n.myEventsCalendarRegenerate),
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
