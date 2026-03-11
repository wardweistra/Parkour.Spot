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
 * Converts a Firebase Storage spot image URL to its resized version (1200x1200).
 * storage-resize-images extension creates: spots/resized/baseName_1200x1200.webp
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
          .replace(/spots%2F([^?&#]+)\.(jpg|jpeg|png|webp)/i, "spots%2Fresized%2F$1_1200x1200.webp");
    }
    // Handle storage.googleapis.com format: .../spots/filename.jpg
    const match = originalUrl.match(/\/(spots)\/([^/]+)\.(jpg|jpeg|png|webp)(\?|#|$)/i);
    if (match && match[1] === "spots" && match[2] !== "resized") {
      const baseName = match[2];
      return originalUrl
          .replace(`/spots/${baseName}.${match[3]}`, `/spots/resized/${baseName}_1200x1200.webp`);
    }
    return originalUrl;
  } catch {
    return originalUrl;
  }
}

/**
 * Parses a Firebase Storage spot image URL and returns original + expected resized paths.
 * Returns null if URL is not a spots/ image (external, already resized, etc).
 * resizedPathCandidates: paths to check for existence (1200x1200, 1200x630). Image "has resized" if any exists.
 * @param {string} url - Firebase Storage image URL
 * @return {{originalPath: string, resizedPath: string, resizedPathCandidates: string[]}|null}
 */
function getResizedPathInfo(url) {
  if (typeof url !== "string") return null;
  try {
    if (!url.includes("storage.googleapis.com") &&
        !url.includes("firebasestorage.googleapis.com")) {
      return null;
    }
    let originalPath = null;
    if (url.includes("firebasestorage.googleapis.com") && url.includes("/o/")) {
      const encodedPath = url.split("/o/")[1]?.split("?")[0] || "";
      originalPath = decodeURIComponent(encodedPath);
    } else {
      const match = url.match(/\/(spots)\/([^/]+)\.(jpg|jpeg|png|webp)(\?|#|$)/i);
      if (match && match[1] === "spots" && match[2] !== "resized") {
        originalPath = `spots/${match[2]}.${match[3].toLowerCase()}`;
      }
    }
    if (!originalPath || !originalPath.startsWith("spots/") ||
        originalPath.startsWith("spots/resized/")) {
      return null;
    }
    const filename = originalPath.split("/").pop();
    const baseName = filename.replace(/\.[^.]+$/, "");
    const resizedPath = `spots/resized/${baseName}_1200x1200.webp`;
    const resizedPathCandidates = [
      resizedPath,
      `spots/resized/${baseName}_1200x630.webp`,
    ];
    return {originalPath, resizedPath, resizedPathCandidates};
  } catch (_) {
    return null;
  }
}

/** Recognized image content types (for excluding application/octet-stream etc.) */
const IMAGE_CONTENT_TYPES = new Set([
  "image/jpeg", "image/jpg", "image/png", "image/webp", "image/gif",
]);

/**
 * Returns the correct image content type for a storage path.
 * If storedContentType is application/octet-stream or not a recognized image type,
 * derives the type from the file extension.
 * @param {string} storagePath - e.g. "spots/filename.jpg"
 * @param {string|null|undefined} storedContentType - current metadata contentType
 * @return {string} Valid image content type
 */
function getImageContentTypeForPath(storagePath, storedContentType) {
  if (storedContentType && IMAGE_CONTENT_TYPES.has(storedContentType)) {
    return storedContentType;
  }
  const ext = (storagePath.split(".").pop() || "").toLowerCase();
  const byExt = {
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    png: "image/png",
    webp: "image/webp",
    gif: "image/gif",
  };
  return byExt[ext] || "image/jpeg";
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
  getResizedPathInfo,
  getImageContentTypeForPath,
  isEphemeralImageHost,
};
