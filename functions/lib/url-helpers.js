/* eslint-disable max-len */
/**
 * URL and path helper functions for ParkourSpot Cloud Functions
 */

/**
 * Extracts spot ID from URL pathname
 * @param {string} pathname - The URL pathname
 * @return {string|null} The extracted spot ID or null
 */
function extractSpotIdFromPath(pathname) {
  // Match: /<cc>/<city>/<spotId>
  let m = pathname.match(/^\/[a-zA-Z]{2}\/[^/]+\/([^/?#]+)$/);
  if (m && m[1]) return m[1];
  // Match: /spot/<spotId>
  m = pathname.match(/^\/spot\/([^/?#]+)$/);
  if (m && m[1]) return m[1];
  return null;
}

/**
 * Extracts filename from URL
 * @param {string} url - The URL
 * @return {string|null} The extracted filename or null
 */
function extractFilename(url) {
  try {
    const urlObj = new URL(url);
    const pathname = urlObj.pathname;

    // Handle Firebase Storage URLs with encoded paths
    if (
      url.includes("firebasestorage.googleapis.com") &&
      pathname.includes("/o/")
    ) {
      // Format: /v0/b/bucket-name/o/spots%2Ffilename.jpg
      const encodedPath = pathname.split("/o/")[1];
      const decodedPath = decodeURIComponent(encodedPath);
      return decodedPath.split("/").pop();
    } else {
      // Format: /bucket-name/spots/filename.jpg
      return pathname.split("/").pop();
    }
  } catch (urlError) {
    // Fallback to simple extraction
    const urlParts = url.split("/");
    const lastPart = urlParts[urlParts.length - 1];
    return lastPart.split("?")[0]; // Remove query parameters
  }
}

/**
 * Converts a Firebase Storage spot image URL to its resized version.
 * storage-resize-images extension creates: spots/resized/baseName_1200x630.webp
 * @param {string} originalUrl - Original Firebase Storage URL
 * @return {string} Resized URL or original if not convertible
 */
function getResizedImageUrlForApi(originalUrl) {
  if (typeof originalUrl !== "string") return originalUrl;
  try {
    if (!originalUrl.includes("storage.googleapis.com") &&
        !originalUrl.includes("firebasestorage.googleapis.com")) {
      return originalUrl;
    }
    // Handle firebasestorage.googleapis.com/v0/b/bucket/o/spots%2Ffilename.jpg
    if (originalUrl.includes("firebasestorage.googleapis.com") &&
        originalUrl.includes("spots%2F") && !originalUrl.includes("spots%2Fresized%2F")) {
      return originalUrl
          .replace(/spots%2F([^?&#]+)\.(jpg|jpeg|png|webp)/i, "spots%2Fresized%2F$1_1200x630.webp");
    }
    // Handle storage.googleapis.com format: .../spots/filename.jpg
    const match = originalUrl.match(/\/(spots)\/([^/]+)\.(jpg|jpeg|png|webp)(\?|#|$)/i);
    if (match && match[1] === "spots" && match[2] !== "resized") {
      const baseName = match[2];
      return originalUrl
          .replace(`/spots/${baseName}.${match[3]}`, `/spots/resized/${baseName}_1200x630.webp`);
    }
    return originalUrl;
  } catch {
    return originalUrl;
  }
}

/**
 * Determines whether a given image URL belongs to an ephemeral Google host
 * whose links are unstable and should not be cached by original URL.
 * @param {string} imageUrl
 * @return {boolean}
 */
function isEphemeralImageHost(imageUrl) {
  try {
    const host = new URL(imageUrl).hostname.toLowerCase();
    return (
      host === "mymaps.usercontent.google.com" ||
      host === "lh3.googleusercontent.com"
    );
  } catch (_) {
    return false;
  }
}

module.exports = {
  extractSpotIdFromPath,
  extractFilename,
  getResizedImageUrlForApi,
  isEphemeralImageHost,
};
