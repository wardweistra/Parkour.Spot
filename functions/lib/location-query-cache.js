"use strict";

/**
 * Cached resolution of country/city page queries (e.g. "Amsterdam,
 * Netherlands") to map coordinates.
 *
 * Country and city pages used to call Places Autocomplete + Place Details on
 * every page load, so a crawler rendering thousands of city pages caused
 * thousands of billable Place Details calls. These helpers let the backend
 * geocode each query once and serve it from Firestore afterwards.
 */

const crypto = require("crypto");

const LOCATION_QUERY_CACHE_COLLECTION = "locationQueryCache";
const MAX_LOCATION_QUERY_LENGTH = 120;
// Queries Google could not resolve are retried after this long.
const NOT_FOUND_RETRY_MS = 30 * 24 * 60 * 60 * 1000;

/**
 * Normalizes a location query for use as a cache key.
 * @param {string} query - Raw query, e.g. " Amsterdam,  Netherlands ".
 * @return {string|null} Lowercased, whitespace-collapsed query or null.
 */
function normalizeLocationQuery(query) {
  if (typeof query !== "string") return null;
  const normalized = query
      .normalize("NFC")
      .replace(/\s+/g, " ")
      .replace(/\s*,\s*/g, ", ")
      .trim()
      .toLowerCase();
  if (!normalized || normalized.length > MAX_LOCATION_QUERY_LENGTH) {
    return null;
  }
  return normalized;
}

/**
 * Normalizes an optional language code (e.g. "nl", "pt-BR").
 * @param {*} language - Language from the request.
 * @return {string} Language code or "" when absent/invalid.
 */
function normalizeLanguage(language) {
  if (typeof language !== "string") return "";
  const trimmed = language.trim();
  return /^[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})?$/.test(trimmed) ?
    trimmed.toLowerCase() :
    "";
}

/**
 * Builds the Firestore document id for a normalized query and language.
 * @param {string} normalizedQuery - Output of normalizeLocationQuery.
 * @param {string} language - Output of normalizeLanguage.
 * @return {string} Stable hex document id.
 */
function locationQueryCacheId(normalizedQuery, language) {
  return crypto
      .createHash("sha256")
      .update(`${language}|${normalizedQuery}`)
      .digest("hex")
      .slice(0, 40);
}

/**
 * Builds the Geocoding API URL for a location query.
 * @param {string} query - The query to geocode.
 * @param {string} apiKey - Server Maps API key.
 * @param {string} language - Optional language code.
 * @return {string} Request URL.
 */
function buildGeocodeQueryUrl(query, apiKey, language) {
  const params = new URLSearchParams();
  params.append("address", query);
  params.append("key", apiKey);
  if (language) params.append("language", language);
  return `https://maps.googleapis.com/maps/api/geocode/json?${params.toString()}`;
}

/**
 * Converts a Geocoding API response into the same shape the app gets from
 * the placeDetails function (latitude, longitude, viewport, types, ...).
 * @param {Object} response - Parsed Geocoding API JSON.
 * @return {Object} {status, details, error}: status is "ok", "not_found"
 *   (cacheable) or "error" (not cacheable).
 */
function parseGeocodeQueryResponse(response) {
  if (!response || typeof response !== "object") {
    return {status: "error", details: null, error: "Empty response"};
  }
  if (response.status === "ZERO_RESULTS") {
    return {status: "not_found", details: null, error: "ZERO_RESULTS"};
  }
  if (
    response.status !== "OK" ||
    !Array.isArray(response.results) ||
    response.results.length === 0
  ) {
    return {
      status: "error",
      details: null,
      error: response.error_message || response.status || "Geocoding failed",
    };
  }

  const top = response.results[0];
  const geometry = top.geometry || {};
  const loc = geometry.location || {};
  if (typeof loc.lat !== "number" || typeof loc.lng !== "number") {
    return {status: "error", details: null, error: "Result has no location"};
  }

  let city = null;
  let countryCode = null;
  const components = Array.isArray(top.address_components) ?
    top.address_components :
    [];
  const countryComp = components.find(
      (c) => Array.isArray(c.types) && c.types.includes("country"),
  );
  if (countryComp && countryComp.short_name) {
    countryCode = countryComp.short_name;
  }
  for (const t of [
    "locality",
    "postal_town",
    "administrative_area_level_2",
    "administrative_area_level_1",
  ]) {
    const comp = components.find(
        (c) => Array.isArray(c.types) && c.types.includes(t),
    );
    if (comp && comp.long_name) {
      city = comp.long_name;
      break;
    }
  }

  return {
    status: "ok",
    error: null,
    details: {
      latitude: loc.lat,
      longitude: loc.lng,
      formattedAddress: top.formatted_address || null,
      city,
      countryCode,
      viewport: geometry.viewport || null,
      types: Array.isArray(top.types) ? top.types : [],
    },
  };
}

/**
 * Whether a cached entry can be served without calling Google again.
 * @param {Object|undefined} entry - Cached Firestore data.
 * @param {number} nowMs - Current time in ms.
 * @return {boolean} True when the entry is usable.
 */
function isCachedLocationUsable(entry, nowMs) {
  if (!entry || typeof entry !== "object") return false;
  if (entry.status === "ok") {
    return !!entry.details && typeof entry.details.latitude === "number";
  }
  if (entry.status === "not_found") {
    const checkedAt = typeof entry.checkedAtMs === "number" ?
      entry.checkedAtMs :
      0;
    return nowMs - checkedAt < NOT_FOUND_RETRY_MS;
  }
  return false;
}

module.exports = {
  LOCATION_QUERY_CACHE_COLLECTION,
  MAX_LOCATION_QUERY_LENGTH,
  NOT_FOUND_RETRY_MS,
  buildGeocodeQueryUrl,
  isCachedLocationUsable,
  locationQueryCacheId,
  normalizeLanguage,
  normalizeLocationQuery,
  parseGeocodeQueryResponse,
};
