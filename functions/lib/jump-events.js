/**
 * Jump Events NL helpers for event sync.
 *
 * Public agenda JSON:
 *   GET https://jumpevents.nl/api/events
 *
 * Accepts the site homepage or the API URL and normalizes to the API endpoint.
 */

const JUMP_EVENTS_HOSTS = new Set(["jumpevents.nl", "www.jumpevents.nl"]);
const JUMP_EVENTS_API_PATH = "/api/events";
const JUMP_EVENTS_ORIGIN = "https://jumpevents.nl";
const JUMP_EVENTS_PUBLIC_URL = `${JUMP_EVENTS_ORIGIN}/`;
const JUMP_EVENTS_API_URL = `${JUMP_EVENTS_ORIGIN}${JUMP_EVENTS_API_PATH}`;
/** Implied local timezone for NL agenda times when no source default is set. */
const JUMP_EVENTS_DEFAULT_TIME_ZONE = "Europe/Amsterdam";
const MAX_EVENTS = 500;

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
function isJumpEventsHost(hostname) {
  return JUMP_EVENTS_HOSTS.has(String(hostname || "").toLowerCase());
}

/**
 * Normalizes a Jump Events NL page or API URL to the events JSON endpoint.
 * @param {*} value
 * @return {string}
 */
function normalizeJumpEventsFeedUrl(value) {
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
  if (!isJumpEventsHost(parsed.hostname)) {
    throw new Error(
        "jumpEventsNl icsUrl must point to jumpevents.nl " +
        "(homepage or /api/events)",
    );
  }
  return JUMP_EVENTS_API_URL;
}

/**
 * Public agenda page URL for Jump Events NL.
 * @param {string=} _feedUrl
 * @return {string}
 */
function jumpEventsPublicUrl(_feedUrl) {
  return JUMP_EVENTS_PUBLIC_URL;
}

/**
 * @param {*} payload
 * @return {boolean}
 */
function isJumpEventsPayload(payload) {
  return Array.isArray(payload);
}

/**
 * Builds an absolute image URL for a Jump Events photo filename.
 * @param {*} photo
 * @return {string|null}
 */
function jumpEventsImageUrl(photo) {
  const filename = toNonEmptyString(photo);
  if (!filename) return null;
  try {
    return new URL(
        `/uploads/${encodeURIComponent(filename)}`,
        JUMP_EVENTS_ORIGIN,
    ).toString();
  } catch (_) {
    return null;
  }
}

/**
 * Builds the public detail page URL for one Jump Events agenda item.
 * @param {*} eventId
 * @param {string=} siteOrigin
 * @return {string|null}
 */
function jumpEventsEventUrl(eventId, siteOrigin = JUMP_EVENTS_ORIGIN) {
  const id = eventId != null ? toNonEmptyString(String(eventId)) : null;
  if (!id) return null;
  const origin = toNonEmptyString(siteOrigin) || JUMP_EVENTS_ORIGIN;
  try {
    return new URL(`/evenement/${encodeURIComponent(id)}`, origin).toString();
  } catch (_) {
    return null;
  }
}

/**
 * Fetches Jump Events NL agenda JSON.
 * @param {string} pageUrl
 * @param {Object} options
 * @param {function(string, Object=): Promise<string>} options.downloadText
 * @return {Promise<Object>}
 */
async function fetchJumpEventsCalendarEvents(pageUrl, {downloadText}) {
  if (typeof downloadText !== "function") {
    throw new Error("downloadText is required");
  }

  const feedUrl = normalizeJumpEventsFeedUrl(pageUrl);
  const text = await downloadText(feedUrl, {
    headers: {
      "Accept": "application/json, text/plain, */*",
    },
  });

  let payload;
  try {
    payload = JSON.parse(text);
  } catch (error) {
    throw new Error(
        `Failed parsing Jump Events JSON: ${error.message}`,
    );
  }
  if (!isJumpEventsPayload(payload)) {
    throw new Error("URL did not return a Jump Events JSON array");
  }

  /** @type {Array<Object>} */
  const items = [];
  const seenIds = new Set();
  for (const item of payload) {
    if (!item || typeof item !== "object") continue;
    const id = item.id != null ? toNonEmptyString(String(item.id)) : null;
    if (id) {
      if (seenIds.has(id)) continue;
      seenIds.add(id);
    }
    items.push(item);
    if (items.length >= MAX_EVENTS) break;
  }

  return {
    items,
    collectionUrl: jumpEventsPublicUrl(feedUrl),
    siteOrigin: JUMP_EVENTS_ORIGIN,
    defaultTimeZone: JUMP_EVENTS_DEFAULT_TIME_ZONE,
  };
}

module.exports = {
  JUMP_EVENTS_API_URL,
  JUMP_EVENTS_DEFAULT_TIME_ZONE,
  JUMP_EVENTS_ORIGIN,
  JUMP_EVENTS_PUBLIC_URL,
  MAX_EVENTS,
  fetchJumpEventsCalendarEvents,
  isJumpEventsHost,
  isJumpEventsPayload,
  jumpEventsImageUrl,
  jumpEventsEventUrl,
  jumpEventsPublicUrl,
  normalizeJumpEventsFeedUrl,
};
