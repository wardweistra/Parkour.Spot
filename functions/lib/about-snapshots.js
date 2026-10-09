/* eslint-disable max-len */
/**
 * Pure helpers for about.parkour.spot daily snapshots.
 * Slug rules mirror functions/utils.js (keep in sync with about/src/lib/slug.ts).
 */

const {slugify} = require("../utils");
const {
  hasValidCoordinates,
  isEventPast,
  resolveEventMainLocation,
} = require("./event-map-pins");

const TOP_SPOTS_LIMIT = 10;

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
    latitude: hasValidCoordinates(spot.latitude, spot.longitude) ? spot.latitude : null,
    longitude: hasValidCoordinates(spot.latitude, spot.longitude) ? spot.longitude : null,
    address: nonEmpty(spot.address),
  };
}

/**
 * @param {*} value
 * @return {string|null}
 */
function nonEmpty(value) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

/**
 * Event location for About pages: the event's own fields first, then the
 * server-derived resolvedLocation (first eligible linked spot).
 * @param {Object} event
 * @return {{city: (string|null), countryCode: (string|null),
 *   latitude: (number|null), longitude: (number|null),
 *   placeName: (string|null), placeSpotId: (string|null),
 *   placeSpotCitySlug: (string|null), locationSource: (string|null)}}
 */
function effectiveEventLocation(event) {
  const resolved = event.resolvedLocation && typeof event.resolvedLocation === "object" ?
    event.resolvedLocation :
    {};
  const hasVenue = hasValidCoordinates(event.latitude, event.longitude);
  const countryCode = nonEmpty(event.countryCode) || nonEmpty(resolved.countryCode);
  const fromSpot = !hasVenue && (resolved.source === "spot" || resolved.source === "list");
  let placeName = null;
  if (fromSpot) {
    placeName = resolved.source === "list" ?
      nonEmpty(resolved.spotListName) || nonEmpty(resolved.spotName) :
      nonEmpty(resolved.spotName);
  }
  const resolvedHasCoords = hasValidCoordinates(resolved.latitude, resolved.longitude);
  // A list-sourced place is named after the list, so it has no single spot page.
  const spotCity = nonEmpty(resolved.city);
  const placeSpotId = fromSpot && resolved.source === "spot" && spotCity ?
    nonEmpty(resolved.spotId) :
    null;
  return {
    city: nonEmpty(event.city) || nonEmpty(resolved.city),
    countryCode: countryCode ? countryCode.toLowerCase() : null,
    latitude: hasVenue ? event.latitude : (resolvedHasCoords ? resolved.latitude : null),
    longitude: hasVenue ? event.longitude : (resolvedHasCoords ? resolved.longitude : null),
    placeName,
    placeSpotId,
    placeSpotCitySlug: placeSpotId ? slugify(spotCity) : null,
    locationSource: hasVenue ? "venue" : (fromSpot ? resolved.source : null),
  };
}

/**
 * Fills resolvedLocation for events the trigger has not processed yet
 * (no direct coordinates, linked spots or lists, no stored value).
 * @param {Array<Object>} events
 * @param {Map<string, Object>} spotsById
 * @param {Map<string, Object>} listsById
 * @return {Array<Object>}
 */
function withResolvedLocationFallback(events, spotsById, listsById) {
  return events.map((event) => {
    if (!needsResolvedLocationFallback(event)) return event;
    const resolvedLocation = resolveEventMainLocation(event, spotsById, listsById);
    return resolvedLocation ? {...event, resolvedLocation} : event;
  });
}

/**
 * @param {Object} event
 * @return {boolean}
 */
function needsResolvedLocationFallback(event) {
  if (event.resolvedLocation && typeof event.resolvedLocation === "object") {
    return false;
  }
  if (hasValidCoordinates(event.latitude, event.longitude)) return false;
  const hasSpots = Array.isArray(event.spotIds) && event.spotIds.length > 0;
  const hasLists = Array.isArray(event.spotListIds) && event.spotListIds.length > 0;
  return hasSpots || hasLists;
}

/**
 * @param {Object} event
 * @param {string} slug
 * @return {Object}
 */
function toEventSummary(event, slug) {
  const {city, countryCode} = effectiveEventLocation(event);
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
  const location = effectiveEventLocation(event);
  const imageUrls = Array.isArray(event.imageUrls) ?
    event.imageUrls.filter((u) => typeof u === "string" && u.trim()) :
    [];
  return {
    ...summary,
    description: typeof event.description === "string" ? event.description : null,
    address: typeof event.address === "string" ? event.address : null,
    latitude: location.latitude,
    longitude: location.longitude,
    placeName: location.placeName,
    placeSpotId: location.placeSpotId,
    placeSpotCitySlug: location.placeSpotCitySlug,
    locationSource: location.locationSource,
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
 * Explore ranking: above-average spots first, then unrated spots (random
 * ranking in [0, 1)), then below-average spots.
 * @param {Object} a
 * @param {Object} b
 * @return {number}
 */
function byRankingDesc(a, b) {
  return (Number(b.ranking) || 0) - (Number(a.ranking) || 0);
}

/**
 * @param {string} countryCode
 * @param {string} generatedAt
 * @return {Object}
 */
function emptyCountryDoc(countryCode, generatedAt) {
  return {
    countryCode,
    generatedAt,
    spotCount: 0,
    cities: [],
    spots: [],
    events: [],
  };
}

/**
 * @param {string} countryCode
 * @param {string} city
 * @param {string} citySlug
 * @param {string} generatedAt
 * @return {Object}
 */
function emptyCityDoc(countryCode, city, citySlug, generatedAt) {
  return {
    countryCode,
    city,
    citySlug,
    generatedAt,
    spotCount: 0,
    spots: [],
    events: [],
  };
}

/**
 * Group public spots by country/city and build hub payloads.
 * Every city with a public spot gets a hub. `spots` is a sample in Explore
 * order; `spotCount` is the full library.
 * @param {Array<Object>} spots - docs with id fields
 * @param {Object} [options]
 * @return {{countryDocs: Map, cityDocs: Map, indexCountries: Array, generatedAt: string}}
 */
function buildPlaceSnapshots(spots, options = {}) {
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
    /** @type {Array<{spot: Object, citySlug: string}>} */
    const countryPool = [];

    for (const [, entry] of citiesMap.entries()) {
      if (entry.spots.length === 0) continue;
      const citySlug = slugify(entry.city);
      const top = [...entry.spots].sort(byRankingDesc).slice(0, topLimit).map(
          (s) => toSpotSummary(s, citySlug, countryCode),
      );
      for (const spot of entry.spots) {
        countryPool.push({spot, citySlug});
      }

      const cityId = `${countryCode}_${citySlug}`;
      cityDocs.set(cityId, {
        countryCode,
        city: entry.city,
        citySlug,
        generatedAt,
        spotCount: entry.spots.length,
        spots: top,
        events: [],
      });

      eligibleCities.push({
        city: entry.city,
        citySlug,
        spotCount: entry.spots.length,
        eventCount: 0,
      });
    }

    if (eligibleCities.length === 0) continue;

    eligibleCities.sort((a, b) => b.spotCount - a.spotCount ||
      a.city.localeCompare(b.city));

    const countryTop = [...countryPool]
        .sort((a, b) => byRankingDesc(a.spot, b.spot))
        .slice(0, topLimit)
        .map(({spot, citySlug}) => toSpotSummary(spot, citySlug, countryCode));
    const spotCount = eligibleCities.reduce(
        (sum, city) => sum + city.spotCount, 0);

    countryDocs.set(countryCode, {
      countryCode,
      generatedAt,
      spotCount,
      cities: eligibleCities,
      spots: countryTop,
      events: [],
    });

    indexCountries.push({
      code: countryCode,
      cityCount: eligibleCities.length,
      spotCount,
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
    if (!cc) continue;

    if (!countryDocs.has(cc)) {
      countryDocs.set(cc, emptyCountryDoc(cc, generatedAt));
      indexCountries.push({
        code: cc,
        cityCount: 0,
        spotCount: 0,
        eventCount: 0,
      });
    }
    const country = countryDocs.get(cc);
    country.events.push(summary);
    const indexEntry = indexCountries.find((c) => c.code === cc);
    if (indexEntry) indexEntry.eventCount += 1;

    if (!summary.citySlug || !summary.city) continue;

    const cityId = `${cc}_${summary.citySlug}`;
    if (!cityDocs.has(cityId)) {
      cityDocs.set(
          cityId,
          emptyCityDoc(cc, summary.city, summary.citySlug, generatedAt),
      );
      country.cities.push({
        city: summary.city,
        citySlug: summary.citySlug,
        spotCount: 0,
        eventCount: 0,
      });
      if (indexEntry) indexEntry.cityCount += 1;
    }
    cityDocs.get(cityId).events.push(summary);
    const cityRef = country.cities.find((c) => c.citySlug === summary.citySlug);
    if (cityRef) cityRef.eventCount += 1;
  }

  const byStart = (a, b) => {
    const at = a.startAt || "";
    const bt = b.startAt || "";
    return at.localeCompare(bt);
  };

  for (const doc of countryDocs.values()) {
    doc.cities.sort((a, b) => b.spotCount - a.spotCount ||
      a.city.localeCompare(b.city));
    doc.events.sort(byStart);
  }
  indexCountries.sort((a, b) => a.code.localeCompare(b.code));
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
  TOP_SPOTS_LIMIT,
  eventSlug,
  isPublicEvent,
  toSpotSummary,
  effectiveEventLocation,
  needsResolvedLocationFallback,
  withResolvedLocationFallback,
  toEventSummary,
  toEventDetail,
  buildPlaceSnapshots,
  attachEventsAndBuildIndexes,
};
