/**
 * YouTube thumbnail URL helpers shared by import and moderator edit.
 */

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

module.exports = {
  youtubeThumbnailUrl,
  isPlausibleYoutubeVideoId,
  youtubeIdsNeedingThumbnails,
};
