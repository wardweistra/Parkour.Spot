/**
 * Momence host-schedule helpers for event sync.
 *
 * Public read API:
 *   GET https://readonly-api.momence.com/host-plugins/host/{hostId}/host-schedule
 *   GET .../host-schedule/sessions
 *
 * Accepts that API URL, a Momence host page, or a site page that embeds
 * momence.com/plugin/host-schedule/host-schedule.js (host_id="…").
 * Sessions are limited to the Event tag unless the URL already pins tagIds.
 */

const MOMENCE_API_ORIGIN = "https://readonly-api.momence.com";
const MOMENCE_EVENT_TAG_NAME = "event";
const MOMENCE_PAGE_SIZE = 50;
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
 * @param {*} value
 * @return {URL}
 */
function parseHttpUrl(value) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error("icsUrl is required");
  }
  let parsed;
  try {
    parsed = new URL(value.trim());
  } catch (_) {
    throw new Error("icsUrl must be a valid URL");
  }
  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    throw new Error("icsUrl must use http or https");
  }
  parsed.hash = "";
  return parsed;
}

/**
 * @param {URL} parsed
 * @return {string|null}
 */
function hostIdFromUrl(parsed) {
  const match = /\/host\/(\d+)(?:\/|$)/.exec(parsed.pathname);
  return match ? match[1] : null;
}

/**
 * @param {URL} parsed
 * @return {Array<string>}
 */
function tagIdsFromUrl(parsed) {
  /** @type {Array<string>} */
  const ids = [];
  for (const [key, value] of parsed.searchParams.entries()) {
    if (key !== "tagIds" && key !== "tagIds[]") continue;
    const id = toNonEmptyString(value);
    if (id) ids.push(id);
  }
  return ids;
}

/**
 * @param {string} hostId
 * @param {Array<string>} tagIds
 * @return {string}
 */
function canonicalMomenceFeedUrl(hostId, tagIds) {
  const url = new URL(
      `${MOMENCE_API_ORIGIN}/host-plugins/host/${hostId}/host-schedule`,
  );
  for (const tagId of tagIds) {
    url.searchParams.append("tagIds[]", tagId);
  }
  return url.toString();
}

/**
 * Reads host_id and tag_ids from a Momence schedule embed.
 * @param {string} html
 * @return {Object} hostId and tagIds.
 */
function extractMomenceHostFromHtml(html) {
  const text = typeof html === "string" ? html : "";
  const hostMatch = /host_id\s*=\s*["'](\d+)["']/i.exec(text) ||
    /\/host\/(\d+)(?:\/|["'?#\s])/i.exec(text);
  let tagIds = [];
  const tagMatch = /tag_ids\s*=\s*["']\[([0-9,\s]*)\]["']/i.exec(text);
  if (tagMatch) {
    tagIds = tagMatch[1]
        .split(",")
        .map((part) => part.trim())
        .filter((part) => part.length > 0);
  }
  return {
    hostId: hostMatch ? hostMatch[1] : null,
    tagIds,
  };
}

/**
 * @param {string} feedUrl
 * @return {string}
 */
function momencePublicUrl(feedUrl) {
  const parsed = parseHttpUrl(feedUrl);
  return parsed.toString();
}

/**
 * Resolves a pasted Momence or gym page URL to the host-schedule API URL.
 * Tag ids already on the URL win. Otherwise tag ids on the schedule embed
 * are kept. An embed without tag ids is resolved again at fetch time to
 * the host's Event tag.
 * @param {*} value
 * @param {function(string, Object=): Promise<string>} downloadText
 * @return {Promise<Object>} canonicalUrl and publicUrl.
 */
async function resolveMomenceFeedUrl(value, downloadText) {
  const parsed = parseHttpUrl(value);
  const publicUrl = parsed.toString();
  let hostId = hostIdFromUrl(parsed);
  let tagIds = tagIdsFromUrl(parsed);
  if (!hostId) {
    if (typeof downloadText !== "function") {
      throw new Error("downloadText is required");
    }
    const html = await downloadText(publicUrl, {
      headers: {"Accept": "text/html, application/xhtml+xml, */*"},
    });
    const extracted = extractMomenceHostFromHtml(html);
    hostId = extracted.hostId;
    if (tagIds.length === 0) tagIds = extracted.tagIds;
  }
  if (!hostId) {
    throw new Error(
        "Momence schedule URL did not include a host id. " +
        "Paste the gym schedule page or the readonly host-schedule URL.",
    );
  }
  return {
    canonicalUrl: canonicalMomenceFeedUrl(hostId, tagIds),
    publicUrl,
  };
}

/**
 * Sync normalizer for a URL that already contains /host/{id}/.
 * @param {*} value
 * @return {string}
 */
function normalizeMomenceFeedUrl(value) {
  const parsed = parseHttpUrl(value);
  const hostId = hostIdFromUrl(parsed);
  if (!hostId) {
    throw new Error(
        "momenceHostSchedule icsUrl must include /host/{id}/ " +
        "or be resolved from a schedule page",
    );
  }
  return canonicalMomenceFeedUrl(hostId, tagIdsFromUrl(parsed));
}

/**
 * @param {Date} date
 * @param {string} timeZone
 * @return {Object<string, string>}
 */
function zonedDateParts(date, timeZone) {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  /** @type {Object<string, string>} */
  const parts = {};
  for (const part of fmt.formatToParts(date)) {
    if (part.type !== "literal") parts[part.type] = part.value;
  }
  if (parts.hour === "24") parts.hour = "00";
  return parts;
}

/**
 * Wall-clock interpreted as UTC, minus the actual instant.
 * @param {Date} date
 * @param {string} timeZone
 * @return {number}
 */
function timeZoneOffsetMs(date, timeZone) {
  const parts = zonedDateParts(date, timeZone);
  const asUtc = Date.UTC(
      Number(parts.year),
      Number(parts.month) - 1,
      Number(parts.day),
      Number(parts.hour),
      Number(parts.minute),
      Number(parts.second),
  );
  return asUtc - date.getTime();
}

/**
 * UTC instant of local midnight on the calendar day of `now` in `timeZone`.
 * @param {string} timeZone
 * @param {Date} now
 * @return {Date}
 */
function startOfZonedDayUtc(timeZone, now) {
  const parts = zonedDateParts(now, timeZone);
  const wallAsUtc = Date.UTC(
      Number(parts.year),
      Number(parts.month) - 1,
      Number(parts.day),
      0,
      0,
      0,
      0,
  );
  let utc = wallAsUtc;
  for (let attempt = 0; attempt < 3; attempt++) {
    const offset = timeZoneOffsetMs(new Date(utc), timeZone);
    const next = wallAsUtc - offset;
    if (next === utc) break;
    utc = next;
  }
  return new Date(utc);
}

/**
 * @param {*} payload
 * @return {Array<Object>}
 */
function momenceTags(payload) {
  if (!payload || typeof payload !== "object") return [];
  if (!Array.isArray(payload.tags)) return [];
  return payload.tags.filter((tag) => tag && typeof tag === "object");
}

/**
 * @param {Array<Object>} tags
 * @return {string|null}
 */
function eventTagId(tags) {
  for (const tag of tags) {
    const name = toNonEmptyString(tag.name);
    if (name && name.toLowerCase() === MOMENCE_EVENT_TAG_NAME) {
      return tag.id != null ? String(tag.id) : null;
    }
  }
  return null;
}

/**
 * @param {*} amount
 * @param {*} currency
 * @return {string|null}
 */
function formatMomenceTicketPrice(amount, currency) {
  if (amount == null || amount === "") return null;
  const numeric = Number(amount);
  if (!Number.isFinite(numeric)) return null;
  const formatted = Number.isInteger(numeric) ?
    String(numeric) :
    numeric.toFixed(2);
  const code = toNonEmptyString(currency);
  const normalized = code ? code.toLowerCase() : "usd";
  if (normalized === "usd") return `$${formatted}`;
  if (normalized === "eur") return `€${formatted}`;
  if (normalized === "gbp") return `£${formatted}`;
  return `${formatted} ${normalized.toUpperCase()}`;
}

/**
 * @param {string} url
 * @param {function(string, Object=): Promise<string>} downloadText
 * @return {Promise<*>}
 */
async function downloadMomenceJson(url, downloadText) {
  const text = await downloadText(url, {
    headers: {"Accept": "application/json, text/plain, */*"},
  });
  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Error(`Failed parsing Momence JSON: ${error.message}`);
  }
}

/**
 * Fetches upcoming Momence sessions for a host schedule.
 * @param {string} pageUrl Canonical host-schedule URL, or any supported URL.
 * @param {Object} options
 * @param {function(string, Object=): Promise<string>} options.downloadText
 * @param {Date=} options.now
 * @return {Promise<Object>} items, hostTimeZone, publicUrl, canonicalUrl.
 */
async function fetchMomenceHostSchedule(pageUrl, {downloadText, now} = {}) {
  if (typeof downloadText !== "function") {
    throw new Error("downloadText is required");
  }
  const resolved = await resolveMomenceFeedUrl(pageUrl, downloadText);
  const metadataUrl = canonicalMomenceFeedUrl(
      hostIdFromUrl(new URL(resolved.canonicalUrl)),
      [],
  );
  const metadata = await downloadMomenceJson(metadataUrl, downloadText);
  const host = metadata && typeof metadata.host === "object" ?
    metadata.host :
    null;
  const hostTimeZone = host ? toNonEmptyString(host.timeZone) : null;
  const pinnedTagIds = tagIdsFromUrl(new URL(resolved.canonicalUrl));
  let tagIds = pinnedTagIds;
  if (tagIds.length === 0) {
    const eventId = eventTagId(momenceTags(metadata));
    if (!eventId) {
      throw new Error(
          "Momence host has no Event tag. " +
          "Tag those sessions Event, or pin tagIds on the schedule URL.",
      );
    }
    tagIds = [eventId];
  }

  const timeZoneForWindow = hostTimeZone || "UTC";
  const fromDate = startOfZonedDayUtc(
      timeZoneForWindow,
      now instanceof Date ? now : new Date(),
  );
  /** @type {Array<Object>} */
  const items = [];
  const seenIds = new Set();
  let page = 0;
  let totalCount = Infinity;
  while (items.length < MAX_EVENTS && page * MOMENCE_PAGE_SIZE < totalCount) {
    const sessionsUrl = new URL(`${metadataUrl}/sessions`);
    for (const tagId of tagIds) {
      sessionsUrl.searchParams.append("tagIds[]", tagId);
    }
    sessionsUrl.searchParams.set("fromDate", fromDate.toISOString());
    sessionsUrl.searchParams.set("pageSize", String(MOMENCE_PAGE_SIZE));
    sessionsUrl.searchParams.set("page", String(page));
    sessionsUrl.searchParams.set("timeZone", timeZoneForWindow);
    const body = await downloadMomenceJson(
        sessionsUrl.toString(),
        downloadText,
    );
    const payload = body && Array.isArray(body.payload) ? body.payload : null;
    if (!payload) {
      throw new Error("Momence sessions response has no payload array");
    }
    const pagination = body.pagination && typeof body.pagination === "object" ?
      body.pagination :
      {};
    if (Number.isFinite(Number(pagination.totalCount))) {
      totalCount = Number(pagination.totalCount);
    }
    for (const item of payload) {
      if (!item || typeof item !== "object") continue;
      if (item.isCancelled === true) continue;
      const id = item.id != null ? String(item.id) : null;
      if (id) {
        if (seenIds.has(id)) continue;
        seenIds.add(id);
      }
      items.push(item);
      if (items.length >= MAX_EVENTS) break;
    }
    if (payload.length < MOMENCE_PAGE_SIZE) break;
    page += 1;
  }

  return {
    items,
    hostTimeZone,
    publicUrl: resolved.publicUrl,
    canonicalUrl: resolved.canonicalUrl,
  };
}

module.exports = {
  MAX_EVENTS,
  MOMENCE_API_ORIGIN,
  MOMENCE_EVENT_TAG_NAME,
  MOMENCE_PAGE_SIZE,
  canonicalMomenceFeedUrl,
  eventTagId,
  extractMomenceHostFromHtml,
  fetchMomenceHostSchedule,
  formatMomenceTicketPrice,
  momencePublicUrl,
  normalizeMomenceFeedUrl,
  resolveMomenceFeedUrl,
  startOfZonedDayUtc,
};
