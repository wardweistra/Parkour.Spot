const MAX_SPOT_PINS_PER_EVENT = 100;

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
 * @param {number|null|undefined} latitude
 * @param {number|null|undefined} longitude
 * @return {boolean}
 */
function hasValidCoordinates(latitude, longitude) {
  if (typeof latitude !== "number" || typeof longitude !== "number") {
    return false;
  }
  if (Number.isNaN(latitude) || Number.isNaN(longitude)) return false;
  if (latitude < -90 || latitude > 90) return false;
  if (longitude < -180 || longitude > 180) return false;
  return true;
}

/**
 * @param {Object} eventData
 * @param {Date=} now
 * @return {boolean}
 */
function isEventPast(eventData, now = new Date()) {
  const startAt = normalizeDate(eventData.startAt);
  const endAt = normalizeDate(eventData.endAt);
  if (endAt) return endAt.getTime() < now.getTime();
  if (startAt) return startAt.getTime() < now.getTime();
  return true;
}

/**
 * @param {string|null|undefined} visibility
 * @return {boolean}
 */
function isExpandableListVisibility(visibility) {
  if (typeof visibility !== "string") {
    // Legacy lists without visibility default to unlisted.
    return true;
  }
  const normalized = visibility.trim().toLowerCase();
  return normalized === "public" || normalized === "unlisted";
}

/**
 * Mirrors SpotList.effectiveSpotIds in Dart.
 * @param {Object} listData
 * @return {string[]}
 */
function effectiveSpotIdsFromList(listData) {
  const sections = listData.sections;
  if (Array.isArray(sections) && sections.length > 0) {
    const seen = new Set();
    const result = [];
    for (const section of sections) {
      const entries = section && Array.isArray(section.entries) ?
        section.entries :
        [];
      for (const entry of entries) {
        const spotId = entry && typeof entry.spotId === "string" ?
          entry.spotId.trim() :
          "";
        if (spotId.length > 0 && !seen.has(spotId)) {
          seen.add(spotId);
          result.push(spotId);
        }
      }
    }
    return result;
  }
  const spotIds = listData.spotIds;
  if (!Array.isArray(spotIds)) return [];
  return spotIds
      .filter((id) => typeof id === "string" && id.trim().length > 0)
      .map((id) => id.trim());
}

/**
 * @param {Object} spotData
 * @return {boolean}
 */
function isSpotEligibleForPin(spotData) {
  if (!spotData || typeof spotData !== "object") return false;
  if (spotData.hidden === true) return false;
  const duplicateOf = spotData.duplicateOf;
  if (typeof duplicateOf === "string" && duplicateOf.trim().length > 0) {
    return false;
  }
  return hasValidCoordinates(spotData.latitude, spotData.longitude);
}

/**
 * Collects unique spot ids from event and expandable linked lists.
 * @param {Object} eventData
 * @param {Map<string, Object>} listsById
 * @return {string[]}
 */
function collectLinkedSpotIds(eventData, listsById) {
  const seen = new Set();
  const result = [];

  const addId = (spotId) => {
    if (typeof spotId !== "string") return;
    const trimmed = spotId.trim();
    if (trimmed.length === 0 || seen.has(trimmed)) return;
    seen.add(trimmed);
    result.push(trimmed);
  };

  const directSpotIds = Array.isArray(eventData.spotIds) ?
    eventData.spotIds :
    [];
  for (const spotId of directSpotIds) addId(spotId);

  const spotListIds = Array.isArray(eventData.spotListIds) ?
    eventData.spotListIds :
    [];
  for (const listId of spotListIds) {
    if (typeof listId !== "string" || listId.trim().length === 0) continue;
    const listData = listsById.get(listId.trim());
    if (!listData) continue;
    if (!isExpandableListVisibility(listData.visibility)) continue;
    for (const spotId of effectiveSpotIdsFromList(listData)) {
      addId(spotId);
    }
  }

  return result;
}

/**
 * Denormalized card fields for Explore event pins.
 * @param {Object} eventData
 * @return {Object}
 */
function pickEventCardFields(eventData) {
  const fields = {};
  const description = typeof eventData.description === "string" ?
    eventData.description.trim() :
    "";
  if (description.length > 0) {
    fields.description = description.length > 500 ?
      description.slice(0, 500) :
      description;
  }

  const imageUrls = Array.isArray(eventData.imageUrls) ?
    eventData.imageUrls
        .filter((url) => typeof url === "string" && url.trim().length > 0)
        .map((url) => url.trim())
        .slice(0, 10) :
    [];
  if (imageUrls.length > 0) {
    fields.imageUrls = imageUrls;
  }

  return fields;
}

/**
 * Builds pin document payloads for an event (pure; for tests).
 * @param {string} eventId
 * @param {Object} eventData
 * @param {Map<string, Object>} spotsById
 * @param {Map<string, Object>} listsById
 * @param {Object=} options
 * @param {Date=} options.now
 * @return {{pins: Array<{id: string, data: Object}>, truncated: boolean}}
 */
function buildEventMapPinWrites(
    eventId,
    eventData,
    spotsById,
    listsById,
    options = {},
) {
  const now = options.now || new Date();
  const pins = [];

  const duplicateOf = eventData.duplicateOf;
  if (typeof duplicateOf === "string" && duplicateOf.trim().length > 0) {
    return {pins, truncated: false};
  }
  if (isEventPast(eventData, now)) {
    return {pins, truncated: false};
  }

  const title = typeof eventData.title === "string" ?
    eventData.title.trim() :
    "";
  const startAt = normalizeDate(eventData.startAt);
  const endAt = normalizeDate(eventData.endAt);
  if (!startAt) return {pins, truncated: false};

  const basePin = {
    eventId,
    startAt,
    title: title.length > 0 ? title : "Event",
    ...pickEventCardFields(eventData),
  };
  if (endAt) basePin.endAt = endAt;

  if (hasValidCoordinates(eventData.latitude, eventData.longitude)) {
    pins.push({
      id: `${eventId}_venue`,
      data: {
        ...basePin,
        kind: "venue",
        latitude: eventData.latitude,
        longitude: eventData.longitude,
      },
    });
  }

  const linkedSpotIds = collectLinkedSpotIds(eventData, listsById);
  let spotPinCount = 0;
  let truncated = false;

  for (const spotId of linkedSpotIds) {
    if (spotPinCount >= MAX_SPOT_PINS_PER_EVENT) {
      truncated = true;
      break;
    }
    const spotData = spotsById.get(spotId);
    if (!isSpotEligibleForPin(spotData)) continue;
    pins.push({
      id: `${eventId}_spot_${spotId}`,
      data: {
        ...basePin,
        kind: "spot",
        spotId,
        latitude: spotData.latitude,
        longitude: spotData.longitude,
      },
    });
    spotPinCount += 1;
  }

  return {pins, truncated};
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} eventId
 * @return {Promise<void>}
 */
async function deleteEventMapPins(db, eventId) {
  const snapshot = await db.collection("eventMapPins")
      .where("eventId", "==", eventId)
      .get();
  if (snapshot.empty) return;

  const batch = db.batch();
  for (const doc of snapshot.docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} eventId
 * @param {Object} eventData
 * @param {Object=} options
 * @return {Promise<{pinsWritten: number, truncated: boolean}>}
 */
async function materializeEventMapPins(db, eventId, eventData, options = {}) {
  await deleteEventMapPins(db, eventId);

  const spotListIds = Array.isArray(eventData.spotListIds) ?
    eventData.spotListIds
        .filter((id) => typeof id === "string" && id.trim().length > 0)
        .map((id) => id.trim()) :
    [];

  const listsById = new Map();
  for (const listId of spotListIds) {
    const listSnap = await db.collection("spotLists").doc(listId).get();
    if (listSnap.exists) {
      listsById.set(listId, listSnap.data() || {});
    }
  }

  const allSpotIds = collectLinkedSpotIds(eventData, listsById);
  const spotsById = new Map();
  const chunkSize = 30;
  for (let i = 0; i < allSpotIds.length; i += chunkSize) {
    const chunk = allSpotIds.slice(i, i + chunkSize);
    const spotSnaps = await Promise.all(
        chunk.map((spotId) => db.collection("spots").doc(spotId).get()),
    );
    for (let j = 0; j < chunk.length; j++) {
      const snap = spotSnaps[j];
      if (snap.exists) {
        spotsById.set(chunk[j], snap.data() || {});
      }
    }
  }

  const {pins, truncated} = buildEventMapPinWrites(
      eventId,
      eventData,
      spotsById,
      listsById,
      options,
  );

  if (pins.length === 0) {
    return {pinsWritten: 0, truncated};
  }

  const batch = db.batch();
  for (const pin of pins) {
    batch.set(db.collection("eventMapPins").doc(pin.id), pin.data);
  }
  await batch.commit();

  if (truncated) {
    console.warn("eventMapPins.truncated", {
      eventId,
      max: MAX_SPOT_PINS_PER_EVENT,
    });
  }

  return {pinsWritten: pins.length, truncated};
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} listId
 * @return {Promise<{eventsProcessed: number}>}
 */
async function rematerializeEventsForSpotList(db, listId) {
  const snapshot = await db.collection("events")
      .where("spotListIds", "array-contains", listId)
      .get();

  let eventsProcessed = 0;
  for (const doc of snapshot.docs) {
    await materializeEventMapPins(db, doc.id, doc.data() || {});
    eventsProcessed += 1;
  }
  return {eventsProcessed};
}

module.exports = {
  MAX_SPOT_PINS_PER_EVENT,
  normalizeDate,
  hasValidCoordinates,
  isEventPast,
  isExpandableListVisibility,
  effectiveSpotIdsFromList,
  isSpotEligibleForPin,
  collectLinkedSpotIds,
  pickEventCardFields,
  buildEventMapPinWrites,
  deleteEventMapPins,
  materializeEventMapPins,
  rematerializeEventsForSpotList,
};
