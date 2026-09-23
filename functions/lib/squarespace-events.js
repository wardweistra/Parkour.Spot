/**
 * Squarespace calendar (events collection) helpers for event sync.
 *
 * Squarespace exposes an undocumented collection JSON feed via ?format=json
 * on the public events page. Responses include upcoming/past arrays and
 * optional pagination.nextPageUrl.
 */

const MAX_EVENTS = 500;
const MAX_PAGES = 20;

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
 * Normalizes a Squarespace events page URL to the JSON feed form.
 * @param {*} value
 * @return {string}
 */
function normalizeSquarespaceEventsPageUrl(value) {
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
  parsed.hash = "";
  parsed.searchParams.set("format", "json");
  return parsed.toString();
}

/**
 * Public (HTML) events page URL derived from a feed URL.
 * @param {string} feedUrl
 * @return {string}
 */
function squarespaceEventsPublicUrl(feedUrl) {
  const parsed = new URL(feedUrl);
  parsed.searchParams.delete("format");
  const qs = parsed.searchParams.toString();
  parsed.search = qs.length > 0 ? `?${qs}` : "";
  return parsed.toString();
}

/**
 * @param {*} payload
 * @return {boolean}
 */
function isSquarespaceCalendarPayload(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    return false;
  }
  return Array.isArray(payload.upcoming) || Array.isArray(payload.past);
}

/**
 * Fetches all pages of a Squarespace events calendar JSON feed.
 * @param {string} pageUrl
 * @param {Object} options
 * @param {function(string): Promise<string>} options.downloadText
 * @return {Promise<Object>}
 */
async function fetchSquarespaceCalendarEvents(pageUrl, {downloadText}) {
  if (typeof downloadText !== "function") {
    throw new Error("downloadText is required");
  }

  const feedUrl = normalizeSquarespaceEventsPageUrl(pageUrl);
  const origin = new URL(feedUrl).origin;
  /** @type {Array<Object>} */
  const items = [];
  const seenIds = new Set();
  let nextUrl = feedUrl;
  /** @type {string|null} */
  let websiteTimeZone = null;
  let pages = 0;

  while (nextUrl && pages < MAX_PAGES && items.length < MAX_EVENTS) {
    pages += 1;
    const text = await downloadText(nextUrl);
    let payload;
    try {
      payload = JSON.parse(text);
    } catch (error) {
      throw new Error(
          `Failed parsing Squarespace calendar JSON: ${error.message}`,
      );
    }
    if (!isSquarespaceCalendarPayload(payload)) {
      throw new Error(
          "URL did not return a Squarespace calendar JSON response",
      );
    }

    if (!websiteTimeZone) {
      const website = payload.website && typeof payload.website === "object" ?
        payload.website :
        null;
      websiteTimeZone = website ?
        toNonEmptyString(website.timeZone) :
        null;
    }

    const pageItems = [
      ...(Array.isArray(payload.upcoming) ? payload.upcoming : []),
      ...(Array.isArray(payload.past) ? payload.past : []),
    ];
    for (const item of pageItems) {
      if (!item || typeof item !== "object") continue;
      const id = item.id != null ? toNonEmptyString(String(item.id)) : null;
      if (id) {
        if (seenIds.has(id)) continue;
        seenIds.add(id);
      }
      items.push(item);
      if (items.length >= MAX_EVENTS) break;
    }

    const pagination = payload.pagination &&
        typeof payload.pagination === "object" ?
      payload.pagination :
      null;
    if (
      pagination &&
      pagination.nextPage &&
      toNonEmptyString(pagination.nextPageUrl) &&
      items.length < MAX_EVENTS
    ) {
      const next = new URL(pagination.nextPageUrl, origin);
      next.hash = "";
      next.searchParams.set("format", "json");
      nextUrl = next.toString();
    } else {
      nextUrl = null;
    }
  }

  return {
    items,
    websiteTimeZone,
    collectionUrl: squarespaceEventsPublicUrl(feedUrl),
    siteOrigin: origin,
  };
}

module.exports = {
  MAX_EVENTS,
  MAX_PAGES,
  fetchSquarespaceCalendarEvents,
  isSquarespaceCalendarPayload,
  normalizeSquarespaceEventsPageUrl,
  squarespaceEventsPublicUrl,
};
