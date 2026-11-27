/* eslint-disable max-len */
/**
 * Request parsing and response shaping for the yearly review endpoints:
 * the card image (`yearReviewCard`), the page data (`getYearReview`) and
 * the page's share preview (`userAndListPage`).
 *
 * Public URLs (Firebase Hosting rewrites):
 *   /year/2026/@noor             review page (Flutter)
 *   /year/2026/@noor/story.jpg   9:16 card
 *   /year/2026/@noor/square.jpg  1:1 card
 * Users without a username use their uid instead of `@username`.
 */

const {FIRST_STATS_YEAR} = require("./user-stats");
const {moreSpots} = require("./year-review-copy");

const CARD_FILES = Object.freeze({
  "story.jpg": "story",
  "square.jpg": "square",
});

/**
 * @param {unknown} value
 * @param {Date} now
 * @return {number|null} A year with stats that has started, or null.
 */
function parseReviewYear(value, now = new Date()) {
  const year = Number.parseInt(String(value || ""), 10);
  if (!Number.isInteger(year) || String(year) !== String(value).trim()) return null;
  if (year < FIRST_STATS_YEAR || year > now.getUTCFullYear()) return null;
  return year;
}

/**
 * @param {unknown} value
 * @return {string} uid or username without a leading "@", or "".
 */
function normalizeHandle(value) {
  if (typeof value !== "string") return "";
  let decoded = value;
  try {
    decoded = decodeURIComponent(value);
  } catch (_) {
    // Keep the raw segment.
  }
  const handle = decoded.trim().replace(/^@/, "");
  return /^[A-Za-z0-9_.-]{1,64}$/.test(handle) ? handle : "";
}

/**
 * Card request from a Hosting path (`/year/2026/@noor/story.jpg`) or, when
 * the function is called directly, from query parameters
 * (`?user=noor&year=2026&format=story`).
 * @param {string} path
 * @param {Object} query
 * @param {Date=} now
 * @return {{handle: string, year: number, format: string, locale: (string|null)}|null}
 */
function parseYearReviewCardRequest(path, query = {}, now = new Date()) {
  const locale = typeof query.locale === "string" ? query.locale : null;
  const segments = String(path || "").split("/").filter(Boolean);
  if (segments[0] === "year" && segments.length === 4) {
    const format = CARD_FILES[segments[3]];
    const year = parseReviewYear(segments[1], now);
    const handle = normalizeHandle(segments[2]);
    return format && year && handle ? {handle, year, format, locale} : null;
  }
  const format = typeof query.format === "string" ? query.format : "story";
  const year = parseReviewYear(query.year, now);
  const handle = normalizeHandle(query.user);
  if (!Object.values(CARD_FILES).includes(format) || !year || !handle) return null;
  return {handle, year, format, locale};
}

/**
 * Review page path (`/year/2026/@noor`) → handle and year.
 * @param {string[]} segments Path segments.
 * @param {Date=} now
 * @return {{handle: string, year: number}|null}
 */
function parseYearReviewPagePath(segments, now = new Date()) {
  if (segments[0] !== "year" || segments.length !== 3) return null;
  const year = parseReviewYear(segments[1], now);
  const handle = normalizeHandle(segments[2]);
  return year && handle ? {handle, year} : null;
}

/**
 * Public path of a review page or card.
 * @param {{year: number, username: (string|null), userId: string}} data
 * @param {string=} file "story.jpg" or "square.jpg"; omit for the page.
 * @return {string}
 */
function yearReviewPath(data, file) {
  const handle = data.username ? `@${data.username}` : data.userId;
  // "@" is valid as-is in a path segment and handles are limited to
  // [A-Za-z0-9_.-], so no encoding: copied links read /year/2026/@noor rather
  // than %40noor. Parsing still decodes %40 for links shared before.
  const base = `/year/${data.year}/${handle}`;
  return file ? `${base}/${file}` : base;
}

/**
 * JSON for the review page: what the card shows, with frames' spot ids so the
 * page can link to each spot. Dates become ISO strings.
 * @param {Object} data From buildYearReviewData.
 * @param {Object=} options
 * @param {string=} options.sentence The card's sentence as plain text, for
 *     the page's image description.
 * @param {Date=} options.now
 * @return {Object}
 */
function serializeYearReview(data, {sentence = "", now = new Date()} = {}) {
  return {
    sentence,
    userId: data.userId,
    username: data.username,
    name: data.name,
    year: data.year,
    soFar: now.getTime() < Date.UTC(data.year + 1, 0, 1),
    counts: data.counts,
    lead: data.lead,
    places: data.places,
    frames: data.frames.map((frame) => ({
      spotId: frame.spotId,
      kind: frame.kind,
      name: frame.name,
      city: frame.city,
      imageUrl: frame.imageUrl,
      date: frame.date instanceof Date ? frame.date.toISOString() : null,
    })),
    // Spots beyond the listed frames, matching the card's +N and the
    // sentence's count.
    moreCount: moreSpots(data, data.frames.length),
    pagePath: yearReviewPath(data),
    storyPath: yearReviewPath(data, "story.jpg"),
    squarePath: yearReviewPath(data, "square.jpg"),
  };
}

module.exports = {
  parseReviewYear,
  normalizeHandle,
  parseYearReviewCardRequest,
  parseYearReviewPagePath,
  yearReviewPath,
  serializeYearReview,
};
