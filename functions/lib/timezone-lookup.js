/* eslint-disable max-len */
/**
 * Timezone lookup helpers for ParkourSpot Cloud Functions.
 */

const https = require("https");
const {normalizeImportedTimeZone} = require("./event-sync");

/**
 * @param {*} response
 * @return {string|null}
 */
function parseGoogleTimeZoneResponse(response) {
  if (!response || response.status !== "OK") {
    return null;
  }
  return normalizeImportedTimeZone(response.timeZoneId);
}

/**
 * @param {number} latitude
 * @param {number} longitude
 * @param {number} timestampSeconds
 * @param {string} apiKey
 * @return {string}
 */
function buildGoogleTimeZoneApiUrl(
    latitude,
    longitude,
    timestampSeconds,
    apiKey,
) {
  const location = `${latitude},${longitude}`;
  const params = new URLSearchParams({
    location,
    timestamp: String(timestampSeconds),
    key: apiKey,
  });
  return `https://maps.googleapis.com/maps/api/timezone/json?${params.toString()}`;
}

/**
 * @param {string} url
 * @return {Promise<Object>}
 */
function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https
        .get(url, (res) => {
          let data = "";
          res.on("data", (chunk) => (data += chunk));
          res.on("end", () => {
            try {
              resolve(JSON.parse(data));
            } catch (error) {
              reject(error);
            }
          });
        })
        .on("error", reject);
  });
}

/**
 * @param {number} latitude
 * @param {number} longitude
 * @param {string} apiKey
 * @param {function(string): Promise<Object>=} fetchJsonImpl
 * @return {Promise<string|null>}
 */
async function lookupTimeZoneFromCoordinates(
    latitude,
    longitude,
    apiKey,
    fetchJsonImpl = fetchJson,
) {
  if (!apiKey || typeof apiKey !== "string" || apiKey.trim().length === 0) {
    throw new Error("Google Maps API key not configured");
  }
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    throw new Error("latitude and longitude must be finite numbers");
  }

  const timestampSeconds = Math.floor(Date.now() / 1000);
  const url = buildGoogleTimeZoneApiUrl(
      latitude,
      longitude,
      timestampSeconds,
      apiKey,
  );
  const response = await fetchJsonImpl(url);
  return parseGoogleTimeZoneResponse(response);
}

module.exports = {
  buildGoogleTimeZoneApiUrl,
  fetchJson,
  lookupTimeZoneFromCoordinates,
  parseGoogleTimeZoneResponse,
};
