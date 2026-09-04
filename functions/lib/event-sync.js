const ical = require("node-ical");
const {
  decodeBasicHtmlEntities,
  htmlToPlainText,
} = require("./html-plain-text");

/** @type {"feed"} */
const EVENT_TIME_ZONE_SOURCE_FEED = "feed";
/** @type {"sourceDefault"} */
const EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT = "sourceDefault";

/**
 * Coerces unknown input into a non-empty trimmed string.
 * @param {*} value
 * @return {string|null}
 */
function toNonEmptyString(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * Normalizes a potentially date-like value.
 * @param {*} value
 * @return {Date|null}
 */
function normalizeDate(value) {
  if (!value) return null;
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
  if (typeof value.toDate === "function") {
    const asDate = value.toDate();
    if (asDate instanceof Date && !Number.isNaN(asDate.getTime())) {
      return asDate;
    }
  }
  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed;
    }
  }
  return null;
}

/**
 * Normalizes an iCal recurrence ID so it can be persisted.
 * @param {*} value
 * @return {string|null}
 */
function normalizeRecurrenceId(value) {
  const asDate = normalizeDate(value);
  if (asDate) return asDate.toISOString();
  return toNonEmptyString(value);
}

/**
 * Builds a unique key for one imported external event.
 * @param {string} uid
 * @param {string|null} recurrenceId
 * @return {string}
 */
function buildExternalEventKey(uid, recurrenceId) {
  const normalizedUid = toNonEmptyString(uid);
  if (!normalizedUid) {
    throw new Error("External event UID is required");
  }
  const normalizedRecurrenceId = normalizeRecurrenceId(recurrenceId);
  if (!normalizedRecurrenceId) return normalizedUid;
  return `${normalizedUid}::${normalizedRecurrenceId}`;
}

/**
 * Compares nullable strings while ignoring whitespace and empty-string/null.
 * @param {*} left
 * @param {*} right
 * @return {boolean}
 */
function nullableStringEqual(left, right) {
  const normalizedLeft = toNonEmptyString(left);
  const normalizedRight = toNonEmptyString(right);
  return normalizedLeft === normalizedRight;
}

/**
 * @param {string} timeZone
 * @return {boolean}
 */
function isValidIanaTimeZone(timeZone) {
  try {
    // eslint-disable-next-line new-cap
    Intl.DateTimeFormat(undefined, {timeZone});
    return true;
  } catch (_) {
    return false;
  }
}

/**
 * @param {*} raw
 * @return {string|null}
 */
function normalizeImportedTimeZone(raw) {
  const trimmed = toNonEmptyString(raw);
  if (!trimmed) return null;
  if (trimmed === "Etc/UTC" || trimmed === "UTC") return null;
  return isValidIanaTimeZone(trimmed) ? trimmed : null;
}

/**
 * @param {Object} parsedCalendar
 * @return {string|null}
 */
function extractCalendarTimeZone(parsedCalendar) {
  for (const value of Object.values(parsedCalendar)) {
    if (!value || value.type !== "VCALENDAR") continue;
    const fromWr = normalizeImportedTimeZone(value["WR-TIMEZONE"]);
    if (fromWr) return fromWr;
  }
  return null;
}

/**
 * Unfolds RFC 5545 line continuations (leading space/tab).
 * @param {string} block
 * @return {string}
 */
function unfoldIcsBlock(block) {
  return block.replace(/\r\n/g, "\n").replace(/\n[ \t]/g, "");
}

/**
 * @param {string} icsText
 * @return {Map<string, string>}
 */
function buildUidToIcsBlockMap(icsText) {
  const map = new Map();
  const normalized = icsText.replace(/\r\n/g, "\n");
  const re = /BEGIN:VEVENT\n([\s\S]*?)END:VEVENT/g;
  let match;
  while ((match = re.exec(normalized)) !== null) {
    const block = unfoldIcsBlock(match[1]);
    const uidMatch = /^UID:(.+)$/m.exec(block);
    if (!uidMatch) continue;
    const uid = uidMatch[1].trim();
    if (uid.length > 0) map.set(uid, block);
  }
  return map;
}

/**
 * @param {string} ymd - YYYYMMDD
 * @return {{year: number, month: number, day: number}|null}
 */
function parseYmd(ymd) {
  if (!/^\d{8}$/.test(ymd)) return null;
  const year = Number(ymd.slice(0, 4));
  const month = Number(ymd.slice(4, 6));
  const day = Number(ymd.slice(6, 8));
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return {year, month, day};
}

/**
 * @param {string} icsBlock
 * @return {Object|null}
 */
function extractValueDatesFromIcsBlock(icsBlock) {
  const startMatch =
    /^DTSTART(?:;[^:\r\n]*)?:(\d{8})/m.exec(icsBlock);
  if (!startMatch) return null;
  const startYmd = startMatch[1];
  const endMatch = /^DTEND(?:;[^:\r\n]*)?:(\d{8})/m.exec(icsBlock);
  return {
    startYmd,
    endYmdExclusive: endMatch ? endMatch[1] : null,
  };
}

/**
 * @param {number} utcMs
 * @param {string} timeZone
 * @return {Object}
 */
function getZonedWallClock(utcMs, timeZone) {
  // eslint-disable-next-line new-cap
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hour12: false,
  });
  /** @type {Record<string, string>} */
  const parts = {};
  for (const part of formatter.formatToParts(new Date(utcMs))) {
    if (part.type !== "literal") parts[part.type] = part.value;
  }
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour: Number(parts.hour),
    minute: Number(parts.minute),
    second: Number(parts.second),
  };
}

/**
 * Wall-clock in [timeZone] to UTC (mirrors Dart localDateTimeToUtc).
 * @param {number} year
 * @param {number} month
 * @param {number} day
 * @param {number} hour
 * @param {number} minute
 * @param {number} second
 * @param {number} millisecond
 * @param {string} timeZone
 * @return {Date}
 */
function localDateTimeToUtc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    millisecond,
    timeZone,
) {
  const targetMs = Date.UTC(
      year,
      month - 1,
      day,
      hour,
      minute,
      second,
      millisecond,
  );
  let utcMs = targetMs;
  for (let i = 0; i < 6; i++) {
    const wall = getZonedWallClock(utcMs, timeZone);
    const wallMs = Date.UTC(
        wall.year,
        wall.month - 1,
        wall.day,
        wall.hour,
        wall.minute,
        wall.second,
        0,
    );
    const diff = targetMs - wallMs;
    if (diff === 0) break;
    utcMs += diff;
  }
  return new Date(utcMs);
}

/**
 * @param {number} year
 * @param {number} month
 * @param {number} day
 * @param {string} timeZone
 * @return {Date}
 */
function dateStartToUtc(year, month, day, timeZone) {
  return localDateTimeToUtc(year, month, day, 0, 0, 0, 0, timeZone);
}

/**
 * @param {number} year
 * @param {number} month
 * @param {number} day
 * @param {string} timeZone
 * @return {Date}
 */
function dateEndToUtc(year, month, day, timeZone) {
  const nextDay = new Date(Date.UTC(year, month - 1, day));
  nextDay.setUTCDate(nextDay.getUTCDate() + 1);
  const startOfNextDay = dateStartToUtc(
      nextDay.getUTCFullYear(),
      nextDay.getUTCMonth() + 1,
      nextDay.getUTCDate(),
      timeZone,
  );
  return new Date(startOfNextDay.getTime() - 1);
}

/**
 * @param {{year: number, month: number, day: number}} ymd
 * @return {{year: number, month: number, day: number}}
 */
function subtractOneCalendarDay(ymd) {
  const date = new Date(Date.UTC(ymd.year, ymd.month - 1, ymd.day));
  date.setUTCDate(date.getUTCDate() - 1);
  return {
    year: date.getUTCFullYear(),
    month: date.getUTCMonth() + 1,
    day: date.getUTCDate(),
  };
}

/**
 * @param {string} endYmdExclusive - YYYYMMDD (ICS exclusive DTEND)
 * @return {{year: number, month: number, day: number}|null}
 */
function endInclusiveFromExclusive(endYmdExclusive) {
  const parsed = parseYmd(endYmdExclusive);
  if (!parsed) return null;
  return subtractOneCalendarDay(parsed);
}

/**
 * @param {string} icsBlock
 * @param {string} calendarTimeZone
 * @return {Object|null}
 */
function normalizeAllDaySchedule(icsBlock, calendarTimeZone) {
  const dates = extractValueDatesFromIcsBlock(icsBlock);
  if (!dates) return null;
  const startParts = parseYmd(dates.startYmd);
  if (!startParts) return null;

  const startAt = dateStartToUtc(
      startParts.year,
      startParts.month,
      startParts.day,
      calendarTimeZone,
  );

  let endAt = null;
  if (dates.endYmdExclusive) {
    const endInclusive = endInclusiveFromExclusive(dates.endYmdExclusive);
    if (endInclusive) {
      endAt = dateEndToUtc(
          endInclusive.year,
          endInclusive.month,
          endInclusive.day,
          calendarTimeZone,
      );
    }
  }

  return {
    startAt,
    endAt,
    isDateOnly: true,
    timeZone: calendarTimeZone,
  };
}

/**
 * All-day VALUE=DATE bounds when feed has no X-WR-TIMEZONE (floating dates).
 * @param {string} icsBlock
 * @return {Object|null}
 */
function normalizeAllDayScheduleUtc(icsBlock) {
  const dates = extractValueDatesFromIcsBlock(icsBlock);
  if (!dates) return null;
  const startParts = parseYmd(dates.startYmd);
  if (!startParts) return null;

  const startAt = new Date(Date.UTC(
      startParts.year,
      startParts.month - 1,
      startParts.day,
      0,
      0,
      0,
      0,
  ));

  let endAt = null;
  if (dates.endYmdExclusive) {
    const endInclusive = endInclusiveFromExclusive(dates.endYmdExclusive);
    if (endInclusive) {
      endAt = new Date(Date.UTC(
          endInclusive.year,
          endInclusive.month - 1,
          endInclusive.day,
          23,
          59,
          59,
          999,
      ));
    }
  }

  return {
    startAt,
    endAt,
    isDateOnly: true,
    timeZone: null,
  };
}

/**
 * @param {*} value
 * @return {string|null}
 */
function extractEventTimeZoneFromNodeIcal(value) {
  const start = value && value.start;
  if (!start || typeof start !== "object") return null;
  const tz = start.tz;
  if (typeof tz === "string") return normalizeImportedTimeZone(tz);
  return null;
}

/**
 * @param {*} data
 * @return {boolean}
 */
function normalizeIsDateOnly(data) {
  return data && data.isDateOnly === true;
}

/**
 * Compares a stored Firestore timestamp-like field against a Date value.
 * @param {*} storedValue
 * @param {Date|null} incomingDate
 * @return {boolean}
 */
function nullableDateEqual(storedValue, incomingDate) {
  const normalizedStoredDate = normalizeDate(storedValue);
  if (!normalizedStoredDate && !incomingDate) return true;
  if (!normalizedStoredDate || !incomingDate) return false;
  return normalizedStoredDate.getTime() === incomingDate.getTime();
}

/**
 * Trims trailing punctuation often glued to URLs in prose or ICS text.
 * @param {string} url
 * @return {string}
 */
function trimTrailingUrlPunctuation(url) {
  return url.replace(/[.,;:!?)]+$/g, "");
}

/**
 * Collects every http(s) URL in document order (href= and plain text).
 * @param {string} html
 * @return {Array<{idx: number, url: string}>}
 */
function collectHttpUrlsInOrder(html) {
  if (!html || typeof html !== "string") return [];
  /** @type {Array<{idx: number, url: string}>} */
  const found = [];
  let m;
  const hrefRe = /\bhref\s*=\s*["'](https?:\/\/[^"'>\s]+)/gi;
  while ((m = hrefRe.exec(html)) !== null) {
    const url = trimTrailingUrlPunctuation(decodeBasicHtmlEntities(m[1]));
    if (url.length > 0) found.push({idx: m.index, url});
  }
  const plainRe = /\bhttps?:\/\/[^\s<>"']+/gi;
  while ((m = plainRe.exec(html)) !== null) {
    const url = trimTrailingUrlPunctuation(decodeBasicHtmlEntities(m[0]));
    if (url.length > 0) found.push({idx: m.index, url});
  }
  found.sort((a, b) => a.idx - b.idx);
  return found;
}

/**
 * Last http(s) URL in reading order (for event website from feed description).
 * @param {string} html
 * @return {string|null}
 */
function extractLastHttpUrlFromDescription(html) {
  const found = collectHttpUrlsInOrder(html);
  if (found.length === 0) return null;
  return found[found.length - 1].url;
}

/**
 * ICS / HTML event description: br tags to newlines, strip tags,
 * decode common entities.
 * @param {string} raw
 * @return {string|null}
 */
function normalizeImportedEventDescription(raw) {
  if (!raw || typeof raw !== "string") return null;
  const text = htmlToPlainText(raw);
  return text.length > 0 ? text : null;
}

/**
 * Removes the URL chosen for websiteUrl from plain description text
 * (all exact matches), then tidies whitespace.
 * @param {string|null} text
 * @param {string|null} urlToRemove
 * @return {string|null}
 */
function removeExtractedWebsiteUrlFromDescription(text, urlToRemove) {
  if (!text || !urlToRemove) return text;
  let out = text.split(urlToRemove).join("");
  out = out
      .replace(/[ \t]+\n/g, "\n")
      .replace(/\n[ \t]+/g, "\n")
      .replace(/[ \t]{2,}/g, " ")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
  return out.length > 0 ? out : null;
}

/**
 * Checks whether a source-sync should update event content fields.
 * @param {Object} existingData
 * @param {Object} incomingData
 * @return {boolean}
 */
function hasExternalEventContentChanges(existingData, incomingData) {
  if (!nullableStringEqual(existingData.title, incomingData.title)) return true;
  if (
    !nullableStringEqual(existingData.description, incomingData.description)
  ) {
    return true;
  }
  if (!nullableStringEqual(existingData.websiteUrl, incomingData.websiteUrl)) {
    return true;
  }
  if (!nullableStringEqual(existingData.address, incomingData.address)) {
    return true;
  }
  if (!nullableDateEqual(existingData.startAt, incomingData.startAt)) {
    return true;
  }
  if (!nullableDateEqual(existingData.endAt, incomingData.endAt)) {
    return true;
  }
  if (
    !nullableStringEqual(existingData.eventSourceId, incomingData.eventSourceId)
  ) {
    return true;
  }
  if (
    !nullableStringEqual(
        existingData.eventSourceName,
        incomingData.eventSourceName,
    )
  ) {
    return true;
  }
  if (
    !nullableStringEqual(
        existingData.externalEventUid,
        incomingData.externalEventUid,
    )
  ) {
    return true;
  }
  if (
    !nullableStringEqual(
        existingData.externalEventRecurrenceId,
        incomingData.externalEventRecurrenceId,
    )
  ) {
    return true;
  }
  if (
    !nullableStringEqual(
        existingData.externalEventKey,
        incomingData.externalEventKey,
    )
  ) {
    return true;
  }
  if (
    normalizeIsDateOnly(existingData) !== normalizeIsDateOnly(incomingData)
  ) {
    return true;
  }
  if (!nullableStringEqual(existingData.timeZone, incomingData.timeZone)) {
    return true;
  }
  if (
    !nullableStringEqual(
        existingData.timeZoneSource,
        incomingData.timeZoneSource,
    )
  ) {
    return true;
  }
  if (
    !nullableStringEqual(
        existingData.externalImageUrl,
        incomingData.externalImageUrl,
    )
  ) {
    return true;
  }
  return false;
}

/**
 * Checks whether the normalized event address changed.
 * @param {Object|null|undefined} existingData
 * @param {Object} incomingData
 * @return {boolean}
 */
function hasExternalEventAddressChanged(existingData, incomingData) {
  return !nullableStringEqual(
      existingData ? existingData.address : null,
      incomingData ? incomingData.address : null,
  );
}

/**
 * @param {Object|null|undefined} data
 * @return {boolean}
 */
function hasStoredEventCoordinates(data) {
  if (!data || typeof data !== "object") return false;
  const lat = data.latitude;
  const lng = data.longitude;
  return (
    lat != null &&
    lng != null &&
    Number.isFinite(Number(lat)) &&
    Number.isFinite(Number(lng))
  );
}

/**
 * @param {Object|null|undefined} data
 * @return {boolean}
 */
function hasExternalEventPlaceFields(data) {
  if (!data || typeof data !== "object") return false;
  return Boolean(
      toNonEmptyString(data.city) && toNonEmptyString(data.countryCode),
  );
}

/**
 * Checks whether this event should attempt address geocoding now.
 * - Always true for creates with an address.
 * - True when the address changed to another non-empty value.
 * - True when the address matches but lat/lon are missing or invalid.
 * @param {Object|null|undefined} existingData
 * @param {Object} incomingData
 * @return {boolean}
 */
function shouldGeocodeExternalEventAddress(existingData, incomingData) {
  if (hasStoredEventCoordinates(incomingData)) return false;
  const incomingAddress = toNonEmptyString(
      incomingData ? incomingData.address : null,
  );
  if (!incomingAddress) return false;
  if (!existingData) return true;
  if (hasExternalEventAddressChanged(existingData, incomingData)) return true;
  return !hasStoredEventCoordinates(existingData);
}

/**
 * @param {*} raw
 * @return {string|null}
 */
function normalizeEventSyncSourceDefaultTimeZone(raw) {
  return normalizeImportedTimeZone(raw);
}

/**
 * Resolves all-day schedule and time zone source from an ICS block.
 * @param {string} icsBlock
 * @param {string|null} calendarTimeZone
 * @param {string|null} sourceDefaultTimeZone
 * @return {{schedule: (Object|null), timeZoneSource: (string|null)}}
 */
function resolveAllDaySchedule(
    icsBlock,
    calendarTimeZone,
    sourceDefaultTimeZone,
) {
  if (calendarTimeZone) {
    const schedule = normalizeAllDaySchedule(icsBlock, calendarTimeZone);
    if (!schedule) return {schedule: null, timeZoneSource: null};
    return {schedule, timeZoneSource: EVENT_TIME_ZONE_SOURCE_FEED};
  }
  if (sourceDefaultTimeZone) {
    const schedule = normalizeAllDaySchedule(icsBlock, sourceDefaultTimeZone);
    if (!schedule) return {schedule: null, timeZoneSource: null};
    return {schedule, timeZoneSource: EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT};
  }
  const schedule = normalizeAllDayScheduleUtc(icsBlock);
  return {schedule, timeZoneSource: null};
}

/**
 * Parses VEVENT records from an ICS file into normalized event payloads.
 * @param {string} icsText
 * @param {Object} sourceMeta
 * @param {string} sourceMeta.sourceId
 * @param {string} sourceMeta.sourceName
 * @param {string=} sourceMeta.sourceDefaultTimeZone
 * @return {Array<Object>}
 */
function parseExternalEventsFromIcs(
    icsText,
    {sourceId, sourceName, sourceDefaultTimeZone = null},
) {
  const parsedCalendar = ical.sync.parseICS(icsText);
  const parsedEvents = [];
  const calendarTimeZone = extractCalendarTimeZone(parsedCalendar);
  const normalizedSourceDefaultTimeZone =
    normalizeEventSyncSourceDefaultTimeZone(sourceDefaultTimeZone);
  const uidToIcsBlock = buildUidToIcsBlockMap(icsText);

  for (const value of Object.values(parsedCalendar)) {
    if (!value || value.type !== "VEVENT") continue;

    const uid = toNonEmptyString(value.uid);
    if (!uid) continue;

    const isAllDay = value.datetype === "date";
    let startAt = null;
    let endAt = null;
    let isDateOnly = false;
    let timeZone = null;
    let timeZoneSource = null;

    if (isAllDay) {
      const icsBlock = uidToIcsBlock.get(uid);
      if (!icsBlock) {
        console.warn(
            `Skipping all-day ICS event "${value.summary || uid}": ` +
            "VEVENT block not found in raw ICS",
        );
        continue;
      }
      const resolved = resolveAllDaySchedule(
          icsBlock,
          calendarTimeZone,
          normalizedSourceDefaultTimeZone,
      );
      if (!resolved.schedule) {
        console.warn(
            `Skipping all-day ICS event "${value.summary || uid}": ` +
            "could not parse VALUE=DATE bounds",
        );
        continue;
      }
      startAt = resolved.schedule.startAt;
      endAt = resolved.schedule.endAt;
      isDateOnly = resolved.schedule.isDateOnly;
      timeZone = resolved.schedule.timeZone;
      timeZoneSource = resolved.timeZoneSource;
    } else {
      startAt = normalizeDate(value.start);
      endAt = normalizeDate(value.end);
      isDateOnly = false;
      timeZone = extractEventTimeZoneFromNodeIcal(value);
      if (timeZone) timeZoneSource = EVENT_TIME_ZONE_SOURCE_FEED;
    }

    if (!startAt) continue;

    const recurrenceId = normalizeRecurrenceId(value.recurrenceid);

    const rawDescription =
        typeof value.description === "string" ? value.description : "";
    const descriptionFromBody = normalizeImportedEventDescription(
        rawDescription,
    );
    const lastUrlInDescription = extractLastHttpUrlFromDescription(
        rawDescription,
    );
    const websiteUrl =
        toNonEmptyString(lastUrlInDescription) || toNonEmptyString(value.url);

    const descriptionAfterUrlRemoval =
        removeExtractedWebsiteUrlFromDescription(
            descriptionFromBody,
            lastUrlInDescription,
        );

    const eventPayload = {
      title: toNonEmptyString(value.summary) || "Untitled event",
      description: toNonEmptyString(descriptionAfterUrlRemoval),
      websiteUrl,
      address: toNonEmptyString(value.location),
      startAt,
      endAt,
      isDateOnly,
      eventSourceId: sourceId,
      eventSourceName: sourceName,
      externalEventUid: uid,
      externalEventRecurrenceId: recurrenceId,
      externalEventKey: buildExternalEventKey(uid, recurrenceId),
    };
    if (timeZone) eventPayload.timeZone = timeZone;
    if (timeZoneSource) eventPayload.timeZoneSource = timeZoneSource;
    parsedEvents.push(eventPayload);
  }

  return parsedEvents;
}

/** @type {"ics"} */
const EVENT_SYNC_SOURCE_TYPE_ICS = "ics";
/** @type {"wixPublishedCalendar"} */
const EVENT_SYNC_SOURCE_TYPE_WIX_PUBLISHED_CALENDAR = "wixPublishedCalendar";

/**
 * @param {*} value
 * @return {"ics"|"wixPublishedCalendar"}
 */
function normalizeEventSyncSourceType(value) {
  if (value === EVENT_SYNC_SOURCE_TYPE_WIX_PUBLISHED_CALENDAR) {
    return EVENT_SYNC_SOURCE_TYPE_WIX_PUBLISHED_CALENDAR;
  }
  return EVENT_SYNC_SOURCE_TYPE_ICS;
}

/**
 * @param {*} raw
 * @return {string|null}
 */
function normalizeExternalImageUrl(raw) {
  let candidate = raw;
  if (typeof candidate === "string") {
    const trimmed = candidate.trim();
    if (!trimmed) return null;
    if (trimmed.startsWith("[")) {
      try {
        candidate = JSON.parse(trimmed);
      } catch (_) {
        candidate = trimmed;
      }
    } else {
      candidate = trimmed;
    }
  }
  if (Array.isArray(candidate)) {
    candidate = candidate.find((item) => {
      return typeof item === "string" && item.trim();
    });
  }
  const trimmed = toNonEmptyString(candidate);
  if (!trimmed) return null;
  let parsed;
  try {
    parsed = new URL(trimmed);
  } catch (_) {
    return null;
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    return null;
  }
  return parsed.toString();
}

/**
 * @param {*} value
 * @return {boolean}
 */
function isWixAllDayFlag(value) {
  return value === true || value === 1 || value === "1";
}

/**
 * @param {string} value
 * @return {{year: number, month: number, day: number}|null}
 */
function parseIsoDateOnly(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) return null;
  return {
    year: Number(match[1]),
    month: Number(match[2]),
    day: Number(match[3]),
  };
}

/**
 * @param {string} value
 * @return {{
 *   year: number,
 *   month: number,
 *   day: number,
 *   hour: number,
 *   minute: number,
 *   second: number,
 * }|null}
 */
function parseIsoLocalDateTime(value) {
  const match =
    /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2}))?$/.exec(value);
  if (!match) return null;
  return {
    year: Number(match[1]),
    month: Number(match[2]),
    day: Number(match[3]),
    hour: Number(match[4]),
    minute: Number(match[5]),
    second: match[6] != null ? Number(match[6]) : 0,
  };
}

/**
 * @param {Object|null|undefined} venue
 * @return {{latitude: number, longitude: number}|null}
 */
function extractWixVenueCoordinates(venue) {
  if (!venue || typeof venue !== "object") return null;
  const lat = Number(venue.lat);
  const lngRaw = venue.lng != null ? venue.lng : venue.long;
  const lng = Number(lngRaw);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  return {latitude: lat, longitude: lng};
}

/**
 * @param {*} raw
 * @return {string|null}
 */
function normalizeWixWebsiteCandidate(raw) {
  const value = toNonEmptyString(raw);
  if (!value) return null;
  if (value.toLowerCase() === "event_page") return null;
  return value;
}

/**
 * @param {Object} event
 * @return {string|null}
 */
function extractWixWebsiteUrl(event) {
  const link = normalizeWixWebsiteCandidate(event.link);
  if (link) return link;
  const organizerWebsite = event.organizer &&
      typeof event.organizer === "object" ?
    normalizeWixWebsiteCandidate(event.organizer.website) :
    null;
  if (organizerWebsite) return organizerWebsite;
  const venueWebsite = event.venue && typeof event.venue === "object" ?
    normalizeWixWebsiteCandidate(event.venue.website) :
    null;
  return venueWebsite;
}

/**
 * @param {string} startRaw
 * @param {string|null} endRaw
 * @param {boolean} isDateOnly
 * @param {string|null} timeZone
 * @param {string|null} timeZoneSource
 * @return {Object|null}
 */
function resolveWixEventSchedule(
    startRaw,
    endRaw,
    isDateOnly,
    timeZone,
    timeZoneSource,
) {
  if (isDateOnly) {
    const startParts = parseIsoDateOnly(startRaw);
    if (!startParts) return null;
    let endAt = null;
    if (endRaw) {
      const endParts = parseIsoDateOnly(endRaw);
      if (endParts) {
        endAt = timeZone ?
          dateEndToUtc(
              endParts.year,
              endParts.month,
              endParts.day,
              timeZone,
          ) :
          new Date(Date.UTC(
              endParts.year,
              endParts.month - 1,
              endParts.day,
              23,
              59,
              59,
              999,
          ));
      }
    }
    const startAt = timeZone ?
      dateStartToUtc(
          startParts.year,
          startParts.month,
          startParts.day,
          timeZone,
      ) :
      new Date(Date.UTC(
          startParts.year,
          startParts.month - 1,
          startParts.day,
          0,
          0,
          0,
          0,
      ));
    return {
      startAt,
      endAt,
      isDateOnly: true,
      timeZone: timeZone || null,
      timeZoneSource: timeZone ? timeZoneSource : null,
    };
  }

  const startParts = parseIsoLocalDateTime(startRaw);
  if (!startParts) return null;
  if (!timeZone) {
    // Floating timed without a timezone cannot be resolved safely.
    return null;
  }
  const startAt = localDateTimeToUtc(
      startParts.year,
      startParts.month,
      startParts.day,
      startParts.hour,
      startParts.minute,
      startParts.second,
      0,
      timeZone,
  );
  let endAt = null;
  if (endRaw) {
    const endParts = parseIsoLocalDateTime(endRaw);
    if (endParts) {
      endAt = localDateTimeToUtc(
          endParts.year,
          endParts.month,
          endParts.day,
          endParts.hour,
          endParts.minute,
          endParts.second,
          0,
          timeZone,
      );
    }
  }
  return {
    startAt,
    endAt,
    isDateOnly: false,
    timeZone,
    timeZoneSource,
  };
}

/**
 * Parses BoomTech/Wix published_calendar JSON into normalized event payloads.
 * @param {Object} payload
 * @param {Object} sourceMeta
 * @param {string} sourceMeta.sourceId
 * @param {string} sourceMeta.sourceName
 * @param {string=} sourceMeta.sourceDefaultTimeZone
 * @return {Array<Object>}
 */
function parseExternalEventsFromWixPublishedCalendar(
    payload,
    {sourceId, sourceName, sourceDefaultTimeZone = null},
) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("published_calendar payload must be a JSON object");
  }

  const events = Array.isArray(payload.events) ? payload.events : [];
  const feedTimeZone = normalizeImportedTimeZone(payload.time_zone);
  const normalizedSourceDefaultTimeZone =
    normalizeEventSyncSourceDefaultTimeZone(sourceDefaultTimeZone);

  let defaultTimeZone = null;
  let defaultTimeZoneSource = null;
  if (feedTimeZone) {
    defaultTimeZone = feedTimeZone;
    defaultTimeZoneSource = EVENT_TIME_ZONE_SOURCE_FEED;
  } else if (normalizedSourceDefaultTimeZone) {
    defaultTimeZone = normalizedSourceDefaultTimeZone;
    defaultTimeZoneSource = EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT;
  }

  const parsedEvents = [];
  for (const event of events) {
    if (!event || typeof event !== "object") continue;

    const uid = event.id != null ? toNonEmptyString(String(event.id)) : null;
    if (!uid) continue;

    const startRaw = toNonEmptyString(event.start);
    if (!startRaw) continue;

    const endRaw = toNonEmptyString(event.end);
    const isDateOnly = isWixAllDayFlag(event.all_day) ||
        parseIsoDateOnly(startRaw) != null;

    const eventTimeZone = normalizeImportedTimeZone(event.time_zone);
    let timeZone = defaultTimeZone;
    let timeZoneSource = defaultTimeZoneSource;
    if (eventTimeZone) {
      timeZone = eventTimeZone;
      timeZoneSource = EVENT_TIME_ZONE_SOURCE_FEED;
    }

    const schedule = resolveWixEventSchedule(
        startRaw,
        endRaw,
        isDateOnly,
        timeZone,
        timeZoneSource,
    );
    if (!schedule || !schedule.startAt) continue;

    const rawDescription =
        typeof event.desc === "string" ? event.desc : "";
    const descriptionFromBody = normalizeImportedEventDescription(
        rawDescription,
    );
    const lastUrlInDescription = extractLastHttpUrlFromDescription(
        rawDescription,
    );
    const websiteUrl =
        extractWixWebsiteUrl(event) ||
        toNonEmptyString(lastUrlInDescription);

    const descriptionAfterUrlRemoval =
        removeExtractedWebsiteUrlFromDescription(
            descriptionFromBody,
            lastUrlInDescription,
        );

    const venue = event.venue && typeof event.venue === "object" ?
      event.venue :
      null;
    const address = venue ?
      (toNonEmptyString(venue.address) || toNonEmptyString(venue.name)) :
      null;
    const coords = extractWixVenueCoordinates(venue);

    const eventPayload = {
      title: toNonEmptyString(event.title) || "Untitled event",
      description: toNonEmptyString(descriptionAfterUrlRemoval),
      websiteUrl,
      address,
      startAt: schedule.startAt,
      endAt: schedule.endAt,
      isDateOnly: schedule.isDateOnly,
      eventSourceId: sourceId,
      eventSourceName: sourceName,
      externalEventUid: uid,
      externalEventRecurrenceId: null,
      externalEventKey: buildExternalEventKey(uid, null),
    };
    if (schedule.timeZone) eventPayload.timeZone = schedule.timeZone;
    if (schedule.timeZoneSource) {
      eventPayload.timeZoneSource = schedule.timeZoneSource;
    }
    if (coords) {
      eventPayload.latitude = coords.latitude;
      eventPayload.longitude = coords.longitude;
    }
    const externalImageUrl = normalizeExternalImageUrl(event.image);
    if (externalImageUrl) {
      eventPayload.externalImageUrl = externalImageUrl;
    }
    parsedEvents.push(eventPayload);
  }

  return parsedEvents;
}

module.exports = {
  EVENT_SYNC_SOURCE_TYPE_ICS,
  EVENT_SYNC_SOURCE_TYPE_WIX_PUBLISHED_CALENDAR,
  EVENT_TIME_ZONE_SOURCE_FEED,
  EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT,
  buildExternalEventKey,
  buildUidToIcsBlockMap,
  dateEndToUtc,
  dateStartToUtc,
  extractLastHttpUrlFromDescription,
  extractValueDatesFromIcsBlock,
  hasExternalEventAddressChanged,
  hasExternalEventContentChanges,
  hasExternalEventPlaceFields,
  hasStoredEventCoordinates,
  normalizeAllDaySchedule,
  normalizeAllDayScheduleUtc,
  normalizeEventSyncSourceDefaultTimeZone,
  normalizeEventSyncSourceType,
  normalizeImportedEventDescription,
  normalizeImportedTimeZone,
  parseExternalEventsFromIcs,
  parseExternalEventsFromWixPublishedCalendar,
  normalizeRecurrenceId,
  removeExtractedWebsiteUrlFromDescription,
  resolveAllDaySchedule,
  shouldGeocodeExternalEventAddress,
};
