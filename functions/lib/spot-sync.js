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
 * Checks whether a source-sync should update imported spot content fields.
 * Only compares source-owned fields present on the incoming payload (the
 * write that would be applied). Preserved fields such as coordinates,
 * address, ratings, ranking, duplicate, hidden, and attributes are ignored.
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

module.exports = {
  hasImportedSpotContentChanges,
};
