/**
 * API helper functions for ParkourSpot Cloud Functions
 */

const crypto = require("crypto");

/**
 * Hash API key with SHA-256 for storage/lookup.
 * High-entropy random API keys (not user passwords);
 * SHA-256 fingerprint is intentional.
 * @param {string} apiKey - Plain API key
 * @return {string} Hex-encoded SHA-256 hash
 */
function hashApiKey(apiKey) {
  // codeql[js/insufficient-password-hash]: API key digest, not password hash
  return crypto.createHash("sha256").update(apiKey).digest("hex");
}

/**
 * Generate a new API key (ps_ prefix + 32 random hex chars)
 * @return {string}
 */
function generateApiKey() {
  return "ps_" + crypto.randomBytes(16).toString("hex");
}

/**
 * Serialize a Firestore document for JSON API response.
 * Converts Firestore Timestamps to ISO 8601 strings.
 * @param {Object} data - Raw document data
 * @return {Object} JSON-serializable object
 */
function serializeSpotForApi(data) {
  const result = {};
  for (const [key, value] of Object.entries(data)) {
    if (value && typeof value.toDate === "function") {
      result[key] = value.toDate().toISOString();
    } else if (value !== undefined && value !== null) {
      result[key] = value;
    }
  }
  return result;
}

module.exports = {
  hashApiKey,
  generateApiKey,
  serializeSpotForApi,
};
