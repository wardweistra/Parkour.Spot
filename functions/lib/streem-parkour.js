/**
 * Streem Parkour Basel helpers for event sync.
 *
 * Events live in a static homepage dialog:
 *   <dialog id="events"> … <div class="event">…</div> …
 *
 * There is no ICS or JSON API. Accepts the site homepage URL and fetches HTML.
 */

const {
  EVENT_TIME_ZONE_SOURCE_FEED,
  EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT,
  buildExternalEventKey,
  dateEndToUtc,
  dateStartToUtc,
  normalizeEventSyncSourceDefaultTimeZone,
  normalizeImportedEventDescription,
} = require("./event-sync");
const {htmlToPlainText} = require("./html-plain-text");

const STREEM_PARKOUR_HOSTS = new Set([
  "streemparkour.com",
  "www.streemparkour.com",
]);
const STREEM_PARKOUR_ORIGIN = "https://www.streemparkour.com";
const STREEM_PARKOUR_PUBLIC_URL = `${STREEM_PARKOUR_ORIGIN}/`;
const STREEM_PARKOUR_FALLBACK_EVENT_URL = `${STREEM_PARKOUR_ORIGIN}/#events`;
/** Implied local timezone for Swiss date-only listings. */
const STREEM_PARKOUR_DEFAULT_TIME_ZONE = "Europe/Zurich";
const MAX_EVENTS = 500;

const GERMAN_MONTHS = {
  januar: 1,
  februar: 2,
  marz: 3,
  märz: 3,
  april: 4,
  mai: 5,
  juni: 6,
  juli: 7,
  august: 8,
  september: 9,
  oktober: 10,
  november: 11,
  dezember: 12,
};

const WEEKDAY_PREFIX_RE =
  /^(?:montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag)\s*,\s*/i;

const DIALOG_EVENTS_RE =
  /<dialog\b[^>]*\bid\s*=\s*['"]events['"][^>]*>([\s\S]*?)<\/dialog>/i;
const EVENT_CARD_RE = /<div\s+class=['"]event['"]>([\s\S]*?)<\/div>/gi;
const DATE_SPAN_RE =
  /<span\s+class=['"]text--strong['"]>([\s\S]*?)<\/span>/i;
const NOTE_ITALIC_RE = /<i>\(([\s\S]*?)\)<\/i>/i;
const TITLE_LINK_RE =
  /<a\b[^>]*\bhref\s*=\s*['"]([^'"]*)['"][^>]*>([\s\S]*?)<\/a>/i;
const TEXT_NOTE_RE = /<p\s+class=['"]text--note['"]>([\s\S]*?)<\/p>/gi;

/**
 * @param {*} value
 * @return {string|null}
 */
function toNonEmptyString(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * @param {string} hostname
 * @return {boolean}
 */
function isStreemParkourHost(hostname) {
  return STREEM_PARKOUR_HOSTS.has(String(hostname || "").toLowerCase());
}

/**
 * Normalizes a Streem Parkour page URL to the canonical homepage feed URL.
 * @param {*} value
 * @return {string}
 */
function normalizeStreemParkourFeedUrl(value) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error("icsUrl is required");
  }
  const trimmed = value.trim();
  let parsed;
  try {
    parsed = new URL(trimmed);
  } catch (_) {
    throw new Error("icsUrl must be a valid URL");
  }
  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    throw new Error("icsUrl must use http or https");
  }
  if (!isStreemParkourHost(parsed.hostname)) {
    throw new Error(
        "streemParkour icsUrl must point to streemparkour.com",
    );
  }
  return STREEM_PARKOUR_PUBLIC_URL;
}

/**
 * Public homepage URL for Streem Parkour.
 * @param {string=} _feedUrl
 * @return {string}
 */
function streemParkourPublicUrl(_feedUrl) {
  return STREEM_PARKOUR_PUBLIC_URL;
}

/**
 * @param {string} htmlFragment
 * @return {string}
 */
function plainTextFromFragment(htmlFragment) {
  return htmlToPlainText(String(htmlFragment || "")).replace(/\s+/g, " ")
      .trim();
}

/**
 * @param {string} monthToken
 * @return {number|null}
 */
function germanMonthNumber(monthToken) {
  const key = String(monthToken || "")
      .trim()
      .toLowerCase()
      .normalize("NFC");
  if (Object.prototype.hasOwnProperty.call(GERMAN_MONTHS, key)) {
    return GERMAN_MONTHS[key];
  }
  // ASCII-fold ä → a for "März" variants without combining marks.
  const folded = key.replace(/ä/g, "a").replace(/ö/g, "o").replace(/ü/g, "u");
  if (Object.prototype.hasOwnProperty.call(GERMAN_MONTHS, folded)) {
    return GERMAN_MONTHS[folded];
  }
  return null;
}

/**
 * @param {number} year
 * @param {number} month
 * @param {number} day
 * @return {{year: number, month: number, day: number}|null}
 */
function validYmd(year, month, day) {
  if (!Number.isInteger(year) || !Number.isInteger(month) ||
      !Number.isInteger(day)) {
    return null;
  }
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  const probe = new Date(Date.UTC(year, month - 1, day));
  if (
    probe.getUTCFullYear() !== year ||
    probe.getUTCMonth() !== month - 1 ||
    probe.getUTCDate() !== day
  ) {
    return null;
  }
  return {year, month, day};
}

/**
 * Formats a YMD parts object as YYYY-MM-DD.
 * @param {{year: number, month: number, day: number}} parts
 * @return {string}
 */
function formatYmd(parts) {
  const mm = String(parts.month).padStart(2, "0");
  const dd = String(parts.day).padStart(2, "0");
  return `${parts.year}-${mm}-${dd}`;
}

const CROSS_MONTH_RANGE_RE = new RegExp(
    "^(\\d{1,2})\\.\\s*([A-Za-zÄÖÜäöü]+)\\s*[-–—]\\s*" +
    "(\\d{1,2})\\.\\s*([A-Za-zÄÖÜäöü]+)\\s+(\\d{4})$",
    "u",
);
const SAME_MONTH_RANGE_RE = new RegExp(
    "^(\\d{1,2})\\.\\s*(?:bis|und|[-–—])\\s*" +
    "(\\d{1,2})\\.\\s*([A-Za-zÄÖÜäöü]+)\\s+(\\d{4})$",
    "iu",
);
const SINGLE_DAY_RE = new RegExp(
    "^(\\d{1,2})\\.\\s*([A-Za-zÄÖÜäöü]+)\\s+(\\d{4})$",
    "u",
);

/**
 * Parses German date / date-range strings from Streem event cards.
 * Examples: "Samstag, 11. April 2026", "27. Juli - 02. August 2026",
 * "13. und 14. September 2025", "05. bis 11. Juli 2025".
 * @param {*} raw
 * @return {Object|null} `{start, end}` YMD parts; `end` may be null.
 */
function parseGermanEventDate(raw) {
  const text = toNonEmptyString(raw);
  if (!text) return null;
  let cleaned = text.replace(WEEKDAY_PREFIX_RE, "").trim();
  cleaned = cleaned.replace(/\s+/g, " ");

  // Range with two months: 27. Juli - 02. August 2026
  let match = CROSS_MONTH_RANGE_RE.exec(cleaned);
  if (match) {
    const startMonth = germanMonthNumber(match[2]);
    const endMonth = germanMonthNumber(match[4]);
    const year = Number(match[5]);
    const start = validYmd(year, startMonth, Number(match[1]));
    const end = validYmd(year, endMonth, Number(match[3]));
    if (!start || !end) return null;
    return {start, end};
  }

  // Same-month range: 05. bis 11. Juli 2025 / 13. und 14. September 2025
  match = SAME_MONTH_RANGE_RE.exec(cleaned);
  if (match) {
    const month = germanMonthNumber(match[3]);
    const year = Number(match[4]);
    const start = validYmd(year, month, Number(match[1]));
    const end = validYmd(year, month, Number(match[2]));
    if (!start || !end) return null;
    return {start, end};
  }

  // Single day: 11. April 2026
  match = SINGLE_DAY_RE.exec(cleaned);
  if (match) {
    const month = germanMonthNumber(match[2]);
    const start = validYmd(Number(match[3]), month, Number(match[1]));
    if (!start) return null;
    return {start, end: null};
  }

  return null;
}

/**
 * Builds a stable slug fragment for externalEventUid.
 * @param {string} title
 * @return {string}
 */
function normalizeTitleSlug(title) {
  const folded = String(title || "")
      .normalize("NFKD")
      .replace(/[\u0300-\u036f]/g, "")
      .toLowerCase();
  const slug = folded
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .replace(/-{2,}/g, "-");
  return slug || "event";
}

/**
 * @param {string} title
 * @param {{year: number, month: number, day: number}} start
 * @return {string}
 */
function buildStreemExternalEventUid(title, start) {
  return `streem:${normalizeTitleSlug(title)}:${formatYmd(start)}`;
}

/**
 * @param {string|null} href
 * @return {string}
 */
function resolveEventWebsiteUrl(href) {
  const raw = toNonEmptyString(href);
  if (!raw) return STREEM_PARKOUR_FALLBACK_EVENT_URL;
  try {
    const parsed = new URL(raw, STREEM_PARKOUR_ORIGIN);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return STREEM_PARKOUR_FALLBACK_EVENT_URL;
    }
    return parsed.toString();
  } catch (_) {
    return STREEM_PARKOUR_FALLBACK_EVENT_URL;
  }
}

/**
 * @param {{year: number, month: number, day: number}} start
 * @param {{year: number, month: number, day: number}|null} end
 * @param {string|null} timeZone
 * @param {string|null} timeZoneSource
 * @return {Object}
 */
function resolveDateOnlySchedule(start, end, timeZone, timeZoneSource) {
  const startAt = timeZone ?
    dateStartToUtc(start.year, start.month, start.day, timeZone) :
    new Date(Date.UTC(start.year, start.month - 1, start.day, 0, 0, 0, 0));
  let endAt = null;
  const endParts = end || start;
  if (endParts) {
    endAt = timeZone ?
      dateEndToUtc(endParts.year, endParts.month, endParts.day, timeZone) :
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
  return {
    startAt,
    endAt,
    isDateOnly: true,
    timeZone: timeZone || null,
    timeZoneSource: timeZone ? timeZoneSource : null,
  };
}

/**
 * Parses one Streem `.event` card HTML fragment.
 * @param {string} cardHtml
 * @return {Object|null}
 */
function parseStreemEventCard(cardHtml) {
  const dateMatch = DATE_SPAN_RE.exec(cardHtml);
  if (!dateMatch) return null;
  const dateText = plainTextFromFragment(dateMatch[1]);
  const parsedDate = parseGermanEventDate(dateText);
  if (!parsedDate) return null;

  const linkMatch = TITLE_LINK_RE.exec(cardHtml);
  if (!linkMatch) return null;
  const title = plainTextFromFragment(linkMatch[2]);
  if (!title) return null;

  const noteMatch = NOTE_ITALIC_RE.exec(cardHtml);
  const participantNote = noteMatch ?
    toNonEmptyString(plainTextFromFragment(noteMatch[1])) :
    null;

  let address = null;
  TEXT_NOTE_RE.lastIndex = 0;
  let noteMatchIter;
  while ((noteMatchIter = TEXT_NOTE_RE.exec(cardHtml)) !== null) {
    const noteHtml = noteMatchIter[1];
    // Skip the date line (contains text--strong).
    if (/text--strong/i.test(noteHtml)) continue;
    const loc = plainTextFromFragment(noteHtml);
    if (loc) address = loc;
  }

  return {
    title,
    href: linkMatch[1],
    participantNote,
    address,
    start: parsedDate.start,
    end: parsedDate.end,
  };
}

/**
 * Parses Streem homepage HTML into external event payloads.
 * @param {string} html
 * @param {Object} sourceMeta
 * @param {string} sourceMeta.sourceId
 * @param {string} sourceMeta.sourceName
 * @param {string=} sourceMeta.sourceDefaultTimeZone
 * @return {Array<Object>}
 */
function parseStreemParkourHtml(
    html,
    {sourceId, sourceName, sourceDefaultTimeZone = null},
) {
  if (typeof html !== "string" || html.trim().length === 0) {
    throw new Error("Streem Parkour page HTML is required");
  }

  const dialogMatch = DIALOG_EVENTS_RE.exec(html);
  if (!dialogMatch) {
    throw new Error(
        "Streem Parkour page did not include an events dialog",
    );
  }

  const normalizedSourceDefaultTimeZone =
    normalizeEventSyncSourceDefaultTimeZone(sourceDefaultTimeZone);

  let timeZone = STREEM_PARKOUR_DEFAULT_TIME_ZONE;
  let timeZoneSource = EVENT_TIME_ZONE_SOURCE_FEED;
  if (normalizedSourceDefaultTimeZone) {
    timeZone = normalizedSourceDefaultTimeZone;
    timeZoneSource = EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT;
  }

  const dialogHtml = dialogMatch[1];
  const parsedEvents = [];
  EVENT_CARD_RE.lastIndex = 0;
  let cardMatch;
  while ((cardMatch = EVENT_CARD_RE.exec(dialogHtml)) !== null) {
    if (parsedEvents.length >= MAX_EVENTS) break;
    const card = parseStreemEventCard(cardMatch[1]);
    if (!card) continue;

    const schedule = resolveDateOnlySchedule(
        card.start,
        card.end,
        timeZone,
        timeZoneSource,
    );
    const uid = buildStreemExternalEventUid(card.title, card.start);
    const description = normalizeImportedEventDescription(
        card.participantNote || "",
    );
    const websiteUrl = resolveEventWebsiteUrl(card.href);

    const eventPayload = {
      title: card.title,
      description,
      websiteUrl,
      address: card.address,
      startAt: schedule.startAt,
      endAt: schedule.endAt,
      isDateOnly: true,
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
    parsedEvents.push(eventPayload);
  }

  if (parsedEvents.length === 0) {
    throw new Error("Streem Parkour events dialog had no usable events");
  }
  return parsedEvents;
}

module.exports = {
  STREEM_PARKOUR_DEFAULT_TIME_ZONE,
  STREEM_PARKOUR_FALLBACK_EVENT_URL,
  STREEM_PARKOUR_ORIGIN,
  STREEM_PARKOUR_PUBLIC_URL,
  MAX_EVENTS,
  buildStreemExternalEventUid,
  isStreemParkourHost,
  normalizeStreemParkourFeedUrl,
  normalizeTitleSlug,
  parseGermanEventDate,
  parseStreemParkourHtml,
  streemParkourPublicUrl,
};
