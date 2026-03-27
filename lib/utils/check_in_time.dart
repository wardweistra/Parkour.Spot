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
