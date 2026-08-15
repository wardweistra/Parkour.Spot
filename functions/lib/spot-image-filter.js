/**
 * Applies the optional "has images" constraint to a Firestore query.
 *
 * @param {FirebaseFirestore.Query} query
 * @param {boolean} hasImages
 * @return {FirebaseFirestore.Query}
 */
function applyHasImagesFilter(query, hasImages) {
  if (hasImages !== true) return query;
  return query.where("hasImages", "==", true);
}

/**
 * Derives the materialized hasImages value from a spot's image URLs.
 *
 * @param {*} imageUrls
 * @param {*} legacyImageUrl
 * @return {boolean}
 */
function deriveHasImages(imageUrls, legacyImageUrl = null) {
  return (Array.isArray(imageUrls) && imageUrls.length > 0) ||
    (typeof legacyImageUrl === "string" && legacyImageUrl.trim().length > 0);
}

/**
 * Returns the backfill update only when the stored value is missing or stale.
 *
 * @param {Object} spotData
 * @return {{hasImages: boolean}|null}
 */
function buildHasImagesBackfillUpdate(spotData) {
  const expected = deriveHasImages(
      spotData && spotData.imageUrls,
      spotData && spotData.imageUrl,
  );
  if (spotData && spotData.hasImages === expected) return null;
  return {hasImages: expected};
}

module.exports = {
  applyHasImagesFilter,
  deriveHasImages,
  buildHasImagesBackfillUpdate,
};
