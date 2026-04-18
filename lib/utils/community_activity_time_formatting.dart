import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';

/// Human-friendly calendar label: today / tomorrow / yesterday / weekday / date.
String communityFriendlyDayLabel(
  DateTime whenLocal,
  DateTime nowLocal,
  AppLocalizations l10n,
) {
  final w = DateTime(whenLocal.year, whenLocal.month, whenLocal.day);
  final n = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  final diff = w.difference(n).inDays;
  if (diff == 0) {
    return l10n.spotDetailDateToday;
  }
  if (diff == 1) {
    return l10n.communityDateTomorrow;
  }
  if (diff == -1) {
    return l10n.spotDetailDateYesterday;
  }
  if (diff.abs() <= 7) {
    return DateFormat.EEEE().format(whenLocal);
  }
  return DateFormat.yMMMd().format(whenLocal);
}

String _friendlyLocalTimeWithDay(
  DateTime whenUtc,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final ref = (now ?? DateTime.now()).toLocal();
  final t = whenUtc.toLocal();
  final day = communityFriendlyDayLabel(t, ref, l10n);
  final time = DateFormat.jm().format(t);
  return '$time $day';
}

/// End time for check-in tooltips and cards, e.g. "3:45 PM today" (after "until" in copy).
String communityFriendlyCheckInUntil(
  DateTime expectedEndAtUtc,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  return _friendlyLocalTimeWithDay(expectedEndAtUtc, l10n, now: now);
}

/// Planned training start for avatar tooltips only (full window stays on cards).
String communityFriendlyPlannedTrainingStart(
  DateTime plannedStartUtc,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  return _friendlyLocalTimeWithDay(plannedStartUtc, l10n, now: now);
}

/// Training window for tooltips and cards.
/// Same calendar day: "from 2:00 PM until 4:00 PM today".
/// Different days: "from 2:00 PM today until 4:00 PM tomorrow".
String communityFriendlyTrainingWindow(
  DateTime startUtc,
  DateTime endUtc,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final ref = (now ?? DateTime.now()).toLocal();
  final s = startUtc.toLocal();
  final e = endUtc.toLocal();
  final sDay = DateTime(s.year, s.month, s.day);
  final eDay = DateTime(e.year, e.month, e.day);
  final tf = DateFormat.jm();

  if (sDay == eDay) {
    final day = communityFriendlyDayLabel(s, ref, l10n);
    return l10n.communityActivityTrainSameDay(tf.format(s), tf.format(e), day);
  }
  final dayS = communityFriendlyDayLabel(s, ref, l10n);
  final dayE = communityFriendlyDayLabel(e, ref, l10n);
  return l10n.communityActivityTrainSpan(
    tf.format(s),
    dayS,
    tf.format(e),
    dayE,
  );
}
