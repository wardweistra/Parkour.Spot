import '../l10n/app_localizations.dart';

/// Formats a calendar date into a localized relative day phrase.
///
/// Past examples: "today", "yesterday", "3 days ago", "1 month ago".
/// Future examples: "today", "tomorrow", "in 3 days", "in 1 month".
String formatRelativeDateInDays(
  DateTime date,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  // Use UTC civil dates to avoid DST offsets (23/25h days) affecting inDays.
  final today = DateTime.utc(reference.year, reference.month, reference.day);
  final dateOnly = DateTime.utc(date.year, date.month, date.day);
  final difference = today.difference(dateOnly).inDays;

  if (difference == 0) {
    return l10n.spotDetailDateToday;
  }
  if (difference > 0) {
    if (difference == 1) {
      return l10n.spotDetailDateYesterday;
    }
    if (difference < 7) {
      return l10n.spotDetailDateDaysAgo(difference);
    }
    if (difference < 30) {
      return l10n.spotDetailDateWeeksAgo((difference / 7).floor());
    }
    if (difference < 365) {
      return l10n.spotDetailDateMonthsAgo((difference / 30).floor());
    }
    return l10n.spotDetailDateYearsAgo((difference / 365).floor());
  }

  final daysAhead = -difference;
  if (daysAhead == 1) {
    return l10n.communityDateTomorrow;
  }
  if (daysAhead < 7) {
    return l10n.spotDetailDateInDays(daysAhead);
  }
  if (daysAhead < 30) {
    return l10n.spotDetailDateInWeeks((daysAhead / 7).floor());
  }
  if (daysAhead < 365) {
    return l10n.spotDetailDateInMonths((daysAhead / 30).floor());
  }
  return l10n.spotDetailDateInYears((daysAhead / 365).floor());
}
