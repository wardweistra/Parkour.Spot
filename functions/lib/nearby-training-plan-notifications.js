/* eslint-disable max-len */
/**
 * Fan-out in-app notifications when a public training plan is created near users'
 * enabled locations of interest.
 */

const {calculateBounds} = require("./geo");

const COLLECTION_GROUP = "locationsOfInterest";
const QUERY_PAGE_SIZE = 300;
const GET_ALL_CHUNK = 10;
const BATCH_SIZE = 500;

/** @type {string} Stable id for client-side localization */
const NOTIFICATION_KIND_NEARBY_TRAINING_PLAN = "nearby_training_plan";

/**
 * Raw names for localized templates (empty strings → client uses l10n fallbacks).
 * @param {object} planData
 * @param {object} spotData
 * @return {{actorName: string, spotName: string}}
 */
function buildTemplateArgs(planData, spotData) {
  const actorName = typeof planData.displayName === "string" ?
    planData.displayName.trim() :
    "";
  const planSpotName = typeof planData.spotName === "string" ?
    planData.spotName.trim() :
    "";
  const spotNameFromSpot = typeof spotData.name === "string" ?
    spotData.name.trim() :
    "";
  const spotName = planSpotName || spotNameFromSpot || "";
  return {actorName, spotName};
}

/**
 * @param {object} spotData spot fields
 * @return {boolean}
 */
function hasValidSpotCoordinates(spotData) {
  if (!spotData || spotData.hidden === true) {
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
 * Writes per-user notifications for a newly created public training plan.
 * @param {object} options
 * @param {object} options.db Firestore instance
 * @param {object} options.FieldValue admin FieldValue
 * @param {string} options.planId
 * @param {object} options.planData training plan document fields
 * @return {Promise<Object>} result with skipped or notified count
 */
async function fanOutNearbyTrainingPlanNotifications({
  db,
  FieldValue,
  planId,
  planData,
}) {
  if (!shouldFanOutNearbyTrainingPlanNotifications(planData)) {
    console.log("Nearby training-plan notifications skipped:", {
      planId,
      reason: "plan not eligible (private/missing spotId or userId)",
    });
    return {skipped: true};
  }

  const spotId = String(planData.spotId);
  const spotSnap = await db.collection("spots").doc(spotId).get();
  if (!spotSnap.exists) {
    console.log("Nearby training-plan notifications skipped:", {
      planId,
      spotId,
      reason: "spot not found",
    });
    return {skipped: true};
  }

  const spotData = spotSnap.data() || {};
  if (!hasValidSpotCoordinates(spotData)) {
    console.log("Nearby training-plan notifications skipped:", {
      planId,
      spotId,
      reason: "spot has invalid coordinates",
    });
    return {skipped: true};
  }

  const lat = spotData.latitude;
  const lng = spotData.longitude;
  const {minLat, maxLat, minLng, maxLng} = calculateBounds(lat, lng, 5000);
  console.log("Training plan created, checking nearby locationsOfInterest:", {
    planId,
    spotId,
    latitude: lat,
    longitude: lng,
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

  const plannerId = typeof planData.userId === "string" ?
    planData.userId :
    "";
  if (plannerId.length > 0) {
    candidateUserIds.delete(plannerId);
  }

  const usersToNotify = await filterUserIdsWithNotifyFlag(db, [...candidateUserIds]);
  console.log("Resolved nearby training-plan audience:", {
    planId,
    spotId,
    locationsOfInterestCount: matchedLocationCount,
    candidateUserCount: candidateUserIds.size,
    usersToNotifyCount: usersToNotify.length,
  });
  if (usersToNotify.length === 0) {
    return {notified: 0};
  }

  const templateArgs = buildTemplateArgs(planData, spotData);

  let batch = db.batch();
  let ops = 0;
  for (const uid of usersToNotify) {
    const ref = db.collection("users").doc(uid).collection("notifications").doc();
    batch.set(ref, {
      notificationKind: NOTIFICATION_KIND_NEARBY_TRAINING_PLAN,
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

  return {notified: usersToNotify.length};
}

/**
 * @param {object} planData training plan document fields
 * @return {boolean}
 */
function shouldFanOutNearbyTrainingPlanNotifications(planData) {
  if (!planData) {
    return false;
  }
  if (planData.isPrivate === true) {
    return false;
  }
  if (typeof planData.spotId !== "string" || planData.spotId.trim() === "") {
    return false;
  }
  if (typeof planData.userId !== "string" || planData.userId.trim() === "") {
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
      if (data && data.notifyTrainingPlansNearby !== false) {
        out.push(chunk[j]);
      }
    }
  }
  return out;
}

module.exports = {
  fanOutNearbyTrainingPlanNotifications,
  shouldFanOutNearbyTrainingPlanNotifications,
  hasValidSpotCoordinates,
  mergeUserIdsFromSnapshot,
  buildTemplateArgs,
  NOTIFICATION_KIND_NEARBY_TRAINING_PLAN,
};
