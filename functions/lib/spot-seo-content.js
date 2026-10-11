/* eslint-disable max-len */
/**
 * Pure helpers for crawlable spot-page SEO content (view-model only).
 */

const {cleanDescription} = require("./text-processing");
const {isPlausibleYoutubeVideoId} = require("./youtube-thumbnails");

/**
 * Humanize an attribute key for English display (walls_low → Walls low).
 * @param {string} key
 * @return {string}
 */
function humanizeAttributeKey(key) {
  const raw = String(key || "").trim().replace(/_/g, " ");
  if (!raw) return "";
  return raw.charAt(0).toUpperCase() + raw.slice(1);
}

/**
 * Parse jumpflixIds from a spotJumpflixVideos document.
 * @param {Object|null|undefined} data
 * @return {number[]}
 */
function parseJumpflixIds(data) {
  if (!data || typeof data !== "object") return [];
  const ids = data.jumpflixIds;
  if (!Array.isArray(ids)) return [];
  return ids
      .map((e) => (typeof e === "number" ? e : (typeof e === "string" ? parseInt(e, 10) : NaN)))
      .filter((n) => Number.isFinite(n));
}

/**
 * Normalize Jumpflix video docs into {title, url} links.
 * @param {Array<Object>} videos
 * @return {Array<Object>}
 */
function normalizeJumpflixVideoLinks(videos) {
  if (!Array.isArray(videos)) return [];
  const links = [];
  for (const v of videos) {
    if (!v || typeof v !== "object") continue;
    const id = v.id != null ? String(v.id) : "";
    const titleRaw = typeof v.title === "string" ? v.title.trim() : "";
    const urlRaw = typeof v.url === "string" ? v.url.trim() : "";
    const title = titleRaw || (id ? `Jumpflix film ${id}` : "");
    const url = urlRaw || (id ? `https://www.jumpflix.tv/movie/${id}` : "");
    if (!title || !url) continue;
    links.push({title, url});
  }
  return links;
}

/**
 * Build YouTube watch links from spot.youtubeVideoIds.
 * @param {Object} spot
 * @return {Array<Object>}
 */
function buildYoutubeLinks(spot) {
  const ids = spot && Array.isArray(spot.youtubeVideoIds) ? spot.youtubeVideoIds : [];
  const links = [];
  for (const raw of ids) {
    const id = typeof raw === "string" ? raw.trim() : "";
    if (!isPlausibleYoutubeVideoId(id)) continue;
    links.push({
      title: `YouTube video ${id}`,
      url: `https://www.youtube.com/watch?v=${id}`,
    });
  }
  return links;
}

/**
 * @param {Object} spot
 * @return {Object|null}
 */
function buildRatingSummary(spot) {
  if (!spot) return null;
  const value = spot.averageRating;
  const count = spot.ratingCount;
  if (typeof value !== "number" || isNaN(value) || value <= 0) return null;
  if (typeof count !== "number" || !Number.isFinite(count) || count <= 0) return null;
  return {value, count};
}

/**
 * @param {Object} spot
 * @param {string} field
 * @return {string[]}
 */
function stringList(spot, field) {
  const raw = spot && spot[field];
  if (!Array.isArray(raw)) return [];
  return raw
      .filter((v) => typeof v === "string" && v.trim().length > 0)
      .map((v) => humanizeAttributeKey(v.trim()));
}

/**
 * @param {Object} spot
 * @return {Array<Object>}
 */
function buildFacilities(spot) {
  const raw = spot && spot.spotFacilities;
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return [];
  const out = [];
  for (const [key, value] of Object.entries(raw)) {
    if (typeof value !== "string" || !value.trim()) continue;
    const label = humanizeAttributeKey(key);
    if (!label) continue;
    out.push({label, value: value.trim().toLowerCase()});
  }
  return out;
}

/**
 * Build the crawlable spot SEO view-model.
 * Returns null when there is no spot to describe.
 *
 * @param {Object} options
 * @param {Object} options.spot - Spot document data (with id)
 * @param {Array<Object>} [options.breadcrumbs]
 * @param {Array<Object>} [options.jumpflixVideos]
 * @param {string} [options.canonicalHost]
 * @return {Object|null}
 */
function buildSpotSeoContent(options = {}) {
  const spot = options.spot;
  if (!spot || typeof spot !== "object") return null;

  const name = typeof spot.name === "string" ? spot.name.trim() : "";
  if (!name) return null;

  const city = spot.city != null ? String(spot.city).trim() : "";
  const countryCode = spot.countryCode != null ?
    String(spot.countryCode).trim().toUpperCase() : "";
  const locationParts = [];
  if (city) locationParts.push(city);
  if (countryCode) locationParts.push(countryCode);
  const locationLine = locationParts.length > 0 ? locationParts.join(", ") : null;

  const descriptionRaw = typeof spot.description === "string" ? spot.description : "";
  const descriptionPlain = cleanDescription(descriptionRaw).trim();
  const description = descriptionPlain.length > 0 ? descriptionPlain : null;

  const address = spot.address != null && String(spot.address).trim() ?
    String(spot.address).trim() : null;

  const lat = typeof spot.latitude === "number" && Number.isFinite(spot.latitude) ?
    spot.latitude : null;
  const lng = typeof spot.longitude === "number" && Number.isFinite(spot.longitude) ?
    spot.longitude : null;

  let mapUrl = null;
  if (lat != null && lng != null) {
    mapUrl = `https://www.google.com/maps?q=${lat},${lng}`;
  }

  const accessRaw = typeof spot.spotAccess === "string" ? spot.spotAccess.trim() : "";
  const access = accessRaw ? humanizeAttributeKey(accessRaw) : null;

  const sourceName = spot.spotSourceName != null && String(spot.spotSourceName).trim() ?
    String(spot.spotSourceName).trim() : null;

  const breadcrumbs = Array.isArray(options.breadcrumbs) ?
    options.breadcrumbs
        .filter((b) => b && typeof b.name === "string" && typeof b.url === "string")
        .map((b) => ({name: b.name, url: b.url})) :
    [];

  const imageUrls = Array.isArray(spot.imageUrls) ?
    spot.imageUrls.filter((u) => typeof u === "string" && u.trim().startsWith("http")) :
    [];

  return {
    title: name,
    locationLine,
    description,
    address,
    latitude: lat,
    longitude: lng,
    mapUrl,
    rating: buildRatingSummary(spot),
    access,
    features: stringList(spot, "spotFeatures"),
    goodFor: stringList(spot, "goodFor"),
    facilities: buildFacilities(spot),
    youtubeVideos: buildYoutubeLinks(spot),
    jumpflixVideos: normalizeJumpflixVideoLinks(options.jumpflixVideos),
    sourceName,
    breadcrumbs,
    imageUrl: imageUrls.length > 0 ? imageUrls[0] : null,
  };
}

module.exports = {
  humanizeAttributeKey,
  parseJumpflixIds,
  normalizeJumpflixVideoLinks,
  buildYoutubeLinks,
  buildSpotSeoContent,
};
