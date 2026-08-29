/* eslint-disable max-len */
/**
 * Fan-out in-app notifications when a native spot is created near users'
 * enabled locations of interest.
 */

const {
  findUserIdsNearPoint,
  filterUserIdsByFlag,
} = require("./nearby-audience");

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
  const creatorId = typeof spotData.createdBy === "string" ?
    spotData.createdBy :
    "";
  console.log("Spot created, checking nearby locationsOfInterest:", {
    spotId,
    latitude: lat,
    longitude: lng,
  });

  const {userIds, matchedLocationCount} = await findUserIdsNearPoint({
    db,
    lat,
    lng,
    excludeUserId: creatorId,
  });
  const usersToNotify = await filterUserIdsByFlag(
      db, userIds, "notifyNewSpotsNearby",
  );
  console.log("Found locationsOfInterest and resolved notification audience:", {
    spotId,
    locationsOfInterestCount: matchedLocationCount,
    candidateUserCount: userIds.length,
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
    candidateCount: userIds.length,
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
  if (spotData.createdFromCreateNative === true) {
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

module.exports = {
  fanOutNearbyNewSpotNotifications,
  shouldFanOutNearbyNewSpotNotifications,
  buildTemplateArgs,
  NOTIFICATION_KIND_NEARBY_NEW_SPOT,
};
