const {normalizeDate, isEventPast} = require("./event-map-pins");

/** Max pins fetched for exact distinct eventId count. */
const EXACT_EVENT_COUNT_PIN_CAP = 500;

/**
 * @param {Object} pinData
 * @param {Date=} now
 * @return {boolean}
 */
function isPinShowable(pinData, now = new Date()) {
  if (!pinData || typeof pinData !== "object") return false;
  return !isEventPast(pinData, now);
}

/**
 * @param {string} docId
 * @param {Object} data
 * @return {Object|null}
 */
function normalizePin(docId, data) {
  if (!data || typeof data !== "object") return null;
  const eventId = typeof data.eventId === "string" ? data.eventId.trim() : "";
  const kind = data.kind === "venue" || data.kind === "spot" ? data.kind : null;
  const latitude = typeof data.latitude === "number" ? data.latitude : null;
  const longitude = typeof data.longitude === "number" ? data.longitude : null;
  const title = typeof data.title === "string" ? data.title.trim() : "";
  const startAt = normalizeDate(data.startAt);
  if (!eventId || !kind || latitude == null || longitude == null || !startAt) {
    return null;
  }

  const pin = {
    id: docId,
    eventId,
    kind,
    latitude,
    longitude,
    title: title.length > 0 ? title : "Event",
    startAt: startAt.toISOString(),
  };

  const endAt = normalizeDate(data.endAt);
  if (endAt) pin.endAt = endAt.toISOString();

  if (kind === "spot") {
    const spotId = typeof data.spotId === "string" ? data.spotId.trim() : "";
    if (spotId.length > 0) pin.spotId = spotId;
  }

  return pin;
}

/**
 * @param {Iterable<Object>} pins
 * @return {number}
 */
function countDistinctEventIds(pins) {
  const seen = new Set();
  for (const pin of pins) {
    if (pin && typeof pin.eventId === "string" && pin.eventId.length > 0) {
      seen.add(pin.eventId);
    }
  }
  return seen.size;
}

/**
 * One representative pin per eventId (earliest startAt).
 * @param {Object[]} pins
 * @return {Object[]}
 */
function dedupePinsByEventId(pins) {
  const byEvent = new Map();
  for (const pin of pins) {
    if (!pin || !pin.eventId) continue;
    const existing = byEvent.get(pin.eventId);
    if (!existing) {
      byEvent.set(pin.eventId, pin);
      continue;
    }
    const existingStart = new Date(existing.startAt).getTime();
    const pinStart = new Date(pin.startAt).getTime();
    if (pinStart < existingStart) {
      byEvent.set(pin.eventId, pin);
    }
  }
  const result = Array.from(byEvent.values());
  result.sort((a, b) => {
    return new Date(a.startAt).getTime() - new Date(b.startAt).getTime();
  });
  return result;
}

/**
 * @param {Object} params
 * @return {{normalizedMinLng: number, normalizedMaxLng: number,
 *   spansEntireGlobe: boolean, crossesDateline: boolean}}
 */
function resolveLongitudeBounds(params) {
  const {minLng, maxLng} = params;
  const normalizeLongitude = (lng) => {
    return ((lng + 180) % 360 + 360) % 360 - 180;
  };

  const normalizedMinLng = normalizeLongitude(minLng);
  const normalizedMaxLng = normalizeLongitude(maxLng);
  const isFullWrap = normalizedMinLng === normalizedMaxLng;

  let spansEntireGlobe = false;
  let crossesDateline = false;

  if (isFullWrap) {
    spansEntireGlobe = true;
  } else {
    let lngSpan = null;
    if (normalizedMinLng > normalizedMaxLng) {
      lngSpan = (180 - normalizedMinLng) + (normalizedMaxLng - (-180));
    } else {
      const rawSpan = maxLng - minLng;
      lngSpan = rawSpan >= 360 ? rawSpan : normalizedMaxLng - normalizedMinLng;
    }
    spansEntireGlobe = lngSpan >= 360;
    crossesDateline = !spansEntireGlobe && normalizedMinLng > normalizedMaxLng;
  }

  return {
    normalizedMinLng,
    normalizedMaxLng,
    spansEntireGlobe,
    crossesDateline,
  };
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {number} minLat
 * @param {number} maxLat
 * @param {number} lngMin
 * @param {number} lngMax
 * @return {FirebaseFirestore.Query}
 */
function buildEventPinsGeoQuery(db, minLat, maxLat, lngMin, lngMax) {
  return db.collection("eventMapPins")
      .where("longitude", ">=", lngMin)
      .where("longitude", "<=", lngMax)
      .where("latitude", ">=", minLat)
      .where("latitude", "<=", maxLat);
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} params
 * @return {Promise<{success: boolean, pins: Object[], shownCount: number,
 *   totalCount: number, eventCount: number}>}
 */
async function executeEventsInBoundsQuery(db, params) {
  const {
    minLat,
    maxLat,
    minLng,
    maxLng,
    limit = 100,
  } = params || {};

  if (
    typeof minLat !== "number" ||
    typeof maxLat !== "number" ||
    typeof minLng !== "number" ||
    typeof maxLng !== "number"
  ) {
    throw new Error("minLat, maxLat, minLng, maxLng are required numbers");
  }

  const now = new Date();
  const maxItems = Math.max(0, Math.min(200, Number(limit) || 100));
  const bounds = resolveLongitudeBounds({minLng, maxLng});
  const {
    normalizedMinLng,
    normalizedMaxLng,
    spansEntireGlobe,
    crossesDateline,
  } = bounds;

  const mapDocsToPins = (docs) => {
    const pins = [];
    for (const doc of docs) {
      const data = doc.data();
      if (!isPinShowable(data, now)) continue;
      const normalized = normalizePin(doc.id, data);
      if (normalized) pins.push(normalized);
    }
    return pins;
  };

  let allDocs = [];
  let totalCount = 0;

  if (spansEntireGlobe) {
    const query = buildEventPinsGeoQuery(db, minLat, maxLat, -180, 180);
    const [snap, countSnap] = await Promise.all([
      query.get(),
      query.count().get(),
    ]);
    allDocs = snap.docs;
    totalCount = countSnap.data().count || 0;
  } else if (crossesDateline) {
    const query1 = buildEventPinsGeoQuery(
        db, minLat, maxLat, normalizedMinLng, 180);
    const query2 = buildEventPinsGeoQuery(
        db, minLat, maxLat, -180, normalizedMaxLng);
    const [snap1, snap2, count1, count2] = await Promise.all([
      query1.get(),
      query2.get(),
      query1.count().get(),
      query2.count().get(),
    ]);
    allDocs = [...snap1.docs, ...snap2.docs];
    totalCount = (count1.data().count || 0) + (count2.data().count || 0);
  } else {
    const query = buildEventPinsGeoQuery(
        db, minLat, maxLat, normalizedMinLng, normalizedMaxLng);
    const [snap, countSnap] = await Promise.all([
      query.get(),
      query.count().get(),
    ]);
    allDocs = snap.docs;
    totalCount = countSnap.data().count || 0;
  }

  const filteredPins = mapDocsToPins(allDocs);
  const pins = filteredPins.slice(0, maxItems);
  const shownCount = pins.length;

  let eventCount;
  if (totalCount <= EXACT_EVENT_COUNT_PIN_CAP) {
    eventCount = countDistinctEventIds(filteredPins);
  } else {
    // Lower bound when viewport has too many pins for a full distinct scan.
    eventCount = countDistinctEventIds(pins);
  }

  return {
    success: true,
    pins,
    shownCount,
    totalCount,
    eventCount,
  };
}

module.exports = {
  EXACT_EVENT_COUNT_PIN_CAP,
  isPinShowable,
  normalizePin,
  countDistinctEventIds,
  dedupePinsByEventId,
  resolveLongitudeBounds,
  buildEventPinsGeoQuery,
  executeEventsInBoundsQuery,
};
