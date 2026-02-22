/* eslint-disable max-len */
/**
 * Text processing helpers for ParkourSpot Cloud Functions
 */

const {buildSpotSearchWords} = require("./spot-attributes");

/**
 * Builds description for social sharing from spot data
 * @param {Object} s - Spot data object
 * @return {string} Formatted description
 */
function buildDescription(s) {
  const defaultDescription = "Discover and share parkour spots around the world";
  if (!s) return defaultDescription;
  const parts = [];
  if (s.address && String(s.address).trim().length > 0) {
    parts.push(`📍 ${String(s.address).trim()}`);
  }
  if (typeof s.averageRating === "number" && !isNaN(s.averageRating) && s.ratingCount > 0 && s.averageRating > 0) {
    parts.push(`⭐ ${s.averageRating.toFixed(1)}`);
  }
  if (s.description && String(s.description).trim().length > 0) {
    const d = String(s.description).trim().replace(/\s+/g, " ");
    // Keep description concise
    const clipped = d.length > 220 ? d.slice(0, 217) + "…" : d;
    parts.push(`💬 ${clipped}`);
  }
  return parts.length ? parts.join("\n") : defaultDescription;
}

/**
 * Normalizes search query: lowercase, remove punctuation. Returns string for matching.
 * @param {string} str
 * @return {string}
 */
function normalizeSearchQuery(str) {
  if (!str || typeof str !== "string") return "";
  return str
      .toLowerCase()
      .replace(/[\s\p{P}\p{S}]/gu, " ")
      .replace(/[^\p{L}\p{N}\s]/gu, "")
      .replace(/\s+/g, " ")
      .trim();
}

/**
 * Extracts search tokens from query (same logic as buildSpotSearchWords).
 * @param {string} query
 * @return {string[]}
 */
function getSearchQueryTokens(query) {
  return buildSpotSearchWords(query);
}

/**
 * Deterministic doc ID for spotSearchTerms collection
 * @param {string} spotId
 * @param {string} term
 * @return {string}
 */
function spotSearchTermDocId(spotId, term) {
  return `${spotId}_${term}`;
}

/**
 * Cleans HTML from description text
 * @param {string} description - The description text to clean
 * @return {string} The cleaned description text
 */
function cleanDescription(description) {
  if (!description) return "";

  // Remove HTML tags but preserve line breaks
  let cleaned = description
      .replace(/<br\s*\/?>/gi, "\n") // Convert <br> tags to newlines
      .replace(/<img[^>]*>/gi, "") // Remove <img> tags
      .replace(/<[^>]*>/g, "") // Remove all other HTML tags
      .replace(/&nbsp;/g, " ") // Convert &nbsp; to spaces
      .replace(/&amp;/g, "&") // Convert &amp; to &
      .replace(/&lt;/g, "<") // Convert &lt; to <
      .replace(/&gt;/g, ">") // Convert &gt; to >
      .replace(/&quot;/g, "\"") // Convert &quot; to "
      .replace(/&apos;/g, "'") // Convert &apos; to '
      .replace(/\n\s*\n\s*\n/g, "\n\n") // Replace 3+ newlines with 2
      .replace(/\n\s*\n/g, "\n\n") // Replace 2+ newlines with 2
      .trim(); // Remove leading/trailing whitespace

  // Remove YouTube URLs since we extract video IDs separately
  cleaned = cleaned
      .replace(/https?:\/\/(www\.)?youtube\.com\/watch\?v=[^\s\n]+/g, "") // Remove watch URLs
      .replace(/https?:\/\/(www\.)?youtube\.com\/embed\/[^\s\n]+/g, "") // Remove embed URLs
      .replace(/https?:\/\/(www\.)?youtube\.com\/shorts\/[^\s\n]+/g, "") // Remove shorts URLs
      .replace(/https?:\/\/youtu\.be\/[^\s\n]+/g, "") // Remove youtu.be URLs
      .replace(/\]\]>/g, "") // Remove CDATA closing tags
      .replace(/\n\s*\n\s*\n/g, "\n\n") // Clean up extra newlines again
      .replace(/\n\s*\n/g, "\n\n") // Replace 2+ newlines with 2
      .trim(); // Remove leading/trailing whitespace

  return cleaned;
}

/**
 * Extract YouTube video IDs from an HTML/text description
 * Supports urls like: youtu.be/<id>, youtube.com/watch?v=<id>, embed/<id>, shorts/<id>
 * @param {string} description
 * @return {string[]} unique list of video IDs
 */
function extractYoutubeVideoIdsFromDescription(description) {
  if (!description) return [];
  const ids = new Set();

  const urlRegex = /(https?:\/\/[^\s"'<>)]+)/g;
  let match;
  while ((match = urlRegex.exec(description)) !== null) {
    const url = match[1];
    try {
      const uri = new URL(url);
      const host = uri.hostname.toLowerCase();
      const segments = uri.pathname.split("/").filter(Boolean);

      if (host.includes("youtu.be")) {
        const last = segments[segments.length - 1];
        if (last) ids.add(last);
        continue;
      }

      if (host.includes("youtube.com") || host.includes("www.youtube.com")) {
        const v = uri.searchParams.get("v");
        if (v) {
          ids.add(v);
          continue;
        }
        const embedIdx = segments.indexOf("embed");
        if (embedIdx !== -1 && embedIdx + 1 < segments.length) {
          ids.add(segments[embedIdx + 1]);
          continue;
        }
        const shortsIdx = segments.indexOf("shorts");
        if (shortsIdx !== -1 && shortsIdx + 1 < segments.length) {
          ids.add(segments[shortsIdx + 1]);
          continue;
        }
      }
    } catch (_) {
      // Ignore parse errors
    }
  }

  return Array.from(ids);
}

/**
 * Extracts image URLs from placemark data
 * @param {Object} placemark - The placemark data (description may be string or array)
 * @return {string[]} The image URLs
 */
function extractImageUrls(placemark) {
  const imageUrls = [];
  const desc = placemark?.description;
  const description = Array.isArray(desc) ? (desc[0] || "") : (desc || "");

  // Extract from description CDATA
  const imgRegex = /<img[^>]+src="([^"]+)"/g;
  let match;
  while ((match = imgRegex.exec(description)) !== null) {
    imageUrls.push(match[1]);
  }

  // Also add YouTube thumbnails for any YouTube links present in the description
  const youtubeIds = extractYoutubeVideoIdsFromDescription(description);
  for (const vid of youtubeIds) {
    const existingThumbnail = imageUrls.find(
        (url) =>
          url.includes(`img.youtube.com/vi/${vid}/`) &&
        (url.includes("hqdefault.jpg") ||
          url.includes("mqdefault.jpg") ||
          url.includes("default.jpg")),
    );

    if (existingThumbnail) {
      const index = imageUrls.indexOf(existingThumbnail);
      imageUrls[index] = `https://img.youtube.com/vi/${vid}/maxresdefault.jpg`;
    } else {
      imageUrls.push(`https://img.youtube.com/vi/${vid}/maxresdefault.jpg`);
    }
  }

  // Extract from ExtendedData gx_media_links
  const extendedData = placemark.extendedData || {};
  if (extendedData.Data) {
    const mediaData = extendedData.Data.find(
        (data) => data.$ && data.$.name === "gx_media_links",
    );
    if (mediaData && mediaData.value && mediaData.value[0]) {
      const mediaUrls = mediaData.value[0]
          .split(" ")
          .filter((url) => url.trim());
      imageUrls.push(...mediaUrls);
    }
  }

  // Remove duplicates and filter out invalid URLs
  const filteredUrls = [...new Set(imageUrls)].filter((url) => {
    if (!url || !url.startsWith("http")) {
      return false;
    }
    try {
      const host = new URL(url).hostname.toLowerCase();
      const isValid =
        host.includes("google.com") ||
        host.includes("googleusercontent.com") ||
        host.includes("img.youtube.com") ||
        host.includes("ytimg.com");
      return isValid;
    } catch (_) {
      return false;
    }
  });
  return filteredUrls;
}

module.exports = {
  buildDescription,
  normalizeSearchQuery,
  getSearchQueryTokens,
  spotSearchTermDocId,
  cleanDescription,
  extractYoutubeVideoIdsFromDescription,
  extractImageUrls,
};
