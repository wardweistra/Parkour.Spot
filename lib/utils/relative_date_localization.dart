import '../l10n/app_localizations.dart';

/// Formats a calendar date into a localized relative day phrase.
///
/// Examples: "today", "yesterday", "3 days ago", "1 month ago".
String formatRelativeDateInDays(
  DateTime date,
  AppLocalizations l10n, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final dateOnly = DateTime(date.year, date.month, date.day);
  final difference = today.difference(dateOnly).inDays;

  if (difference <= 0) {
    return l10n.spotDetailDateToday;
  } else if (difference == 1) {
    return l10n.spotDetailDateYesterday;
  } else if (difference < 7) {
    return l10n.spotDetailDateDaysAgo(difference);
  } else if (difference < 30) {
    final weeks = (difference / 7).floor();
    return l10n.spotDetailDateWeeksAgo(weeks);
  } else if (difference < 365) {
    final months = (difference / 30).floor();
    return l10n.spotDetailDateMonthsAgo(months);
  } else {
    final years = (difference / 365).floor();
    return l10n.spotDetailDateYearsAgo(years);
  }
}
