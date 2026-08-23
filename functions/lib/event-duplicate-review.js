/**
 * Detects transferable-field changes on events marked as duplicates.
 * Stores a baseline at link time and flags field groups for moderator review.
 */

const FIELD_GROUPS = Object.freeze([
  "photos",
  "linkedSpots",
  "title",
  "description",
  "location",
  "schedule",
  "website",
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
 * @return {Date|null}
 */
function normalizeDate(value) {
  if (!value) return null;
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
  if (typeof value.toDate === "function") {
    const asDate = value.toDate();
    if (asDate instanceof Date && !Number.isNaN(asDate.getTime())) {
      return asDate;
    }
  }
  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return null;
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
    title: toNonEmptyString(source.title) || "",
    description: toNonEmptyString(source.description),
    websiteUrl: toNonEmptyString(source.websiteUrl),
    imageUrls: normalizeStringList(source.imageUrls),
    spotIds: normalizeStringList(source.spotIds),
    spotListIds: normalizeStringList(source.spotListIds),
    latitude: normalizeNumber(source.latitude),
    longitude: normalizeNumber(source.longitude),
    address: toNonEmptyString(source.address),
    city: toNonEmptyString(source.city),
    countryCode: toNonEmptyString(source.countryCode),
    startAt: normalizeDate(source.startAt),
    endAt: normalizeDate(source.endAt),
    isDateOnly: source.isDateOnly === true,
    timeZone: toNonEmptyString(source.timeZone),
    timeZoneSource: toNonEmptyString(source.timeZoneSource),
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
 * @param {Date|null} left
 * @param {Date|null} right
 * @return {boolean}
 */
function datesEqual(left, right) {
  if (left == null && right == null) return true;
  if (left == null || right == null) return false;
  return left.getTime() === right.getTime();
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
  if (
    !stringSetsEqual(left.spotIds, right.spotIds) ||
    !stringSetsEqual(left.spotListIds, right.spotListIds)
  ) {
    changed.push("linkedSpots");
  }
  if (left.title !== right.title) changed.push("title");
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
    !datesEqual(left.startAt, right.startAt) ||
    !datesEqual(left.endAt, right.endAt) ||
    left.isDateOnly !== right.isDateOnly ||
    left.timeZone !== right.timeZone ||
    left.timeZoneSource !== right.timeZoneSource
  ) {
    changed.push("schedule");
  }
  if (left.websiteUrl !== right.websiteUrl) changed.push("website");

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
 * is needed (keeps onEventWritten idempotent).
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
