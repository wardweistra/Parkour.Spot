/* eslint-disable max-len */
/**
 * Fan-out in-app notifications when a native spot is created near users'
 * enabled locations of interest.
 */

const {calculateBounds} = require("./geo");

const COLLECTION_GROUP = "locationsOfInterest";
const QUERY_PAGE_SIZE = 300;
const GET_ALL_CHUNK = 10;
const MAX_TITLE_LEN = 200;
const BATCH_SIZE = 500;

const PREFIX = "New spot nearby: ";

/**
 * Writes per-user notifications for a newly created spot.
 * @param {object} options
 * @param {object} options.db Firestore instance
 * @param {object} options.FieldValue admin FieldValue
 * @param {string} options.spotId
 * @param {object} options.spotData spot document fields
 * @return {Promise<Object>} result with skipped or notified count
 */
async function fanOutNearbyNewSpotNotifications({db, FieldValue, spotId, spotData}) {
  if (!shouldFanOutNearbyNewSpotNotifications(spotData)) {
    return {skipped: true};
  }

  const lat = spotData.latitude;
  const lng = spotData.longitude;
  const {minLat, maxLat, minLng, maxLng} = calculateBounds(lat, lng, 5000);

  const candidateUserIds = new Set();
  let lastDoc = null;
  for (;;) {
    let q = db.collectionGroup(COLLECTION_GROUP)
        .where("enabled", "==", true)
        .where("latitude", ">=", minLat)
        .where("latitude", "<=", maxLat)
        .limit(QUERY_PAGE_SIZE);
    if (lastDoc) {
      q = q.startAfter(lastDoc);
    }
    const snap = await q.get();
    if (snap.empty) {
      break;
    }
    mergeLngFilteredUserIdsFromSnapshot(snap, minLng, maxLng, candidateUserIds);
    if (snap.size < QUERY_PAGE_SIZE) {
      break;
    }
    lastDoc = snap.docs[snap.docs.length - 1];
  }

  const creatorId = spotData.createdBy;
  if (typeof creatorId === "string" && creatorId.length > 0) {
    candidateUserIds.delete(creatorId);
  }

  const usersToNotify = await filterUserIdsWithNotifyFlag(db, [...candidateUserIds]);
  if (usersToNotify.length === 0) {
    return {notified: 0};
  }

  const title = buildNotificationTitle(spotData);
  const body =
    "A new parkour spot was added near one of your saved locations.";

  let batch = db.batch();
  let ops = 0;
  for (const uid of usersToNotify) {
    const ref = db.collection("users").doc(uid).collection("notifications").doc();
    batch.set(ref, {
      title,
      body,
      deeplinkKind: "spot",
      deeplinkId: spotId,
      createdAt: FieldValue.serverTimestamp(),
      read: false,
    });
    ops++;
    if (ops >= BATCH_SIZE) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) {
    await batch.commit();
  }

  console.log("Nearby new-spot notifications:", {
    spotId,
    candidateCount: candidateUserIds.size,
    notified: usersToNotify.length,
  });

  return {notified: usersToNotify.length};
}

/**
 * @param {object} spotData spot document fields
 * @return {boolean}
 */
function shouldFanOutNearbyNewSpotNotifications(spotData) {
  if (!spotData || spotData.hidden === true) {
    return false;
  }
  if (spotData.spotSource != null && String(spotData.spotSource).trim() !== "") {
    return false;
  }
  const lat = spotData.latitude;
  const lng = spotData.longitude;
  if (typeof lat !== "number" || typeof lng !== "number") {
    return false;
  }
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return false;
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return false;
  }
  return true;
}

/**
 * @param {object} snapshot QuerySnapshot
 * @param {number} minLng
 * @param {number} maxLng
 * @param {Set<string>} intoSet
 */
function mergeLngFilteredUserIdsFromSnapshot(snapshot, minLng, maxLng, intoSet) {
  for (const doc of snapshot.docs) {
    const loi = doc.data();
    const loiLng = loi.longitude;
    if (typeof loiLng !== "number" || !Number.isFinite(loiLng)) {
      continue;
    }
    if (loiLng < minLng || loiLng > maxLng) {
      continue;
    }
    const parent = doc.ref.parent;
    const userRef = parent && parent.parent;
    const uid = userRef && userRef.id;
    if (typeof uid === "string" && uid.length > 0) {
      intoSet.add(uid);
    }
  }
}

/**
 * @param {object} db Firestore instance
 * @param {string[]} userIds
 * @return {Promise<string[]>}
 */
async function filterUserIdsWithNotifyFlag(db, userIds) {
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
      if (data && data.notifyNewSpotsNearby === true) {
        out.push(chunk[j]);
      }
    }
  }
  return out;
}

/**
 * @param {object} spotData spot document fields
 * @return {string}
 */
function buildNotificationTitle(spotData) {
  const raw = typeof spotData.name === "string" ? spotData.name.trim() : "";
  const namePart = raw.length > 0 ? raw : "Untitled spot";
  const maxNameLen = Math.max(0, MAX_TITLE_LEN - PREFIX.length);
  const clipped = namePart.length > maxNameLen ?
    namePart.slice(0, maxNameLen - 1).trimEnd() + "…" :
    namePart;
  const title = PREFIX + clipped;
  return title.length <= MAX_TITLE_LEN ? title : title.slice(0, MAX_TITLE_LEN);
}

module.exports = {
  fanOutNearbyNewSpotNotifications,
  shouldFanOutNearbyNewSpotNotifications,
  mergeLngFilteredUserIdsFromSnapshot,
  buildNotificationTitle,
};
