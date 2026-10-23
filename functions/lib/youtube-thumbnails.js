/**
 * YouTube thumbnail URL helpers shared by import and moderator edit.
 */

const https = require("https");

/** Thumbnail qualities to try, highest resolution first. */
const YOUTUBE_THUMBNAIL_QUALITIES = [
  "maxresdefault",
  "sddefault",
  "hqdefault",
];

/**
 * Builds a YouTube thumbnail URL for a video ID.
 * @param {string} videoId
 * @param {string=} quality maxresdefault, sddefault, or hqdefault
 * @return {string}
 */
function youtubeThumbnailUrl(videoId, quality = "maxresdefault") {
  return `https://img.youtube.com/vi/${videoId}/${quality}.jpg`;
}

/**
 * True when the string looks like a YouTube video ID (not a URL).
 * @param {string} id
 * @return {boolean}
 */
function isPlausibleYoutubeVideoId(id) {
  return typeof id === "string" && /^[a-zA-Z0-9_-]{6,20}$/.test(id);
}

/**
 * Extracts a video ID from a YouTube CDN thumbnail URL, if present.
 * @param {string} url
 * @return {string|null}
 */
function extractYoutubeVideoIdFromThumbnailUrl(url) {
  if (typeof url !== "string" || !url) return null;
  const match = url.match(
      /(?:img\.youtube\.com|i\d*\.ytimg\.com)\/vi\/([a-zA-Z0-9_-]{6,20})\//,
  );
  return match ? match[1] : null;
}

/**
 * True when [url] points at a YouTube CDN thumbnail.
 * @param {string} url
 * @return {boolean}
 */
function isYoutubeCdnThumbnailUrl(url) {
  return extractYoutubeVideoIdFromThumbnailUrl(url) != null;
}

/**
 * Candidate thumbnail URLs for [url], highest quality first.
 * Returns an empty array when [url] is not a YouTube CDN thumbnail.
 * @param {string} url
 * @return {string[]}
 */
function getYoutubeThumbnailUrlCandidates(url) {
  const videoId = extractYoutubeVideoIdFromThumbnailUrl(url);
  if (!videoId) return [];
  return YOUTUBE_THUMBNAIL_QUALITIES.map((quality) =>
    youtubeThumbnailUrl(videoId, quality),
  );
}

/**
 * HEAD-checks whether a YouTube thumbnail URL is available (HTTP 200).
 * @param {string} url
 * @return {Promise<boolean>}
 */
function checkYoutubeThumbnailAvailable(url) {
  return new Promise((resolve) => {
    let parsedUrl;
    try {
      parsedUrl = new URL(url);
    } catch (_) {
      resolve(false);
      return;
    }
    if (parsedUrl.protocol !== "https:") {
      resolve(false);
      return;
    }

    const request = https.request(
        parsedUrl,
        {
          method: "HEAD",
          headers: {
            "User-Agent": "ParkourSpotImageSync/1.0 (+https://parkour.spot)",
          },
        },
        (response) => {
          response.resume();
          resolve(response.statusCode === 200);
        },
    );
    request.on("error", () => resolve(false));
    request.setTimeout(10000, () => {
      request.destroy();
      resolve(false);
    });
    request.end();
  });
}

/**
 * Returns the highest-quality available YouTube thumbnail URL for [videoId],
 * or null when none are available.
 * @param {string} videoId
 * @return {Promise<string|null>}
 */
async function resolveYoutubeThumbnailUrl(videoId) {
  if (!isPlausibleYoutubeVideoId(videoId)) return null;
  for (const quality of YOUTUBE_THUMBNAIL_QUALITIES) {
    const url = youtubeThumbnailUrl(videoId, quality);
    if (await checkYoutubeThumbnailAvailable(url)) {
      return url;
    }
  }
  return null;
}

/**
 * Newly added video IDs that do not already have a YouTube CDN
 * thumbnail in photos.
 * @param {string[]} previousIds
 * @param {string[]} nextIds
 * @param {string[]=} existingImageUrls
 * @return {string[]}
 */
function youtubeIdsNeedingThumbnails(
    previousIds,
    nextIds,
    existingImageUrls = [],
) {
  const previous = new Set((previousIds || []).filter(Boolean));
  const urls = existingImageUrls || [];
  const seen = new Set();
  const result = [];
  for (const rawId of nextIds || []) {
    const id = typeof rawId === "string" ? rawId.trim() : "";
    if (!id || previous.has(id) || seen.has(id)) continue;
    seen.add(id);
    const alreadyHasThumbnail = urls.some((url) =>
      typeof url === "string" &&
      (url.includes(`img.youtube.com/vi/${id}/`) ||
        url.includes(`i.ytimg.com/vi/${id}/`)),
    );
    if (!alreadyHasThumbnail) {
      result.push(id);
    }
  }
  return result;
}

/**
 * Indices of YouTube CDN thumbnail URLs in [imageUrls].
 * @param {string[]|*} imageUrls
 * @return {number[]}
 */
function youtubeCdnImageUrlIndices(imageUrls) {
  if (!Array.isArray(imageUrls)) return [];
  const indices = [];
  for (let i = 0; i < imageUrls.length; i++) {
    if (isYoutubeCdnThumbnailUrl(imageUrls[i])) {
      indices.push(i);
    }
  }
  return indices;
}

/**
 * Rewrites imageUrls/imageHashes using successful rehosts keyed by index.
 * Only updates hashes when the parallel array length matches imageUrls.
 *
 * @param {Object} options
 * @param {string[]} options.imageUrls
 * @param {string[]=} options.imageHashes
 * @param {Object} options.rehosts Map of index -> {url, hash}
 * @return {Object} `{imageUrls, imageHashes, replacedCount, changed}`
 */
function applyYoutubeCdnRehosts({imageUrls, imageHashes, rehosts}) {
  const urls = Array.isArray(imageUrls) ? [...imageUrls] : [];
  const hashesAligned =
    Array.isArray(imageHashes) && imageHashes.length === urls.length;
  const hashes = hashesAligned ? [...imageHashes] : undefined;
  let replacedCount = 0;

  if (!rehosts || typeof rehosts !== "object") {
    return {
      imageUrls: urls,
      imageHashes: hashes,
      replacedCount: 0,
      changed: false,
    };
  }

  for (const [rawIndex, entry] of Object.entries(rehosts)) {
    const index = Number(rawIndex);
    if (!Number.isInteger(index) || index < 0 || index >= urls.length) {
      continue;
    }
    if (!isYoutubeCdnThumbnailUrl(urls[index])) continue;
    const nextUrl = entry && typeof entry.url === "string" ? entry.url : "";
    if (!nextUrl) continue;
    urls[index] = nextUrl;
    if (hashes && typeof entry.hash === "string" && entry.hash) {
      hashes[index] = entry.hash;
    }
    replacedCount += 1;
  }

  return {
    imageUrls: urls,
    imageHashes: hashes,
    replacedCount,
    changed: replacedCount > 0,
  };
}

module.exports = {
  YOUTUBE_THUMBNAIL_QUALITIES,
  youtubeThumbnailUrl,
  isPlausibleYoutubeVideoId,
  extractYoutubeVideoIdFromThumbnailUrl,
  isYoutubeCdnThumbnailUrl,
  getYoutubeThumbnailUrlCandidates,
  checkYoutubeThumbnailAvailable,
  resolveYoutubeThumbnailUrl,
  youtubeIdsNeedingThumbnails,
  youtubeCdnImageUrlIndices,
  applyYoutubeCdnRehosts,
};
