import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parkour_spot/l10n/app_localizations.dart';
import 'package:parkour_spot/models/spot_check_in.dart';
import 'package:parkour_spot/models/spot_training_plan.dart';
import 'package:parkour_spot/utils/check_in_time.dart';
import 'package:parkour_spot/utils/spot_training_plan_validation.dart';

sealed class SpotTrainingPlanDialogOutcome {}

class SpotTrainingPlanDialogSaved extends SpotTrainingPlanDialogOutcome {
  SpotTrainingPlanDialogSaved({
    required this.isPrivate,
    required this.plannedStartAt,
    required this.plannedEndAt,
    this.comment,
  });

  final bool isPrivate;
  final DateTime plannedStartAt;
  final DateTime plannedEndAt;
  final String? comment;
}

class SpotTrainingPlanDialogDeleted extends SpotTrainingPlanDialogOutcome {
  SpotTrainingPlanDialogDeleted();
}

Future<SpotTrainingPlanDialogOutcome?> showSpotTrainingPlanDialog(
  BuildContext context, {
  SpotTrainingPlan? existingPlan,
}) {
  return showDialog<SpotTrainingPlanDialogOutcome>(
    context: context,
    builder: (context) => SpotTrainingPlanDialog(existingPlan: existingPlan),
  );
}

class SpotTrainingPlanDialog extends StatefulWidget {
  const SpotTrainingPlanDialog({super.key, this.existingPlan});

  final SpotTrainingPlan? existingPlan;

  @override
  State<SpotTrainingPlanDialog> createState() => _SpotTrainingPlanDialogState();
}

class _SpotTrainingPlanDialogState extends State<SpotTrainingPlanDialog> {
  static const Duration _quarterStep = Duration(minutes: 15);

  late bool _sharePublicly;
  late final TextEditingController _commentController;
  late DateTime _start;
  late DateTime _end;

  bool get _isEdit => widget.existingPlan != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingPlan;
    if (existing != null) {
      _sharePublicly = !existing.isPrivate;
      _commentController = TextEditingController(text: existing.comment ?? '');
      _start = existing.plannedStartAt.toLocal();
      _end = existing.plannedEndAt.toLocal();
    } else {
      _sharePublicly = true;
      _commentController = TextEditingController();
      final now = DateTime.now();
      _start = roundToNearest15Minutes(now.add(const Duration(hours: 1)));
      _end = roundToNearest15Minutes(_start.add(const Duration(hours: 2)));
      _reconcileBounds();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _reconcileBounds() {
    if (!_end.isAfter(_start)) {
      _end = roundToNearest15Minutes(_start.add(_quarterStep));
    }
    final minEnd = _start.add(SpotTrainingPlan.minWindowDuration);
    if (_end.isBefore(minEnd)) {
      _end = roundToNearest15Minutes(minEnd);
    }
    final maxEnd = _start.add(SpotCheckIn.maxSessionDuration);
    if (_end.isAfter(maxEnd)) {
      _end = roundToNearest15Minutes(maxEnd);
    }
    final now = DateTime.now();
    final latestStart = now.add(SpotTrainingPlan.maxAdvanceHorizon);
    if (_start.isAfter(latestStart)) {
      _start = roundToNearest15Minutes(latestStart);
      _reconcileBounds();
      return;
    }
  }

  String? _validationMessage(AppLocalizations l10n) {
    final code = SpotTrainingPlanValidation.validateWindow(
      plannedStartAt: _start,
      plannedEndAt: _end,
      now: DateTime.now(),
      requireEndInFuture: true,
    );
    if (code == null) return null;
    switch (code) {
      case 'order':
        return l10n.spotTrainingPlanValidationOrder;
      case 'minDuration':
        return l10n.spotTrainingPlanValidationMinDuration;
      case 'maxDuration':
        return l10n.spotTrainingPlanValidationMaxDuration;
      case 'startTooFar':
        return l10n.spotTrainingPlanValidationStartTooFar;
      case 'endNotFuture':
        return l10n.spotTrainingPlanValidationEndNotFuture;
      default:
        return l10n.spotTrainingPlanValidationInvalid;
    }
  }

  Future<void> _pickStart() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final last = now.add(SpotTrainingPlan.maxAdvanceHorizon);
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: first,
      lastDate: last,
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (!mounted) return;
    if (t == null) return;
    setState(() {
      _start = roundToNearest15Minutes(
        DateTime(d.year, d.month, d.day, t.hour, t.minute),
      );
      _reconcileBounds();
    });
  }

  Future<void> _pickEnd() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: DateTime(_start.year, _start.month, _start.day),
      lastDate: _start.add(
        SpotCheckIn.maxSessionDuration + const Duration(days: 1),
      ),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end),
    );
    if (!mounted) return;
    if (t == null) return;
    setState(() {
      _end = roundToNearest15Minutes(
        DateTime(d.year, d.month, d.day, t.hour, t.minute),
      );
      _reconcileBounds();
    });
  }

  void _nudgeStart(int sign) {
    assert(sign == 1 || sign == -1);
    final now = DateTime.now();
    final latest = now.add(SpotTrainingPlan.maxAdvanceHorizon);
    setState(() {
      final next = _start.add(Duration(minutes: 15 * sign));
      if (sign < 0) {
        if (next.isBefore(roundToNearest15Minutes(now))) return;
        _start = roundToNearest15Minutes(next);
      } else {
        final capped = next.isAfter(latest) ? latest : next;
        _start = roundToNearest15Minutes(capped);
      }
      _reconcileBounds();
    });
  }

  void _nudgeEnd(int sign) {
    assert(sign == 1 || sign == -1);
    setState(() {
      final next = _end.add(Duration(minutes: 15 * sign));
      final minEnd = _start.add(SpotTrainingPlan.minWindowDuration);
      final maxEnd = _start.add(SpotCheckIn.maxSessionDuration);
      if (sign < 0) {
        final floored = next.isBefore(minEnd) ? minEnd : next;
        _end = roundToNearest15Minutes(floored);
      } else {
        final capped = next.isAfter(maxEnd) ? maxEnd : next;
        _end = roundToNearest15Minutes(capped);
      }
      _reconcileBounds();
    });
  }

  Future<void> _confirmDelete(AppLocalizations l10n) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.spotTrainingPlanDialogDeleteTitle),
        content: Text(
          l10n.spotTrainingPlanDialogDeleteBody,
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.spotTrainingPlanDialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.spotTrainingPlanDialogDelete),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.of(context).pop(SpotTrainingPlanDialogDeleted());
    }
  }

  void _save() {
    final trimmed = _commentController.text.trim();
    Navigator.of(context).pop(
      SpotTrainingPlanDialogSaved(
        isPrivate: !_sharePublicly,
        plannedStartAt: _start,
        plannedEndAt: _end,
        comment: trimmed.isEmpty ? null : trimmed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final cs = theme.colorScheme;
    final fmt = DateFormat('MMM d, y • h:mm a');
    final err = _validationMessage(l10n);

    return AlertDialog(
      constraints: const BoxConstraints(maxWidth: 520),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.event_available_outlined, color: cs.primary, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isEdit
                  ? l10n.spotTrainingPlanDialogTitleEdit
                  : l10n.spotTrainingPlanDialogTitle,
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
              l10n.spotTrainingPlanDialogBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l10n.spotTrainingPlanDialogSharePublic),
              subtitle: Text(l10n.spotTrainingPlanDialogShareSub),
              value: _sharePublicly,
              onChanged: (v) => setState(() => _sharePublicly = v),
            ),
            const SizedBox(height: 20),
            _timeRow(
              theme: theme,
              cs: cs,
              label: l10n.spotTrainingPlanDialogStartLabel,
              valueStr: fmt.format(_start),
              onPick: _pickStart,
              onSub: () => _nudgeStart(-1),
              onAdd: () => _nudgeStart(1),
            ),
            const SizedBox(height: 20),
            _timeRow(
              theme: theme,
              cs: cs,
              label: l10n.spotTrainingPlanDialogEndLabel,
              valueStr: fmt.format(_end),
              onPick: _pickEnd,
              onSub: () => _nudgeEnd(-1),
              onAdd: () => _nudgeEnd(1),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _commentController,
              maxLength: SpotTrainingPlan.maxCommentLength,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.spotDetailSessionNoteLabel,
                hintText: l10n.spotDetailSessionNoteHint,
                border: const OutlineInputBorder(),
                counterText: '',
                isDense: true,
              ),
            ),
            if (err != null) ...[
              const SizedBox(height: 12),
              Text(
                err,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
              ),
            ],
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
                onPressed: () => _confirmDelete(l10n),
                style: TextButton.styleFrom(foregroundColor: cs.error),
                child: Text(l10n.spotTrainingPlanDialogDelete),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.spotTrainingPlanDialogCancel),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: err == null ? _save : null,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(l10n.spotTrainingPlanDialogSave),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Matches [SpotCheckInDialog] time nudge rows: tonal ± controls and centered label/value.
  Widget _timeRow({
    required ThemeData theme,
    required ColorScheme cs,
    required String label,
    required String valueStr,
    required VoidCallback onPick,
    required VoidCallback onSub,
    required VoidCallback onAdd,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton.filledTonal(
          tooltip: '15 minutes earlier',
          onPressed: onSub,
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
                InkWell(
                  onTap: onPick,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Text(
                      valueStr,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: '15 minutes later',
          onPressed: onAdd,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
