import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/parkour_event.dart';
import '../services/auth_service.dart';
import '../services/event_report_service.dart';
import 'event_duplicate_picker.dart';

class EventDuplicateReportDialog extends StatefulWidget {
  const EventDuplicateReportDialog({super.key, required this.event});

  final ParkourEvent event;

  @override
  State<EventDuplicateReportDialog> createState() =>
      _EventDuplicateReportDialogState();
}

class _EventDuplicateReportDialogState extends State<EventDuplicateReportDialog> {
  late final TextEditingController _detailsController;
  late final TextEditingController _emailController;
  ParkourEvent? _selectedOriginal;
  String? _selectionError;
  String? _emailError;
  String? _submissionError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _detailsController = TextEditingController();
    _emailController = TextEditingController(
      text: auth.isAuthenticated
          ? (auth.userProfile?.email ?? auth.currentUser?.email ?? '')
          : '',
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final auth = context.read<AuthService>();
    final isLoggedIn = auth.isAuthenticated && auth.userProfile != null;
    final eventId = widget.event.id;
    final selected = _selectedOriginal;

    if (eventId == null || eventId.isEmpty) {
      setState(() => _submissionError = l10n.eventDetailUnableFlagDuplicate);
      return;
    }

    if (selected?.id == null || selected!.id!.isEmpty) {
      setState(() {
        _selectionError = l10n.eventDetailDuplicateReportSelectRequired;
        _submissionError = null;
      });
      return;
    }

    final trimmedEmail = _emailController.text.trim();
    if (!isLoggedIn) {
      if (trimmedEmail.isEmpty) {
        setState(() {
          _emailError = l10n.spotDetailEmailRequired;
          _submissionError = null;
        });
        return;
      }
      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!emailRegex.hasMatch(trimmedEmail)) {
        setState(() {
          _emailError = l10n.spotDetailEmailInvalid;
          _submissionError = null;
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _selectionError = null;
      _emailError = null;
      _submissionError = null;
    });

    final reporterName = (() {
      final profileName = auth.userProfile?.displayName;
      if (profileName != null && profileName.trim().isNotEmpty) {
        return profileName.trim();
      }
      final authName = auth.currentUser?.displayName;
      if (authName != null && authName.trim().isNotEmpty) {
        return authName.trim();
      }
      return null;
    })();

    final contactEmail = isLoggedIn
        ? (trimmedEmail.isNotEmpty
              ? trimmedEmail
              : auth.userProfile?.email ?? auth.currentUser?.email ?? '')
        : trimmedEmail;

    final success = await context.read<EventReportService>().submitEventDuplicateSuggestion(
      targetEventId: eventId,
      targetEventTitle: widget.event.title,
      startAt: widget.event.startAt,
      endAt: widget.event.endAt,
      isDateOnly: widget.event.isDateOnly,
      timeZone: widget.event.timeZone,
      description: widget.event.description,
      websiteUrl: widget.event.websiteUrl,
      latitude: widget.event.latitude,
      longitude: widget.event.longitude,
      address: widget.event.address,
      city: widget.event.city,
      countryCode: widget.event.countryCode,
      existingSpotIds: widget.event.spotIds,
      existingSpotListIds: widget.event.spotListIds,
      duplicateOfEventId: selected.id!,
      duplicateOfEventTitle: selected.title,
      details: _detailsController.text.trim().isEmpty
          ? null
          : _detailsController.text.trim(),
      reporterUserId: auth.currentUser?.uid,
      reporterName: reporterName,
      reporterEmail: contactEmail.isEmpty ? null : contactEmail,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _submissionError = l10n.spotDetailReportSendFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final auth = context.read<AuthService>();
    final isLoggedIn = auth.isAuthenticated && auth.userProfile != null;
    final eventId = widget.event.id;

    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(Icons.copy_all, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.eventDetailFlagDuplicateDialogTitle)),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.eventDetailFlagDuplicateIntro,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.eventDetailFlagDuplicateWhichQuestion,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (_selectionError != null) ...[
                  Text(
                    _selectionError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (eventId != null)
                  EventDuplicatePicker(
                    currentEventId: eventId,
                    referenceStartAt: widget.event.startAt,
                    referenceEndAt: widget.event.endAt,
                    nativeOnlyOriginals: false,
                    showNativeOnlyHint: false,
                    selectedEvent: _selectedOriginal,
                    onEventSelected: (event) {
                      setState(() {
                        _selectedOriginal = event;
                        _selectionError = null;
                      });
                    },
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _detailsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.spotDetailReportAdditionalDetails,
                    border: const OutlineInputBorder(),
                  ),
                  enabled: !_isSubmitting,
                ),
                if (!isLoggedIn) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.spotDetailReportEmailLabel,
                      border: const OutlineInputBorder(),
                      errorText: _emailError,
                    ),
                    enabled: !_isSubmitting,
                  ),
                ],
                if (_submissionError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _submissionError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.profileCancel),
          ),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : Text(l10n.spotDetailSubmitReport),
          ),
        ],
      ),
    );
  }
}
