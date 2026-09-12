/* eslint-disable max-len */
/**
 * Naver Map shared bookmark-list helpers for parkour spot sync.
 *
 * Accepts a share id or a public/API URL and fetches
 * pages.map.naver.com maps-bookmark JSON (bookmarkList + folder).
 */

const http = require("http");
const https = require("https");

// Naver's bookmark API returns HTTP 500 for non-browser User-Agent strings.
const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";
const DEFAULT_SPOT_NAME = "Parkour spot";
const DEFAULT_PAGE_SIZE = 500;
const MAX_BOOKMARKS = 20000;
const SHARE_ID_RE = /^[a-f0-9]{32}$/i;

/**
 * @param {*} value
 * @return {string|null}
 */
function toNonEmptyString(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * @param {*} value
 * @return {number|null}
 */
function toFiniteNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim()) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return null;
}

/**
 * Extracts a Naver Map bookmark-list share id from a share id, API URL, or
 * public folder URL.
 * @param {*} value
 * @return {string|null}
 */
function extractNaverShareId(value) {
  const raw = toNonEmptyString(value);
  if (!raw) return null;
  if (SHARE_ID_RE.test(raw)) return raw.toLowerCase();

  try {
    const parsed = new URL(raw);
    const path = parsed.pathname || "";
    const sharesMatch = /\/shares\/([a-f0-9]{32})(?:\/|$)/i.exec(path);
    if (sharesMatch) return sharesMatch[1].toLowerCase();
    const folderMatch = /\/folder\/([a-f0-9]{32})(?:\/|$)/i.exec(path);
    if (folderMatch) return folderMatch[1].toLowerCase();
    const anyMatch = /([a-f0-9]{32})/i.exec(path);
    if (anyMatch) return anyMatch[1].toLowerCase();
  } catch (_) {
    return null;
  }
  return null;
}

/**
 * @param {string} shareId
 * @return {string}
 */
function naverSharePageUrl(shareId) {
  return `https://map.naver.com/p/favorite/sharedPlace/folder/${shareId}`;
}

/**
 * @param {string} shareId
 * @param {number} start
 * @param {number} limit
 * @return {string}
 */
function naverBookmarksApiUrl(shareId, start, limit) {
  const params = new URLSearchParams({
    start: String(start),
    limit: String(limit),
    sort: "lastUseTime",
  });
  return "https://pages.map.naver.com/save-pages/api/maps-bookmark/v3/shares/" +
    `${shareId}/bookmarks?${params.toString()}`;
}

/**
 * @param {Object} bookmark
 * @return {{latitude: number, longitude: number, altitude: number}|null}
 */
function extractNaverCoordinates(bookmark) {
  if (!bookmark || typeof bookmark !== "object") return null;
  const longitude = toFiniteNumber(bookmark.px);
  const latitude = toFiniteNumber(bookmark.py);
  if (latitude == null || longitude == null) return null;
  if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
    return null;
  }
  return {latitude, longitude, altitude: 0};
}

/**
 * @param {Object} bookmark
 * @return {string}
 */
function pickNaverName(bookmark) {
  return toNonEmptyString(bookmark.displayName) ||
    toNonEmptyString(bookmark.displayname) ||
    toNonEmptyString(bookmark.name) ||
    toNonEmptyString(bookmark.address) ||
    toNonEmptyString(bookmark.mappedAddress) ||
    DEFAULT_SPOT_NAME;
}

/**
 * @param {Object} bookmark
 * @return {string}
 */
function buildNaverDescription(bookmark) {
  const lines = [];
  const memo = toNonEmptyString(bookmark.memo);
  if (memo) lines.push(memo);
  const url = toNonEmptyString(bookmark.url);
  if (url) lines.push(`Website: ${url}`);
  return lines.join("\n\n");
}

/**
 * @param {*} mappings
 * @return {string[]}
 */
function folderNamesFromMappings(mappings) {
  if (!Array.isArray(mappings)) return [];
  const names = [];
  for (const mapping of mappings) {
    if (typeof mapping === "string") {
      const name = toNonEmptyString(mapping);
      if (name) names.push(name);
      continue;
    }
    if (!mapping || typeof mapping !== "object") continue;
    const name = toNonEmptyString(mapping.name) ||
      toNonEmptyString(mapping.folderName) ||
      toNonEmptyString(mapping.folder);
    if (name) names.push(name);
  }
  return names;
}

/**
 * @param {string[]} names
 * @return {string[]}
 */
function uniqueNonEmpty(names) {
  const seen = new Set();
  const result = [];
  for (const name of names) {
    const normalized = toNonEmptyString(name);
    if (!normalized) continue;
    const key = normalized.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(normalized);
  }
  return result;
}

/**
 * Maps one Naver bookmark to a sync placemark.
 * @param {Object} bookmark
 * @param {string|null} shareFolderName
 * @return {Object|null}
 */
function mapNaverBookmarkToPlacemark(bookmark, shareFolderName = null) {
  if (!bookmark || typeof bookmark !== "object") return null;
  if (bookmark.available === false) return null;

  const bookmarkId = bookmark.bookmarkId;
  if (bookmarkId == null || String(bookmarkId).trim() === "") return null;

  const coordinates = extractNaverCoordinates(bookmark);
  if (!coordinates) return null;

  const folderPath = uniqueNonEmpty([
    shareFolderName,
    ...folderNamesFromMappings(bookmark.folderMappings),
  ]);
  const folderName = folderPath.length > 0 ?
    folderPath[folderPath.length - 1] :
    null;

  const address = toNonEmptyString(bookmark.address) ||
    toNonEmptyString(bookmark.mappedAddress);

  const placemark = {
    name: pickNaverName(bookmark),
    description: buildNaverDescription(bookmark),
    coordinates,
    externalId: `bookmark/${String(bookmarkId).trim()}`,
    extendedData: {},
    folderPath,
    folderName,
  };

  if (address) {
    placemark.address = address;
  }

  if (bookmark.isIndoor === true) {
    placemark.spotFacilities = {covered: "yes"};
  }

  return placemark;
}

/**
 * @param {Object} json
 * @return {Object[]}
 */
function mapNaverBookmarksResponseToPlacemarks(json) {
  const folderName = json && json.folder ?
    toNonEmptyString(json.folder.name) :
    null;
  const list = json && Array.isArray(json.bookmarkList) ?
    json.bookmarkList :
    (json && Array.isArray(json.bookmarks) ? json.bookmarks : []);
  const placemarks = [];
  for (const bookmark of list) {
    const placemark = mapNaverBookmarkToPlacemark(bookmark, folderName);
    if (placemark) placemarks.push(placemark);
  }
  return placemarks;
}

/**
 * @param {string} url
 * @param {number=} redirectCount
 * @return {Promise<string>}
 */
function getText(url, redirectCount = 0) {
  if (redirectCount > 5) {
    return Promise.reject(
        new Error("Too many redirects while fetching Naver Map bookmarks"),
    );
  }

  const parsedUrl = new URL(url);
  if (parsedUrl.protocol !== "https:" && parsedUrl.protocol !== "http:") {
    return Promise.reject(new Error("Naver Map URL must use http or https"));
  }
  const client = parsedUrl.protocol === "http:" ? http : https;

  return new Promise((resolve, reject) => {
    const request = client.request(parsedUrl, {
      method: "GET",
      headers: {
        "User-Agent": USER_AGENT,
        "Accept": "application/json",
        "Referer": "https://map.naver.com/",
      },
    }, (response) => {
      if (
        response.statusCode &&
        response.statusCode >= 300 &&
        response.statusCode < 400 &&
        response.headers.location
      ) {
        response.resume();
        const redirectedUrl = new URL(
            response.headers.location,
            parsedUrl,
        ).toString();
        resolve(getText(redirectedUrl, redirectCount + 1));
        return;
      }

      let responseBody = "";
      response.setEncoding("utf8");
      response.on("data", (chunk) => {
        responseBody += chunk;
      });
      response.on("end", () => {
        const statusCode = response.statusCode || 0;
        if (statusCode >= 400) {
          reject(new Error(
              `Naver Map bookmarks request failed (HTTP ${statusCode})`,
          ));
          return;
        }
        resolve(responseBody);
      });
    });

    request.on("error", reject);
    request.setTimeout(60000, () => {
      request.destroy(new Error("Naver Map bookmarks request timed out"));
    });
    request.end();
  });
}

/**
 * @param {number} ms
 * @return {Promise<void>}
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Fetches every page of a shared Naver Map bookmark list.
 * @param {*} sourceUrl Share id, public folder URL, or bookmarks API URL
 * @param {Object=} options
 * @param {Function=} options.getTextFn Injectable GET helper for tests
 * @param {number=} options.pageSize
 * @param {number=} options.maxAttempts
 * @return {Promise<Object[]>}
 */
async function fetchNaverBookmarkPlacemarks(sourceUrl, options = {}) {
  const shareId = extractNaverShareId(sourceUrl);
  if (!shareId) {
    throw new Error(
        "Invalid Naver Map share URL. Paste a shared bookmark list URL " +
        "or the maps-bookmark API URL.",
    );
  }

  const getTextFn = options.getTextFn || getText;
  const pageSize = options.pageSize || DEFAULT_PAGE_SIZE;
  const maxAttempts = options.maxAttempts || 3;

  const placemarks = [];
  let start = 0;
  let shareFolderName = null;
  let totalCount = null;

  while (start < MAX_BOOKMARKS) {
    const apiUrl = naverBookmarksApiUrl(shareId, start, pageSize);
    let lastError = null;
    let json = null;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        const text = await getTextFn(apiUrl);
        json = JSON.parse(text);
        lastError = null;
        break;
      } catch (error) {
        lastError = error;
        const message = error && error.message ? String(error.message) : "";
        const retryable =
          message.includes("HTTP 429") ||
          message.includes("HTTP 504") ||
          message.includes("HTTP 502") ||
          message.includes("timed out");
        if (!retryable || attempt === maxAttempts) {
          break;
        }
        await sleep(1000 * attempt);
      }
    }

    if (lastError) {
      throw new Error(
          `Failed fetching Naver Map bookmarks: ${
            lastError.message ? lastError.message : "unknown error"
          }`,
      );
    }

    if (!shareFolderName && json && json.folder) {
      shareFolderName = toNonEmptyString(json.folder.name);
    }
    if (totalCount == null && json && json.folder) {
      totalCount = toFiniteNumber(json.folder.bookmarkCount);
    }

    const list = json && Array.isArray(json.bookmarkList) ?
      json.bookmarkList :
      (json && Array.isArray(json.bookmarks) ? json.bookmarks : []);
    for (const bookmark of list) {
      const placemark = mapNaverBookmarkToPlacemark(bookmark, shareFolderName);
      if (placemark) placemarks.push(placemark);
    }

    if (list.length === 0 || list.length < pageSize) {
      break;
    }
    start += list.length;
    if (totalCount != null && start >= totalCount) {
      break;
    }
  }

  return placemarks;
}

module.exports = {
  USER_AGENT,
  DEFAULT_SPOT_NAME,
  extractNaverShareId,
  naverSharePageUrl,
  naverBookmarksApiUrl,
  extractNaverCoordinates,
  pickNaverName,
  buildNaverDescription,
  mapNaverBookmarkToPlacemark,
  mapNaverBookmarksResponseToPlacemarks,
  fetchNaverBookmarkPlacemarks,
};
