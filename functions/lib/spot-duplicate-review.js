/**
 * Detects transferable-field changes on spots marked as duplicates.
 * Stores a baseline at link time and flags field groups for moderator review.
 */

const FIELD_GROUPS = Object.freeze([
  "photos",
  "youtube",
  "name",
  "description",
  "location",
  "attributes",
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
 * @param {*} value
 * @return {number|null}
 */
function normalizeNumber(value) {
  if (value == null || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

/**
 * @param {*} value
 * @return {string[]}
 */
function normalizeStringList(value) {
  if (!Array.isArray(value)) return [];
  const result = [];
  for (const item of value) {
    const normalized = toNonEmptyString(item);
    if (normalized) result.push(normalized);
  }
  return result;
}

/**
 * @param {*} value
 * @return {Object<string, string>}
 */
function normalizeStringMap(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return {};
  const result = {};
  for (const [key, raw] of Object.entries(value)) {
    const normalizedKey = toNonEmptyString(key);
    const normalizedValue = toNonEmptyString(raw);
    if (normalizedKey && normalizedValue) {
      result[normalizedKey] = normalizedValue;
    }
  }
  return result;
}

/**
 * @param {Object|null|undefined} data
 * @return {string|null}
 */
function getDuplicateOf(data) {
  if (!data || typeof data !== "object") return null;
  return toNonEmptyString(data.duplicateOf);
}

/**
 * @param {Object|null|undefined} data
 * @return {boolean}
 */
function hasReviewBaseline(data) {
  if (!data || typeof data !== "object") return false;
  const baseline = data.duplicateReviewBaseline;
  return Boolean(baseline) &&
    typeof baseline === "object" &&
    !Array.isArray(baseline);
}

/**
 * Snapshot of transferable fields used as the last-reviewed baseline.
 * @param {Object|null|undefined} data
 * @return {Object}
 */
function buildDuplicateReviewSnapshot(data) {
  const source = data && typeof data === "object" ? data : {};
  return {
    name: toNonEmptyString(source.name) || "",
    description: toNonEmptyString(source.description),
    imageUrls: normalizeStringList(source.imageUrls),
    youtubeVideoIds: normalizeStringList(source.youtubeVideoIds),
    latitude: normalizeNumber(source.latitude),
    longitude: normalizeNumber(source.longitude),
    address: toNonEmptyString(source.address),
    city: toNonEmptyString(source.city),
    countryCode: toNonEmptyString(source.countryCode),
    spotAccess: toNonEmptyString(source.spotAccess),
    spotFeatures: normalizeStringList(source.spotFeatures),
    spotFacilities: normalizeStringMap(source.spotFacilities),
    goodFor: normalizeStringList(source.goodFor),
  };
}

/**
 * @param {string[]} left
 * @param {string[]} right
 * @return {boolean}
 */
function stringListsEqual(left, right) {
  if (left.length !== right.length) return false;
  return left.every((value, index) => value === right[index]);
}

/**
 * @param {string[]} left
 * @param {string[]} right
 * @return {boolean}
 */
function stringSetsEqual(left, right) {
  if (left.length !== right.length) return false;
  const sortedLeft = [...left].sort();
  const sortedRight = [...right].sort();
  return sortedLeft.every((value, index) => value === sortedRight[index]);
}

/**
 * @param {Object<string, string>} left
 * @param {Object<string, string>} right
 * @return {boolean}
 */
function stringMapsEqual(left, right) {
  const leftKeys = Object.keys(left).sort();
  const rightKeys = Object.keys(right).sort();
  if (!stringListsEqual(leftKeys, rightKeys)) return false;
  return leftKeys.every((key) => left[key] === right[key]);
}

/**
 * @param {number|null} left
 * @param {number|null} right
 * @return {boolean}
 */
function numbersEqual(left, right) {
  if (left == null && right == null) return true;
  if (left == null || right == null) return false;
  return left === right;
}

/**
 * @param {Object} baseline
 * @param {Object} current
 * @return {string[]}
 */
function diffDuplicateFieldGroups(baseline, current) {
  const left = buildDuplicateReviewSnapshot(baseline);
  const right = buildDuplicateReviewSnapshot(current);
  const changed = [];

  if (!stringListsEqual(left.imageUrls, right.imageUrls)) {
    changed.push("photos");
  }
  if (!stringListsEqual(left.youtubeVideoIds, right.youtubeVideoIds)) {
    changed.push("youtube");
  }
  if (left.name !== right.name) changed.push("name");
  if (left.description !== right.description) changed.push("description");
  if (
    !numbersEqual(left.latitude, right.latitude) ||
    !numbersEqual(left.longitude, right.longitude) ||
    left.address !== right.address ||
    left.city !== right.city ||
    left.countryCode !== right.countryCode
  ) {
    changed.push("location");
  }
  if (
    left.spotAccess !== right.spotAccess ||
    !stringSetsEqual(left.spotFeatures, right.spotFeatures) ||
    !stringMapsEqual(left.spotFacilities, right.spotFacilities) ||
    !stringSetsEqual(left.goodFor, right.goodFor)
  ) {
    changed.push("attributes");
  }

  return changed;
}

/**
 * @param {*} value
 * @return {string[]}
 */
function normalizeChangedFields(value) {
  if (!Array.isArray(value)) return [];
  const allowed = new Set(FIELD_GROUPS);
  const seen = new Set();
  const result = [];
  for (const item of value) {
    const key = toNonEmptyString(item);
    if (!key || !allowed.has(key) || seen.has(key)) continue;
    seen.add(key);
    result.push(key);
  }
  return result;
}

/**
 * @param {string[]} left
 * @param {string[]} right
 * @return {boolean}
 */
function changedFieldsEqual(left, right) {
  return stringListsEqual(
      [...normalizeChangedFields(left)].sort(),
      [...normalizeChangedFields(right)].sort(),
  );
}

/**
 * @param {Object|null|undefined} data
 * @return {boolean}
 */
function hasStoredReviewFields(data) {
  if (!data || typeof data !== "object") return false;
  if (hasReviewBaseline(data)) return true;
  if (data.duplicateHasPendingChanges === true) return true;
  if (data.duplicateHasPendingChanges === false) return true;
  return normalizeChangedFields(data.duplicateChangedFields).length > 0;
}

/**
 * @param {Object|null|undefined} data
 * @param {string[]} changedFields
 * @param {boolean} expectBaseline
 * @return {boolean}
 */
function pendingStateMatches(data, changedFields, expectBaseline) {
  const pending = changedFields.length > 0;
  const storedPending = data && data.duplicateHasPendingChanges === true;
  if (storedPending !== pending) return false;
  if (!changedFieldsEqual(data && data.duplicateChangedFields, changedFields)) {
    return false;
  }
  if (expectBaseline && !hasReviewBaseline(data)) return false;
  return true;
}

/**
 * Builds a Firestore update for duplicate review state, or null when no write
 * is needed (keeps onSpotUpdated idempotent).
 * @param {Object|null|undefined} beforeData
 * @param {Object|null|undefined} afterData
 * @param {*} fieldValueDelete FieldValue.delete() sentinel
 * @return {Object|null}
 */
function buildDuplicateReviewUpdate(beforeData, afterData, fieldValueDelete) {
  const afterDup = getDuplicateOf(afterData);
  if (!afterDup) {
    if (!hasStoredReviewFields(afterData)) return null;
    return {
      duplicateReviewBaseline: fieldValueDelete,
      duplicateChangedFields: fieldValueDelete,
      duplicateHasPendingChanges: fieldValueDelete,
    };
  }

  const beforeDup = getDuplicateOf(beforeData);
  const newlyLinked = !beforeDup && Boolean(afterDup);
  const afterSnap = buildDuplicateReviewSnapshot(afterData);

  if (newlyLinked) {
    if (
      pendingStateMatches(afterData, [], true) &&
      diffDuplicateFieldGroups(
          afterData.duplicateReviewBaseline,
          afterSnap,
      ).length === 0
    ) {
      return null;
    }
    return {
      duplicateReviewBaseline: afterSnap,
      duplicateChangedFields: fieldValueDelete,
      duplicateHasPendingChanges: false,
    };
  }

  if (!hasReviewBaseline(afterData)) {
    const beforeSnap = beforeData ?
      buildDuplicateReviewSnapshot(beforeData) :
      afterSnap;
    const changed = beforeData ?
      diffDuplicateFieldGroups(beforeSnap, afterSnap) :
      [];
    if (changed.length > 0) {
      if (pendingStateMatches(afterData, changed, true)) return null;
      return {
        duplicateReviewBaseline: beforeSnap,
        duplicateChangedFields: changed,
        duplicateHasPendingChanges: true,
      };
    }
    if (pendingStateMatches(afterData, [], true)) return null;
    return {
      duplicateReviewBaseline: afterSnap,
      duplicateChangedFields: fieldValueDelete,
      duplicateHasPendingChanges: false,
    };
  }

  const changed = diffDuplicateFieldGroups(
      afterData.duplicateReviewBaseline,
      afterSnap,
  );
  if (pendingStateMatches(afterData, changed, true)) return null;
  if (changed.length > 0) {
    return {
      duplicateChangedFields: changed,
      duplicateHasPendingChanges: true,
    };
  }
  return {
    duplicateChangedFields: fieldValueDelete,
    duplicateHasPendingChanges: false,
  };
}

module.exports = {
  FIELD_GROUPS,
  buildDuplicateReviewSnapshot,
  buildDuplicateReviewUpdate,
  diffDuplicateFieldGroups,
  getDuplicateOf,
};
