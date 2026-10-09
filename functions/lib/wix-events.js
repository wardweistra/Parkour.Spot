/**
 * Wix Events calendar helpers for event sync.
 *
 * Public Wix Events & Tickets list pages embed an Events app instance JWT and
 * widget compId in SSR HTML. The viewer API then returns paginated event JSON:
 *   GET /_api/wix-one-events-server/web/paginated-events/viewer
 * with Authorization: <instance JWT>.
 *
 * If the API fails or returns nothing, events embedded in appsWarmupData under
 * widgetcomp-* are used as a fallback (upcoming list only).
 */

const MAX_EVENTS = 500;
const MAX_PAGES = 20;
const PAGE_SIZE = 50;
const WIX_EVENTS_APP_DEFINITION_ID = "140603ad-af8d-84a5-2c80-a0f60cb47351";
const WIX_EVENTS_DEFAULT_DETAILS_PATH = "/event-details";

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
 * Normalizes a public Wix Events page URL.
 * @param {*} value
 * @return {string}
 */
function normalizeWixEventsPageUrl(value) {
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
  if (parsed.pathname.includes("/api/published_calendar")) {
    throw new Error(
        "wixEventsCalendar icsUrl must be a public Wix Events page, " +
        "not a BoomTech published_calendar URL",
    );
  }
  parsed.hash = "";
  return parsed.toString();
}

/**
 * Public events page URL (same as the stored feed URL for Wix Events).
 * @param {string} feedUrl
 * @return {string}
 */
function wixEventsPublicUrl(feedUrl) {
  return normalizeWixEventsPageUrl(feedUrl);
}

/**
 * Decode a JWT payload without verifying the signature.
 * @param {string} token
 * @return {Object|null}
 */
function decodeJwtPayload(token) {
  const parts = token.split(".");
  if (parts.length < 2) return null;
  try {
    const payload = parts[1];
    const pad = "=".repeat((4 - (payload.length % 4)) % 4);
    const json = Buffer.from(payload + pad, "base64url").toString("utf8");
    const data = JSON.parse(json);
    return data && typeof data === "object" ? data : null;
  } catch (_) {
    return null;
  }
}

/**
 * @param {string} html
 * @return {string|null}
 */
function extractWixEventsInstanceFromHtml(html) {
  if (typeof html !== "string" || !html) return null;
  const re = /"instance"\s*:\s*"([^"]+)"/g;
  let match;
  while ((match = re.exec(html)) !== null) {
    const token = match[1];
    const payload = decodeJwtPayload(token);
    if (payload && payload.appDefId === WIX_EVENTS_APP_DEFINITION_ID) {
      return token;
    }
  }
  return null;
}

/**
 * @param {string} html
 * @return {Array<string>}
 */
function extractWixEventsCompIdsFromHtml(html) {
  if (typeof html !== "string" || !html) return [];
  const seen = new Set();
  const ids = [];
  const re = /"widgetcomp-([a-zA-Z0-9_-]+)"/g;
  let match;
  while ((match = re.exec(html)) !== null) {
    const compId = `comp-${match[1]}`;
    if (seen.has(compId)) continue;
    seen.add(compId);
    ids.push(compId);
  }
  return ids;
}

/**
 * Extract upcoming events embedded in appsWarmupData widget payloads.
 * @param {string} html
 * @return {Array<Object>}
 */
function extractWixEventsFromWarmupHtml(html) {
  if (typeof html !== "string" || !html) return [];
  const items = [];
  const seenIds = new Set();
  const markerRe =
    /"widgetcomp-[^"]+"\s*:\s*\{\s*"events"\s*:\s*\{\s*"events"\s*:\s*\[/g;
  let marker;
  while ((marker = markerRe.exec(html)) !== null) {
    const searchFrom = marker.index + marker[0].length - 1;
    const start = html.indexOf("[", searchFrom);
    if (start < 0) continue;
    let depth = 0;
    let inStr = false;
    let esc = false;
    let end = -1;
    for (let i = start; i < html.length; i++) {
      const ch = html[i];
      if (inStr) {
        if (esc) {
          esc = false;
        } else if (ch === "\\") {
          esc = true;
        } else if (ch === "\"") {
          inStr = false;
        }
        continue;
      }
      if (ch === "\"") {
        inStr = true;
        continue;
      }
      if (ch === "[") depth += 1;
      else if (ch === "]") {
        depth -= 1;
        if (depth === 0) {
          end = i;
          break;
        }
      }
    }
    if (end < 0) continue;
    let events;
    try {
      events = JSON.parse(html.slice(start, end + 1));
    } catch (_) {
      continue;
    }
    if (!Array.isArray(events)) continue;
    for (const event of events) {
      if (!event || typeof event !== "object") continue;
      const id = event.id != null ? toNonEmptyString(String(event.id)) : null;
      if (id) {
        if (seenIds.has(id)) continue;
        seenIds.add(id);
      }
      items.push(event);
      if (items.length >= MAX_EVENTS) return items;
    }
  }
  return items;
}

/**
 * Finds the event details page path (e.g. "/event-details-registration")
 * from rendered event links on the list page. Sites can rename this page, so
 * the Wix default is only a fallback.
 * @param {string} html
 * @param {string} origin
 * @param {Iterable<string>} slugs
 * @return {string|null}
 */
function extractWixEventsDetailsPathFromHtml(html, origin, slugs) {
  if (typeof html !== "string" || !html) return null;
  const slugSet = new Set();
  for (const slug of slugs) {
    const value = toNonEmptyString(slug);
    if (value) slugSet.add(value);
  }
  if (slugSet.size === 0) return null;

  const counts = new Map();
  const re = /href="([^"]+)"/g;
  let match;
  while ((match = re.exec(html)) !== null) {
    let parsed;
    try {
      parsed = new URL(match[1].replace(/&amp;/g, "&"), origin);
    } catch (_) {
      continue;
    }
    if (parsed.origin !== origin) continue;
    const segments = parsed.pathname.split("/").filter(Boolean);
    if (segments.length < 2) continue;
    let last;
    try {
      last = decodeURIComponent(segments[segments.length - 1]);
    } catch (_) {
      continue;
    }
    if (!slugSet.has(last)) continue;
    const prefix = `/${segments.slice(0, -1).join("/")}`;
    counts.set(prefix, (counts.get(prefix) || 0) + 1);
  }

  let best = null;
  let bestCount = 0;
  for (const [prefix, count] of counts) {
    if (count > bestCount) {
      best = prefix;
      bestCount = count;
    }
  }
  return best;
}

/**
 * @param {string} pageUrl
 * @param {Object} options
 * @param {function(string, Object=): Promise<string>} options.downloadText
 * @return {Promise<Object>}
 */
async function fetchWixEventsCalendarEvents(pageUrl, {downloadText}) {
  if (typeof downloadText !== "function") {
    throw new Error("downloadText is required");
  }

  const feedUrl = normalizeWixEventsPageUrl(pageUrl);
  const origin = new URL(feedUrl).origin;
  const html = await downloadText(feedUrl);
  const instance = extractWixEventsInstanceFromHtml(html);
  const compIds = extractWixEventsCompIdsFromHtml(html);

  /** @type {Array<Object>} */
  const items = [];
  const seenIds = new Set();

  /**
   * @param {Object} event
   */
  function pushEvent(event) {
    if (!event || typeof event !== "object") return;
    const id = event.id != null ? toNonEmptyString(String(event.id)) : null;
    if (id) {
      if (seenIds.has(id)) return;
      seenIds.add(id);
    }
    items.push(event);
  }

  if (instance && compIds.length > 0) {
    let apiFailed = false;
    for (const compId of compIds) {
      if (items.length >= MAX_EVENTS || apiFailed) break;
      let offset = 0;
      let pages = 0;
      let hasMore = true;
      while (
        hasMore &&
        pages < MAX_PAGES &&
        items.length < MAX_EVENTS
      ) {
        pages += 1;
        const apiUrl = new URL(
            "/_api/wix-one-events-server/web/paginated-events/viewer",
            origin,
        );
        apiUrl.searchParams.set("compId", compId);
        apiUrl.searchParams.set("limit", String(PAGE_SIZE));
        apiUrl.searchParams.set("offset", String(offset));
        apiUrl.searchParams.set("fetchBadges", "true");

        let text;
        try {
          text = await downloadText(apiUrl.toString(), {
            headers: {
              "Authorization": instance,
              "Accept": "application/json",
            },
          });
        } catch (_) {
          apiFailed = true;
          hasMore = false;
          break;
        }

        let payload;
        try {
          payload = JSON.parse(text);
        } catch (error) {
          throw new Error(
              `Failed parsing Wix Events viewer JSON: ${error.message}`,
          );
        }
        if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
          throw new Error(
              "URL did not return a Wix Events viewer JSON response",
          );
        }

        const pageEvents = Array.isArray(payload.events) ? payload.events : [];
        for (const event of pageEvents) {
          pushEvent(event);
          if (items.length >= MAX_EVENTS) break;
        }

        hasMore = payload.hasMore === true && pageEvents.length > 0;
        offset += pageEvents.length;
        if (pageEvents.length === 0) hasMore = false;
      }
    }
  }

  if (items.length === 0) {
    const warmupEvents = extractWixEventsFromWarmupHtml(html);
    for (const event of warmupEvents) {
      pushEvent(event);
      if (items.length >= MAX_EVENTS) break;
    }
  }

  if (items.length === 0) {
    throw new Error(
        "Could not find Wix Events data on the page " +
        "(missing Events widget instance or event list)",
    );
  }

  const eventDetailsPath = extractWixEventsDetailsPathFromHtml(
      html,
      origin,
      items.map((event) => event.slug),
  ) || WIX_EVENTS_DEFAULT_DETAILS_PATH;

  return {
    items,
    collectionUrl: wixEventsPublicUrl(feedUrl),
    siteOrigin: origin,
    eventDetailsPath,
  };
}

module.exports = {
  MAX_EVENTS,
  MAX_PAGES,
  PAGE_SIZE,
  WIX_EVENTS_APP_DEFINITION_ID,
  WIX_EVENTS_DEFAULT_DETAILS_PATH,
  decodeJwtPayload,
  extractWixEventsCompIdsFromHtml,
  extractWixEventsDetailsPathFromHtml,
  extractWixEventsFromWarmupHtml,
  extractWixEventsInstanceFromHtml,
  fetchWixEventsCalendarEvents,
  normalizeWixEventsPageUrl,
  wixEventsPublicUrl,
};
