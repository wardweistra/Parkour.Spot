/* eslint-disable max-len */
/**
 * Fan-out in-app notifications when a native spot is created near users'
 * enabled locations of interest.
 */

const {calculateBounds} = require("./geo");

const COLLECTION_GROUP = "locationsOfInterest";
const QUERY_PAGE_SIZE = 300;
const GET_ALL_CHUNK = 10;
const BATCH_SIZE = 500;

/** @type {string} Stable id for client-side localization */
const NOTIFICATION_KIND_NEARBY_NEW_SPOT = "nearby_new_spot";

/**
 * Raw names for localized templates (empty strings → client uses l10n fallbacks).
 * @param {object} spotData
 * @return {{actorName: string, spotName: string}}
 */
function buildTemplateArgs(spotData) {
  const actorName = typeof spotData.createdByName === "string" ?
    spotData.createdByName.trim() :
    "";
  const spotName = typeof spotData.name === "string" ?
    spotData.name.trim() :
    "";
  return {actorName, spotName};
}

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
    console.log("Nearby new-spot notifications skipped:", {
      spotId,
      reason: "spot not eligible (hidden/import/invalid coords)",
    });
    return {skipped: true};
  }

  const lat = spotData.latitude;
  const lng = spotData.longitude;
  const {minLat, maxLat, minLng, maxLng} = calculateBounds(lat, lng, 5000);
  console.log("Spot created, checking nearby locationsOfInterest:", {
    spotId,
    latitude: lat,
    longitude: lng,
  });
  console.log("Finding locationsOfInterest within boundary box:", {
    spotId,
    minLat,
    maxLat,
    minLng,
    maxLng,
  });

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
    matchedLocationCount += snap.size;
    mergeUserIdsFromSnapshot(snap, candidateUserIds);
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
  console.log("Found locationsOfInterest and resolved notification audience:", {
    spotId,
    locationsOfInterestCount: matchedLocationCount,
    candidateUserCount: candidateUserIds.size,
    usersToNotifyCount: usersToNotify.length,
    usersToNotify,
  });
  if (usersToNotify.length === 0) {
    return {notified: 0};
  }

  const templateArgs = buildTemplateArgs(spotData);

  let batch = db.batch();
  let ops = 0;
  for (const uid of usersToNotify) {
    const ref = db.collection("users").doc(uid).collection("notifications").doc();
    batch.set(ref, {
      notificationKind: NOTIFICATION_KIND_NEARBY_NEW_SPOT,
      templateArgs,
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
 * @param {Set<string>} intoSet
 */
function mergeUserIdsFromSnapshot(snapshot, intoSet) {
  for (const doc of snapshot.docs) {
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
      if (data && data.notifyNewSpotsNearby !== false) {
        out.push(chunk[j]);
      }
    }
  }
  return out;
}

module.exports = {
  fanOutNearbyNewSpotNotifications,
  shouldFanOutNearbyNewSpotNotifications,
  mergeUserIdsFromSnapshot,
  buildTemplateArgs,
  NOTIFICATION_KIND_NEARBY_NEW_SPOT,
};
