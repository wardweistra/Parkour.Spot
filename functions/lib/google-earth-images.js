/* eslint-disable max-len */
/**
 * Google Earth hosted image URL helpers.
 * Google Earth KML exports use gx:imageUrl templates with a {size} placeholder
 * and fife=s{size} query parameter (Google FIFE image sizes).
 */

/** Largest FIFE sizes to try, in descending order. s0 is the original. */
const GOOGLE_EARTH_IMAGE_SIZE_CANDIDATES = ["0", "2048", "1024", "512", "256"];

/**
 * Decodes common XML entity encodings in KML attribute values.
 * @param {string} value
 * @return {string}
 */
function decodeKmlXmlEntities(value) {
  if (typeof value !== "string") return "";
  return value
      .replace(/&amp;/g, "&")
      .replace(/&lt;/g, "<")
      .replace(/&gt;/g, ">")
      .replace(/&quot;/g, "\"")
      .replace(/&#39;/g, "'");
}

/**
 * Resolves a Google Earth gx:imageUrl template to a concrete download URL.
 * Uses s0 (original) when available; callers may retry other sizes on failure.
 * @param {string} templateUrl Raw URL from KML (may contain {size})
 * @param {string=} preferredSize FIFE size suffix without leading s (default 0)
 * @return {string|null}
 */
function resolveGoogleEarthImageUrl(templateUrl, preferredSize = "0") {
  if (typeof templateUrl !== "string") return null;
  const trimmed = decodeKmlXmlEntities(templateUrl.trim());
  if (!trimmed.startsWith("http://") && !trimmed.startsWith("https://")) {
    return null;
  }
  if (trimmed.includes("{size}")) {
    return trimmed.replace(/\{size\}/g, preferredSize);
  }
  return trimmed;
}

/**
 * Builds candidate download URLs for a Google Earth image template, largest first.
 * @param {string} templateUrl
 * @return {string[]}
 */
function buildGoogleEarthImageUrlCandidates(templateUrl) {
  if (typeof templateUrl !== "string") return [];
  const decoded = decodeKmlXmlEntities(templateUrl.trim());
  if (!decoded.startsWith("http://") && !decoded.startsWith("https://")) {
    return [];
  }

  const urls = [];
  const seen = new Set();
  const add = (url) => {
    if (!url || seen.has(url)) return;
    seen.add(url);
    urls.push(url);
  };

  if (decoded.includes("{size}")) {
    for (const size of GOOGLE_EARTH_IMAGE_SIZE_CANDIDATES) {
      add(resolveGoogleEarthImageUrl(decoded, size));
    }
  } else {
    add(decoded);
  }

  return urls;
}

module.exports = {
  GOOGLE_EARTH_IMAGE_SIZE_CANDIDATES,
  decodeKmlXmlEntities,
  resolveGoogleEarthImageUrl,
  buildGoogleEarthImageUrlCandidates,
};
