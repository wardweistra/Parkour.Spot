/* eslint-disable max-len */
/**
 * Per-user secret iCal feed for Going / Interested RSVPs.
 */

const {hashApiKey, generateCalendarToken} = require("./api-helpers");

const CALENDAR_FEEDS_COLLECTION = "calendarFeeds";
const CALENDAR_FEED_BY_TOKEN_COLLECTION = "calendarFeedByToken";
const PUBLIC_ORIGIN = "https://parkour.spot";
const CAL_NAME = "ParkourSpot — My events";
const INTERESTED_PREFIX = "[Interested] ";

/**
 * @param {string} token
 * @return {string}
 */
function calendarFeedUrl(token) {
  return `${PUBLIC_ORIGIN}/calendar/${encodeURIComponent(token)}.ics`;
}

/**
 * @param {string} path
 * @return {string|null}
 */
function extractCalendarTokenFromPath(path) {
  if (typeof path !== "string") return null;
  const normalized = path.split("?")[0];
  const match = normalized.match(/\/calendar\/([^/]+?)(?:\.ics)?\/?$/i);
  if (!match) return null;
  try {
    return decodeURIComponent(match[1]).trim() || null;
  } catch (e) {
    return match[1].trim() || null;
  }
}

/**
 * Escape text for ICS SUMMARY / DESCRIPTION / LOCATION.
 * @param {string} value
 * @return {string}
 */
function escapeIcsText(value) {
  return String(value)
      .replace(/\\/g, "\\\\")
      .replace(/\r\n/g, "\\n")
      .replace(/\n/g, "\\n")
      .replace(/\r/g, "\\n")
      .replace(/;/g, "\\;")
      .replace(/,/g, "\\,");
}

/**
 * Fold a content line to RFC 5545 line length (75 octets), CRLF + space.
 * @param {string} line
 * @return {string}
 */
function foldIcsLine(line) {
  const limit = 75;
  if (Buffer.byteLength(line, "utf8") <= limit) {
    return line;
  }
  const parts = [];
  let remaining = line;
  let first = true;
  while (remaining.length > 0) {
    const maxChars = first ? limit : limit - 1;
    let cut = Math.min(remaining.length, maxChars);
    while (cut > 1 && Buffer.byteLength(remaining.slice(0, cut), "utf8") > maxChars) {
      cut -= 1;
    }
    if (cut < 1) cut = 1;
    parts.push(first ? remaining.slice(0, cut) : " " + remaining.slice(0, cut));
    remaining = remaining.slice(cut);
    first = false;
  }
  return parts.join("\r\n");
}

/**
 * @param {Date} date
 * @return {string} YYYYMMDDTHHMMSSZ
 */
function formatIcsDateTimeUtc(date) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  const hh = String(date.getUTCHours()).padStart(2, "0");
  const mm = String(date.getUTCMinutes()).padStart(2, "0");
  const ss = String(date.getUTCSeconds()).padStart(2, "0");
  return `${y}${m}${d}T${hh}${mm}${ss}Z`;
}

/**
 * @param {Date} date
 * @return {string} YYYYMMDD (UTC calendar date)
 */
function formatIcsDateOnly(date) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}${m}${d}`;
}

/**
 * @param {*} value
 * @return {Date|null}
 */
function toJsDate(value) {
  if (!value) return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }
  if (typeof value.toDate === "function") {
    const d = value.toDate();
    return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
  }
  if (typeof value === "string" || typeof value === "number") {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

/**
 * @param {string|null|undefined} value
 * @return {string|null}
 */
function trimmedId(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * @param {Object|null|undefined} eventData
 * @return {string|null}
 */
function eventLocationLine(eventData) {
  if (!eventData) return null;
  const address = trimmedId(eventData.address);
  if (address) return address;
  const parts = [];
  const city = trimmedId(eventData.city);
  const country = trimmedId(eventData.countryCode);
  if (city) parts.push(city);
  if (country) parts.push(country.toUpperCase());
  if (parts.length) return parts.join(", ");
  const resolved = eventData.resolvedLocation;
  if (resolved && typeof resolved === "object") {
    const label = trimmedId(resolved.label) || trimmedId(resolved.name);
    if (label) return label;
  }
  return null;
}

/**
 * Join interests to events, remap duplicates to native, Going wins.
 * Mirrors Flutter partitionMyEvents (without upcoming/past split).
 * @param {Array<{eventId: string, status: string}>} interests
 * @param {Object<string, Object>} eventsById map id -> {id, ...fields}
 * @return {Array<{eventId: string, status: string, event: Object}>}
 */
function selectFeedEntries(interests, eventsById) {
  const byCanonical = new Map();
  for (const interest of interests) {
    const listingId = trimmedId(interest.eventId);
    if (!listingId) continue;
    const listing = eventsById[listingId];
    if (!listing) continue;
    const nativeId = trimmedId(listing.duplicateOf);
    const display = nativeId && eventsById[nativeId] ?
      eventsById[nativeId] :
      listing;
    const displayId = trimmedId(display.id) || nativeId || listingId;
    const status = interest.status === "going" ? "going" : "interested";
    const existing = byCanonical.get(displayId);
    if (!existing || (existing.status !== "going" && status === "going")) {
      byCanonical.set(displayId, {
        eventId: displayId,
        status,
        event: display,
      });
    }
  }
  return Array.from(byCanonical.values()).sort((a, b) => {
    const aStart = toJsDate(a.event.startAt) || new Date(0);
    const bStart = toJsDate(b.event.startAt) || new Date(0);
    const startCmp = aStart.getTime() - bStart.getTime();
    if (startCmp !== 0) return startCmp;
    const aTitle = String(a.event.title || "").toLowerCase();
    const bTitle = String(b.event.title || "").toLowerCase();
    return aTitle.localeCompare(bTitle);
  });
}

/**
 * @param {{eventId: string, status: string, event: Object}} entry
 * @return {string[]} ICS lines for one VEVENT (unfolded content lines)
 */
function buildVEventLines(entry) {
  const event = entry.event || {};
  const eventId = trimmedId(entry.eventId) || "unknown";
  const title = typeof event.title === "string" && event.title.trim() ?
    event.title.trim() :
    "Untitled event";
  const summary = entry.status === "interested" ?
    `${INTERESTED_PREFIX}${title}` :
    title;
  const startAt = toJsDate(event.startAt);
  if (!startAt) return [];

  const endAt = toJsDate(event.endAt);
  const isDateOnly = event.isDateOnly === true;
  const url = `${PUBLIC_ORIGIN}/event/${encodeURIComponent(eventId)}`;
  const location = eventLocationLine(event);
  const updatedAt = toJsDate(event.updatedAt) || startAt;

  const lines = [
    "BEGIN:VEVENT",
    `UID:${eventId}@parkour.spot`,
    `DTSTAMP:${formatIcsDateTimeUtc(new Date())}`,
    `LAST-MODIFIED:${formatIcsDateTimeUtc(updatedAt)}`,
  ];

  if (isDateOnly) {
    const startDate = formatIcsDateOnly(startAt);
    let endDate;
    if (endAt) {
      // VALUE=DATE DTEND is exclusive; if end is same calendar day, add one day.
      const endExclusive = new Date(Date.UTC(
          endAt.getUTCFullYear(),
          endAt.getUTCMonth(),
          endAt.getUTCDate() + 1,
      ));
      endDate = formatIcsDateOnly(endExclusive);
    } else {
      const next = new Date(Date.UTC(
          startAt.getUTCFullYear(),
          startAt.getUTCMonth(),
          startAt.getUTCDate() + 1,
      ));
      endDate = formatIcsDateOnly(next);
    }
    lines.push(`DTSTART;VALUE=DATE:${startDate}`);
    lines.push(`DTEND;VALUE=DATE:${endDate}`);
  } else {
    lines.push(`DTSTART:${formatIcsDateTimeUtc(startAt)}`);
    const effectiveEnd = endAt && endAt.getTime() > startAt.getTime() ?
      endAt :
      new Date(startAt.getTime() + 60 * 60 * 1000);
    lines.push(`DTEND:${formatIcsDateTimeUtc(effectiveEnd)}`);
  }

  lines.push(`SUMMARY:${escapeIcsText(summary)}`);
  lines.push(`URL:${url}`);
  const descriptionParts = [
    entry.status === "interested" ? "Status: Interested" : "Status: Going",
    `Open on ParkourSpot: ${url}`,
  ];
  lines.push(`DESCRIPTION:${escapeIcsText(descriptionParts.join("\n"))}`);
  if (location) {
    lines.push(`LOCATION:${escapeIcsText(location)}`);
  }
  lines.push("END:VEVENT");
  return lines;
}

/**
 * @param {Array<{eventId: string, status: string, event: Object}>} entries
 * @return {string} full ICS document
 */
function buildIcsCalendar(entries) {
  const lines = [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//ParkourSpot//My Events//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    `X-WR-CALNAME:${escapeIcsText(CAL_NAME)}`,
  ];
  for (const entry of entries) {
    lines.push(...buildVEventLines(entry));
  }
  lines.push("END:VCALENDAR");
  return lines.map(foldIcsLine).join("\r\n") + "\r\n";
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @return {Promise<Array<{eventId: string, status: string, event: Object}>>}
 */
async function loadFeedEntriesForUser(db, userId) {
  const interestsSnap = await db
      .collection("users")
      .doc(userId)
      .collection("eventInterests")
      .get();

  const interests = [];
  for (const doc of interestsSnap.docs) {
    const data = doc.data() || {};
    const status = data.status === "going" ? "going" :
      (data.status === "interested" ? "interested" : null);
    if (!status) continue;
    const eventId = trimmedId(data.eventId) || trimmedId(doc.id);
    if (!eventId) continue;
    interests.push({eventId, status});
  }

  if (interests.length === 0) {
    return [];
  }

  const idSet = new Set(interests.map((i) => i.eventId));
  const eventsById = {};

  const fetchIds = async (ids) => {
    const unique = [...ids].filter((id) => id && !eventsById[id]);
    const chunkSize = 30;
    for (let i = 0; i < unique.length; i += chunkSize) {
      const chunk = unique.slice(i, i + chunkSize);
      await Promise.all(chunk.map(async (id) => {
        const snap = await db.collection("events").doc(id).get();
        if (snap.exists) {
          eventsById[id] = {id, ...snap.data()};
        }
      }));
    }
  };

  await fetchIds(idSet);

  const missingNative = new Set();
  for (const event of Object.values(eventsById)) {
    const nativeId = trimmedId(event.duplicateOf);
    if (nativeId && !eventsById[nativeId]) {
      missingNative.add(nativeId);
    }
  }
  if (missingNative.size > 0) {
    await fetchIds(missingNative);
  }

  return selectFeedEntries(interests, eventsById);
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {*} FieldValue
 * @param {string} userId
 * @return {Promise<{token: string, url: string, created: boolean}>}
 */
async function getOrCreateCalendarFeed(db, FieldValue, userId) {
  const feedRef = db.collection(CALENDAR_FEEDS_COLLECTION).doc(userId);
  const existing = await feedRef.get();
  if (existing.exists) {
    const data = existing.data() || {};
    const token = trimmedId(data.token);
    if (token) {
      return {token, url: calendarFeedUrl(token), created: false};
    }
  }

  const token = generateCalendarToken();
  const tokenHash = hashApiKey(token);
  const batch = db.batch();
  batch.set(feedRef, {
    token,
    tokenHash,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  batch.set(db.collection(CALENDAR_FEED_BY_TOKEN_COLLECTION).doc(tokenHash), {
    userId,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {token, url: calendarFeedUrl(token), created: true};
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {*} FieldValue
 * @param {string} userId
 * @return {Promise<{token: string, url: string}>}
 */
async function regenerateCalendarFeed(db, FieldValue, userId) {
  const feedRef = db.collection(CALENDAR_FEEDS_COLLECTION).doc(userId);
  const existing = await feedRef.get();
  const oldHash = existing.exists ?
    trimmedId((existing.data() || {}).tokenHash) :
    null;

  const token = generateCalendarToken();
  const tokenHash = hashApiKey(token);
  const batch = db.batch();
  if (oldHash && oldHash !== tokenHash) {
    batch.delete(db.collection(CALENDAR_FEED_BY_TOKEN_COLLECTION).doc(oldHash));
  }
  batch.set(feedRef, {
    token,
    tokenHash,
    createdAt: existing.exists ?
      ((existing.data() || {}).createdAt || FieldValue.serverTimestamp()) :
      FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  batch.set(db.collection(CALENDAR_FEED_BY_TOKEN_COLLECTION).doc(tokenHash), {
    userId,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {token, url: calendarFeedUrl(token)};
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} token
 * @return {Promise<string|null>} userId
 */
async function resolveUserIdFromCalendarToken(db, token) {
  const trimmed = trimmedId(token);
  if (!trimmed) return null;
  const tokenHash = hashApiKey(trimmed);
  const snap = await db
      .collection(CALENDAR_FEED_BY_TOKEN_COLLECTION)
      .doc(tokenHash)
      .get();
  if (!snap.exists) return null;
  return trimmedId((snap.data() || {}).userId);
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @return {Promise<string>}
 */
async function buildIcsForUser(db, userId) {
  const entries = await loadFeedEntriesForUser(db, userId);
  return buildIcsCalendar(entries);
}

module.exports = {
  CALENDAR_FEEDS_COLLECTION,
  CALENDAR_FEED_BY_TOKEN_COLLECTION,
  PUBLIC_ORIGIN,
  CAL_NAME,
  INTERESTED_PREFIX,
  calendarFeedUrl,
  extractCalendarTokenFromPath,
  escapeIcsText,
  foldIcsLine,
  formatIcsDateTimeUtc,
  formatIcsDateOnly,
  toJsDate,
  selectFeedEntries,
  buildVEventLines,
  buildIcsCalendar,
  loadFeedEntriesForUser,
  getOrCreateCalendarFeed,
  regenerateCalendarFeed,
  resolveUserIdFromCalendarToken,
  buildIcsForUser,
};
