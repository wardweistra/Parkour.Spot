/* eslint-disable max-len */
/**
 * Geographic helper functions for ParkourSpot Cloud Functions
 */

const countries = require("i18n-iso-countries");

// Register English locale for country names
countries.registerLocale(require("i18n-iso-countries/langs/en.json"));

// Countries that need "the" article prefix (e.g., "the Netherlands", not "Netherlands")
const COUNTRIES_WITH_ARTICLE = new Set([
  "NL", // Netherlands
  "PH", // Philippines
  "BS", // Bahamas
  "GM", // Gambia
  "MV", // Maldives
  "AE", // United Arab Emirates
  "US", // United States
  "GB", // United Kingdom
]);

/**
 * Get country name with proper article if needed
 * @param {string} countryCode - ISO 3166-1 alpha-2 country code
 * @param {boolean} withArticle - Whether to include "the" article (default: true)
 * @return {string} Country name with "the" prefix if needed
 */
function getCountryNameWithArticle(countryCode, withArticle = true) {
  const countryName = countries.getName(countryCode, "en") || countryCode;
  if (withArticle && COUNTRIES_WITH_ARTICLE.has(countryCode.toUpperCase())) {
    return `the ${countryName}`;
  }
  return countryName;
}

/**
 * Calculate distance between two coordinates using Haversine formula
 * @param {number} lat1 - Latitude of first point
 * @param {number} lon1 - Longitude of first point
 * @param {number} lat2 - Latitude of second point
 * @param {number} lon2 - Longitude of second point
 * @return {number} Distance in meters
 */
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Calculate bounding box for approximate 50m radius
 * @param {number} lat - Latitude
 * @param {number} lon - Longitude
 * @param {number} distanceMeters - Distance in meters (default 50)
 * @return {Object} Bounding box with minLat, maxLat, minLng, maxLng
 */
function calculateBounds(lat, lon, distanceMeters = 50) {
  // 1 degree latitude ≈ 111 km = 111,000 m
  // 50 m ≈ 0.00045 degrees latitude
  const latOffset = distanceMeters / 111000; // ~0.00045 degrees for 50m
  // For longitude, account for latitude (longitude lines get closer near poles)
  const lngOffset = latOffset / Math.abs(Math.cos(lat * Math.PI / 180.0));

  return {
    minLat: lat - latOffset,
    maxLat: lat + latOffset,
    minLng: lon - lngOffset,
    maxLng: lon + lngOffset,
  };
}

module.exports = {
  getCountryNameWithArticle,
  calculateDistance,
  calculateBounds,
};
