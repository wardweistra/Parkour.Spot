import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class EventScheduleUtils {
  static bool _initialized = false;
  static List<String>? _cachedTimeZoneIds;

  static void ensureTimeZonesInitialized() {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _initialized = true;
  }

  static List<String> availableTimeZoneIds() {
    ensureTimeZonesInitialized();
    final cached = _cachedTimeZoneIds;
    if (cached != null) return cached;
    final zones = tz.timeZoneDatabase.locations.keys.toList()..sort();
    _cachedTimeZoneIds = zones;
    return zones;
  }

  static String? normalizeTimeZone(String? rawValue) {
    final trimmed = rawValue?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    ensureTimeZonesInitialized();
    if (!tz.timeZoneDatabase.locations.containsKey(trimmed)) return null;
    return trimmed;
  }

  static DateTime toDisplayDateTime(DateTime utcInstant, {String? timeZone}) {
    final normalized = normalizeTimeZone(timeZone);
    if (normalized == null) {
      return utcInstant.toLocal();
    }
    final location = tz.getLocation(normalized);
    return tz.TZDateTime.from(utcInstant.toUtc(), location);
  }

  static DateTime localDateTimeToUtc(
    DateTime localDateTime, {
    String? timeZone,
  }) {
    final normalized = normalizeTimeZone(timeZone);
    if (normalized == null) {
      return DateTime(
        localDateTime.year,
        localDateTime.month,
        localDateTime.day,
        localDateTime.hour,
        localDateTime.minute,
        localDateTime.second,
        localDateTime.millisecond,
        localDateTime.microsecond,
      ).toUtc();
    }
    final location = tz.getLocation(normalized);
    final zoned = tz.TZDateTime(
      location,
      localDateTime.year,
      localDateTime.month,
      localDateTime.day,
      localDateTime.hour,
      localDateTime.minute,
      localDateTime.second,
      localDateTime.millisecond,
      localDateTime.microsecond,
    );
    return DateTime.fromMillisecondsSinceEpoch(
      zoned.millisecondsSinceEpoch,
      isUtc: true,
    );
  }

  static DateTime dateStartToUtc(DateTime date, {String? timeZone}) {
    return localDateTimeToUtc(
      DateTime(date.year, date.month, date.day),
      timeZone: timeZone,
    );
  }

  static DateTime dateEndToUtc(DateTime date, {String? timeZone}) {
    return localDateTimeToUtc(
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999),
      timeZone: timeZone,
    );
  }

  static bool isSameCalendarDay(
    DateTime first,
    DateTime second, {
    String? timeZone,
  }) {
    final a = toDisplayDateTime(first, timeZone: timeZone);
    final b = toDisplayDateTime(second, timeZone: timeZone);
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String formatTimeZoneLabel(String timeZone, {DateTime? referenceUtc}) {
    final normalized = normalizeTimeZone(timeZone);
    if (normalized == null) return timeZone;
    final location = tz.getLocation(normalized);
    final instant = (referenceUtc ?? DateTime.now()).toUtc();
    final zoned = tz.TZDateTime.from(instant, location);
    final offset = _formatOffset(zoned.timeZoneOffset);
    return '$normalized (UTC$offset · ${zoned.timeZoneName})';
  }

  static String formatSummaryLine(
    BuildContext context, {
    required DateTime startAt,
    DateTime? endAt,
    required bool isDateOnly,
    String? timeZone,
  }) {
    final localizations = MaterialLocalizations.of(context);
    final start = toDisplayDateTime(startAt, timeZone: timeZone);
    final end = endAt == null
        ? null
        : toDisplayDateTime(endAt, timeZone: timeZone);
    final sameDay =
        end != null && isSameCalendarDay(startAt, end, timeZone: timeZone);

    final startDate = localizations.formatMediumDate(start);
    final endDate = end == null ? null : localizations.formatMediumDate(end);
    final startTime = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(start),
    );
    final endTime = end == null
        ? null
        : localizations.formatTimeOfDay(TimeOfDay.fromDateTime(end));
    final zoneSuffix = _timeZoneSuffix(timeZone, start);

    if (isDateOnly) {
      if (end == null || sameDay) return startDate;
      return '$startDate – $endDate';
    }

    if (end == null) return '$startDate · $startTime$zoneSuffix';
    if (sameDay) return '$startDate · $startTime – $endTime$zoneSuffix';
    return '$startDate $startTime – $endDate $endTime$zoneSuffix';
  }

  static String _timeZoneSuffix(String? timeZone, DateTime displayStart) {
    final normalized = normalizeTimeZone(timeZone);
    if (normalized == null) return '';
    return ' ${displayStart.timeZoneName}';
  }

  static String _formatOffset(Duration offset) {
    final totalMinutes = offset.inMinutes;
    final sign = totalMinutes >= 0 ? '+' : '-';
    final absoluteMinutes = totalMinutes.abs();
    final hours = absoluteMinutes ~/ 60;
    final minutes = absoluteMinutes % 60;
    final hh = hours.toString().padLeft(2, '0');
    final mm = minutes.toString().padLeft(2, '0');
    return '$sign$hh:$mm';
  }
}
