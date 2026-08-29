/* eslint-disable max-len */
/**
 * Shared nearby-notification audience: enabled locations of interest within
 * each document's alert radius (10 / 50 / 100 km, default 50 km).
 */

const {calculateBounds, calculateDistance} = require("./geo");

const COLLECTION_GROUP = "locationsOfInterest";
const QUERY_PAGE_SIZE = 300;
const GET_ALL_CHUNK = 10;
const MAX_ALERT_RADIUS_METERS = 100000;
const DEFAULT_ALERT_RADIUS_KM = 50;
const ALLOWED_ALERT_RADIUS_KM = new Set([10, 50, 100]);

/**
 * @param {*} value
 * @return {number} 10, 50, or 100
 */
function normalizeAlertRadiusKm(value) {
  const n = typeof value === "number" ? value : Number(value);
  if (ALLOWED_ALERT_RADIUS_KM.has(n)) {
    return n;
  }
  return DEFAULT_ALERT_RADIUS_KM;
}

/**
 * Whether this location-of-interest document is within its own alert radius
 * of (lat, lng).
 * @param {object} loiData
 * @param {number} lat
 * @param {number} lng
 * @return {boolean}
 */
function locationMatchesPoint(loiData, lat, lng) {
  if (!loiData) {
    return false;
  }
  const loiLat = loiData.latitude;
  const loiLng = loiData.longitude;
  if (typeof loiLat !== "number" || typeof loiLng !== "number") {
    return false;
  }
  if (!Number.isFinite(loiLat) || !Number.isFinite(loiLng)) {
    return false;
  }
  const radiusMeters = normalizeAlertRadiusKm(loiData.alertRadiusKm) * 1000;
  return calculateDistance(lat, lng, loiLat, loiLng) <= radiusMeters;
}

/**
 * @param {object} doc QueryDocumentSnapshot
 * @return {string|null}
 */
function userIdFromLoiDoc(doc) {
  const parent = doc.ref && doc.ref.parent;
  const userRef = parent && parent.parent;
  const uid = userRef && userRef.id;
  if (typeof uid === "string" && uid.length > 0) {
    return uid;
  }
  return null;
}

/**
 * Users with at least one enabled location of interest within that location's
 * alert radius of (lat, lng).
 * @param {object} options
 * @param {FirebaseFirestore.Firestore} options.db
 * @param {number} options.lat
 * @param {number} options.lng
 * @param {string} [options.excludeUserId]
 * @return {Promise<{userIds: string[], matchedLocationCount: number}>}
 */
async function findUserIdsNearPoint({db, lat, lng, excludeUserId}) {
  const {minLat, maxLat, minLng, maxLng} =
      calculateBounds(lat, lng, MAX_ALERT_RADIUS_METERS);
  const candidateUserIds = new Set();
  let matchedLocationCount = 0;
  let lastDoc = null;
  for (;;) {
    let q = db.collectionGroup(COLLECTION_GROUP)
        .where("enabled", "==", true)
        .where("latitude", ">=", minLat)
        .where("latitude", "<=", maxLat)
        .where("longitude", ">=", minLng)
        .where("longitude", "<=", maxLng)
        .limit(QUERY_PAGE_SIZE);
    if (lastDoc) {
      q = q.startAfter(lastDoc);
    }
    const snap = await q.get();
    if (snap.empty) {
      break;
    }
    for (const doc of snap.docs) {
      const data = typeof doc.data === "function" ? doc.data() : {};
      if (!locationMatchesPoint(data, lat, lng)) {
        continue;
      }
      matchedLocationCount++;
      const uid = userIdFromLoiDoc(doc);
      if (uid) {
        candidateUserIds.add(uid);
      }
    }
    if (snap.size < QUERY_PAGE_SIZE) {
      break;
    }
    lastDoc = snap.docs[snap.docs.length - 1];
  }
  if (typeof excludeUserId === "string" && excludeUserId.length > 0) {
    candidateUserIds.delete(excludeUserId);
  }
  return {
    userIds: [...candidateUserIds],
    matchedLocationCount,
  };
}

/**
 * Keep user ids whose user doc has flagName !== false (missing defaults on).
 * @param {FirebaseFirestore.Firestore} db
 * @param {string[]} userIds
 * @param {string} flagName
 * @return {Promise<string[]>}
 */
async function filterUserIdsByFlag(db, userIds, flagName) {
  const out = [];
  for (let i = 0; i < userIds.length; i += GET_ALL_CHUNK) {
    const chunk = userIds.slice(i, i + GET_ALL_CHUNK);
    const refs = chunk.map((uid) => db.collection("users").doc(uid));
    const snaps = await db.getAll(...refs);
    for (let j = 0; j < snaps.length; j++) {
      const doc = snaps[j];
      if (!doc.exists) {
        continue;
      }
      const data = doc.data();
      if (data && data[flagName] !== false) {
        out.push(chunk[j]);
      }
    }
  }
  return out;
}

module.exports = {
  MAX_ALERT_RADIUS_METERS,
  DEFAULT_ALERT_RADIUS_KM,
  ALLOWED_ALERT_RADIUS_KM,
  normalizeAlertRadiusKm,
  locationMatchesPoint,
  findUserIdsNearPoint,
  filterUserIdsByFlag,
};
