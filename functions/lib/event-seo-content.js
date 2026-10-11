/* eslint-disable max-len */
/**
 * Pure helpers for crawlable event-page SEO content (view-model only).
 */

const {slugify} = require("../utils");
const {cleanDescription} = require("./text-processing");
const {toJsDate} = require("./user-calendar-feed");

const MAX_LINKED_SPOTS = 20;

/**
 * @param {Date} date
 * @param {boolean} isDateOnly
 * @return {string|null}
 */
function toSchemaDate(date, isDateOnly) {
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) return null;
  if (isDateOnly) {
    return date.toISOString().slice(0, 10);
  }
  return date.toISOString();
}

/**
 * Human-readable when line for the SEO article.
 * @param {Date} startAt
 * @param {Date|null} endAt
 * @param {boolean} isDateOnly
 * @param {string|null} timeZone
 * @return {string|null}
 */
function formatWhenDisplay(startAt, endAt, isDateOnly, timeZone) {
  if (!(startAt instanceof Date) || Number.isNaN(startAt.getTime())) return null;

  const tz = typeof timeZone === "string" && timeZone.trim() ? timeZone.trim() : null;
  const dateOpts = isDateOnly ?
    {year: "numeric", month: "long", day: "numeric", timeZone: "UTC"} :
    {
      year: "numeric",
      month: "long",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
      timeZone: tz || "UTC",
      timeZoneName: tz ? "short" : undefined,
    };

  let startLabel;
  try {
    startLabel = startAt.toLocaleString("en-GB", dateOpts);
  } catch (_) {
    startLabel = isDateOnly ?
      startAt.toISOString().slice(0, 10) :
      startAt.toISOString();
  }

  if (!endAt || Number.isNaN(endAt.getTime()) || endAt.getTime() <= startAt.getTime()) {
    return startLabel;
  }

  let endLabel;
  try {
    endLabel = endAt.toLocaleString("en-GB", dateOpts);
  } catch (_) {
    endLabel = isDateOnly ?
      endAt.toISOString().slice(0, 10) :
      endAt.toISOString();
  }
  return `${startLabel} – ${endLabel}`;
}

/**
 * @param {Object} event
 * @return {Object} {latitude, longitude} or nulls
 */
function effectiveCoords(event) {
  if (typeof event.latitude === "number" && Number.isFinite(event.latitude) &&
      typeof event.longitude === "number" && Number.isFinite(event.longitude)) {
    return {latitude: event.latitude, longitude: event.longitude};
  }
  const resolved = event.resolvedLocation;
  if (resolved && typeof resolved === "object" &&
      typeof resolved.latitude === "number" && Number.isFinite(resolved.latitude) &&
      typeof resolved.longitude === "number" && Number.isFinite(resolved.longitude)) {
    return {latitude: resolved.latitude, longitude: resolved.longitude};
  }
  return {latitude: null, longitude: null};
}

/**
 * @param {Object} event
 * @return {Object} {city, countryCode}
 */
function effectiveCityCountry(event) {
  let city = event.city != null ? String(event.city).trim() : "";
  let countryCode = event.countryCode != null ?
    String(event.countryCode).trim().toUpperCase() : "";
  const resolved = event.resolvedLocation;
  if (resolved && typeof resolved === "object") {
    if (!city && resolved.city != null) {
      city = String(resolved.city).trim();
    }
    if (!countryCode && resolved.countryCode != null) {
      countryCode = String(resolved.countryCode).trim().toUpperCase();
    }
  }
  return {
    city: city || null,
    countryCode: countryCode || null,
  };
}

/**
 * @param {Object} spot
 * @return {Object|null} {title, url}
 */
function linkedSpotLink(spot) {
  if (!spot || typeof spot !== "object") return null;
  const id = spot.id != null ? String(spot.id).trim() : "";
  const name = typeof spot.name === "string" ? spot.name.trim() : "";
  if (!id || !name) return null;

  const city = spot.city != null ? String(spot.city).trim() : "";
  const countryCode = spot.countryCode != null ?
    String(spot.countryCode).trim().toLowerCase() : "";
  let url;
  if (city && countryCode && countryCode.length === 2) {
    url = `/${countryCode}/${slugify(city)}/${id}`;
  } else {
    url = `/spot/${id}`;
  }
  return {title: name, url};
}

/**
 * Build the crawlable event SEO view-model.
 * Returns null when there is no event to describe.
 *
 * @param {Object} options
 * @param {Object} options.event - Event document data (with id)
 * @param {Array<Object>} [options.breadcrumbs]
 * @param {Array<Object>} [options.linkedSpots] - Spot docs for event.spotIds
 * @param {string} [options.canonicalHost]
 * @return {Object|null}
 */
function buildEventSeoContent(options = {}) {
  const event = options.event;
  if (!event || typeof event !== "object") return null;

  const title = typeof event.title === "string" ? event.title.trim() : "";
  if (!title) return null;

  const isDateOnly = event.isDateOnly === true;
  const startAt = toJsDate(event.startAt);
  const endAt = toJsDate(event.endAt);
  const timeZone = typeof event.timeZone === "string" && event.timeZone.trim() ?
    event.timeZone.trim() : null;

  const whenDisplay = startAt ?
    formatWhenDisplay(startAt, endAt, isDateOnly, timeZone) : null;
  const startDateIso = startAt ? toSchemaDate(startAt, isDateOnly) : null;
  const endDateIso = endAt ? toSchemaDate(endAt, isDateOnly) : null;

  const descriptionRaw = typeof event.description === "string" ? event.description : "";
  const descriptionPlain = cleanDescription(descriptionRaw).trim();
  const description = descriptionPlain.length > 0 ? descriptionPlain : null;

  const address = event.address != null && String(event.address).trim() ?
    String(event.address).trim() : null;

  const {city, countryCode} = effectiveCityCountry(event);
  const locationParts = [];
  if (city) locationParts.push(city);
  if (countryCode) locationParts.push(countryCode);
  const locationLine = locationParts.length > 0 ? locationParts.join(", ") : null;

  const {latitude, longitude} = effectiveCoords(event);
  let mapUrl = null;
  if (latitude != null && longitude != null) {
    mapUrl = `https://www.google.com/maps?q=${latitude},${longitude}`;
  }

  const websiteUrl = typeof event.websiteUrl === "string" &&
    event.websiteUrl.trim().startsWith("http") ?
    event.websiteUrl.trim() : null;

  const sourceName = event.eventSourceName != null &&
    String(event.eventSourceName).trim() ?
    String(event.eventSourceName).trim() : null;

  const breadcrumbs = Array.isArray(options.breadcrumbs) ?
    options.breadcrumbs
        .filter((b) => b && typeof b.name === "string" && typeof b.url === "string")
        .map((b) => ({name: b.name, url: b.url})) :
    [];

  const linkedSpots = [];
  const rawSpots = Array.isArray(options.linkedSpots) ? options.linkedSpots : [];
  for (const spot of rawSpots.slice(0, MAX_LINKED_SPOTS)) {
    const link = linkedSpotLink(spot);
    if (link) linkedSpots.push(link);
  }

  const imageUrls = Array.isArray(event.imageUrls) ?
    event.imageUrls.filter((u) => typeof u === "string" && u.trim().startsWith("http")) :
    [];

  return {
    kind: "event",
    title,
    locationLine,
    description,
    address,
    latitude,
    longitude,
    mapUrl,
    whenDisplay,
    startDateIso,
    endDateIso,
    isDateOnly,
    websiteUrl,
    linkedSpots,
    sourceName,
    breadcrumbs,
    imageUrl: imageUrls.length > 0 ? imageUrls[0] : null,
    // Spot-only fields left empty so the shared renderer skips them
    rating: null,
    access: null,
    features: [],
    goodFor: [],
    facilities: [],
    youtubeVideos: [],
    jumpflixVideos: [],
  };
}

module.exports = {
  toSchemaDate,
  formatWhenDisplay,
  effectiveCoords,
  effectiveCityCountry,
  linkedSpotLink,
  buildEventSeoContent,
  MAX_LINKED_SPOTS,
};
