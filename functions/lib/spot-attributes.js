/* eslint-disable max-len */
/**
 * Spot attribute normalization and default-merge helpers for ParkourSpot Cloud Functions
 */

// Spot attribute defaults supported for sync source defaults/backfills.
const VALID_SPOT_ACCESS_VALUES = new Set(["public", "restricted", "paid"]);
const VALID_SPOT_FEATURE_VALUES = new Set([
  "walls_low",
  "walls_medium",
  "walls_high",
  "bars_low",
  "bars_medium",
  "bars_high",
  "climbing_tree",
  "rocks",
  "soft_landing_pit",
  "roof_gap",
  "bouncy_equipment",
]);
const VALID_GOOD_FOR_VALUES = new Set([
  "vaults",
  "balance",
  "ascend",
  "descend",
  "speed_run",
  "water_challenges",
  "pole_slide",
  "precisions",
  "wall_runs",
  "strides",
  "rolls",
  "cats",
  "flow",
  "flips",
  "swings",
]);
const VALID_SPOT_FACILITY_KEYS = new Set([
  "covered",
  "lighting",
  "water_tap",
  "toilet",
  "parking",
]);
const VALID_SPOT_FACILITY_VALUES = new Set(["yes", "no"]);

// Stop words to exclude from spot name search index
const SPOT_NAME_STOP_WORDS = new Set([
  "the", "a", "an", "of", "in", "on", "at", "to", "for", "and", "or", "but",
  "is", "it", "as", "with", "by", "from", "de", "la", "le", "und", "der", "die",
  "et", "en", "van", "het", "een",
]);

const MIN_WORD_PREFIX_LENGTH = 3;

/**
 * Removes undefined values from an object to make it Firestore-safe
 * @param {Object} obj - The object to clean
 * @return {Object} The cleaned object
 */
function cleanUndefinedValues(obj) {
  const cleaned = {};
  for (const [key, value] of Object.entries(obj)) {
    if (value !== undefined) {
      cleaned[key] = value;
    }
  }
  return cleaned;
}

/**
 * Builds unique search words from spot name: split, lowercase, remove punctuation
 * and stop words. Full words only (no prefixes) - used for spotSearchTerms collection.
 * @param {string} name - Spot name
 * @return {string[]}
 */
function buildSpotSearchWords(name) {
  if (!name || typeof name !== "string") return [];
  const normalized = name
      .replace(/[\s\p{P}\p{S}]/gu, " ")
      .split(/\s+/)
      .map((w) => w.toLowerCase().replace(/[^\p{L}\p{N}]/gu, ""))
      .filter((w) => w && w.length >= MIN_WORD_PREFIX_LENGTH && !SPOT_NAME_STOP_WORDS.has(w));
  return [...new Set(normalized)];
}

/**
 * Normalizes a list of strings.
 * @param {Array<*>} values
 * @param {Set<string>=} allowedValues
 * @return {Array<string>}
 */
function normalizeStringArray(values, allowedValues = undefined) {
  if (!Array.isArray(values)) return [];
  const result = [];
  const seen = new Set();
  for (const value of values) {
    if (typeof value !== "string") continue;
    const cleaned = value.trim().toLowerCase();
    if (!cleaned) continue;
    if (allowedValues && !allowedValues.has(cleaned)) continue;
    if (seen.has(cleaned)) continue;
    seen.add(cleaned);
    result.push(cleaned);
  }
  return result;
}

/**
 * Keeps existing string arrays stable without dropping unknown values.
 * @param {Array<*>} values
 * @return {Array<string>}
 */
function normalizeExistingStringArray(values) {
  if (!Array.isArray(values)) return [];
  const result = [];
  const seen = new Set();
  for (const value of values) {
    if (typeof value !== "string") continue;
    const cleaned = value.trim();
    if (!cleaned) continue;
    if (seen.has(cleaned)) continue;
    seen.add(cleaned);
    result.push(cleaned);
  }
  return result;
}

/**
 * Normalizes one default-attributes object.
 * @param {*} rawDefaults
 * @return {Object|null}
 */
function normalizeSpotAttributeDefaults(rawDefaults) {
  if (!rawDefaults || typeof rawDefaults !== "object" || Array.isArray(rawDefaults)) {
    return null;
  }

  const normalized = {};

  if (typeof rawDefaults.spotAccess === "string") {
    const access = rawDefaults.spotAccess.trim().toLowerCase();
    if (VALID_SPOT_ACCESS_VALUES.has(access)) {
      normalized.spotAccess = access;
    }
  }

  const normalizedSpotFeatures = normalizeStringArray(
      rawDefaults.spotFeatures,
      VALID_SPOT_FEATURE_VALUES,
  );
  if (normalizedSpotFeatures.length > 0) {
    normalized.spotFeatures = normalizedSpotFeatures;
  }

  const normalizedGoodFor = normalizeStringArray(
      rawDefaults.goodFor,
      VALID_GOOD_FOR_VALUES,
  );
  if (normalizedGoodFor.length > 0) {
    normalized.goodFor = normalizedGoodFor;
  }

  if (
    rawDefaults.spotFacilities &&
    typeof rawDefaults.spotFacilities === "object" &&
    !Array.isArray(rawDefaults.spotFacilities)
  ) {
    const facilities = {};
    for (const [key, value] of Object.entries(rawDefaults.spotFacilities)) {
      const facilityKey = String(key).trim().toLowerCase();
      const facilityValue = typeof value === "string" ?
        value.trim().toLowerCase() :
        "";
      if (!VALID_SPOT_FACILITY_KEYS.has(facilityKey)) continue;
      if (!VALID_SPOT_FACILITY_VALUES.has(facilityValue)) continue;
      facilities[facilityKey] = facilityValue;
    }
    if (Object.keys(facilities).length > 0) {
      normalized.spotFacilities = facilities;
    }
  }

  return Object.keys(normalized).length > 0 ? normalized : null;
}

/**
 * Normalizes folder-specific default attributes map.
 * @param {*} rawFolderDefaults
 * @return {Object<string, Object>}
 */
function normalizeFolderSpotAttributeDefaults(rawFolderDefaults) {
  if (
    !rawFolderDefaults ||
    typeof rawFolderDefaults !== "object" ||
    Array.isArray(rawFolderDefaults)
  ) {
    return {};
  }

  const normalized = {};
  for (const [rawFolderName, rawDefaults] of Object.entries(rawFolderDefaults)) {
    if (typeof rawFolderName !== "string") continue;
    const folderName = rawFolderName.trim();
    if (!folderName) continue;
    const defaults = normalizeSpotAttributeDefaults(rawDefaults);
    if (defaults) {
      normalized[folderName] = defaults;
    }
  }
  return normalized;
}

/**
 * Builds case-insensitive lookup for folder defaults.
 * @param {Object<string, Object>} folderDefaults
 * @return {Object<string, Object>}
 */
function buildFolderDefaultsLookup(folderDefaults) {
  const lookup = {};
  for (const [folderName, defaults] of Object.entries(folderDefaults || {})) {
    const key = folderName.trim().toLowerCase();
    if (!key) continue;
    lookup[key] = defaults;
  }
  return lookup;
}

/**
 * Merges two default-attribute objects into one effective set.
 * Arrays are unioned, facilities/access in overrideDefaults win.
 * @param {Object|null} baseDefaults
 * @param {Object|null} overrideDefaults
 * @return {Object|null}
 */
function mergeSpotAttributeDefaults(baseDefaults, overrideDefaults) {
  const hasBase = baseDefaults && typeof baseDefaults === "object";
  const hasOverride = overrideDefaults && typeof overrideDefaults === "object";
  if (!hasBase && !hasOverride) return null;

  const merged = {};

  const baseSpotFeatures = hasBase ?
    normalizeStringArray(baseDefaults.spotFeatures, VALID_SPOT_FEATURE_VALUES) :
    [];
  const overrideSpotFeatures = hasOverride ?
    normalizeStringArray(overrideDefaults.spotFeatures, VALID_SPOT_FEATURE_VALUES) :
    [];
  const mergedSpotFeatures = mergeUniqueStringArrays(
      baseSpotFeatures,
      overrideSpotFeatures,
  );
  if (mergedSpotFeatures.length > 0) {
    merged.spotFeatures = mergedSpotFeatures;
  }

  const baseGoodFor = hasBase ?
    normalizeStringArray(baseDefaults.goodFor, VALID_GOOD_FOR_VALUES) :
    [];
  const overrideGoodFor = hasOverride ?
    normalizeStringArray(overrideDefaults.goodFor, VALID_GOOD_FOR_VALUES) :
    [];
  const mergedGoodFor = mergeUniqueStringArrays(baseGoodFor, overrideGoodFor);
  if (mergedGoodFor.length > 0) {
    merged.goodFor = mergedGoodFor;
  }

  const baseFacilities = (
    hasBase &&
    baseDefaults.spotFacilities &&
    typeof baseDefaults.spotFacilities === "object" &&
    !Array.isArray(baseDefaults.spotFacilities)
  ) ? baseDefaults.spotFacilities : {};
  const overrideFacilities = (
    hasOverride &&
    overrideDefaults.spotFacilities &&
    typeof overrideDefaults.spotFacilities === "object" &&
    !Array.isArray(overrideDefaults.spotFacilities)
  ) ? overrideDefaults.spotFacilities : {};
  const mergedFacilities = {};
  for (const [key, value] of Object.entries(baseFacilities)) {
    const facilityKey = String(key).trim().toLowerCase();
    const facilityValue = typeof value === "string" ?
      value.trim().toLowerCase() :
      "";
    if (!VALID_SPOT_FACILITY_KEYS.has(facilityKey)) continue;
    if (!VALID_SPOT_FACILITY_VALUES.has(facilityValue)) continue;
    mergedFacilities[facilityKey] = facilityValue;
  }
  for (const [key, value] of Object.entries(overrideFacilities)) {
    const facilityKey = String(key).trim().toLowerCase();
    const facilityValue = typeof value === "string" ?
      value.trim().toLowerCase() :
      "";
    if (!VALID_SPOT_FACILITY_KEYS.has(facilityKey)) continue;
    if (!VALID_SPOT_FACILITY_VALUES.has(facilityValue)) continue;
    mergedFacilities[facilityKey] = facilityValue;
  }
  if (Object.keys(mergedFacilities).length > 0) {
    merged.spotFacilities = mergedFacilities;
  }

  const baseAccess = hasBase && typeof baseDefaults.spotAccess === "string" ?
    baseDefaults.spotAccess.trim().toLowerCase() :
    null;
  if (baseAccess && VALID_SPOT_ACCESS_VALUES.has(baseAccess)) {
    merged.spotAccess = baseAccess;
  }
  const overrideAccess = hasOverride && typeof overrideDefaults.spotAccess === "string" ?
    overrideDefaults.spotAccess.trim().toLowerCase() :
    null;
  if (overrideAccess && VALID_SPOT_ACCESS_VALUES.has(overrideAccess)) {
    merged.spotAccess = overrideAccess;
  }

  return Object.keys(merged).length > 0 ? merged : null;
}

/**
 * Returns effective defaults for a spot based on source + folder scope.
 * @param {Object|null} sourceDefaults
 * @param {Object<string, Object>} folderDefaultsLookup
 * @param {string|null|undefined} folderName
 * @return {Object|null}
 */
function getEffectiveSpotAttributeDefaults(
    sourceDefaults,
    folderDefaultsLookup,
    folderName,
) {
  const folderKey = typeof folderName === "string" ?
    folderName.trim().toLowerCase() :
    "";
  const folderDefaults = folderKey ? folderDefaultsLookup[folderKey] || null : null;
  return mergeSpotAttributeDefaults(sourceDefaults, folderDefaults);
}

/**
 * Merges unique string arrays preserving original order.
 * @param {Array<string>} existingValues
 * @param {Array<string>} valuesToAdd
 * @return {Array<string>}
 */
function mergeUniqueStringArrays(existingValues, valuesToAdd) {
  const merged = normalizeExistingStringArray(existingValues);
  for (const value of normalizeExistingStringArray(valuesToAdd)) {
    if (!merged.includes(value)) {
      merged.push(value);
    }
  }
  return merged;
}

/**
 * Compares two string arrays for exact equality.
 * @param {Array<string>} a
 * @param {Array<string>} b
 * @return {boolean}
 */
function areStringArraysEqual(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b)) return false;
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

/**
 * Applies defaults into spotData. Returns true if any field changed.
 * @param {Object} spotData
 * @param {Object|null} defaults
 * @return {boolean}
 */
function applySpotAttributeDefaultsToSpotData(spotData, defaults) {
  if (!spotData || !defaults) return false;
  let changed = false;

  if (
    typeof defaults.spotAccess === "string" &&
    VALID_SPOT_ACCESS_VALUES.has(defaults.spotAccess)
  ) {
    if (spotData.spotAccess !== defaults.spotAccess) {
      spotData.spotAccess = defaults.spotAccess;
      changed = true;
    }
  }

  if (Array.isArray(defaults.spotFeatures) && defaults.spotFeatures.length > 0) {
    const existingSpotFeatures = normalizeExistingStringArray(spotData.spotFeatures);
    const mergedSpotFeatures = mergeUniqueStringArrays(
        existingSpotFeatures,
        defaults.spotFeatures,
    );
    if (!areStringArraysEqual(existingSpotFeatures, mergedSpotFeatures)) {
      spotData.spotFeatures = mergedSpotFeatures;
      changed = true;
    }
  }

  if (Array.isArray(defaults.goodFor) && defaults.goodFor.length > 0) {
    const existingGoodFor = normalizeExistingStringArray(spotData.goodFor);
    const mergedGoodFor = mergeUniqueStringArrays(
        existingGoodFor,
        defaults.goodFor,
    );
    if (!areStringArraysEqual(existingGoodFor, mergedGoodFor)) {
      spotData.goodFor = mergedGoodFor;
      changed = true;
    }
  }

  if (
    defaults.spotFacilities &&
    typeof defaults.spotFacilities === "object" &&
    !Array.isArray(defaults.spotFacilities)
  ) {
    const existingFacilities = (
      spotData.spotFacilities &&
      typeof spotData.spotFacilities === "object" &&
      !Array.isArray(spotData.spotFacilities)
    ) ? {...spotData.spotFacilities} : {};
    const mergedFacilities = {...existingFacilities};
    let facilitiesChanged = false;
    for (const [key, value] of Object.entries(defaults.spotFacilities)) {
      if (mergedFacilities[key] !== value) {
        mergedFacilities[key] = value;
        facilitiesChanged = true;
      }
    }
    if (facilitiesChanged) {
      spotData.spotFacilities = mergedFacilities;
      changed = true;
    }
  }

  return changed;
}

/**
 * Builds a Firestore update payload for spot attributes.
 * @param {Object} spotData
 * @param {*} updatedAt - Firestore serverTimestamp or similar (caller provides)
 * @return {Object}
 */
function buildSpotAttributeUpdateData(spotData, updatedAt) {
  return cleanUndefinedValues({
    updatedAt,
    spotAccess: spotData.spotAccess,
    spotFeatures: spotData.spotFeatures,
    goodFor: spotData.goodFor,
    spotFacilities: spotData.spotFacilities,
  });
}

module.exports = {
  cleanUndefinedValues,
  buildSpotSearchWords,
  normalizeStringArray,
  normalizeExistingStringArray,
  normalizeSpotAttributeDefaults,
  normalizeFolderSpotAttributeDefaults,
  buildFolderDefaultsLookup,
  mergeSpotAttributeDefaults,
  getEffectiveSpotAttributeDefaults,
  mergeUniqueStringArrays,
  areStringArraysEqual,
  applySpotAttributeDefaultsToSpotData,
  buildSpotAttributeUpdateData,
};
