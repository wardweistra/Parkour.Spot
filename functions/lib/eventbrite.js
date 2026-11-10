/**
 * Eventbrite collection helpers for event sync.
 *
 * A collection page embeds a schema.org ItemList of Events in JSON-LD.
 * Each start time carries a numeric offset, not an IANA zone. The zone is
 * resolved from venue coordinates and kept only when it reproduces that
 * wall clock.
 */

const {
  EVENT_TIME_ZONE_SOURCE_FEED,
  buildExternalEventKey,
  normalizeExternalImageUrl,
  normalizeImportedEventDescription,
  normalizeImportedTimeZone,
} = require("./event-sync");

const COLLECTION_PATH_RE =
  /^\/(?:[a-z]{2}(?:[-_][a-z]{2})?\/)?cc\/[a-z0-9-]+-\d+\/?$/i;
const EVENT_ID_RE = /-tickets-(\d+)(?:[/?#]|$)/;
const OFFSET_DATE_RE = new RegExp(
    "^(\\d{4})-(\\d{2})-(\\d{2})T(\\d{2}):(\\d{2})" +
    "(?::(\\d{2}))?(?:\\.\\d+)?(Z|[+-]\\d{2}:?\\d{2})$",
);
const JSON_LD_RE =
  /<script[^>]*type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;

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
function parseHttpsUrl(value) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error("icsUrl is required");
  }
  let parsed;
  try {
    parsed = new URL(value.trim());
  } catch (_) {
    throw new Error("icsUrl must be a valid URL");
  }
  if (parsed.protocol !== "https:") {
    throw new Error("Eventbrite collection URL must use https");
  }
  parsed.hash = "";
  parsed.search = "";
  return parsed;
}

/**
 * @param {string} pathname
 * @return {Array<string>}
 */
function pathSegments(pathname) {
  return pathname.split("/").filter((part) => part.length > 0);
}

/**
 * Canonical https collection URL with query and hash removed.
 * @param {*} value
 * @return {string}
 */
function normalizeEventbriteCollectionUrl(value) {
  const parsed = parseHttpsUrl(value);
  const host = parsed.hostname.toLowerCase();
  if (!/(^|\.)eventbrite\./.test(host)) {
    throw new Error(
        "Eventbrite collection URL must be an eventbrite host",
    );
  }
  if (COLLECTION_PATH_RE.test(parsed.pathname)) {
    return parsed.toString();
  }
  const segments = pathSegments(parsed.pathname).map((part) => {
    return part.toLowerCase();
  });
  if (segments.includes("e")) {
    throw new Error(
        "Eventbrite collection URL must be a collection page " +
        "(/cc/...), not a single event",
    );
  }
  if (segments.includes("o")) {
    throw new Error(
        "Eventbrite collection URL must be a collection page " +
        "(/cc/...), not an organizer page",
    );
  }
  throw new Error(
      "Eventbrite collection URL must be an https /cc/{slug}-{id} page",
  );
}

/**
 * @param {*} value
 * @return {number|null}
 */
function finiteCoordinate(value) {
  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) ? number : null;
}

/**
 * @param {number} latitude
 * @param {number} longitude
 * @return {boolean}
 */
function isValidCoordinatePair(latitude, longitude) {
  return Number.isFinite(latitude) &&
    Number.isFinite(longitude) &&
    latitude >= -90 &&
    latitude <= 90 &&
    longitude >= -180 &&
    longitude <= 180;
}

/**
 * @param {*} raw
 * @return {{date: Date, local: Object}|null}
 */
function parseOffsetDateTime(raw) {
  const value = toNonEmptyString(raw);
  if (!value) return null;
  const match = OFFSET_DATE_RE.exec(value);
  if (!match) return null;
  let offset = match[7];
  if (offset !== "Z" && offset.length === 5) {
    offset = `${offset.slice(0, 3)}:${offset.slice(3)}`;
  }
  const second = match[6] || "00";
  const iso = `${match[1]}-${match[2]}-${match[3]}` +
    `T${match[4]}:${match[5]}:${second}${offset}`;
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return null;
  return {
    date,
    local: {
      year: Number(match[1]),
      month: Number(match[2]),
      day: Number(match[3]),
      hour: Number(match[4]),
      minute: Number(match[5]),
    },
  };
}

/**
 * @param {*} value
 * @return {Array<string>}
 */
function schemaTypes(value) {
  if (!value || typeof value !== "object") return [];
  const rawType = value["@type"];
  if (typeof rawType === "string") return [rawType];
  if (Array.isArray(rawType)) {
    return rawType.filter((item) => typeof item === "string");
  }
  return [];
}

/**
 * @param {string} html
 * @return {{events: Array<Object>, listCount: number}}
 */
function extractJsonLdEvents(html) {
  const text = typeof html === "string" ? html : "";
  const events = [];
  let listCount = 0;
  JSON_LD_RE.lastIndex = 0;
  let match = JSON_LD_RE.exec(text);
  while (match) {
    let parsed;
    try {
      parsed = JSON.parse(match[1].trim());
    } catch (_) {
      parsed = null;
    }
    if (parsed) {
      listCount += collectItemListEvents(parsed, events);
    }
    match = JSON_LD_RE.exec(text);
  }
  return {events, listCount};
}

/**
 * @param {*} value
 * @param {Array<Object>} events
 * @return {number} ItemList blocks visited.
 */
function collectItemListEvents(value, events) {
  if (!value || typeof value !== "object") return 0;
  if (Array.isArray(value)) {
    let count = 0;
    for (const item of value) {
      count += collectItemListEvents(item, events);
    }
    return count;
  }
  let count = 0;
  if (schemaTypes(value).includes("ItemList")) {
    count += 1;
    const elements = Array.isArray(value.itemListElement) ?
      value.itemListElement :
      [];
    for (const element of elements) {
      const event = eventFromListElement(element);
      if (event) events.push(event);
    }
  }
  if (Array.isArray(value["@graph"])) {
    count += collectItemListEvents(value["@graph"], events);
  }
  return count;
}

/**
 * @param {*} element
 * @return {Object|null}
 */
function eventFromListElement(element) {
  if (!element || typeof element !== "object") return null;
  if (schemaTypes(element).includes("Event")) return element;
  const item = element.item;
  if (item && schemaTypes(item).includes("Event")) return item;
  return null;
}

/**
 * @param {string} url
 * @return {string|null}
 */
function eventIdFromUrl(url) {
  const match = EVENT_ID_RE.exec(url);
  return match ? match[1] : null;
}

/**
 * @param {*} location
 * @return {{
 *   address: (string|null),
 *   placeName: (string|null),
 *   latitude: (number|null),
 *   longitude: (number|null),
 * }}
 */
function readVenue(location) {
  const empty = {
    address: null,
    placeName: null,
    latitude: null,
    longitude: null,
  };
  if (!location || typeof location !== "object") return empty;
  const placeName = toNonEmptyString(location.name);
  const postal = location.address && typeof location.address === "object" ?
    location.address :
    null;
  const lines = [];
  if (placeName) lines.push(placeName);
  let latitude = finiteCoordinate(location.latitude);
  let longitude = finiteCoordinate(location.longitude);
  if (postal) {
    const street = toNonEmptyString(postal.streetAddress);
    const locality = toNonEmptyString(postal.addressLocality);
    const region = toNonEmptyString(postal.addressRegion);
    const postalCode = toNonEmptyString(postal.postalCode);
    const country = toNonEmptyString(postal.addressCountry);
    if (street) lines.push(street);
    const cityLine = [locality, region].filter(Boolean).join(", ");
    const cityPostal = [cityLine, postalCode].filter(Boolean).join(" ");
    if (cityPostal) lines.push(cityPostal);
    if (country) lines.push(country);
    const postalLat = finiteCoordinate(postal.latitude);
    const postalLng = finiteCoordinate(postal.longitude);
    if (postalLat != null && postalLng != null) {
      latitude = postalLat;
      longitude = postalLng;
    }
  }
  if (!isValidCoordinatePair(latitude, longitude)) {
    latitude = null;
    longitude = null;
  }
  return {
    address: lines.length > 0 ? lines.join(", ") : null,
    placeName,
    latitude,
    longitude,
  };
}

/**
 * @param {*} image
 * @return {string|null}
 */
function imageUrlFromEvent(image) {
  if (image && typeof image === "object" && !Array.isArray(image)) {
    return normalizeExternalImageUrl(image.url);
  }
  return normalizeExternalImageUrl(image);
}

/**
 * City clause after the last " - ", without a trailing "(MEX)" tag.
 * @param {string|null} title
 * @return {string|null}
 */
function cityClauseFromTitle(title) {
  const value = toNonEmptyString(title);
  if (!value) return null;
  const separator = value.lastIndexOf(" - ");
  if (separator < 0) return null;
  const clause = value
      .slice(separator + 3)
      .replace(/\s*\([^)]*\)\s*$/, "")
      .trim();
  return clause.length > 0 ? clause : null;
}

/**
 * @param {Object} event
 * @return {Array<string>}
 */
function geocodeQueriesFor(event) {
  const address = toNonEmptyString(event.address);
  const placeName = toNonEmptyString(event.placeName);
  const city = cityClauseFromTitle(event.title);
  const queries = [];
  if (address) queries.push(address);
  if (placeName && !queries.includes(placeName)) queries.push(placeName);
  if (city && !queries.includes(city)) queries.push(city);
  return queries;
}

/**
 * @param {Date} instant
 * @param {string} timeZone
 * @return {{year: number, month: number, day: number,
 *   hour: number, minute: number}|null}
 */
function zonedWallClock(instant, timeZone) {
  let formatter;
  try {
    formatter = new Intl.DateTimeFormat("en-US", {
      timeZone,
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      hourCycle: "h23",
    });
  } catch (_) {
    return null;
  }
  /** @type {Record<string, string>} */
  const parts = {};
  for (const part of formatter.formatToParts(instant)) {
    if (part.type !== "literal") parts[part.type] = part.value;
  }
  let hour = Number(parts.hour);
  if (hour === 24) hour = 0;
  return {
    year: Number(parts.year),
    month: Number(parts.month),
    day: Number(parts.day),
    hour,
    minute: Number(parts.minute),
  };
}

/**
 * @param {Date} instant
 * @param {string} timeZone
 * @param {Object|null|undefined} local
 * @return {boolean}
 */
function wallClockMatches(instant, timeZone, local) {
  if (!local || !(instant instanceof Date)) return false;
  const wall = zonedWallClock(instant, timeZone);
  if (!wall) return false;
  return wall.year === local.year &&
    wall.month === local.month &&
    wall.day === local.day &&
    wall.hour === local.hour &&
    wall.minute === local.minute;
}

/**
 * @param {number} latitude
 * @param {number} longitude
 * @return {string}
 */
function coordinateCacheKey(latitude, longitude) {
  return `${latitude.toFixed(3)},${longitude.toFixed(3)}`;
}

/**
 * Parses an Eventbrite collection page into external event payloads.
 * `localStart` and `placeName` stay on the in-memory event for
 * resolveEventbriteLocations and are not written to Firestore.
 * @param {string} html
 * @param {Object} sourceMeta
 * @param {string} sourceMeta.sourceId
 * @param {string} sourceMeta.sourceName
 * @return {Array<Object>}
 */
function parseEventbriteCollectionHtml(
    html,
    {sourceId, sourceName},
) {
  const extracted = extractJsonLdEvents(html);
  if (extracted.listCount === 0) {
    throw new Error(
        "Eventbrite collection page did not include an event list",
    );
  }

  const parsedEvents = [];
  for (const event of extracted.events) {
    const websiteUrl = toNonEmptyString(event.url);
    if (!websiteUrl) continue;
    const uid = eventIdFromUrl(websiteUrl);
    if (!uid) continue;
    const start = parseOffsetDateTime(event.startDate);
    if (!start) continue;

    const venue = readVenue(event.location);
    const end = parseOffsetDateTime(event.endDate);
    const title = toNonEmptyString(event.name) || "Untitled event";
    const description = normalizeImportedEventDescription(
        toNonEmptyString(event.description) || "",
    );

    const eventPayload = {
      title,
      description,
      websiteUrl,
      address: venue.address,
      startAt: start.date,
      endAt: end ? end.date : null,
      isDateOnly: false,
      eventSourceId: sourceId,
      eventSourceName: sourceName,
      externalEventUid: uid,
      externalEventRecurrenceId: null,
      externalEventKey: buildExternalEventKey(uid, null),
      localStart: start.local,
      placeName: venue.placeName,
    };
    if (venue.latitude != null && venue.longitude != null) {
      eventPayload.latitude = venue.latitude;
      eventPayload.longitude = venue.longitude;
    }
    const externalImageUrl = imageUrlFromEvent(event.image);
    if (externalImageUrl) {
      eventPayload.externalImageUrl = externalImageUrl;
    }
    parsedEvents.push(eventPayload);
  }

  if (extracted.events.length > 0 && parsedEvents.length === 0) {
    throw new Error(
        "Eventbrite collection page had no usable events",
    );
  }
  return parsedEvents;
}

/**
 * @param {Object} event
 * @param {function(string): Promise<Object|null>} geocodeAddress
 * @return {Promise<Object|null>}
 */
async function geocodeMissingVenue(event, geocodeAddress) {
  const queries = geocodeQueriesFor(event);
  for (const query of queries) {
    const geocoded = await geocodeAddress(query);
    const latitude = geocoded ? finiteCoordinate(geocoded.latitude) : null;
    const longitude = geocoded ? finiteCoordinate(geocoded.longitude) : null;
    if (!isValidCoordinatePair(latitude, longitude)) continue;
    return {
      latitude,
      longitude,
      address: toNonEmptyString(geocoded.address),
    };
  }
  return null;
}

/**
 * Fills missing coordinates, then sets timeZone when the venue zone
 * reproduces the Eventbrite wall clock. The source default time zone is
 * not used.
 * @param {Array<Object>} events
 * @param {Object} options
 * @param {function(string): Promise<Object|null>=} options.geocodeAddress
 * @param {function(number, number): Promise<string|null>=
 *   } options.lookupTimeZone
 * @param {function(string, Object=): void=} options.warn
 * @return {Promise<Array<Object>>}
 */
async function resolveEventbriteLocations(events, options = {}) {
  if (!Array.isArray(events)) {
    throw new Error("Eventbrite events must be an array");
  }
  const geocodeAddress = options.geocodeAddress;
  const lookupTimeZone = options.lookupTimeZone;
  const warn = typeof options.warn === "function" ? options.warn : () => {};
  /** @type {Map<string, string|null>} */
  const zoneCache = new Map();
  const resolved = [];

  for (const event of events) {
    if (!event || typeof event !== "object") continue;
    const next = Object.assign({}, event);
    const localStart = next.localStart || null;
    delete next.localStart;
    delete next.placeName;

    const hasCoordinates = isValidCoordinatePair(
        next.latitude,
        next.longitude,
    );
    if (!hasCoordinates && typeof geocodeAddress === "function") {
      const geocoded = await geocodeMissingVenue(
          event,
          geocodeAddress,
      );
      if (geocoded) {
        next.latitude = geocoded.latitude;
        next.longitude = geocoded.longitude;
        if (!next.address && geocoded.address) {
          next.address = geocoded.address;
        }
      }
    }

    if (!isValidCoordinatePair(next.latitude, next.longitude)) {
      warn("eventbriteTimeZone.noCoordinates", {
        externalEventUid: next.externalEventUid || null,
      });
      resolved.push(next);
      continue;
    }

    if (typeof lookupTimeZone !== "function") {
      warn("eventbriteTimeZone.lookupFailed", {
        externalEventUid: next.externalEventUid || null,
      });
      resolved.push(next);
      continue;
    }

    const cacheKey = coordinateCacheKey(next.latitude, next.longitude);
    if (!zoneCache.has(cacheKey)) {
      try {
        const lookedUp = await lookupTimeZone(
            next.latitude,
            next.longitude,
        );
        zoneCache.set(cacheKey, normalizeImportedTimeZone(lookedUp));
        if (!zoneCache.get(cacheKey)) {
          warn("eventbriteTimeZone.unavailable", {cacheKey});
        }
      } catch (error) {
        zoneCache.set(cacheKey, null);
        warn("eventbriteTimeZone.lookupFailed", {
          cacheKey,
          error: error && error.message ? error.message : String(error),
        });
      }
    }

    const timeZone = zoneCache.get(cacheKey);
    if (timeZone && wallClockMatches(next.startAt, timeZone, localStart)) {
      next.timeZone = timeZone;
      next.timeZoneSource = EVENT_TIME_ZONE_SOURCE_FEED;
    } else if (timeZone) {
      warn("eventbriteTimeZone.wallClockMismatch", {
        externalEventUid: next.externalEventUid || null,
        timeZone,
      });
    }
    resolved.push(next);
  }

  return resolved;
}

module.exports = {
  normalizeEventbriteCollectionUrl,
  parseEventbriteCollectionHtml,
  resolveEventbriteLocations,
};
