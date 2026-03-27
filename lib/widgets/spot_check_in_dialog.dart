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
    this.checkedInAt,
  });
  final bool isPrivate;
  final DateTime expectedEndAt;
  final String? comment;

  /// Set when editing an existing check-in (start / arrived time).
  final DateTime? checkedInAt;
}

class SpotCheckInDialogDeleted extends SpotCheckInDialogOutcome {
  SpotCheckInDialogDeleted();
}

/// User chose to extend a recently expired check-in at this spot instead of creating new.
class SpotCheckInDialogExtendInstead extends SpotCheckInDialogOutcome {
  SpotCheckInDialogExtendInstead(this.checkIn);
  final SpotCheckIn checkIn;
}

/// Check in at a spot, or edit / delete an existing check-in.
Future<SpotCheckInDialogOutcome?> showSpotCheckInDialog(
  BuildContext context, {
  SpotCheckIn? existingCheckIn,
  /// When true, show “Still here” (prefill end = now + 1h). Set from
  /// [SpotCheckInService.stillHereEligibleForUser] so it’s only true for the user’s
  /// latest check-in within the time window.
  bool stillHereEligible = false,
  /// Active check-ins at other spots (new check-in only); shown as a notice before saving.
  List<SpotCheckIn> activeElsewhere = const [],
  /// New check-in only: recent session at this spot that can be extended instead of duplicating.
  SpotCheckIn? extendableAtSameSpot,
}) {
  return showDialog<SpotCheckInDialogOutcome>(
    context: context,
    builder: (context) => SpotCheckInDialog(
      existingCheckIn: existingCheckIn,
      stillHereEligible: stillHereEligible,
      activeElsewhere: activeElsewhere,
      extendableAtSameSpot: extendableAtSameSpot,
    ),
  );
}

class SpotCheckInDialog extends StatefulWidget {
  const SpotCheckInDialog({
    super.key,
    this.existingCheckIn,
    this.stillHereEligible = false,
    this.activeElsewhere = const [],
    this.extendableAtSameSpot,
  });

  /// When set, dialog is in edit mode with these values.
  final SpotCheckIn? existingCheckIn;

  /// Show “Still here” when time window + latest-check-in rules pass (see [SpotCheckInService.stillHereEligibleForUser]).
  final bool stillHereEligible;

  /// Non-empty when opening a new check-in while already active elsewhere.
  final List<SpotCheckIn> activeElsewhere;

  /// New check-in only: extend this session instead of creating a duplicate document.
  final SpotCheckIn? extendableAtSameSpot;

  @override
  State<SpotCheckInDialog> createState() => _SpotCheckInDialogState();
}

class _SpotCheckInDialogState extends State<SpotCheckInDialog> {
  /// When true, others can see this check-in on the spot (maps to `isPrivate: false`).
  late bool _sharePublicly;
  late final TextEditingController _commentController;
  late DateTime _expectedEndAt;
  late DateTime _checkedInAt;

  static const Duration _quarterStep = Duration(minutes: 15);

  bool get _isEdit => widget.existingCheckIn != null;

  String _activeElsewhereNotice() {
    final others = widget.activeElsewhere;
    if (others.isEmpty) return '';
    if (others.length == 1) {
      final name = others.single.spotName?.trim();
      if (name != null && name.isNotEmpty) {
        return 'You’re currently checked in at $name. Checking in here will end that check-in.';
      }
      return 'You’re checked in at another spot. Checking in here will end that check-in.';
    }
    return 'You have active check-ins at other spots. Checking in here will end those check-ins.';
  }

  /// Currently within [checkedInAt, expectedEndAt] (same rule as [SpotCheckIn.isActiveAt]).
  bool get _isActiveCheckIn =>
      widget.existingCheckIn != null &&
      widget.existingCheckIn!.isActiveAt(DateTime.now());

  @override
  void initState() {
    super.initState();
    final existing = widget.existingCheckIn;
    if (existing != null) {
      _sharePublicly = !existing.isPrivate;
      _commentController = TextEditingController(text: existing.comment ?? '');
      _checkedInAt = existing.checkedInAt.toLocal();
      _expectedEndAt = existing.expectedEndAt.toLocal();
      _reconcileEditSessionBounds();
    } else {
      _sharePublicly = true;
      _commentController = TextEditingController();
      _expectedEndAt = defaultExpectedEndAt(DateTime.now());
      _checkedInAt = DateTime.now(); // only used when [_isEdit] is true
    }
  }

  /// Keep end after start and within max duration (edit mode).
  void _reconcileEditSessionBounds() {
    if (!_checkedInAt.isBefore(_expectedEndAt)) {
      _expectedEndAt = roundToNearest15Minutes(
        _checkedInAt.add(_quarterStep),
      );
      return;
    }
    if (_expectedEndAt.difference(_checkedInAt) > SpotCheckIn.maxSessionDuration) {
      _expectedEndAt = _checkedInAt.add(SpotCheckIn.maxSessionDuration);
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

  void _popSaved({DateTime? expectedEndAt}) {
    final end = expectedEndAt ?? _expectedEndAt;
    final trimmed = _commentController.text.trim();
    Navigator.of(context).pop(
      SpotCheckInDialogSaved(
        isPrivate: !_sharePublicly,
        expectedEndAt: end,
        comment: trimmed.isEmpty ? null : trimmed,
        checkedInAt: _isEdit ? _checkedInAt : null,
      ),
    );
  }

  /// End time = now + 1h with same default as a fresh check-in; user taps Save when ready.
  void _stillHere() {
    setState(() {
      _expectedEndAt = defaultExpectedEndAt(DateTime.now());
      _reconcileEditSessionBounds();
    });
  }

  /// Sets end to now (or just after start if the clock is behind) and saves.
  void _endNowAndSave() {
    final now = DateTime.now();
    final end =
        now.isAfter(_checkedInAt) ? now : _checkedInAt.add(const Duration(seconds: 1));
    _popSaved(expectedEndAt: end);
  }

  void _nudgeStartByQuarter(int sign) {
    assert(sign == 1 || sign == -1);
    final next = _checkedInAt.add(Duration(minutes: 15 * sign));
    if (sign < 0) {
      if (!_canSubtractStartForNext(next)) return;
    }
    setState(() {
      if (sign > 0) {
        final maxStart = _expectedEndAt.subtract(_quarterStep);
        _checkedInAt = roundToNearest15Minutes(
          next.isAfter(maxStart) ? maxStart : next,
        );
      } else {
        _checkedInAt = roundToNearest15Minutes(next);
        if (!_expectedEndAt.isAfter(_checkedInAt)) {
          _expectedEndAt = roundToNearest15Minutes(
            _checkedInAt.add(_quarterStep),
          );
        }
      }
    });
  }

  /// True if moving start to [next] (earlier than now) keeps session length ≤ 12h.
  bool _canSubtractStartForNext(DateTime next) {
    if (!next.isBefore(_expectedEndAt)) return false;
    return _expectedEndAt.difference(next) <= SpotCheckIn.maxSessionDuration;
  }

  bool _canSubtractStart() {
    final next = _checkedInAt.subtract(_quarterStep);
    return _canSubtractStartForNext(next);
  }

  void _nudgeEndByQuarter(int sign) {
    assert(sign == 1 || sign == -1);
    if (!_isEdit) {
      _nudgeEndByQuarterForNew(sign);
      return;
    }
    final next = _expectedEndAt.add(Duration(minutes: 15 * sign));
    final maxEnd = _checkedInAt.add(SpotCheckIn.maxSessionDuration);
    setState(() {
      if (sign > 0) {
        _expectedEndAt = roundToNearest15Minutes(
          next.isAfter(maxEnd) ? maxEnd : next,
        );
      } else {
        final minEnd = _checkedInAt.add(_quarterStep);
        _expectedEndAt = roundToNearest15Minutes(
          next.isBefore(minEnd) ? minEnd : next,
        );
      }
    });
  }

  void _nudgeEndByQuarterForNew(int sign) {
    assert(sign == 1 || sign == -1);
    final now = DateTime.now();
    final maxEnd = now.add(SpotCheckIn.maxSessionDuration);
    final next = _expectedEndAt.add(Duration(minutes: 15 * sign));
    if (sign < 0) {
      if (!next.isAfter(now)) return;
    } else {
      if (next.isAfter(maxEnd)) return;
    }
    setState(() => _expectedEndAt = roundToNearest15Minutes(next));
  }

  bool _canAddStart() {
    final limit = _expectedEndAt.subtract(_quarterStep);
    return _checkedInAt.add(_quarterStep).compareTo(limit) <= 0;
  }

  bool _canSubtractEnd() {
    return _expectedEndAt.subtract(_quarterStep).isAfter(_checkedInAt);
  }

  bool _canAddEnd() {
    return !_expectedEndAt
        .add(_quarterStep)
        .isAfter(_checkedInAt.add(SpotCheckIn.maxSessionDuration));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final canSubStart = _isEdit && _canSubtractStart();
    final canAddStart = _isEdit && _canAddStart();
    final canSubEnd = _isEdit ? _canSubtractEnd() : _canSubtractEndForNew(now);
    final canAddEnd = _isEdit ? _canAddEnd() : _canAddEndForNew(now);

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
              _isEdit ? 'Edit check-in' : 'Check in',
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
              _isEdit
                  ? 'Adjust when you arrived, when you left or plan to leave, visibility, and your note.'
                  : 'Log that you’re training now at this spot.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            if (!_isEdit && widget.extendableAtSameSpot != null) ...[
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.history_outlined,
                        size: 22,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'You have a recently expired check-in here.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface,
                                height: 1.35,
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => Navigator.of(context).pop(
                                  SpotCheckInDialogExtendInstead(
                                    widget.extendableAtSameSpot!,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.only(top: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Extend that check-in instead'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (!_isEdit && widget.activeElsewhere.isNotEmpty) ...[
              const SizedBox(height: 16),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.swap_horiz_outlined,
                        size: 22,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _activeElsewhereNotice(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Share publicly'),
              subtitle: const Text(
                'Turn off to only log this for yourself.',
              ),
              value: _sharePublicly,
              onChanged: (v) => setState(() => _sharePublicly = v),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 20),
              _timeNudgeRow(
                theme: theme,
                cs: cs,
                label: 'Arrived',
                valueStr: DateFormat(
                  'MMM d, y • h:mm a',
                ).format(_checkedInAt.toLocal()),
                canSub: canSubStart,
                canAdd: canAddStart,
                onSub: () => _nudgeStartByQuarter(-1),
                onAdd: () => _nudgeStartByQuarter(1),
              ),
            ],
            const SizedBox(height: 20),
            _timeNudgeRow(
              theme: theme,
              cs: cs,
              label: _isEdit ? 'Until' : 'Here until',
              valueStr: untilStr,
              canSub: canSubEnd,
              canAdd: canAddEnd,
              onSub: () => _nudgeEndByQuarter(-1),
              onAdd: () => _nudgeEndByQuarter(1),
            ),
            if (_isEdit && (widget.stillHereEligible || _isActiveCheckIn)) ...[
              const SizedBox(height: 16),
              if (widget.stillHereEligible) ...[
                OutlinedButton.icon(
                  onPressed: _stillHere,
                  icon: const Icon(Icons.schedule_outlined),
                  label: const Text('Still here'),
                ),
                if (_isActiveCheckIn) const SizedBox(height: 8),
              ],
              if (_isActiveCheckIn)
                OutlinedButton.icon(
                  onPressed: _endNowAndSave,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End now'),
                ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
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
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _popSaved,
                  icon: Icon(
                    _isEdit ? Icons.save_outlined : Icons.place_outlined,
                  ),
                  label: Text(_isEdit ? 'Save' : 'Check in'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// New check-in: end must stay after "now" and within 12h (same as before).
  bool _canSubtractEndForNew(DateTime now) {
    return _expectedEndAt.subtract(_quarterStep).isAfter(now);
  }

  bool _canAddEndForNew(DateTime now) {
    final maxEnd = now.add(SpotCheckIn.maxSessionDuration);
    return !_expectedEndAt.add(_quarterStep).isAfter(maxEnd);
  }

  Widget _timeNudgeRow({
    required ThemeData theme,
    required ColorScheme cs,
    required String label,
    required String valueStr,
    required bool canSub,
    required bool canAdd,
    required VoidCallback onSub,
    required VoidCallback onAdd,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          tooltip: '15 minutes earlier',
          onPressed: canSub ? onSub : null,
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
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  valueStr,
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
          onPressed: canAdd ? onAdd : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
