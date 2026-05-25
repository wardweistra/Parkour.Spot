const ical = require("node-ical");

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
 * Decodes a small set of HTML entities (for extracted URLs and text snippets).
 * @param {string} s
 * @return {string}
 */
function decodeBasicHtmlEntities(s) {
  if (!s) return "";
  return s
      .replace(/&amp;/gi, "&")
      .replace(/&lt;/gi, "<")
      .replace(/&gt;/gi, ">")
      .replace(/&quot;/gi, "\"")
      .replace(/&#39;/g, "'")
      .replace(/&apos;/gi, "'");
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
  const text = raw
      .replace(/<br\s*\/?>/gi, "\n")
      .replace(/<[^>]*>/g, "")
      .replace(/&nbsp;/g, " ")
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, "\"")
      .replace(/&apos;/g, "'")
      .replace(/&#39;/g, "'")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
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
 * Checks whether this event should attempt address geocoding now.
 * - Always true for creates with an address.
 * - True when the address changed to another non-empty value.
 * - True when the address matches but lat/lon are missing or invalid.
 * @param {Object|null|undefined} existingData
 * @param {Object} incomingData
 * @return {boolean}
 */
function shouldGeocodeExternalEventAddress(existingData, incomingData) {
  const incomingAddress = toNonEmptyString(
      incomingData ? incomingData.address : null,
  );
  if (!incomingAddress) return false;
  if (!existingData) return true;
  if (hasExternalEventAddressChanged(existingData, incomingData)) return true;
  return !hasStoredEventCoordinates(existingData);
}

/**
 * Parses VEVENT records from an ICS file into normalized event payloads.
 * @param {string} icsText
 * @param {Object} sourceMeta
 * @param {string} sourceMeta.sourceId
 * @param {string} sourceMeta.sourceName
 * @return {Array<Object>}
 */
function parseExternalEventsFromIcs(icsText, {sourceId, sourceName}) {
  const parsedCalendar = ical.sync.parseICS(icsText);
  const parsedEvents = [];
  const calendarTimeZone = extractCalendarTimeZone(parsedCalendar);
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

    if (isAllDay) {
      if (!calendarTimeZone) {
        console.warn(
            `Skipping all-day ICS event "${value.summary || uid}": ` +
            "calendar has no valid X-WR-TIMEZONE",
        );
        continue;
      }
      const icsBlock = uidToIcsBlock.get(uid);
      if (!icsBlock) {
        console.warn(
            `Skipping all-day ICS event "${value.summary || uid}": ` +
            "VEVENT block not found in raw ICS",
        );
        continue;
      }
      const schedule = normalizeAllDaySchedule(icsBlock, calendarTimeZone);
      if (!schedule) {
        console.warn(
            `Skipping all-day ICS event "${value.summary || uid}": ` +
            "could not parse VALUE=DATE bounds",
        );
        continue;
      }
      startAt = schedule.startAt;
      endAt = schedule.endAt;
      isDateOnly = schedule.isDateOnly;
      timeZone = schedule.timeZone;
    } else {
      startAt = normalizeDate(value.start);
      endAt = normalizeDate(value.end);
      isDateOnly = false;
      timeZone = extractEventTimeZoneFromNodeIcal(value);
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
    parsedEvents.push(eventPayload);
  }

  return parsedEvents;
}

module.exports = {
  buildExternalEventKey,
  buildUidToIcsBlockMap,
  dateEndToUtc,
  dateStartToUtc,
  extractLastHttpUrlFromDescription,
  extractValueDatesFromIcsBlock,
  hasExternalEventAddressChanged,
  hasExternalEventContentChanges,
  normalizeAllDaySchedule,
  normalizeImportedEventDescription,
  normalizeImportedTimeZone,
  parseExternalEventsFromIcs,
  normalizeRecurrenceId,
  removeExtractedWebsiteUrlFromDescription,
  shouldGeocodeExternalEventAddress,
};
