/* eslint-disable max-len */
/**
 * URL and path helper functions for ParkourSpot Cloud Functions
 */

/**
 * True if hostname is exactly domain or a subdomain of it.
 * @param {string} hostname
 * @param {string} domain
 * @return {boolean}
 */
function hostnameMatches(hostname, domain) {
  if (!hostname || !domain) return false;
  const host = String(hostname).toLowerCase();
  const d = String(domain).toLowerCase();
  return host === d || host.endsWith(`.${d}`);
}

/**
 * True if hostname matches any of the given domains.
 * @param {string} hostname
 * @param {...string} domains
 * @return {boolean}
 */
function hostnameMatchesAny(hostname, ...domains) {
  return domains.some((d) => hostnameMatches(hostname, d));
}

/**
 * Parse hostname from a URL string; null if unparseable.
 * @param {string} url
 * @return {string|null}
 */
function hostnameFromUrl(url) {
  if (typeof url !== "string" || !url) return null;
  try {
    return new URL(url).hostname.toLowerCase();
  } catch (_) {
    return null;
  }
}

/**
 * True if URL host is Firebase / GCS object storage used for spot images.
 * @param {string} url
 * @return {boolean}
 */
function isFirebaseStorageUrl(url) {
  const host = hostnameFromUrl(url);
  if (!host) return false;
  return hostnameMatchesAny(
      host,
      "firebasestorage.googleapis.com",
      "storage.googleapis.com",
  );
}

/**
 * True if URL host is the Firebase download-API host (encoded /o/ paths).
 * @param {string} url
 * @return {boolean}
 */
function isFirebaseStorageDownloadApiUrl(url) {
  const host = hostnameFromUrl(url);
  return host ? hostnameMatches(host, "firebasestorage.googleapis.com") : false;
}

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
    if (isFirebaseStorageDownloadApiUrl(url) && pathname.includes("/o/")) {
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

const RESIZABLE_STORAGE_PREFIXES = ["spots", "events"];

/**
 * Converts a Firebase Storage spot/event image URL to its resized version (1200x1200).
 * storage-resize-images extension creates: {prefix}/resized/baseName_1200x1200.webp
 * @param {string} originalUrl - Original Firebase Storage URL
 * @return {string} Resized URL or original if not convertible
 */
function getResizedImageUrlForApi(originalUrl) {
  if (typeof originalUrl !== "string") return originalUrl;
  try {
    if (!isFirebaseStorageUrl(originalUrl)) {
      return originalUrl;
    }
    const isDownloadApi = isFirebaseStorageDownloadApiUrl(originalUrl);
    for (const prefix of RESIZABLE_STORAGE_PREFIXES) {
      const encodedPrefix = `${prefix}%2F`;
      const encodedResizedPrefix = `${prefix}%2Fresized%2F`;
      if (isDownloadApi &&
          originalUrl.includes(encodedPrefix) &&
          !originalUrl.includes(encodedResizedPrefix)) {
        const pattern = new RegExp(
            `${prefix}%2F([^?&#]+)\\.(jpg|jpeg|png|webp|gif)`, "i");
        if (pattern.test(originalUrl)) {
          return originalUrl.replace(
              pattern,
              `${prefix}%2Fresized%2F$1_1200x1200.webp`,
          );
        }
      }
      const match = originalUrl.match(
          new RegExp(`\\/(?:${prefix})\\/([^/]+)\\.(jpg|jpeg|png|webp|gif)(\\?|#|$)`, "i"),
      );
      if (match && match[1] !== "resized") {
        const baseName = match[1];
        return originalUrl.replace(
            `/${prefix}/${baseName}.${match[2]}`,
            `/${prefix}/resized/${baseName}_1200x1200.webp`,
        );
      }
    }
    return originalUrl;
  } catch {
    return originalUrl;
  }
}

/**
 * Parses a Firebase Storage spot/event image URL and returns original + expected resized paths.
 * Returns null if URL is not a spots/ or events/ image (external, already resized, etc).
 * resizedPathCandidates: paths to check for existence (1200x1200, 1200x630). Image "has resized" if any exists.
 * @param {string} url - Firebase Storage image URL
 * @return {{originalPath: string, resizedPath: string, resizedPathCandidates: string[]}|null}
 */
function getResizedPathInfo(url) {
  if (typeof url !== "string") return null;
  try {
    if (!isFirebaseStorageUrl(url)) {
      return null;
    }
    let originalPath = null;
    if (isFirebaseStorageDownloadApiUrl(url) && url.includes("/o/")) {
      const encodedPath = url.split("/o/")[1]?.split("?")[0] || "";
      originalPath = decodeURIComponent(encodedPath);
    } else {
      for (const prefix of RESIZABLE_STORAGE_PREFIXES) {
        const match = url.match(
            new RegExp(`\\/(?:${prefix})\\/([^/]+)\\.(jpg|jpeg|png|webp|gif)(\\?|#|$)`, "i"),
        );
        if (match && match[1] !== "resized") {
          originalPath = `${prefix}/${match[1]}.${match[2].toLowerCase()}`;
          break;
        }
      }
    }
    if (!originalPath) return null;
    const prefix = RESIZABLE_STORAGE_PREFIXES.find((p) => originalPath.startsWith(`${p}/`));
    if (!prefix || originalPath.startsWith(`${prefix}/resized/`)) {
      return null;
    }
    const filename = originalPath.split("/").pop();
    const baseName = filename.replace(/\.[^.]+$/, "");
    const resizedPath = `${prefix}/resized/${baseName}_1200x1200.webp`;
    const resizedPathCandidates = [
      resizedPath,
      `${prefix}/resized/${baseName}_1200x630.webp`,
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

/**
 * True if URL is a Google profile / user-content image host.
 * @param {string} url
 * @return {boolean}
 */
function isGoogleUserContentUrl(url) {
  const host = hostnameFromUrl(url);
  return host ? hostnameMatches(host, "googleusercontent.com") : false;
}

module.exports = {
  hostnameMatches,
  hostnameMatchesAny,
  hostnameFromUrl,
  isFirebaseStorageUrl,
  isFirebaseStorageDownloadApiUrl,
  isGoogleUserContentUrl,
  extractSpotIdFromPath,
  extractFilename,
  getResizedImageUrlForApi,
  getResizedPathInfo,
  getImageContentTypeForPath,
  isEphemeralImageHost,
};
