/* eslint-disable max-len */
/**
 * Public community source catalogs for about.parkour.spot.
 * Only safe display fields are written — never sync URLs or credentials.
 */

/**
 * @param {*} value
 * @return {string|null}
 */
function trimOrNull(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * @param {string} handle
 * @return {string|null}
 */
function normalizeInstagramHandle(handle) {
  const trimmed = trimOrNull(handle);
  if (!trimmed) return null;
  return trimmed.replace(/^@/, "");
}

/**
 * @param {FirebaseFirestore.QueryDocumentSnapshot} doc
 * @param {Map<string, number>} countsById
 * @param {"spot"|"event"} kind
 * @return {Object|null}
 */
function toPublicSource(doc, countsById, kind) {
  const data = doc.data() || {};
  if (data.isActive === false) return null;
  const name = trimOrNull(data.name) || doc.id;
  const entry = {
    id: doc.id,
    name,
    publicUrl: trimOrNull(data.publicUrl),
    description: trimOrNull(data.description),
    instagramHandle: normalizeInstagramHandle(data.instagramHandle),
  };
  if (kind === "spot") {
    entry.spotCount = countsById.get(doc.id) || 0;
  } else {
    entry.eventCount = countsById.get(doc.id) || 0;
  }
  return entry;
}

/**
 * @param {Array<Object>} spots
 * @return {Map<string, number>}
 */
function countSpotsBySourceId(spots) {
  const counts = new Map();
  for (const spot of spots) {
    if (spot.hidden === true) continue;
    if (spot.duplicateOf != null && spot.duplicateOf !== "") continue;
    const sourceId =
      typeof spot.spotSource === "string" ? spot.spotSource.trim() : "";
    if (!sourceId) continue;
    counts.set(sourceId, (counts.get(sourceId) || 0) + 1);
  }
  return counts;
}

/**
 * @param {Array<Object>} events
 * @return {Map<string, number>}
 */
function countEventsBySourceId(events) {
  const counts = new Map();
  for (const event of events) {
    const sourceId =
      typeof event.eventSourceId === "string" ?
        event.eventSourceId.trim() :
        "";
    if (!sourceId) continue;
    counts.set(sourceId, (counts.get(sourceId) || 0) + 1);
  }
  return counts;
}

/**
 * @param {Object} a
 * @param {Object} b
 * @return {number}
 */
function byName(a, b) {
  return a.name.localeCompare(b.name, "en", {sensitivity: "base"});
}

/**
 * Build the community-sources snapshot payload.
 * @param {Object} input
 * @param {FirebaseFirestore.QuerySnapshot} input.spotSourcesSnap
 * @param {FirebaseFirestore.QuerySnapshot} input.eventSourcesSnap
 * @param {Array<Object>} input.spots
 * @param {Array<Object>} input.events
 * @param {Date} [input.now]
 * @return {Object}
 */
function buildCommunitySources({
  spotSourcesSnap,
  eventSourcesSnap,
  spots,
  events,
  now = new Date(),
}) {
  const spotCounts = countSpotsBySourceId(spots);
  const eventCounts = countEventsBySourceId(events);

  const spotSources = spotSourcesSnap.docs
      .map((doc) => toPublicSource(doc, spotCounts, "spot"))
      .filter(Boolean)
      .sort(byName);

  const eventSources = eventSourcesSnap.docs
      .map((doc) => toPublicSource(doc, eventCounts, "event"))
      .filter(Boolean)
      .sort(byName);

  return {
    generatedAt: now.toISOString(),
    spotSources,
    eventSources,
  };
}

module.exports = {
  buildCommunitySources,
  countSpotsBySourceId,
  countEventsBySourceId,
  toPublicSource,
};
