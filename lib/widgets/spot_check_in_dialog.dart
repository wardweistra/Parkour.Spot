import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/spot_check_in.dart';
import '../utils/check_in_time.dart';

/// Outcome of [showSpotCheckInDialog] (save, delete, or cancel via null).
sealed class SpotCheckInDialogOutcome {}

class SpotCheckInDialogSaved extends SpotCheckInDialogOutcome {
  SpotCheckInDialogSaved({
    required this.isPrivate,
    required this.expectedEndAt,
    this.comment,
  });
  final bool isPrivate;
  final DateTime expectedEndAt;
  final String? comment;
}

class SpotCheckInDialogDeleted extends SpotCheckInDialogOutcome {
  SpotCheckInDialogDeleted();
}

/// Check in at a spot, or edit / delete an existing check-in.
Future<SpotCheckInDialogOutcome?> showSpotCheckInDialog(
  BuildContext context, {
  SpotCheckIn? existingCheckIn,
}) {
  return showDialog<SpotCheckInDialogOutcome>(
    context: context,
    builder: (context) => SpotCheckInDialog(existingCheckIn: existingCheckIn),
  );
}

class SpotCheckInDialog extends StatefulWidget {
  const SpotCheckInDialog({super.key, this.existingCheckIn});

  /// When set, dialog is in edit mode with these values.
  final SpotCheckIn? existingCheckIn;

  @override
  State<SpotCheckInDialog> createState() => _SpotCheckInDialogState();
}

class _SpotCheckInDialogState extends State<SpotCheckInDialog> {
  /// When true, others can see this check-in on the spot (maps to `isPrivate: false`).
  late bool _sharePublicly;
  late final TextEditingController _commentController;
  late DateTime _expectedEndAt;

  static const Duration _quarterStep = Duration(minutes: 15);

  bool get _isEdit => widget.existingCheckIn != null;

  /// Session is over: show read-only details and delete only (no save).
  bool get _sessionEnded =>
      widget.existingCheckIn != null &&
      !widget.existingCheckIn!.isActiveAt(DateTime.now());

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCheckIn;
    if (existing != null) {
      _sharePublicly = !existing.isPrivate;
      _commentController = TextEditingController(text: existing.comment ?? '');
      _expectedEndAt = existing.expectedEndAt.toLocal();
    } else {
      _sharePublicly = true;
      _commentController = TextEditingController();
      _expectedEndAt = defaultExpectedEndAt(DateTime.now());
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete check-in?'),
        content: Text(
          'Remove this visit record from your history. This does not remove the spot from your “Been to” list.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(SpotCheckInDialogDeleted());
    }
  }

  void _nudgeEndByQuarter(int sign) {
    assert(sign == 1 || sign == -1);
    final now = DateTime.now();
    final maxEnd = now.add(SpotCheckIn.maxSessionDuration);
    final next = _expectedEndAt.add(Duration(minutes: 15 * sign));
    if (sign < 0) {
      if (!next.isAfter(now)) return;
    } else {
      if (next.isAfter(maxEnd)) return;
    }
    setState(() => _expectedEndAt = next);
  }

  bool _canSubtractQuarter(DateTime now) {
    return _expectedEndAt.subtract(_quarterStep).isAfter(now);
  }

  bool _canAddQuarter(DateTime maxEnd) {
    return !_expectedEndAt.add(_quarterStep).isAfter(maxEnd);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final maxEnd = now.add(SpotCheckIn.maxSessionDuration);
    final canSub = !_sessionEnded && _canSubtractQuarter(now);
    final canAdd = !_sessionEnded && _canAddQuarter(maxEnd);
    final untilStr = DateFormat(
      'MMM d, y • h:mm a',
    ).format(_expectedEndAt.toLocal());
    final cs = theme.colorScheme;
    final err = cs.error;

    return AlertDialog(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.place_outlined,
            color: cs.primary,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _sessionEnded
                  ? 'Check-in'
                  : (_isEdit ? 'Edit check-in' : 'Check in'),
              style: theme.textTheme.titleLarge,
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _sessionEnded
                  ? 'This session has ended. You can remove it from your history.'
                  : _isEdit
                      ? 'Update how long you’ll be here, visibility, or your note.'
                      : 'Log that you’re training now at this spot.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Share publicly'),
              subtitle: const Text(
                'Turn off to only log this for yourself.',
              ),
              value: _sharePublicly,
              onChanged: _sessionEnded
                  ? null
                  : (v) => setState(() => _sharePublicly = v),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: '15 minutes earlier',
                  onPressed: canSub ? () => _nudgeEndByQuarter(-1) : null,
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Here until',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          untilStr,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '15 minutes later',
                  onPressed: canAdd ? () => _nudgeEndByQuarter(1) : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              readOnly: _sessionEnded,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                hintText: 'e.g. what you plan to work on',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLength: SpotCheckIn.maxCommentLength,
              maxLines: 3,
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        Row(
          mainAxisAlignment: _isEdit
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.end,
          children: [
            if (_isEdit)
              TextButton(
                onPressed: _confirmDelete,
                style: TextButton.styleFrom(foregroundColor: err),
                child: const Text('Delete'),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_sessionEnded ? 'Close' : 'Cancel'),
                ),
                if (!_sessionEnded) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      final trimmed = _commentController.text.trim();
                      Navigator.of(context).pop(
                        SpotCheckInDialogSaved(
                          isPrivate: !_sharePublicly,
                          expectedEndAt: _expectedEndAt,
                          comment: trimmed.isEmpty ? null : trimmed,
                        ),
                      );
                    },
                    icon: Icon(
                      _isEdit ? Icons.save_outlined : Icons.place_outlined,
                    ),
                    label: Text(_isEdit ? 'Save' : 'Check in'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}
