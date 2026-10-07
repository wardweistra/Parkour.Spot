/* eslint-disable max-len */
/**
 * Site-wide totals for about.parkour.spot, written to snapshots/about-index.stats.
 * Only aggregate counts are stored, never names or user ids.
 */

const ACTIVITY_WINDOW_DAYS = 30;

/**
 * @param {*} value
 * @return {Date|null}
 */
function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") {
    try {
      return value.toDate();
    } catch (_) {
      return null;
    }
  }
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value === "string") {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof value.seconds === "number") return new Date(value.seconds * 1000);
  return null;
}

/**
 * @param {Date} now
 * @return {Date}
 */
function activityWindowStart(now) {
  return new Date(now.getTime() - ACTIVITY_WINDOW_DAYS * 24 * 60 * 60 * 1000);
}

/**
 * @param {Object} spot
 * @return {boolean}
 */
function hasPhoto(spot) {
  if (Array.isArray(spot.imageUrls) &&
    spot.imageUrls.some((u) => typeof u === "string" && u.trim())) {
    return true;
  }
  return typeof spot.imageUrl === "string" && spot.imageUrl.trim().length > 0;
}

/**
 * @param {*} value
 * @return {number|null}
 */
function countOrNull(value) {
  if (value == null) return null;
  const n = Number(value);
  return Number.isFinite(n) && n >= 0 ? Math.round(n) : null;
}

/**
 * Library and activity totals from loaded spots, upcoming events, and
 * pre-computed Firestore counts.
 * @param {Object} input
 * @param {Array<Object>} input.spots - non-hidden spot docs
 * @param {Array<Object>} input.upcomingEvents - public upcoming event summaries
 * @param {Object} [input.counts] - aggregate counts from Firestore
 * @param {Date} [input.now]
 * @return {Object}
 */
function buildAboutStats({spots, upcomingEvents, counts = {}, now = new Date()}) {
  const since = activityWindowStart(now);
  const countries = new Set();
  const cities = new Set();
  const sources = new Set();
  let spotCount = 0;
  let spotsWithPhotosCount = 0;
  let spotsAdded30d = 0;

  for (const spot of spots) {
    if (spot.hidden === true) continue;
    if (spot.duplicateOf != null && spot.duplicateOf !== "") continue;
    spotCount += 1;

    const cc = typeof spot.countryCode === "string" ?
      spot.countryCode.trim().toLowerCase() :
      "";
    if (cc.length === 2) {
      countries.add(cc);
      const city = typeof spot.city === "string" ? spot.city.trim().toLowerCase() : "";
      if (city) cities.add(`${cc}_${city}`);
    }

    const source = typeof spot.spotSource === "string" ? spot.spotSource.trim() : "";
    if (source) sources.add(source);

    if (hasPhoto(spot)) spotsWithPhotosCount += 1;

    const createdAt = toDate(spot.createdAt);
    if (createdAt && createdAt >= since && createdAt <= now) spotsAdded30d += 1;
  }

  const eventCountries = new Set();
  for (const event of upcomingEvents) {
    if (typeof event.countryCode === "string" && event.countryCode.length === 2) {
      eventCountries.add(event.countryCode.toLowerCase());
    }
  }

  return {
    generatedAt: now.toISOString(),
    activityWindowDays: ACTIVITY_WINDOW_DAYS,
    spotCount,
    countryCount: countries.size,
    cityCount: cities.size,
    spotSourceCount: sources.size,
    spotsWithPhotosCount,
    spotsAdded30d,
    upcomingEventCount: upcomingEvents.length,
    eventCountryCount: eventCountries.size,
    deduplicatedCount: countOrNull(counts.deduplicatedCount),
    ratingCount: countOrNull(counts.ratingCount),
    ratings30d: countOrNull(counts.ratings30d),
    checkIns30d: countOrNull(counts.checkIns30d),
    trainingPlans30d: countOrNull(counts.trainingPlans30d),
    improvementSuggestionCount: countOrNull(counts.improvementSuggestionCount),
    monthlyActiveUsers: countOrNull(counts.monthlyActiveUsers),
  };
}

module.exports = {
  ACTIVITY_WINDOW_DAYS,
  activityWindowStart,
  buildAboutStats,
};
