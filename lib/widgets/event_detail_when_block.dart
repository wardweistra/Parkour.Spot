import 'package:flutter/material.dart';

import '../constants/spot_detail_ui.dart';
import '../utils/event_schedule_utils.dart';

/// Start / end schedule for an event detail page (no event icon — title owns that).
class EventDetailWhenBlock extends StatelessWidget {
  const EventDetailWhenBlock({
    super.key,
    required this.startAt,
    this.endAt,
    this.isDateOnly = false,
    this.timeZone,
    required this.startsLabel,
    required this.endsLabel,
    required this.todayLabel,
  });

  final DateTime startAt;
  final DateTime? endAt;
  final bool isDateOnly;
  final String? timeZone;
  final String startsLabel;
  final String endsLabel;
  final String todayLabel;

  static bool _isSameCalendarDay(DateTime a, DateTime b, {String? timeZone}) {
    return EventScheduleUtils.isSameCalendarDay(a, b, timeZone: timeZone);
  }

  static bool _isToday(DateTime dateTime, {String? timeZone}) {
    final local = EventScheduleUtils.toDisplayDateTime(
      dateTime,
      timeZone: timeZone,
    );
    final now = EventScheduleUtils.toDisplayDateTime(
      DateTime.now().toUtc(),
      timeZone: timeZone,
    );
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  static ({String date, String time}) _parts(
    BuildContext context,
    DateTime dateTime, {
    String? timeZone,
  }) {
    final local = EventScheduleUtils.toDisplayDateTime(
      dateTime,
      timeZone: timeZone,
    );
    final material = MaterialLocalizations.of(context);
    return (
      date: material.formatFullDate(local),
      time: material.formatTimeOfDay(TimeOfDay.fromDateTime(local)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final end = endAt;
    final sameDay =
        end != null && _isSameCalendarDay(startAt, end, timeZone: timeZone);
    final showToday =
        _isToday(startAt, timeZone: timeZone) ||
        (end != null && _isToday(end, timeZone: timeZone));

    final semanticsLabel = end == null
        ? isDateOnly
              ? _parts(context, startAt, timeZone: timeZone).date
              : '${_parts(context, startAt, timeZone: timeZone).date}, ${_parts(context, startAt, timeZone: timeZone).time}'
        : sameDay
        ? isDateOnly
              ? _parts(context, startAt, timeZone: timeZone).date
              : '${_parts(context, startAt, timeZone: timeZone).date}, ${_parts(context, startAt, timeZone: timeZone).time} – ${_parts(context, end, timeZone: timeZone).time}'
        : isDateOnly
        ? '${_parts(context, startAt, timeZone: timeZone).date} – ${_parts(context, end, timeZone: timeZone).date}'
        : '${_parts(context, startAt, timeZone: timeZone).date} ${_parts(context, startAt, timeZone: timeZone).time} – ${_parts(context, end, timeZone: timeZone).date} ${_parts(context, end, timeZone: timeZone).time}';

    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Container(
        width: double.infinity,
        padding: SpotDetailUi.detailCardPadding,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(SpotDetailUi.surfaceRadius),
          border: SpotDetailUi.outlineBorder(colors),
        ),
        child: end == null
            ? _SingleMoment(
                context: context,
                dateTime: startAt,
                isDateOnly: isDateOnly,
                timeZone: timeZone,
                showToday: showToday,
                todayLabel: todayLabel,
              )
            : sameDay
            ? _SameDayRange(
                context: context,
                startAt: startAt,
                endAt: end,
                isDateOnly: isDateOnly,
                timeZone: timeZone,
                showToday: showToday,
                todayLabel: todayLabel,
              )
            : _MultiDayRange(
                context: context,
                startAt: startAt,
                endAt: end,
                isDateOnly: isDateOnly,
                timeZone: timeZone,
                startsLabel: startsLabel,
                endsLabel: endsLabel,
                showToday: showToday,
                todayLabel: todayLabel,
              ),
      ),
    );
  }
}

class _SingleMoment extends StatelessWidget {
  const _SingleMoment({
    required this.context,
    required this.dateTime,
    required this.isDateOnly,
    required this.timeZone,
    required this.showToday,
    required this.todayLabel,
  });

  final BuildContext context;
  final DateTime dateTime;
  final bool isDateOnly;
  final String? timeZone;
  final bool showToday;
  final String todayLabel;

  @override
  Widget build(BuildContext _) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final parts = EventDetailWhenBlock._parts(
      context,
      dateTime,
      timeZone: timeZone,
    );

    final dotTop = _timelinePrimaryDateDotTopInset(
      context,
      prefixHeight: showToday ? _todayChipBlockHeight(context) : 0,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: dotTop),
          child: _TimelineDot(filled: true, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showToday) ...[
                _TodayChip(label: todayLabel),
                const SizedBox(height: 6),
              ],
              Text(
                parts.date,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              if (!isDateOnly) ...[
                const SizedBox(height: 2),
                Text(
                  parts.time,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SameDayRange extends StatelessWidget {
  const _SameDayRange({
    required this.context,
    required this.startAt,
    required this.endAt,
    required this.isDateOnly,
    required this.timeZone,
    required this.showToday,
    required this.todayLabel,
  });

  final BuildContext context;
  final DateTime startAt;
  final DateTime endAt;
  final bool isDateOnly;
  final String? timeZone;
  final bool showToday;
  final String todayLabel;

  @override
  Widget build(BuildContext _) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateParts = EventDetailWhenBlock._parts(
      context,
      startAt,
      timeZone: timeZone,
    );
    final startTime = EventDetailWhenBlock._parts(
      context,
      startAt,
      timeZone: timeZone,
    ).time;
    final endTime = EventDetailWhenBlock._parts(
      context,
      endAt,
      timeZone: timeZone,
    ).time;

    final dotTop = _timelinePrimaryDateDotTopInset(
      context,
      prefixHeight: showToday ? _todayChipBlockHeight(context) : 0,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: dotTop),
          child: _TimelineDot(filled: true, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showToday) ...[
                _TodayChip(label: todayLabel),
                const SizedBox(height: 6),
              ],
              Text(
                dateParts.date,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              if (!isDateOnly) ...[
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(text: startTime),
                      TextSpan(
                        text: ' – ',
                        style: TextStyle(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      TextSpan(text: endTime),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MultiDayRange extends StatelessWidget {
  const _MultiDayRange({
    required this.context,
    required this.startAt,
    required this.endAt,
    required this.isDateOnly,
    required this.timeZone,
    required this.startsLabel,
    required this.endsLabel,
    required this.showToday,
    required this.todayLabel,
  });

  final BuildContext context;
  final DateTime startAt;
  final DateTime endAt;
  final bool isDateOnly;
  final String? timeZone;
  final String startsLabel;
  final String endsLabel;
  final bool showToday;
  final String todayLabel;

  @override
  Widget build(BuildContext _) {
    final colors = Theme.of(context).colorScheme;
    const dotSize = _TimelineDot.size;
    const lineWidth = 2.0;
    const lineLeft = (dotSize - lineWidth) / 2;

    final blockHeight = _timelineMomentBlockHeight(
      context,
      showTime: !isDateOnly,
    );
    final dotTopInset = _timelineDotTopInset(context, showTime: !isDateOnly);
    final momentGap = SpotDetailUi.timelineMomentGap;
    final railHeight = 2 * blockHeight + momentGap;
    final lineTop = dotTopInset + dotSize;
    final lineHeight = blockHeight + momentGap - dotSize;
    final endDotTop = blockHeight + momentGap + dotTopInset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showToday) ...[
          _TodayChip(label: todayLabel),
          const SizedBox(height: 8),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: dotSize,
              height: railHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: lineLeft,
                    top: lineTop,
                    width: lineWidth,
                    height: lineHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.outline.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Positioned(
                    top: dotTopInset,
                    child: _TimelineDot(filled: true, color: colors.primary),
                  ),
                  Positioned(
                    top: endDotTop,
                    child: _TimelineDot(filled: false, color: colors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TimelineMomentContent(
                    context: context,
                    label: startsLabel,
                    dateTime: startAt,
                    showTime: !isDateOnly,
                    timeZone: timeZone,
                  ),
                  SizedBox(height: momentGap),
                  _TimelineMomentContent(
                    context: context,
                    label: endsLabel,
                    dateTime: endAt,
                    showTime: !isDateOnly,
                    timeZone: timeZone,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Label + date/time without a timeline dot (used beside the multi-day rail).
class _TimelineMomentContent extends StatelessWidget {
  const _TimelineMomentContent({
    required this.context,
    required this.label,
    required this.dateTime,
    required this.showTime,
    required this.timeZone,
  });

  final BuildContext context;
  final String label;
  final DateTime dateTime;
  final bool showTime;
  final String? timeZone;

  @override
  Widget build(BuildContext _) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final parts = EventDetailWhenBlock._parts(
      context,
      dateTime,
      timeZone: timeZone,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          parts.date,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        if (showTime) ...[
          const SizedBox(height: 2),
          Text(
            parts.time,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// Height of one [_TimelineMomentContent] block (label + date + time).
double _timelineMomentBlockHeight(
  BuildContext context, {
  required bool showTime,
}) {
  final theme = Theme.of(context);
  final direction = Directionality.of(context);
  final labelStyle = theme.textTheme.labelSmall!.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
  final dateStyle = theme.textTheme.titleSmall!.copyWith(
    fontWeight: FontWeight.w600,
    height: 1.25,
  );
  final timeStyle = theme.textTheme.bodyMedium!;

  final labelHeight = _measureTextHeight('STARTS', labelStyle, direction);
  const gap = 4.0;
  final dateHeight = _measureTextHeight('Sun', dateStyle, direction);
  if (!showTime) {
    return labelHeight + gap + dateHeight;
  }
  final timeHeight = _measureTextHeight('0:00', timeStyle, direction);
  return labelHeight + gap + dateHeight + timeHeight;
}

/// Vertical space occupied by [_TodayChip] plus the gap below it.
double _todayChipBlockHeight(BuildContext context) {
  const chipVerticalPadding = 3.0;
  const gapBelowChip = 6.0;
  final theme = Theme.of(context);
  final direction = Directionality.of(context);
  final chipStyle = theme.textTheme.labelSmall!.copyWith(
    fontWeight: FontWeight.w700,
  );
  final chipTextHeight = _measureTextHeight('Today', chipStyle, direction);
  return chipTextHeight + chipVerticalPadding * 2 + gapBelowChip;
}

/// Dot offset for date-first layouts (single moment, same-day range).
double _timelinePrimaryDateDotTopInset(
  BuildContext context, {
  double prefixHeight = 0,
}) {
  final theme = Theme.of(context);
  final dateStyle = theme.textTheme.titleMedium!.copyWith(
    fontWeight: FontWeight.w600,
    height: 1.25,
  );
  final direction = Directionality.of(context);
  final dateHeight = _measureTextHeight('Sun', dateStyle, direction);
  const dotSize = _TimelineDot.size;
  return prefixHeight + (dateHeight - dotSize) / 2;
}

/// Offset from the top of a [_TimelineMomentContent] to the top of its dot.
double _timelineDotTopInset(BuildContext context, {required bool showTime}) {
  final theme = Theme.of(context);
  final labelStyle = theme.textTheme.labelSmall!.copyWith(
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
  );
  final dateStyle = theme.textTheme.titleSmall!.copyWith(
    fontWeight: FontWeight.w600,
    height: 1.25,
  );
  final timeStyle = theme.textTheme.bodyMedium!;

  final direction = Directionality.of(context);
  final labelHeight = _measureTextHeight('STARTS', labelStyle, direction);
  const gap = 4.0;
  final dateRowHeight = showTime
      ? _measureTextHeight('Sun', dateStyle, direction) +
            _measureTextHeight('0:00', timeStyle, direction)
      : _measureTextHeight('Sun', dateStyle, direction);
  const dotSize = _TimelineDot.size;
  return labelHeight + gap + (dateRowHeight - dotSize) / 2;
}

double _measureTextHeight(
  String text,
  TextStyle style,
  TextDirection direction,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    maxLines: 1,
  )..layout();
  return painter.height;
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({required this.filled, required this.color});

  final bool filled;
  final Color color;

  static const double size = 10;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : null,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class _TodayChip extends StatelessWidget {
  const _TodayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
