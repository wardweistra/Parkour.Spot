import type {EventSummary} from "./types";

/** `YYYY-MM-DD` calendar date. */
export type DayKey = string;
/** `YYYY-MM` calendar month. */
export type MonthKey = string;

export type DayPlacement = {
  event: EventSummary;
  /** Row inside the week, stable across the days a multi-day event covers. */
  lane: number;
  isStart: boolean;
  isEnd: boolean;
  /** First cell of this event in the current week row. */
  isSegmentStart: boolean;
  /** Days this segment covers in the current week row (from segment start). */
  segmentLength: number;
  /** This week's segment runs through the event's last day. */
  segmentEndsEvent: boolean;
  isMultiDay: boolean;
  time: string | null;
};

export type CalendarDay = {
  key: DayKey;
  day: number;
  inMonth: boolean;
  placements: DayPlacement[];
};

export type CalendarMonth = {
  key: MonthKey;
  label: string;
  weeks: CalendarDay[][];
  eventCount: number;
};

export type DayEvents = {
  key: DayKey;
  label: string;
  events: EventSummary[];
};

const MAX_SPAN_DAYS = 14;
const MAX_MONTHS = 24;
const DAY_MS = 86_400_000;

const partsFormatters = new Map<string, Intl.DateTimeFormat>();
const timeFormatters = new Map<string, Intl.DateTimeFormat>();

function resolveZone(timeZone: string | null | undefined): string {
  const zone = timeZone?.trim();
  if (!zone) return "UTC";
  try {
    new Intl.DateTimeFormat("en-GB", {timeZone: zone});
    return zone;
  } catch {
    return "UTC";
  }
}

function partsFormatter(zone: string): Intl.DateTimeFormat {
  let formatter = partsFormatters.get(zone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat("en-CA", {
      timeZone: zone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
    partsFormatters.set(zone, formatter);
  }
  return formatter;
}

function parseIso(iso: string | null | undefined): Date | null {
  if (!iso) return null;
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? null : date;
}

function dayKeyAt(date: Date, zone: string): DayKey {
  const parts = partsFormatter(zone).formatToParts(date);
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  return `${get("year")}-${get("month")}-${get("day")}`;
}

function keyToUtc(key: DayKey): number {
  const [y, m, d] = key.split("-").map(Number);
  return Date.UTC(y, m - 1, d);
}

function utcToKey(ms: number): DayKey {
  return new Date(ms).toISOString().slice(0, 10);
}

export function addDays(key: DayKey, days: number): DayKey {
  return utcToKey(keyToUtc(key) + days * DAY_MS);
}

export function monthOf(key: DayKey): MonthKey {
  return key.slice(0, 7);
}

function addMonths(month: MonthKey, count: number): MonthKey {
  const [y, m] = month.split("-").map(Number);
  const date = new Date(Date.UTC(y, m - 1 + count, 1));
  return date.toISOString().slice(0, 7);
}

/** Calendar date the event starts on, in the event's own time zone. */
export function zonedDayKey(event: EventSummary): DayKey | null {
  const start = parseIso(event.startAt);
  if (!start) return null;
  return dayKeyAt(start, resolveZone(event.timeZone));
}

/** Every calendar date the event covers, capped at two weeks. */
export function eventDaySpan(event: EventSummary): DayKey[] {
  const first = zonedDayKey(event);
  if (!first) return [];
  const zone = resolveZone(event.timeZone);
  const end = parseIso(event.endAt);
  const start = parseIso(event.startAt)!;
  let last = first;
  if (end && end.getTime() > start.getTime()) {
    // An end at exactly local midnight belongs to the previous day.
    last = dayKeyAt(new Date(end.getTime() - 1), zone);
    if (last < first) last = first;
  }
  const days: DayKey[] = [];
  for (
    let key = first;
    key <= last && days.length < MAX_SPAN_DAYS;
    key = addDays(key, 1)
  ) {
    days.push(key);
  }
  return days;
}

/** Start time in the event's zone, or null for date-only or undated events. */
export function eventTimeLabel(event: EventSummary): string | null {
  const start = parseIso(event.startAt);
  if (!start || event.isDateOnly) return null;
  const zone = resolveZone(event.timeZone);
  let formatter = timeFormatters.get(zone);
  if (!formatter) {
    formatter = new Intl.DateTimeFormat("en-GB", {
      timeZone: zone,
      timeStyle: "short",
    });
    timeFormatters.set(zone, formatter);
  }
  return formatter.format(start);
}

const monthLabelFormat = new Intl.DateTimeFormat("en-GB", {
  timeZone: "UTC",
  month: "long",
  year: "numeric",
});
const dayLabelFormat = new Intl.DateTimeFormat("en-GB", {
  timeZone: "UTC",
  weekday: "long",
  day: "numeric",
  month: "long",
});
const weekdayFormat = new Intl.DateTimeFormat("en-GB", {
  timeZone: "UTC",
  weekday: "long",
});

export function formatMonthLabel(month: MonthKey): string {
  return monthLabelFormat.format(new Date(keyToUtc(`${month}-01`)));
}

/** "Sunday 15 November" */
export function formatDayLabel(key: DayKey): string {
  return dayLabelFormat.format(new Date(keyToUtc(key)));
}

/** "Sunday 15" */
export function formatWeekdayAndDay(key: DayKey): string {
  const date = new Date(keyToUtc(key));
  return `${weekdayFormat.format(date)} ${date.getUTCDate()}`;
}

/** Monday-first weekday index, 0–6. */
function weekdayIndex(key: DayKey): number {
  return (new Date(keyToUtc(key)).getUTCDay() + 6) % 7;
}

/** Earlier start day first, then longer spans, then local start time. */
function compareEvents(a: EventSummary, b: EventSummary): number {
  const dayDiff = (zonedDayKey(a) ?? "").localeCompare(zonedDayKey(b) ?? "");
  if (dayDiff !== 0) return dayDiff;
  const spanDiff = eventDaySpan(b).length - eventDaySpan(a).length;
  if (spanDiff !== 0) return spanDiff;
  return (eventTimeLabel(a) ?? "").localeCompare(eventTimeLabel(b) ?? "");
}

const shortMonthDayFormat = new Intl.DateTimeFormat("en-GB", {
  timeZone: "UTC",
  day: "numeric",
  month: "long",
});

/** "8–12 October" or "30 October – 2 November". */
export function formatDayRange(first: DayKey, last: DayKey): string {
  const a = new Date(keyToUtc(first));
  const b = new Date(keyToUtc(last));
  if (monthOf(first) === monthOf(last)) {
    return `${a.getUTCDate()}–${shortMonthDayFormat.format(b)}`;
  }
  return `${shortMonthDayFormat.format(a)} – ${shortMonthDayFormat.format(b)}`;
}

/** Date range for multi-day events, "All day", or the local start time. */
export function eventWhenLabel(event: EventSummary): string | null {
  const days = eventDaySpan(event);
  if (days.length > 1) return formatDayRange(days[0], days[days.length - 1]);
  if (event.isDateOnly && days.length === 1) return "All day";
  return eventTimeLabel(event);
}

/** Events grouped by every day they cover, in date order. */
export function eventsByDay(events: EventSummary[]): DayEvents[] {
  const days = new Map<DayKey, EventSummary[]>();
  for (const event of events) {
    for (const key of eventDaySpan(event)) {
      const list = days.get(key) ?? [];
      list.push(event);
      days.set(key, list);
    }
  }
  return [...days.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([key, list]) => ({
      key,
      label: formatDayLabel(key),
      events: list.sort(compareEvents),
    }));
}

/**
 * Month grids from the earlier of `fromMonth` and the first event through the
 * last month any event covers. Weeks start on Monday.
 */
export function buildMonths(
  events: EventSummary[],
  fromMonth?: MonthKey,
): CalendarMonth[] {
  const spans = events
    .map((event) => ({event, days: eventDaySpan(event)}))
    .filter((entry) => entry.days.length > 0);
  if (spans.length === 0) return [];

  const allDays = spans.flatMap((entry) => entry.days).sort();
  let first = monthOf(allDays[0]);
  if (fromMonth && fromMonth > first) first = fromMonth;
  const last = monthOf(allDays[allDays.length - 1]);
  if (first > last) return [];

  const months: CalendarMonth[] = [];
  for (
    let month = first;
    month <= last && months.length < MAX_MONTHS;
    month = addMonths(month, 1)
  ) {
    months.push(buildMonth(month, spans));
  }
  return months;
}

function buildMonth(
  month: MonthKey,
  spans: {event: EventSummary; days: DayKey[]}[],
): CalendarMonth {
  const firstDay = `${month}-01`;
  const gridStart = addDays(firstDay, -weekdayIndex(firstDay));
  const nextMonthFirst = `${addMonths(month, 1)}-01`;
  const weeks: CalendarDay[][] = [];
  const counted = new Set<EventSummary>();

  for (
    let weekStart = gridStart;
    weekStart < nextMonthFirst;
    weekStart = addDays(weekStart, 7)
  ) {
    const weekEnd = addDays(weekStart, 6);
    const week: CalendarDay[] = Array.from({length: 7}, (_, i) => {
      const key = addDays(weekStart, i);
      return {
        key,
        day: Number(key.slice(8)),
        inMonth: monthOf(key) === month,
        placements: [],
      };
    });

    const inWeek = spans
      .filter(
        (entry) =>
          entry.days[0] <= weekEnd &&
          entry.days[entry.days.length - 1] >= weekStart,
      )
      .sort((a, b) => compareEvents(a.event, b.event));

    const lanes: boolean[][] = [];
    for (const {event, days} of inWeek) {
      const covered = days.filter((key) => key >= weekStart && key <= weekEnd);
      const from = weekdayIndex(covered[0]);
      const to = from + covered.length - 1;
      let lane = 0;
      while (lanes[lane]?.slice(from, to + 1).some(Boolean)) lane += 1;
      lanes[lane] ??= Array(7).fill(false);
      for (let i = from; i <= to; i += 1) lanes[lane][i] = true;

      const time = eventTimeLabel(event);
      const isMultiDay = days.length > 1;
      const segmentEndsEvent =
        covered[covered.length - 1] === days[days.length - 1];
      covered.forEach((key, offset) => {
        week[from + offset].placements.push({
          event,
          lane,
          isStart: key === days[0],
          isEnd: key === days[days.length - 1],
          isSegmentStart: offset === 0,
          segmentLength: covered.length - offset,
          segmentEndsEvent,
          isMultiDay,
          time,
        });
        if (monthOf(key) === month) counted.add(event);
      });
    }

    for (const day of week) day.placements.sort((a, b) => a.lane - b.lane);
    weeks.push(week);
  }

  return {
    key: month,
    label: formatMonthLabel(month),
    weeks,
    eventCount: counted.size,
  };
}

export function monthKeyAt(iso: string | null | undefined): MonthKey | null {
  const date = parseIso(iso);
  return date ? dayKeyAt(date, "UTC").slice(0, 7) : null;
}
