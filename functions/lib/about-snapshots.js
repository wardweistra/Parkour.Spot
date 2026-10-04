/* eslint-disable max-len */
/**
 * Pure helpers for about.parkour.spot daily snapshots.
 * Slug rules mirror functions/utils.js (keep in sync with about/src/lib/slug.ts).
 */

const {slugify} = require("../utils");
const {isEventPast} = require("./event-map-pins");

const MIN_RATED_SPOTS_PER_CITY = 5;
const TOP_SPOTS_LIMIT = 20;

/**
 * @param {string} title
 * @param {string} eventId
 * @return {string}
 */
function eventSlug(title, eventId) {
  const base = slugify(title || "event").replace(/^-+|-+$/g, "") || "event";
  const suffix = String(eventId).slice(0, 8).toLowerCase();
  return `${base}-${suffix}`;
}

/**
 * @param {Object} event
 * @return {boolean}
 */
function isPublicEvent(event) {
  const duplicateOf = typeof event.duplicateOf === "string" ?
    event.duplicateOf.trim() :
    "";
  if (duplicateOf.length > 0) {
    return false;
  }

  if (event.isPublic === false || event.isPrivate === true || event.hidden === true) {
    return false;
  }

  const visibility = typeof event.visibility === "string" ?
    event.visibility.trim().toLowerCase() :
    "";
  if (visibility.length > 0 && visibility !== "public") {
    return false;
  }

  return true;
}

/**
 * @param {Object} spot
 * @return {string|null}
 */
function firstImageUrl(spot) {
  if (Array.isArray(spot.imageUrls) && spot.imageUrls.length > 0) {
    const url = spot.imageUrls.find((u) => typeof u === "string" && u.trim());
    if (url) return url.trim();
  }
  if (typeof spot.imageUrl === "string" && spot.imageUrl.trim()) {
    return spot.imageUrl.trim();
  }
  return null;
}

/**
 * @param {Object} spot
 * @param {string} citySlug
 * @param {string} countryCode
 * @return {Object}
 */
function toSpotSummary(spot, citySlug, countryCode) {
  return {
    id: spot.id,
    name: typeof spot.name === "string" ? spot.name : "Untitled spot",
    averageRating: Number(spot.averageRating) || 0,
    ratingCount: Number(spot.ratingCount) || 0,
    ranking: Number(spot.ranking) || 0,
    imageUrl: firstImageUrl(spot),
    city: typeof spot.city === "string" ? spot.city : "",
    citySlug,
    countryCode,
  };
}

/**
 * @param {Object} event
 * @param {string} slug
 * @return {Object}
 */
function toEventSummary(event, slug) {
  const countryCode = typeof event.countryCode === "string" ?
    event.countryCode.trim().toLowerCase() :
    null;
  const city = typeof event.city === "string" && event.city.trim() ?
    event.city.trim() :
    null;
  const citySlug = city ? slugify(city) : null;
  const imageUrl = firstImageUrl(event);

  return {
    slug,
    eventId: event.id,
    title: typeof event.title === "string" ? event.title : "Untitled event",
    startAt: toIso(event.startAt),
    endAt: toIso(event.endAt),
    isDateOnly: event.isDateOnly === true,
    timeZone: typeof event.timeZone === "string" ? event.timeZone : null,
    city,
    citySlug,
    countryCode,
    imageUrl,
    websiteUrl: typeof event.websiteUrl === "string" ? event.websiteUrl : null,
  };
}

/**
 * @param {Object} event
 * @param {string} slug
 * @return {Object}
 */
function toEventDetail(event, slug) {
  const summary = toEventSummary(event, slug);
  const imageUrls = Array.isArray(event.imageUrls) ?
    event.imageUrls.filter((u) => typeof u === "string" && u.trim()) :
    [];
  return {
    ...summary,
    description: typeof event.description === "string" ? event.description : null,
    address: typeof event.address === "string" ? event.address : null,
    latitude: typeof event.latitude === "number" ? event.latitude : null,
    longitude: typeof event.longitude === "number" ? event.longitude : null,
    imageUrls,
  };
}

/**
 * @param {*} value
 * @return {string|null}
 */
function toIso(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") {
    try {
      return value.toDate().toISOString();
    } catch (_) {
      return null;
    }
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (typeof value === "string") {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d.toISOString();
  }
  if (typeof value.seconds === "number") {
    return new Date(value.seconds * 1000).toISOString();
  }
  return null;
}

/**
 * Group public spots by country/city and build hub payloads.
 * @param {Array<Object>} spots - docs with id fields
 * @param {Object} [options]
 * @return {{countries: Map, cities: Map, indexCountries: Array}}
 */
function buildPlaceSnapshots(spots, options = {}) {
  const minRated = options.minRatedSpotsPerCity ?? MIN_RATED_SPOTS_PER_CITY;
  const topLimit = options.topSpotsLimit ?? TOP_SPOTS_LIMIT;
  const generatedAt = options.generatedAt || new Date().toISOString();

  /** @type {Map<string, Map<string, {city: string, spots: Object[]}>>} */
  const grouped = new Map();

  for (const spot of spots) {
    if (spot.hidden === true) continue;
    if (spot.duplicateOf != null && spot.duplicateOf !== "") continue;
    const countryCode = typeof spot.countryCode === "string" ?
      spot.countryCode.trim().toLowerCase() :
      "";
    const cityRaw = typeof spot.city === "string" ? spot.city.trim() : "";
    if (!countryCode || countryCode.length !== 2 || !cityRaw) continue;

    if (!grouped.has(countryCode)) {
      grouped.set(countryCode, new Map());
    }
    const cities = grouped.get(countryCode);
    const cityKey = cityRaw.toLowerCase();
    if (!cities.has(cityKey)) {
      cities.set(cityKey, {city: cityRaw, spots: []});
    }
    cities.get(cityKey).spots.push(spot);
  }

  /** @type {Map<string, Object>} */
  const countryDocs = new Map();
  /** @type {Map<string, Object>} */
  const cityDocs = new Map();
  const indexCountries = [];

  for (const [countryCode, citiesMap] of grouped.entries()) {
    const eligibleCities = [];
    const countrySpotPool = [];

    for (const [, entry] of citiesMap.entries()) {
      const citySlug = slugify(entry.city);
      const rated = entry.spots.filter((s) => (Number(s.ratingCount) || 0) >= 1);
      if (rated.length < minRated) continue;

      const ranked = [...rated].sort(
          (a, b) => (Number(b.ranking) || 0) - (Number(a.ranking) || 0),
      );
      const top = ranked.slice(0, topLimit).map(
          (s) => toSpotSummary(s, citySlug, countryCode),
      );
      countrySpotPool.push(...top);

      const cityId = `${countryCode}_${citySlug}`;
      cityDocs.set(cityId, {
        countryCode,
        city: entry.city,
        citySlug,
        generatedAt,
        spots: top,
        events: [],
      });

      eligibleCities.push({
        city: entry.city,
        citySlug,
        ratedSpotCount: rated.length,
        eventCount: 0,
      });
    }

    if (eligibleCities.length === 0) continue;

    eligibleCities.sort((a, b) => b.ratedSpotCount - a.ratedSpotCount);

    const countryTop = [...countrySpotPool]
        .sort((a, b) => b.ranking - a.ranking)
        .slice(0, topLimit);

    countryDocs.set(countryCode, {
      countryCode,
      generatedAt,
      cities: eligibleCities,
      spots: countryTop,
      events: [],
    });

    indexCountries.push({
      code: countryCode,
      cityCount: eligibleCities.length,
      spotCount: countryTop.length,
      eventCount: 0,
    });
  }

  indexCountries.sort((a, b) => a.code.localeCompare(b.code));

  return {countryDocs, cityDocs, indexCountries, generatedAt};
}

/**
 * Attach upcoming public events into place hubs and build event docs.
 * @param {{countryDocs: Map, cityDocs: Map, indexCountries: Array, generatedAt: string}} placeState
 * @param {Array<Object>} events
 * @param {Date=} now
 * @return {{eventDetails: Map, eventsIndex: Object, aboutIndex: Object}}
 */
function attachEventsAndBuildIndexes(placeState, events, now = new Date()) {
  const {countryDocs, cityDocs, indexCountries, generatedAt} = placeState;
  /** @type {Map<string, Object>} */
  const eventDetails = new Map();
  /** @type {Object[]} */
  const upcomingSummaries = [];

  for (const event of events) {
    if (!isPublicEvent(event)) continue;
    if (isEventPast(event, now)) continue;

    const slug = eventSlug(event.title, event.id);
    const detail = toEventDetail(event, slug);
    eventDetails.set(slug, detail);
    const summary = toEventSummary(event, slug);
    upcomingSummaries.push(summary);

    const cc = summary.countryCode;
    if (cc && countryDocs.has(cc)) {
      countryDocs.get(cc).events.push(summary);
      const indexEntry = indexCountries.find((c) => c.code === cc);
      if (indexEntry) indexEntry.eventCount += 1;
    }

    if (cc && summary.citySlug) {
      const cityId = `${cc}_${summary.citySlug}`;
      if (cityDocs.has(cityId)) {
        cityDocs.get(cityId).events.push(summary);
        const country = countryDocs.get(cc);
        if (country) {
          const cityRef = country.cities.find((c) => c.citySlug === summary.citySlug);
          if (cityRef) cityRef.eventCount += 1;
        }
      }
    }
  }

  const byStart = (a, b) => {
    const at = a.startAt || "";
    const bt = b.startAt || "";
    return at.localeCompare(bt);
  };

  for (const doc of countryDocs.values()) {
    doc.events.sort(byStart);
  }
  for (const doc of cityDocs.values()) {
    doc.events.sort(byStart);
  }
  upcomingSummaries.sort(byStart);

  const aboutIndex = {
    generatedAt,
    countries: indexCountries,
    eventCount: upcomingSummaries.length,
  };

  const eventsIndex = {
    generatedAt,
    events: upcomingSummaries,
  };

  return {eventDetails, eventsIndex, aboutIndex, countryDocs, cityDocs};
}

module.exports = {
  MIN_RATED_SPOTS_PER_CITY,
  TOP_SPOTS_LIMIT,
  eventSlug,
  isPublicEvent,
  toSpotSummary,
  toEventSummary,
  toEventDetail,
  buildPlaceSnapshots,
  attachEventsAndBuildIndexes,
};
