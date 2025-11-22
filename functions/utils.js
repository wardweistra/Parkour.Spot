/* eslint-disable max-len */
/**
 * Shared utility functions for Firebase Cloud Functions
 */

/**
 * Normalizes special characters to their ASCII equivalents
 * e.g., é -> e, É -> e, ñ -> n, etc.
 * @param {string} input - The input string
 * @return {string} Normalized string
 */
function normalizeToAscii(input) {
  const replacements = {
    "à": "a", "á": "a", "â": "a", "ã": "a", "ä": "a", "å": "a",
    "À": "A", "Á": "A", "Â": "A", "Ã": "A", "Ä": "A", "Å": "A",
    "è": "e", "é": "e", "ê": "e", "ë": "e",
    "È": "E", "É": "E", "Ê": "E", "Ë": "E",
    "ì": "i", "í": "i", "î": "i", "ï": "i",
    "Ì": "I", "Í": "I", "Î": "I", "Ï": "I",
    "ò": "o", "ó": "o", "ô": "o", "õ": "o", "ö": "o",
    "Ò": "O", "Ó": "O", "Ô": "O", "Õ": "O", "Ö": "O",
    "ù": "u", "ú": "u", "û": "u", "ü": "u",
    "Ù": "U", "Ú": "U", "Û": "U", "Ü": "U",
    "ý": "y", "ÿ": "y",
    "Ý": "Y", "Ÿ": "Y",
    "ñ": "n", "Ñ": "N",
    "ç": "c", "Ç": "C",
    "ß": "ss",
  };

  let result = input;
  for (const [char, replacement] of Object.entries(replacements)) {
    // Use regex with global flag for compatibility
    const regex = new RegExp(char.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g");
    result = result.replace(regex, replacement);
  }
  return result;
}

/**
 * Slugifies a string for use in URLs
 * Normalizes special characters, lowercases, and replaces spaces/hyphens
 * @param {string} input - The input string
 * @return {string} Slugified string
 */
function slugify(input) {
  const normalized = normalizeToAscii(input);
  const lowered = normalized.toLowerCase();
  const replaced = lowered
      .replace(/[^a-z0-9\s-_]/g, "")
      .replace(/[\s_]+/g, "-");
  return replaced;
}

/**
 * Escape XML/HTML special characters
 * @param {string} text - Text to escape
 * @return {string} Escaped text
 */
function escapeXml(text) {
  if (!text) return "";
  return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&apos;");
}

/**
 * Format a Firestore Timestamp or Date to ISO 8601 string
 * @param {Date|Object|null|undefined} date - Date to format (Firestore Timestamp has toDate method)
 * @return {string|null} ISO 8601 formatted date string, or null if invalid
 */
function formatDateToISO(date) {
  if (!date) return null;
  // Handle Firestore Timestamp (has toDate method) or regular Date
  const dateObj = date.toDate ? date.toDate() : date;
  if (!(dateObj instanceof Date)) return null;
  return dateObj.toISOString();
}

module.exports = {
  normalizeToAscii,
  slugify,
  escapeXml,
  formatDateToISO,
};

