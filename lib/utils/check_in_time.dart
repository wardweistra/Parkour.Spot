/// Rounds [t] to the nearest 15-minute mark in local time (seconds and ms cleared).
DateTime roundToNearest15Minutes(DateTime t) {
  final l = t.toLocal();
  final startOfDay = DateTime(l.year, l.month, l.day);
  final ms = l.difference(startOfDay).inMilliseconds;
  const slotMs = 15 * 60 * 1000;
  final rounded = ((ms + slotMs ~/ 2) ~/ slotMs) * slotMs;
  return startOfDay.add(Duration(milliseconds: rounded));
}

/// Default expected end: one hour after [from], with minutes floored to 15-minute marks.
DateTime defaultExpectedEndAt(DateTime from) {
  final local = from.toLocal();
  final oneHourLater = local.add(const Duration(hours: 1));
  final flooredMinute = (oneHourLater.minute ~/ 15) * 15;
  return DateTime(
    oneHourLater.year,
    oneHourLater.month,
    oneHourLater.day,
    oneHourLater.hour,
    flooredMinute,
    0,
    0,
  );
}
