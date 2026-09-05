/* eslint-disable max-len */
/**
 * OpenStreetMap Overpass helpers for parkour spot sync.
 */

const http = require("http");
const https = require("https");

const OVERPASS_URL = "https://overpass-api.de/api/interpreter";
const OVERPASS_QUERY =
  "[out:json][timeout:90];\nnwr[\"sport\"=\"parkour\"];\nout center tags;";
const USER_AGENT = "ParkourSpotOsmSync/1.0 (+https://parkour.spot)";
const DEFAULT_SPOT_NAME = "Parkour spot";

const GYM_LEISURE = new Set([
  "sports_centre",
  "fitness_centre",
  "sports_hall",
]);
const OUTDOOR_LEISURE = new Set([
  "pitch",
  "playground",
  "park",
  "fitness_station",
]);

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
 * @param {Object} tags
 * @return {string}
 */
function pickOsmName(tags) {
  const direct = toNonEmptyString(tags.name);
  if (direct) return direct;
  const en = toNonEmptyString(tags["name:en"]);
  if (en) return en;
  for (const [key, value] of Object.entries(tags || {})) {
    if (!key.startsWith("name:")) continue;
    const localized = toNonEmptyString(value);
    if (localized) return localized;
  }
  return DEFAULT_SPOT_NAME;
}

/**
 * @param {Object} tags
 * @return {string}
 */
function buildOsmDescription(tags) {
  const lines = [];
  const description = toNonEmptyString(tags.description);
  if (description) lines.push(description);
  const note = toNonEmptyString(tags.note);
  if (note) lines.push(note);
  const website = toNonEmptyString(tags.website) || toNonEmptyString(tags.url);
  if (website) lines.push(`Website: ${website}`);
  const openingHours = toNonEmptyString(tags.opening_hours);
  if (openingHours) lines.push(`Opening hours: ${openingHours}`);
  const phone = toNonEmptyString(tags.phone) || toNonEmptyString(tags["contact:phone"]);
  if (phone) lines.push(`Phone: ${phone}`);
  return lines.join("\n\n");
}

/**
 * @param {string} value
 * @return {boolean}
 */
function isYes(value) {
  return typeof value === "string" && value.trim().toLowerCase() === "yes";
}

/**
 * @param {string} value
 * @return {boolean}
 */
function isNo(value) {
  return typeof value === "string" && value.trim().toLowerCase() === "no";
}

/**
 * Maps OSM access/fee/leisure tags to ParkourSpot spotAccess.
 * @param {Object} tags
 * @return {string|null} public|restricted|paid|null
 */
function mapOsmSpotAccess(tags) {
  const access = toNonEmptyString(tags.access);
  const fee = toNonEmptyString(tags.fee);
  const leisure = toNonEmptyString(tags.leisure);
  const accessLower = access ? access.toLowerCase() : null;
  const feeLower = fee ? fee.toLowerCase() : null;

  if (feeLower === "yes" || accessLower === "customers") {
    return "paid";
  }
  if (
    accessLower === "private" ||
    accessLower === "no" ||
    accessLower === "permit"
  ) {
    return "restricted";
  }
  if (accessLower === "yes" && feeLower !== "yes") {
    return "public";
  }
  if (leisure && OUTDOOR_LEISURE.has(leisure)) {
    return "public";
  }
  if (leisure && GYM_LEISURE.has(leisure)) {
    // Gym-like without explicit fee/access: leave unset rather than guessing paid.
    return null;
  }
  return null;
}

/**
 * @param {Object} tags
 * @return {Object|null}
 */
function mapOsmSpotFacilities(tags) {
  const facilities = {};
  const lit = toNonEmptyString(tags.lit);
  if (lit && isYes(lit)) facilities.lighting = "yes";
  if (lit && isNo(lit)) facilities.lighting = "no";

  const covered = toNonEmptyString(tags.covered);
  const indoor = toNonEmptyString(tags.indoor);
  const indoorLower = indoor ? indoor.toLowerCase() : null;
  if (
    (covered && isYes(covered)) ||
    indoorLower === "yes" ||
    indoorLower === "room"
  ) {
    facilities.covered = "yes";
  } else if (covered && isNo(covered)) {
    facilities.covered = "no";
  } else if (indoorLower === "no") {
    facilities.covered = "no";
  }

  return Object.keys(facilities).length > 0 ? facilities : null;
}

/**
 * Builds a Wikimedia Commons Special:FilePath URL for a File: title.
 * @param {string} filename
 * @return {string}
 */
function commonsSpecialFilePath(filename) {
  const normalized = String(filename).trim().replace(/ /g, "_");
  return `https://commons.wikimedia.org/wiki/Special:FilePath/${encodeURIComponent(normalized)}`;
}

/**
 * Resolves one OSM image / wikimedia_commons value to a downloadable image URL.
 * Wiki File: pages are converted to Commons Special:FilePath; Category: is skipped.
 * @param {string} value
 * @return {string|null}
 */
function resolveOsmImageReference(value) {
  const raw = toNonEmptyString(value);
  if (!raw) return null;

  if (/^Category:/i.test(raw)) {
    return null;
  }

  const fileTag = /^File:(.+)$/i.exec(raw);
  if (fileTag) {
    return commonsSpecialFilePath(fileTag[1]);
  }

  if (!/^https?:\/\//i.test(raw)) {
    return null;
  }

  try {
    const parsed = new URL(raw);
    const host = parsed.hostname.toLowerCase();
    const pathname = parsed.pathname || "";

    // OSM wiki / Commons File: description pages are HTML, not images.
    const filePathMatch = /\/wiki\/File:(.+)$/i.exec(pathname);
    if (
      filePathMatch &&
      (host === "wiki.openstreetmap.org" ||
        host === "commons.wikimedia.org" ||
        host.endsWith(".wikipedia.org") ||
        host.endsWith(".wikimedia.org"))
    ) {
      return commonsSpecialFilePath(decodeURIComponent(filePathMatch[1]));
    }

    // Already a Commons media redirect/path or upload CDN.
    if (
      host === "upload.wikimedia.org" ||
      /\/Special:(FilePath|Redirect\/file)\//i.test(pathname)
    ) {
      return raw;
    }

    // Direct image URLs from other hosts.
    if (/\.(jpe?g|png|gif|webp|avif)(\?|#|$)/i.test(pathname)) {
      return raw;
    }

    // Reject non-image wiki/HTML pages.
    return null;
  } catch (_) {
    return null;
  }
}

/**
 * Resolves OSM image-related tags to downloadable HTTP(S) URLs.
 * @param {Object} tags
 * @return {string[]}
 */
function extractOsmImageUrls(tags) {
  const urls = [];
  const fromImage = resolveOsmImageReference(tags.image);
  if (fromImage) urls.push(fromImage);

  const fromCommons = resolveOsmImageReference(tags.wikimedia_commons);
  if (fromCommons) urls.push(fromCommons);

  return [...new Set(urls)];
}

/**
 * @param {Object} element Overpass element
 * @return {{latitude: number, longitude: number, altitude: number}|null}
 */
function extractOsmCoordinates(element) {
  if (!element || typeof element !== "object") return null;
  if (
    typeof element.lat === "number" &&
    Number.isFinite(element.lat) &&
    typeof element.lon === "number" &&
    Number.isFinite(element.lon)
  ) {
    return {
      latitude: element.lat,
      longitude: element.lon,
      altitude: 0,
    };
  }
  const center = element.center;
  if (
    center &&
    typeof center.lat === "number" &&
    Number.isFinite(center.lat) &&
    typeof center.lon === "number" &&
    Number.isFinite(center.lon)
  ) {
    return {
      latitude: center.lat,
      longitude: center.lon,
      altitude: 0,
    };
  }
  return null;
}

/**
 * Maps one Overpass element to a sync placemark.
 * @param {Object} element
 * @return {Object|null}
 */
function mapOverpassElementToPlacemark(element) {
  if (!element || typeof element !== "object") return null;
  const type = toNonEmptyString(element.type);
  const id = element.id;
  if (!type || id == null) return null;

  const tags = element.tags && typeof element.tags === "object" ?
    element.tags :
    {};
  const sport = toNonEmptyString(tags.sport);
  if (!sport || !sport.split(";").map((s) => s.trim().toLowerCase()).includes("parkour")) {
    return null;
  }

  const coordinates = extractOsmCoordinates(element);
  if (!coordinates) return null;

  const placemark = {
    name: pickOsmName(tags),
    description: buildOsmDescription(tags),
    coordinates,
    externalId: `${type}/${id}`,
    extendedData: {},
    folderPath: [],
    folderName: null,
  };

  const imageUrls = extractOsmImageUrls(tags);
  if (imageUrls.length > 0) {
    placemark.imageUrls = imageUrls;
  }

  const spotAccess = mapOsmSpotAccess(tags);
  if (spotAccess) {
    placemark.spotAccess = spotAccess;
  }

  const spotFacilities = mapOsmSpotFacilities(tags);
  if (spotFacilities) {
    placemark.spotFacilities = spotFacilities;
  }

  return placemark;
}

/**
 * @param {Object} overpassJson
 * @return {Object[]}
 */
function mapOverpassResponseToPlacemarks(overpassJson) {
  const elements = overpassJson && Array.isArray(overpassJson.elements) ?
    overpassJson.elements :
    [];
  const placemarks = [];
  for (const element of elements) {
    const placemark = mapOverpassElementToPlacemark(element);
    if (placemark) placemarks.push(placemark);
  }
  return placemarks;
}

/**
 * @param {string} url
 * @param {string} body
 * @param {number=} redirectCount
 * @return {Promise<string>}
 */
function postText(url, body, redirectCount = 0) {
  if (redirectCount > 5) {
    return Promise.reject(new Error("Too many redirects while fetching Overpass"));
  }

  const parsedUrl = new URL(url);
  if (parsedUrl.protocol !== "https:" && parsedUrl.protocol !== "http:") {
    return Promise.reject(new Error("Overpass URL must use http or https"));
  }
  const client = parsedUrl.protocol === "http:" ? http : https;

  return new Promise((resolve, reject) => {
    const request = client.request(parsedUrl, {
      method: "POST",
      headers: {
        "User-Agent": USER_AGENT,
        "Content-Type": "application/x-www-form-urlencoded",
        "Accept": "application/json",
        "Content-Length": Buffer.byteLength(body),
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
        resolve(postText(redirectedUrl, body, redirectCount + 1));
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
          reject(new Error(`Overpass request failed (HTTP ${statusCode})`));
          return;
        }
        resolve(responseBody);
      });
    });

    request.on("error", reject);
    request.setTimeout(120000, () => {
      request.destroy(new Error("Overpass request timed out"));
    });
    request.write(body);
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
 * Fetches worldwide sport=parkour features and maps them to placemarks.
 * @param {Object=} options
 * @param {string=} options.overpassUrl
 * @param {Function=} options.postTextFn Injectable POST helper for tests
 * @param {number=} options.maxAttempts
 * @return {Promise<Object[]>}
 */
async function fetchOsmParkourPlacemarks(options = {}) {
  const overpassUrl = options.overpassUrl || OVERPASS_URL;
  const postTextFn = options.postTextFn || postText;
  const maxAttempts = options.maxAttempts || 3;
  const body = `data=${encodeURIComponent(OVERPASS_QUERY)}`;

  let lastError = null;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const text = await postTextFn(overpassUrl, body);
      const json = JSON.parse(text);
      return mapOverpassResponseToPlacemarks(json);
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

  throw new Error(
      `Failed fetching OSM parkour features: ${
        lastError && lastError.message ? lastError.message : "unknown error"
      }`,
  );
}

/**
 * Builds attribute defaults object from an OSM placemark.
 * @param {Object} placemark
 * @return {Object|null}
 */
function placemarkOsmAttributeDefaults(placemark) {
  if (!placemark || typeof placemark !== "object") return null;
  const defaults = {};
  if (typeof placemark.spotAccess === "string") {
    defaults.spotAccess = placemark.spotAccess;
  }
  if (
    placemark.spotFacilities &&
    typeof placemark.spotFacilities === "object" &&
    !Array.isArray(placemark.spotFacilities)
  ) {
    defaults.spotFacilities = {...placemark.spotFacilities};
  }
  return Object.keys(defaults).length > 0 ? defaults : null;
}

module.exports = {
  OVERPASS_URL,
  OVERPASS_QUERY,
  USER_AGENT,
  DEFAULT_SPOT_NAME,
  pickOsmName,
  buildOsmDescription,
  mapOsmSpotAccess,
  mapOsmSpotFacilities,
  extractOsmImageUrls,
  resolveOsmImageReference,
  commonsSpecialFilePath,
  extractOsmCoordinates,
  mapOverpassElementToPlacemark,
  mapOverpassResponseToPlacemarks,
  fetchOsmParkourPlacemarks,
  placemarkOsmAttributeDefaults,
};
