/* eslint-disable max-len */
/**
 * Unique-by-user rating aggregates for a spot and its duplicate listings.
 *
 * Source of truth remains `ratings` documents (spotId = the listing rated).
 * Totals for a spot include ratings on that spot and on any spots marked as
 * duplicates of it. The same user is counted once; latest updatedAt wins
 * (createdAt if updatedAt is missing).
 */

const Z = 1.96; // 95% Wilson confidence

/**
 * @param {*} value
 * @return {number}
 */
function timestampMillis(value) {
  if (value == null) return 0;
  if (typeof value.toMillis === "function") {
    const millis = value.toMillis();
    return Number.isFinite(millis) ? millis : 0;
  }
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value.seconds === "number") {
    const nanos = typeof value.nanoseconds === "number" ? value.nanoseconds : 0;
    return value.seconds * 1000 + nanos / 1e6;
  }
  return 0;
}

/**
 * @param {Object|null|undefined} data
 * @return {number}
 */
function ratingRecencyMillis(data) {
  if (!data) return 0;
  const updated = timestampMillis(data.updatedAt);
  if (updated > 0) return updated;
  return timestampMillis(data.createdAt);
}

/**
 * @param {*} value
 * @return {number}
 */
function clampRating(value) {
  const n = typeof value === "number" && Number.isFinite(value) ? value : 0;
  return Math.max(0, Math.min(5, n));
}

/**
 * One rating per user; latest recency wins. Ties keep the first seen.
 * @param {Array<Object>} ratings
 * @return {Array<Object>}
 */
function uniqueRatingsByUser(ratings) {
  const byUser = new Map();
  const list = Array.isArray(ratings) ? ratings : [];
  for (const data of list) {
    if (!data || typeof data !== "object") continue;
    const userId = typeof data.userId === "string" ? data.userId.trim() : "";
    if (!userId) continue;
    const prev = byUser.get(userId);
    if (!prev || ratingRecencyMillis(data) > ratingRecencyMillis(prev)) {
      byUser.set(userId, data);
    }
  }
  return [...byUser.values()];
}

/**
 * Explore selection stores at-or-above-average spots as wilson + this offset
 * and below-average spots as wilson - this offset. Wilson itself is 0..5, so
 * a stored ranking >= this value is the same cut the map uses.
 */
const ABOVE_AVERAGE_RANKING_OFFSET = 10;

/**
 * @param {number} wilsonLowerBound
 * @param {number} wilsonLowerBoundAvg
 * @return {number}
 */
function rankingFromWilson(wilsonLowerBound, wilsonLowerBoundAvg) {
  if (wilsonLowerBound >= wilsonLowerBoundAvg) {
    return wilsonLowerBound + ABOVE_AVERAGE_RANKING_OFFSET;
  }
  return wilsonLowerBound - ABOVE_AVERAGE_RANKING_OFFSET;
}

/**
 * True when a stored ranking is at or above the Wilson average Explore uses.
 * Unrated spots use a random ranking in [0, 1), so they fail this check.
 * @param {*} ranking
 * @return {boolean}
 */
function isAboveAverageRanking(ranking) {
  const value = Number(ranking);
  return Number.isFinite(value) && value >= ABOVE_AVERAGE_RANKING_OFFSET;
}

/**
 * Wilson lower bound on normalized stars (0..5).
 * @param {number} sum clamped stars
 * @param {number} count unique ratings
 * @return {number}
 */
function wilsonLowerBoundFromSum(sum, count) {
  if (count <= 0) return 0;
  const trials = 5 * count;
  const p = sum / trials;
  const denom = 1 + (Z * Z) / trials;
  const center = p + (Z * Z) / (2 * trials);
  const margin = Z * Math.sqrt(
      (p * (1 - p) + (Z * Z) / (4 * trials)) / trials);
  const lowerBoundProportion = (center - margin) / denom;
  return Math.max(0, Math.min(1, lowerBoundProportion)) * 5;
}

/**
 * Unique-by-user average, count, Wilson, and ranking fields for a spot.
 * When there are no ratings, ranking is omitted so the caller can set random.
 * @param {Array<Object>} ratings
 * @param {number} wilsonLowerBoundAvg
 * @return {Object}
 */
function computeSpotRatingAggregates(ratings, wilsonLowerBoundAvg) {
  const unique = uniqueRatingsByUser(ratings);
  const count = unique.length;
  if (count === 0) {
    return {
      empty: true,
      averageRating: 0,
      ratingCount: 0,
      wilsonLowerBound: 0,
      ranking: null,
    };
  }

  let sum = 0;
  for (const data of unique) {
    sum += clampRating(data.rating);
  }
  const average = sum / count;
  const wilsonLowerBound = wilsonLowerBoundFromSum(sum, count);
  const avg = Number.isFinite(wilsonLowerBoundAvg) ? wilsonLowerBoundAvg : 0;
  const ranking = rankingFromWilson(wilsonLowerBound, avg);

  return {
    empty: false,
    averageRating: Number(average.toFixed(4)),
    ratingCount: count,
    wilsonLowerBound: Number(wilsonLowerBound.toFixed(4)),
    ranking: Number(ranking.toFixed(4)),
  };
}

module.exports = {
  timestampMillis,
  ratingRecencyMillis,
  clampRating,
  uniqueRatingsByUser,
  ABOVE_AVERAGE_RANKING_OFFSET,
  rankingFromWilson,
  isAboveAverageRanking,
  wilsonLowerBoundFromSum,
  computeSpotRatingAggregates,
};
