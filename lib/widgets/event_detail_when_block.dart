import 'package:flutter/material.dart';

import '../constants/spot_detail_ui.dart';

/// Start / end schedule for an event detail page (no event icon — title owns that).
class EventDetailWhenBlock extends StatelessWidget {
  const EventDetailWhenBlock({
    super.key,
    required this.startAt,
    this.endAt,
    required this.whenLabel,
    required this.startsLabel,
    required this.endsLabel,
    required this.todayLabel,
  });

  final DateTime startAt;
  final DateTime? endAt;
  final String whenLabel;
  final String startsLabel;
  final String endsLabel;
  final String todayLabel;

  static bool _isSameCalendarDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  static bool _isToday(DateTime dateTime) {
    final local = dateTime.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  static ({String date, String time}) _parts(
    BuildContext context,
    DateTime dateTime,
  ) {
    final local = dateTime.toLocal();
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
    final sameDay = end != null && _isSameCalendarDay(startAt, end);
    final showToday = _isToday(startAt) || (end != null && _isToday(end));

    final semanticsLabel = end == null
        ? '${_parts(context, startAt).date}, ${_parts(context, startAt).time}'
        : sameDay
        ? '${_parts(context, startAt).date}, ${_parts(context, startAt).time} – ${_parts(context, end).time}'
        : '${_parts(context, startAt).date} ${_parts(context, startAt).time} – ${_parts(context, end).date} ${_parts(context, end).time}';

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              whenLabel,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: SpotDetailUi.detailLabelGap),
            end == null
                ? _SingleMoment(
                    context: context,
                    dateTime: startAt,
                    showToday: showToday,
                    todayLabel: todayLabel,
                  )
                : sameDay
                ? _SameDayRange(
                    context: context,
                    startAt: startAt,
                    endAt: end,
                    showToday: showToday,
                    todayLabel: todayLabel,
                  )
                : _MultiDayRange(
                    context: context,
                    startAt: startAt,
                    endAt: end,
                    startsLabel: startsLabel,
                    endsLabel: endsLabel,
                    showToday: showToday,
                    todayLabel: todayLabel,
                  ),
          ],
        ),
      ),
    );
  }
}

class _SingleMoment extends StatelessWidget {
  const _SingleMoment({
    required this.context,
    required this.dateTime,
    required this.showToday,
    required this.todayLabel,
  });

  final BuildContext context;
  final DateTime dateTime;
  final bool showToday;
  final String todayLabel;

  @override
  Widget build(BuildContext _) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final parts = EventDetailWhenBlock._parts(context, dateTime);

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
              const SizedBox(height: 2),
              Text(
                parts.time,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
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
    required this.showToday,
    required this.todayLabel,
  });

  final BuildContext context;
  final DateTime startAt;
  final DateTime endAt;
  final bool showToday;
  final String todayLabel;

  @override
  Widget build(BuildContext _) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dateParts = EventDetailWhenBlock._parts(context, startAt);
    final startTime = EventDetailWhenBlock._parts(context, startAt).time;
    final endTime = EventDetailWhenBlock._parts(context, endAt).time;

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
    required this.startsLabel,
    required this.endsLabel,
    required this.showToday,
    required this.todayLabel,
  });

  final BuildContext context;
  final DateTime startAt;
  final DateTime endAt;
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

    final blockHeight = _timelineMomentBlockHeight(context);
    final dotTopInset = _timelineDotTopInset(context);
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
                  ),
                  SizedBox(height: momentGap),
                  _TimelineMomentContent(
                    context: context,
                    label: endsLabel,
                    dateTime: endAt,
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
  });

  final BuildContext context;
  final String label;
  final DateTime dateTime;

  @override
  Widget build(BuildContext _) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final parts = EventDetailWhenBlock._parts(context, dateTime);

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
        const SizedBox(height: 2),
        Text(
          parts.time,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Height of one [_TimelineMomentContent] block (label + date + time).
double _timelineMomentBlockHeight(BuildContext context) {
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
  final timeHeight = _measureTextHeight('0:00', timeStyle, direction);
  return labelHeight + gap + dateHeight + timeHeight;
}

/// Vertical space occupied by [_TodayChip] plus the gap below it.
double _todayChipBlockHeight(BuildContext context) {
  const chipVerticalPadding = 3.0;
  const gapBelowChip = 6.0;
  final theme = Theme.of(context);
  final direction = Directionality.of(context);
  final chipStyle = theme.textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w700);
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
double _timelineDotTopInset(BuildContext context) {
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
  final dateRowHeight =
      _measureTextHeight('Sun', dateStyle, direction) +
      _measureTextHeight('0:00', timeStyle, direction);
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
