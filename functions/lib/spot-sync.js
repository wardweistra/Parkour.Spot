/**
 * Helpers for imported parkour spot source sync.
 */

/**
 * Coerces unknown input into a non-empty trimmed string.
 * @param {*} value
 * @return {string|null}
 */
function toNonEmptyString(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * Compares nullable strings while ignoring whitespace and empty-string/null.
 * @param {*} left
 * @param {*} right
 * @return {boolean}
 */
function nullableStringEqual(left, right) {
  return toNonEmptyString(left) === toNonEmptyString(right);
}

/**
 * @param {*} value
 * @return {string[]}
 */
function normalizeStringList(value) {
  if (!Array.isArray(value)) return [];
  const result = [];
  for (const item of value) {
    if (item == null) continue;
    const normalized = String(item).trim();
    if (normalized.length > 0) result.push(normalized);
  }
  return result;
}

/**
 * @param {*} left
 * @param {*} right
 * @return {boolean}
 */
function stringListsEqual(left, right) {
  const normalizedLeft = normalizeStringList(left);
  const normalizedRight = normalizeStringList(right);
  if (normalizedLeft.length !== normalizedRight.length) return false;
  return normalizedLeft.every(
      (value, index) => value === normalizedRight[index],
  );
}

/**
 * @param {Object} data
 * @param {string} key
 * @return {boolean}
 */
function hasOwn(data, key) {
  return Boolean(data) && Object.prototype.hasOwnProperty.call(data, key);
}

/**
 * @param {*} left
 * @param {*} right
 * @return {boolean}
 */
function numbersEqual(left, right) {
  if (typeof left !== "number" || typeof right !== "number") {
    return left == null && right == null;
  }
  if (!Number.isFinite(left) || !Number.isFinite(right)) {
    return false;
  }
  return left === right;
}

/** Decimal places for imported-spot coordinate keys (~0.11 m). */
const IMPORTED_SPOT_COORD_DECIMALS = 6;

/**
 * Rounds a latitude/longitude for stable Firestore matching.
 * @param {number} value
 * @return {number|null}
 */
function roundSyncCoordinate(value) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return null;
  }
  const factor = 10 ** IMPORTED_SPOT_COORD_DECIMALS;
  return Math.round(value * factor) / factor;
}

/**
 * Normalizes imported spot names (trim + Unicode NFC) for matching.
 * @param {*} name
 * @return {string|null}
 */
function normalizeImportedSpotName(name) {
  const trimmed = toNonEmptyString(name);
  if (!trimmed) return null;
  return trimmed.normalize("NFC");
}

/**
 * @param {number} latitude
 * @param {number} longitude
 * @return {string|null}
 */
function buildImportedSpotCoordKey(latitude, longitude) {
  const lat = roundSyncCoordinate(latitude);
  const lng = roundSyncCoordinate(longitude);
  if (lat == null || lng == null) return null;
  return `${lat},${lng}`;
}

/**
 * @param {Object} doc Firestore doc or {data: Function}
 * @return {number}
 */
function importedSpotRecencyScore(doc) {
  const data = typeof doc.data === "function" ? doc.data() : {};
  let score = 0;
  if (data.spotSourceRemoved !== true) score += 1000;
  if (!data.duplicateOf) score += 100;
  const createdMs =
    data.createdAt && typeof data.createdAt.toMillis === "function" ?
      data.createdAt.toMillis() :
      0;
  return score * 1e15 - createdMs;
}

/**
 * Picks one canonical spot when several match (e.g. legacy duplicates).
 * @param {Object[]} candidates
 * @return {Object|null}
 */
function pickCanonicalImportedSpot(candidates) {
  if (!Array.isArray(candidates) || candidates.length === 0) {
    return null;
  }
  if (candidates.length === 1) return candidates[0];
  return [...candidates].sort(
      (a, b) => importedSpotRecencyScore(b) - importedSpotRecencyScore(a),
  )[0];
}

/**
 * Builds in-memory indexes for imported spots from one source.
 * @param {Object[]} spotDocs Firestore QueryDocumentSnapshot[]
 * @return {{byExternalId: Map, byCoordKey: Map, byNormalizedName: Map}}
 */
function buildImportedSpotLookup(spotDocs) {
  const byExternalId = new Map();
  const byCoordKey = new Map();
  const byNormalizedName = new Map();

  for (const doc of spotDocs) {
    const data = typeof doc.data === "function" ? doc.data() : {};
    const externalId = toNonEmptyString(data.spotSourceExternalId);
    if (externalId && !byExternalId.has(externalId)) {
      byExternalId.set(externalId, doc);
    }

    const coordKey = buildImportedSpotCoordKey(data.latitude, data.longitude);
    if (coordKey) {
      if (!byCoordKey.has(coordKey)) {
        byCoordKey.set(coordKey, []);
      }
      byCoordKey.get(coordKey).push(doc);
    }

    const normalizedName = normalizeImportedSpotName(data.name);
    if (normalizedName) {
      if (!byNormalizedName.has(normalizedName)) {
        byNormalizedName.set(normalizedName, []);
      }
      byNormalizedName.get(normalizedName).push(doc);
    }
  }

  return {byExternalId, byCoordKey, byNormalizedName};
}

/**
 * Registers a spot in lookup indexes after create (same sync run).
 * @param {{byExternalId: Map, byCoordKey: Map, byNormalizedName: Map}} lookup
 * @param {Object} doc
 */
function registerImportedSpotInLookup(lookup, doc) {
  if (!lookup || !doc) return;
  const data = typeof doc.data === "function" ? doc.data() : {};
  const externalId = toNonEmptyString(data.spotSourceExternalId);
  if (externalId && !lookup.byExternalId.has(externalId)) {
    lookup.byExternalId.set(externalId, doc);
  }

  const coordKey = buildImportedSpotCoordKey(data.latitude, data.longitude);
  if (coordKey) {
    if (!lookup.byCoordKey.has(coordKey)) {
      lookup.byCoordKey.set(coordKey, []);
    }
    lookup.byCoordKey.get(coordKey).push(doc);
  }

  const normalizedName = normalizeImportedSpotName(data.name);
  if (normalizedName) {
    if (!lookup.byNormalizedName.has(normalizedName)) {
      lookup.byNormalizedName.set(normalizedName, []);
    }
    lookup.byNormalizedName.get(normalizedName).push(doc);
  }
}

/**
 * Resolves an existing imported spot for a placemark.
 * Order: external id (with coord/name fallback), rounded coords,
 * normalized name.
 * @param {{byExternalId: Map, byCoordKey: Map, byNormalizedName: Map}} lookup
 * @param {Object} criteria
 * @param {string} [criteria.externalId]
 * @param {number} criteria.latitude
 * @param {number} criteria.longitude
 * @param {string} [criteria.name]
 * @return {Object|null} Firestore doc snapshot or compatible object
 */
function resolveImportedSpotMatch(lookup, criteria) {
  if (!lookup || !criteria) return null;

  const externalId = toNonEmptyString(criteria.externalId);
  const latitude = roundSyncCoordinate(criteria.latitude);
  const longitude = roundSyncCoordinate(criteria.longitude);
  const normalizedName = normalizeImportedSpotName(criteria.name);
  const coordKey =
    latitude != null && longitude != null ?
      buildImportedSpotCoordKey(latitude, longitude) :
      null;

  if (externalId) {
    const byId = lookup.byExternalId.get(externalId);
    if (byId) return byId;
  }

  if (coordKey) {
    const byCoord = lookup.byCoordKey.get(coordKey);
    if (byCoord && byCoord.length > 0) {
      return pickCanonicalImportedSpot(byCoord);
    }
  }

  if (normalizedName) {
    const byName = lookup.byNormalizedName.get(normalizedName) || [];
    if (byName.length === 1) {
      return pickCanonicalImportedSpot(byName);
    }
    if (byName.length > 1 && coordKey) {
      const sameCoord = byName.filter((doc) => {
        const data = doc.data();
        return buildImportedSpotCoordKey(data.latitude, data.longitude) ===
          coordKey;
      });
      if (sameCoord.length > 0) {
        return pickCanonicalImportedSpot(sameCoord);
      }
    }
    if (byName.length > 1 && latitude != null && longitude != null) {
      const exactCoord = byName.filter((doc) => {
        const data = doc.data();
        return data.latitude === latitude && data.longitude === longitude;
      });
      if (exactCoord.length > 0) {
        return pickCanonicalImportedSpot(exactCoord);
      }
    }
  }

  return null;
}

/**
 * Checks whether a source-sync should update imported spot content fields.
 * Only compares source-owned fields present on the incoming payload (the
 * write that would be applied). Preserved fields such as address, ratings,
 * ranking, duplicate, hidden, and attributes are ignored. Latitude/longitude
 * and spotSourceExternalId are compared when present on the incoming payload
 * (needed for OSM geometry/id-stable updates).
 * @param {Object} existingData
 * @param {Object} incomingData
 * @return {boolean}
 */
function hasImportedSpotContentChanges(existingData, incomingData) {
  const existing = existingData && typeof existingData === "object" ?
    existingData :
    {};
  const incoming = incomingData && typeof incomingData === "object" ?
    incomingData :
    {};

  if (!nullableStringEqual(existing.name, incoming.name)) return true;
  if (!nullableStringEqual(existing.description, incoming.description)) {
    return true;
  }
  if (!nullableStringEqual(existing.spotSourceName, incoming.spotSourceName)) {
    return true;
  }

  if (hasOwn(incoming, "folderName") &&
      !nullableStringEqual(existing.folderName, incoming.folderName)) {
    return true;
  }

  if (hasOwn(incoming, "spotSourceExternalId") &&
      !nullableStringEqual(
          existing.spotSourceExternalId,
          incoming.spotSourceExternalId,
      )) {
    return true;
  }

  if (hasOwn(incoming, "latitude") &&
      !numbersEqual(existing.latitude, incoming.latitude)) {
    return true;
  }
  if (hasOwn(incoming, "longitude") &&
      !numbersEqual(existing.longitude, incoming.longitude)) {
    return true;
  }

  if (existing.spotSourceRemoved === true &&
      incoming.spotSourceRemoved !== true) {
    return true;
  }

  if (hasOwn(incoming, "youtubeVideoIds") &&
      !stringListsEqual(existing.youtubeVideoIds, incoming.youtubeVideoIds)) {
    return true;
  }

  if (hasOwn(incoming, "imageUrls") &&
      !stringListsEqual(existing.imageUrls, incoming.imageUrls)) {
    return true;
  }

  if (hasOwn(incoming, "imageHashes") &&
      !stringListsEqual(existing.imageHashes, incoming.imageHashes)) {
    return true;
  }

  if (hasOwn(incoming, "hasImages") &&
      (existing.hasImages === true) !== (incoming.hasImages === true)) {
    return true;
  }

  return false;
}

const SOURCE_TYPE_FILE = "file";
const SOURCE_TYPE_OPENSTREETMAP = "openstreetmap";
const SOURCE_TYPE_NAVERMAP = "navermap";
const SOURCE_TYPE_GOOGLE_EARTH = "google_earth";

/**
 * @param {*} sourceType
 * @return {"file"|"openstreetmap"|"navermap"|"google_earth"}
 */
function normalizeSpotSyncSourceType(sourceType) {
  if (sourceType === SOURCE_TYPE_OPENSTREETMAP) {
    return SOURCE_TYPE_OPENSTREETMAP;
  }
  if (sourceType === SOURCE_TYPE_NAVERMAP) {
    return SOURCE_TYPE_NAVERMAP;
  }
  if (sourceType === SOURCE_TYPE_GOOGLE_EARTH) {
    return SOURCE_TYPE_GOOGLE_EARTH;
  }
  return SOURCE_TYPE_FILE;
}

/**
 * File and Naver Map sources need a URL; OpenStreetMap queries Overpass;
 * Google Earth uses an uploaded KML/KMZ file in Storage.
 * @param {*} sourceType
 * @return {boolean}
 */
function spotSyncSourceRequiresUrl(sourceType) {
  const normalized = normalizeSpotSyncSourceType(sourceType);
  return normalized === SOURCE_TYPE_FILE ||
    normalized === SOURCE_TYPE_NAVERMAP;
}

module.exports = {
  SOURCE_TYPE_FILE,
  SOURCE_TYPE_OPENSTREETMAP,
  SOURCE_TYPE_NAVERMAP,
  SOURCE_TYPE_GOOGLE_EARTH,
  IMPORTED_SPOT_COORD_DECIMALS,
  buildImportedSpotCoordKey,
  buildImportedSpotLookup,
  hasImportedSpotContentChanges,
  normalizeImportedSpotName,
  normalizeSpotSyncSourceType,
  pickCanonicalImportedSpot,
  registerImportedSpotInLookup,
  resolveImportedSpotMatch,
  roundSyncCoordinate,
  spotSyncSourceRequiresUrl,
};
