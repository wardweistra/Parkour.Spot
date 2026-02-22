/* eslint-disable max-len */
/**
 * Import/format detection helpers for ParkourSpot Cloud Functions
 */

const crypto = require("crypto");

/**
 * Detects import format based on URL and file buffer
 * @param {Buffer} buffer - The downloaded file buffer
 * @param {string} url - The original URL
 * @return {"kmz"|"kml"|"geojson"} The detected format
 */
function detectImportFormat(buffer, url) {
  const lowerUrl = (url || "").toLowerCase();
  // URL-based hints first
  if (lowerUrl.endsWith(".kmz")) return "kmz";
  if (lowerUrl.endsWith(".kml")) return "kml";
  if (lowerUrl.endsWith(".json") || lowerUrl.includes("/geojson")) {
    return "geojson";
  }

  // Content-based detection
  if (buffer && buffer.length >= 4) {
    // PK\x03\x04 -> ZIP (KMZ)
    if (buffer[0] === 0x50 && buffer[1] === 0x4b && buffer[2] === 0x03 && buffer[3] === 0x04) {
      return "kmz";
    }
    const text = buffer.slice(0, 256).toString("utf8").trimStart();
    if (text.startsWith("<")) return "kml"; // assume XML KML
    if (text.startsWith("{") || text.startsWith("[")) return "geojson";
  }

  // Default to GeoJSON since uMap often serves without extension
  return "geojson";
}

/**
 * Generates a content-based hash for an image buffer
 * @param {Buffer} imageBuffer - The image buffer
 * @return {string} The SHA-256 hash of the image content
 */
function generateImageHash(imageBuffer) {
  return crypto.createHash("sha256").update(imageBuffer).digest("hex");
}

module.exports = {
  detectImportFormat,
  generateImageHash,
};
