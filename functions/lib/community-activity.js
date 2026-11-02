/* eslint-disable max-len */
/**
 * Region-scoped community activity for the Explore "Community" stream.
 *
 * Source documents (spots, spotCheckIns, spotTrainingPlans, auditLog photo
 * entries) are not queryable by map bounds together, so Cloud Functions
 * materialize one flat document per activity in `communityActivity` with the
 * spot's latitude/longitude denormalized. The Explore sheet then runs the same
 * latitude/longitude range queries it already uses for spots and eventMapPins.
 *
 * Documents are written by Cloud Functions only (see firestore.rules).
 *
 * Upcoming events are not duplicated here: they are read from `eventMapPins`
 * (already geo-indexed) and merged in by `executeCommunityActivityInBoundsQuery`.
 */

const {
  normalizeDate,
  hasValidCoordinates,
  isSpotEligibleForPin,
  spotLocationFieldsChanged,
} = require("./event-map-pins");
const {
  resolveLongitudeBounds,
  executeEventsInBoundsQuery,
  dedupePinsByEventId,
} = require("./events-in-bounds");
const {
  shouldFanOutNearbyNewSpotNotifications,
} = require("./nearby-new-spot-notifications");

const COMMUNITY_ACTIVITY_COLLECTION = "communityActivity";

const KIND_SPOT_ADDED = "spot_added";
const KIND_SPOT_PHOTO_ADDED = "spot_photo_added";
const KIND_SPOT_CHECK_IN = "spot_check_in";
const KIND_SPOT_TRAINING_PLAN = "spot_training_plan";

/** Items before the "now" divider (sorted by occurredAt). */
const TIMELINE_PAST = "past";
/** Items after the "now" divider (sorted by startAt, dropped once endAt passes). */
const TIMELINE_UPCOMING = "upcoming";

/** Past activity older than this is not interesting for the Explore stream. */
const PAST_ACTIVITY_RETENTION_MS = 90 * 24 * 60 * 60 * 1000;
/** Grace period before an upcoming item can be TTL-deleted after it ended. */
const UPCOMING_ACTIVITY_GRACE_MS = 24 * 60 * 60 * 1000;

const MAX_ACTIVITY_IMAGE_URLS = 3;
const MAX_COMMENT_LENGTH = 200;
const MAX_BATCH_OPERATIONS = 400;
const IN_BOUNDS_DEFAULT_LIMIT = 30;
const IN_BOUNDS_MAX_LIMIT = 100;
const EVENTS_DEFAULT_LIMIT = 20;
const GET_ALL_CHUNK = 10;

/**
 * @param {*} value
 * @return {string|null}
 */
function trimmedString(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * @param {Object} fields
 * @return {Object} copy without null/undefined entries
 */
function withoutNulls(fields) {
  const out = {};
  for (const [key, value] of Object.entries(fields)) {
    if (value !== null && value !== undefined) out[key] = value;
  }
  return out;
}

/**
 * @param {unknown} rawUrls
 * @param {number=} max
 * @return {string[]}
 */
function normalizeUrlList(rawUrls, max = MAX_ACTIVITY_IMAGE_URLS) {
  if (!Array.isArray(rawUrls)) return [];
  const seen = new Set();
  const out = [];
  for (const url of rawUrls) {
    const trimmed = trimmedString(url);
    if (!trimmed || seen.has(trimmed)) continue;
    seen.add(trimmed);
    out.push(trimmed);
    if (out.length >= max) break;
  }
  return out;
}

/**
 * @param {string} spotId
 * @return {string}
 */
function spotAddedActivityId(spotId) {
  return `spot_added_${spotId}`;
}

/**
 * @param {string} auditLogId
 * @return {string}
 */
function spotPhotoActivityId(auditLogId) {
  return `spot_photo_${auditLogId}`;
}

/**
 * @param {string} checkInId
 * @return {string}
 */
function checkInActivityId(checkInId) {
  return `check_in_${checkInId}`;
}

/**
 * @param {string} planId
 * @return {string}
 */
function trainingPlanActivityId(planId) {
  return `training_plan_${planId}`;
}

/**
 * Denormalized spot fields shared by every activity kind.
 * @param {string} spotId
 * @param {Object} spotData
 * @return {Object}
 */
function pickSpotFields(spotId, spotData) {
  const countryCode = trimmedString(spotData.countryCode);
  return withoutNulls({
    spotId,
    spotName: trimmedString(spotData.name),
    city: trimmedString(spotData.city),
    countryCode: countryCode ? countryCode.toUpperCase() : null,
    latitude: spotData.latitude,
    longitude: spotData.longitude,
  });
}

/**
 * @param {Object} params
 * @param {string|null} params.userId
 * @param {string|null} params.displayName
 * @param {string|null} params.photoURL
 * @return {Object}
 */
function pickActorFields({userId, displayName, photoURL}) {
  return withoutNulls({
    actorUserId: trimmedString(userId),
    actorDisplayName: trimmedString(displayName),
    actorPhotoURL: trimmedString(photoURL),
  });
}

/**
 * @param {*} value
 * @return {string|null}
 */
function normalizeComment(value) {
  const trimmed = trimmedString(value);
  if (!trimmed) return null;
  return trimmed.length > MAX_COMMENT_LENGTH ?
    trimmed.slice(0, MAX_COMMENT_LENGTH) :
    trimmed;
}

/**
 * Whether a spot can anchor community activity on the map.
 * @param {Object|null|undefined} spotData
 * @return {boolean}
 */
function isSpotEligibleForCommunityActivity(spotData) {
  return isSpotEligibleForPin(spotData);
}

/**
 * "X added this new spot" — native spots created by a signed-in user.
 * @param {string} spotId
 * @param {Object} spotData
 * @param {Object=} options
 * @param {Date=} options.now
 * @param {Object=} options.actorProfile displayName / photoURL
 * @return {{id: string, data: Object}|null}
 */
function buildSpotAddedActivity(spotId, spotData, options = {}) {
  if (!spotData || typeof spotData !== "object") return null;
  if (!shouldFanOutNearbyNewSpotNotifications(spotData)) return null;
  if (!isSpotEligibleForCommunityActivity(spotData)) return null;
  const createdBy = trimmedString(spotData.createdBy);
  if (!createdBy) return null;

  const now = options.now || new Date();
  const occurredAt = normalizeDate(spotData.createdAt) || now;
  const profile = options.actorProfile || {};
  const imageUrls = normalizeUrlList(spotData.imageUrls);

  return {
    id: spotAddedActivityId(spotId),
    data: withoutNulls({
      kind: KIND_SPOT_ADDED,
      timeline: TIMELINE_PAST,
      sourceId: spotId,
      occurredAt,
      expiresAt: new Date(occurredAt.getTime() + PAST_ACTIVITY_RETENTION_MS),
      ...pickSpotFields(spotId, spotData),
      ...pickActorFields({
        userId: createdBy,
        displayName: spotData.createdByName || profile.displayName,
        photoURL: profile.photoURL,
      }),
      imageUrls: imageUrls.length > 0 ? imageUrls : null,
    }),
  };
}

/**
 * Image URLs that an auditLog entry added to a spot.
 * Supports `photoAdded` (approved photo suggestions) and `spotEdit` entries
 * whose `changes.imageUrls` grew (staff edits).
 * @param {Object} logData
 * @return {string[]}
 */
function addedImageUrlsFromAuditLog(logData) {
  if (!logData || typeof logData !== "object") return [];
  const action = trimmedString(logData.action);
  if (action === "photoAdded") {
    const metadata = logData.metadata && typeof logData.metadata === "object" ?
      logData.metadata :
      {};
    return normalizeUrlList(metadata.photoUrls, Number.MAX_SAFE_INTEGER);
  }
  if (action === "spotEdit") {
    const changes = logData.changes && typeof logData.changes === "object" ?
      logData.changes :
      {};
    const imageChange = changes.imageUrls;
    if (!imageChange || typeof imageChange !== "object") return [];
    const before = new Set(normalizeUrlList(imageChange.from, Number.MAX_SAFE_INTEGER));
    return normalizeUrlList(imageChange.to, Number.MAX_SAFE_INTEGER)
        .filter((url) => !before.has(url));
  }
  return [];
}

/**
 * Who should be credited for an auditLog photo addition.
 * `photoAdded` credits the suggester stored in `metadata.contributor`
 * (falls back to the approving moderator); `spotEdit` credits the editor.
 * @param {Object} logData
 * @return {{userId: ?string, displayName: ?string}}
 */
function actorFromAuditLog(logData) {
  const metadata = logData && logData.metadata && typeof logData.metadata === "object" ?
    logData.metadata :
    {};
  const contributor = metadata.contributor && typeof metadata.contributor === "object" ?
    metadata.contributor :
    null;
  if (trimmedString(logData.action) === "photoAdded" && contributor &&
      trimmedString(contributor.userId)) {
    return {
      userId: trimmedString(contributor.userId),
      displayName: trimmedString(contributor.userName),
    };
  }
  return {
    userId: trimmedString(logData.userId),
    displayName: trimmedString(logData.userName),
  };
}

/**
 * "Y added a new photo to this spot".
 * @param {string} auditLogId
 * @param {Object} logData
 * @param {Object|null} spotData
 * @param {Object=} options
 * @param {Date=} options.now
 * @param {Object=} options.actorProfile displayName / photoURL
 * @return {{id: string, data: Object}|null}
 */
function buildSpotPhotoAddedActivity(auditLogId, logData, spotData, options = {}) {
  if (!logData || typeof logData !== "object") return null;
  const spotId = trimmedString(logData.spotId);
  if (!spotId) return null;
  if (!isSpotEligibleForCommunityActivity(spotData)) return null;
  const addedUrls = addedImageUrlsFromAuditLog(logData);
  if (addedUrls.length === 0) return null;
  const actor = actorFromAuditLog(logData);
  if (!actor.userId) return null;

  const now = options.now || new Date();
  const occurredAt = normalizeDate(logData.timestamp) || now;
  const profile = options.actorProfile || {};

  return {
    id: spotPhotoActivityId(auditLogId),
    data: withoutNulls({
      kind: KIND_SPOT_PHOTO_ADDED,
      timeline: TIMELINE_PAST,
      sourceId: auditLogId,
      occurredAt,
      expiresAt: new Date(occurredAt.getTime() + PAST_ACTIVITY_RETENTION_MS),
      ...pickSpotFields(spotId, spotData),
      ...pickActorFields({
        userId: actor.userId,
        displayName: actor.displayName || profile.displayName,
        photoURL: profile.photoURL,
      }),
      photoCount: addedUrls.length,
      imageUrls: addedUrls.slice(0, MAX_ACTIVITY_IMAGE_URLS),
    }),
  };
}

/**
 * @param {Object|null|undefined} checkInData
 * @return {boolean}
 */
function isCheckInEligibleForCommunityActivity(checkInData) {
  if (!checkInData || typeof checkInData !== "object") return false;
  if (checkInData.isPrivate !== false) return false;
  if (!trimmedString(checkInData.spotId)) return false;
  if (!trimmedString(checkInData.userId)) return false;
  return normalizeDate(checkInData.checkedInAt) != null;
}

/**
 * "Z checked in to this spot" (public check-ins only).
 * @param {string} checkInId
 * @param {Object} checkInData
 * @param {Object|null} spotData
 * @return {{id: string, data: Object}|null}
 */
function buildSpotCheckInActivity(checkInId, checkInData, spotData) {
  if (!isCheckInEligibleForCommunityActivity(checkInData)) return null;
  if (!isSpotEligibleForCommunityActivity(spotData)) return null;
  const spotId = trimmedString(checkInData.spotId);
  const occurredAt = normalizeDate(checkInData.checkedInAt);
  const endAt = normalizeDate(checkInData.expectedEndAt);

  return {
    id: checkInActivityId(checkInId),
    data: withoutNulls({
      kind: KIND_SPOT_CHECK_IN,
      timeline: TIMELINE_PAST,
      sourceId: checkInId,
      occurredAt,
      endAt,
      expiresAt: new Date(occurredAt.getTime() + PAST_ACTIVITY_RETENTION_MS),
      ...pickSpotFields(spotId, spotData),
      ...pickActorFields({
        userId: checkInData.userId,
        displayName: checkInData.displayName,
        photoURL: checkInData.photoURL,
      }),
      comment: normalizeComment(checkInData.comment),
    }),
  };
}

/**
 * @param {Object|null|undefined} planData
 * @param {Date=} now
 * @return {boolean}
 */
function isTrainingPlanEligibleForCommunityActivity(planData, now = new Date()) {
  if (!planData || typeof planData !== "object") return false;
  if (planData.isPrivate !== false) return false;
  if (!trimmedString(planData.spotId)) return false;
  if (!trimmedString(planData.userId)) return false;
  const startAt = normalizeDate(planData.plannedStartAt);
  const endAt = normalizeDate(planData.plannedEndAt);
  if (!startAt || !endAt) return false;
  return endAt.getTime() >= now.getTime();
}

/**
 * "A is planning to train at this spot" (public plans that have not ended).
 * @param {string} planId
 * @param {Object} planData
 * @param {Object|null} spotData
 * @param {Object=} options
 * @param {Date=} options.now
 * @return {{id: string, data: Object}|null}
 */
function buildSpotTrainingPlanActivity(planId, planData, spotData, options = {}) {
  const now = options.now || new Date();
  if (!isTrainingPlanEligibleForCommunityActivity(planData, now)) return null;
  if (!isSpotEligibleForCommunityActivity(spotData)) return null;
  const spotId = trimmedString(planData.spotId);
  const startAt = normalizeDate(planData.plannedStartAt);
  const endAt = normalizeDate(planData.plannedEndAt);
  const occurredAt = normalizeDate(planData.createdAt) || now;

  return {
    id: trainingPlanActivityId(planId),
    data: withoutNulls({
      kind: KIND_SPOT_TRAINING_PLAN,
      timeline: TIMELINE_UPCOMING,
      sourceId: planId,
      occurredAt,
      startAt,
      endAt,
      expiresAt: new Date(endAt.getTime() + UPCOMING_ACTIVITY_GRACE_MS),
      ...pickSpotFields(spotId, spotData),
      ...pickActorFields({
        userId: planData.userId,
        displayName: planData.displayName,
        photoURL: planData.photoURL,
      }),
      comment: normalizeComment(planData.comment),
    }),
  };
}

/**
 * Public profile fields for actors whose source document does not carry an
 * avatar (spot creators, photo contributors).
 * @param {FirebaseFirestore.Firestore} db
 * @param {string|null} userId
 * @return {Promise<{displayName: ?string, photoURL: ?string}>}
 */
async function loadActorProfile(db, userId) {
  const trimmed = trimmedString(userId);
  if (!trimmed) return {displayName: null, photoURL: null};
  try {
    const snap = await db.collection("users").doc(trimmed).get();
    if (!snap.exists) return {displayName: null, photoURL: null};
    const data = snap.data() || {};
    if (data.isPublicProfile === false) {
      return {displayName: trimmedString(data.displayName), photoURL: null};
    }
    return {
      displayName: trimmedString(data.displayName),
      photoURL: trimmedString(data.photoURL),
    };
  } catch (err) {
    console.warn("communityActivity.loadActorProfile failed", {userId: trimmed, err});
    return {displayName: null, photoURL: null};
  }
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string|null} spotId
 * @return {Promise<Object|null>}
 */
async function loadSpotData(db, spotId) {
  const trimmed = trimmedString(spotId);
  if (!trimmed) return null;
  const snap = await db.collection("spots").doc(trimmed).get();
  return snap.exists ? (snap.data() || {}) : null;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {{id: string, data: Object}} activity
 * @return {Promise<void>}
 */
async function writeCommunityActivity(db, activity) {
  await db.collection(COMMUNITY_ACTIVITY_COLLECTION)
      .doc(activity.id)
      .set(activity.data);
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} activityId
 * @return {Promise<void>}
 */
async function deleteCommunityActivity(db, activityId) {
  await db.collection(COMMUNITY_ACTIVITY_COLLECTION).doc(activityId).delete();
}

/**
 * Deletes every document in a snapshot in batches.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Array<FirebaseFirestore.QueryDocumentSnapshot>} docs
 * @return {Promise<number>}
 */
async function deleteDocs(db, docs) {
  let deleted = 0;
  for (let i = 0; i < docs.length; i += MAX_BATCH_OPERATIONS) {
    const batch = db.batch();
    const chunk = docs.slice(i, i + MAX_BATCH_OPERATIONS);
    for (const doc of chunk) batch.delete(doc.ref);
    await batch.commit();
    deleted += chunk.length;
  }
  return deleted;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} spotId
 * @return {Promise<number>} deleted count
 */
async function deleteCommunityActivityForSpot(db, spotId) {
  const trimmed = trimmedString(spotId);
  if (!trimmed) return 0;
  const snapshot = await db.collection(COMMUNITY_ACTIVITY_COLLECTION)
      .where("spotId", "==", trimmed)
      .get();
  if (snapshot.empty) return 0;
  return deleteDocs(db, snapshot.docs);
}

/**
 * Re-denormalizes spot location/name on every activity for [spotId].
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} spotId
 * @param {Object} spotData
 * @return {Promise<number>} updated count
 */
async function updateCommunityActivitySpotFields(db, spotId, spotData) {
  const snapshot = await db.collection(COMMUNITY_ACTIVITY_COLLECTION)
      .where("spotId", "==", spotId)
      .get();
  if (snapshot.empty) return 0;
  const fields = pickSpotFields(spotId, spotData);
  let updated = 0;
  for (let i = 0; i < snapshot.docs.length; i += MAX_BATCH_OPERATIONS) {
    const batch = db.batch();
    const chunk = snapshot.docs.slice(i, i + MAX_BATCH_OPERATIONS);
    for (const doc of chunk) batch.update(doc.ref, fields);
    await batch.commit();
    updated += chunk.length;
  }
  return updated;
}

/**
 * onCreate(spots/{spotId}).
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} spotId
 * @param {Object} spotData
 * @param {Object=} options
 * @return {Promise<{written: boolean}>}
 */
async function syncSpotAddedActivity(db, spotId, spotData, options = {}) {
  const createdBy = spotData && trimmedString(spotData.createdBy);
  const actorProfile = createdBy ? await loadActorProfile(db, createdBy) : {};
  const activity = buildSpotAddedActivity(spotId, spotData, {
    now: options.now,
    actorProfile,
  });
  if (!activity) return {written: false};
  await writeCommunityActivity(db, activity);
  return {written: true};
}

/**
 * onCreate(auditLog/{logId}) — only photo additions produce activity.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} auditLogId
 * @param {Object} logData
 * @param {Object=} options
 * @return {Promise<{written: boolean}>}
 */
async function syncSpotPhotoAddedActivity(db, auditLogId, logData, options = {}) {
  if (addedImageUrlsFromAuditLog(logData).length === 0) {
    return {written: false};
  }
  const spotData = await loadSpotData(db, logData.spotId);
  if (!isSpotEligibleForCommunityActivity(spotData)) return {written: false};
  const actor = actorFromAuditLog(logData);
  const actorProfile = await loadActorProfile(db, actor.userId);
  const activity = buildSpotPhotoAddedActivity(auditLogId, logData, spotData, {
    now: options.now,
    actorProfile,
  });
  if (!activity) return {written: false};
  await writeCommunityActivity(db, activity);
  return {written: true};
}

/**
 * onWrite(spotCheckIns/{checkInId}). Deleted or private check-ins remove the
 * activity; public ones (re)write it.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} checkInId
 * @param {Object|null} afterData null when deleted
 * @return {Promise<{written: boolean, deleted: boolean}>}
 */
async function syncSpotCheckInActivity(db, checkInId, afterData) {
  const activityId = checkInActivityId(checkInId);
  if (!isCheckInEligibleForCommunityActivity(afterData)) {
    await deleteCommunityActivity(db, activityId);
    return {written: false, deleted: true};
  }
  const spotData = await loadSpotData(db, afterData.spotId);
  const activity = buildSpotCheckInActivity(checkInId, afterData, spotData);
  if (!activity) {
    await deleteCommunityActivity(db, activityId);
    return {written: false, deleted: true};
  }
  await writeCommunityActivity(db, activity);
  return {written: true, deleted: false};
}

/**
 * onWrite(spotTrainingPlans/{planId}). Plans are deleted when converted into a
 * check-in, which removes the upcoming item; the check-in trigger adds the
 * past one.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} planId
 * @param {Object|null} afterData null when deleted
 * @param {Object=} options
 * @return {Promise<{written: boolean, deleted: boolean}>}
 */
async function syncSpotTrainingPlanActivity(db, planId, afterData, options = {}) {
  const now = options.now || new Date();
  const activityId = trainingPlanActivityId(planId);
  if (!isTrainingPlanEligibleForCommunityActivity(afterData, now)) {
    await deleteCommunityActivity(db, activityId);
    return {written: false, deleted: true};
  }
  const spotData = await loadSpotData(db, afterData.spotId);
  const activity = buildSpotTrainingPlanActivity(planId, afterData, spotData, {now});
  if (!activity) {
    await deleteCommunityActivity(db, activityId);
    return {written: false, deleted: true};
  }
  await writeCommunityActivity(db, activity);
  return {written: true, deleted: false};
}

/**
 * onUpdate/onDelete(spots/{spotId}): hidden, duplicate, or deleted spots drop
 * their activity; moved or renamed spots re-denormalize it.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} spotId
 * @param {Object|null} beforeData
 * @param {Object|null} afterData null when deleted
 * @return {Promise<{deleted: number, updated: number}>}
 */
async function syncCommunityActivityForSpotChange(db, spotId, beforeData, afterData) {
  if (!afterData || !isSpotEligibleForCommunityActivity(afterData)) {
    // Updates to a spot that was already ineligible (hidden, duplicate) cannot
    // have activity to remove; skip the query for those frequent sync writes.
    const stillIneligible = Boolean(afterData) && Boolean(beforeData) &&
      !isSpotEligibleForCommunityActivity(beforeData);
    if (stillIneligible) return {deleted: 0, updated: 0};
    const deleted = await deleteCommunityActivityForSpot(db, spotId);
    return {deleted, updated: 0};
  }
  if (!spotLocationFieldsChanged(beforeData, afterData)) {
    return {deleted: 0, updated: 0};
  }
  const updated = await updateCommunityActivitySpotFields(db, spotId, afterData);
  return {deleted: 0, updated};
}

/**
 * @param {*} value
 * @return {string|null} ISO string
 */
function toIso(value) {
  const date = normalizeDate(value);
  return date ? date.toISOString() : null;
}

/**
 * Callable-safe JSON for one activity document.
 * @param {string} docId
 * @param {Object} data
 * @return {Object|null}
 */
function normalizeCommunityActivity(docId, data) {
  if (!data || typeof data !== "object") return null;
  const kind = trimmedString(data.kind);
  const timeline = trimmedString(data.timeline);
  const occurredAt = toIso(data.occurredAt);
  if (!kind || !timeline || !occurredAt) return null;
  if (!hasValidCoordinates(data.latitude, data.longitude)) return null;
  const spotId = trimmedString(data.spotId);
  if (!spotId) return null;

  const imageUrls = normalizeUrlList(data.imageUrls);
  const photoCount = typeof data.photoCount === "number" && data.photoCount > 0 ?
    Math.floor(data.photoCount) :
    null;

  return withoutNulls({
    id: docId,
    kind,
    timeline,
    latitude: data.latitude,
    longitude: data.longitude,
    occurredAt,
    startAt: toIso(data.startAt),
    endAt: toIso(data.endAt),
    spotId,
    spotName: trimmedString(data.spotName),
    city: trimmedString(data.city),
    countryCode: trimmedString(data.countryCode),
    actorUserId: trimmedString(data.actorUserId),
    actorDisplayName: trimmedString(data.actorDisplayName),
    actorPhotoURL: trimmedString(data.actorPhotoURL),
    photoCount,
    imageUrls: imageUrls.length > 0 ? imageUrls : null,
    comment: trimmedString(data.comment),
  });
}

/**
 * @param {*} value
 * @param {number} fallback
 * @return {number}
 */
function clampLimit(value, fallback) {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return fallback;
  return Math.min(IN_BOUNDS_MAX_LIMIT, Math.floor(n));
}

/**
 * Past activity, newest first. Explicit orderBy on every range field pins the
 * composite index: (timeline, occurredAt DESC, latitude DESC, longitude DESC).
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} bounds
 * @param {number} limit
 * @return {FirebaseFirestore.Query}
 */
function buildPastActivityQuery(db, bounds, limit) {
  return db.collection(COMMUNITY_ACTIVITY_COLLECTION)
      .where("timeline", "==", TIMELINE_PAST)
      .where("latitude", ">=", bounds.minLat)
      .where("latitude", "<=", bounds.maxLat)
      .where("longitude", ">=", bounds.minLng)
      .where("longitude", "<=", bounds.maxLng)
      .orderBy("occurredAt", "desc")
      .orderBy("latitude", "desc")
      .orderBy("longitude", "desc")
      .limit(limit);
}

/**
 * Upcoming activity that has not ended, soonest first. Composite index:
 * (timeline, startAt ASC, endAt ASC, latitude ASC, longitude ASC).
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} bounds
 * @param {Date} now
 * @param {number} limit
 * @return {FirebaseFirestore.Query}
 */
function buildUpcomingActivityQuery(db, bounds, now, limit) {
  return db.collection(COMMUNITY_ACTIVITY_COLLECTION)
      .where("timeline", "==", TIMELINE_UPCOMING)
      .where("endAt", ">=", now)
      .where("latitude", ">=", bounds.minLat)
      .where("latitude", "<=", bounds.maxLat)
      .where("longitude", ">=", bounds.minLng)
      .where("longitude", "<=", bounds.maxLng)
      .orderBy("startAt", "asc")
      .orderBy("endAt", "asc")
      .orderBy("latitude", "asc")
      .orderBy("longitude", "asc")
      .limit(limit);
}

/**
 * Longitude segments for a viewport (two when it crosses the antimeridian).
 * @param {number} minLng
 * @param {number} maxLng
 * @return {Array<{minLng: number, maxLng: number}>}
 */
function longitudeSegments(minLng, maxLng) {
  const {
    normalizedMinLng,
    normalizedMaxLng,
    spansEntireGlobe,
    crossesDateline,
  } = resolveLongitudeBounds({minLng, maxLng});
  if (spansEntireGlobe) return [{minLng: -180, maxLng: 180}];
  if (crossesDateline) {
    return [
      {minLng: normalizedMinLng, maxLng: 180},
      {minLng: -180, maxLng: normalizedMaxLng},
    ];
  }
  return [{minLng: normalizedMinLng, maxLng: normalizedMaxLng}];
}

/**
 * @param {Array<Object>} items
 * @param {string} field ISO date field
 * @param {"asc"|"desc"} direction
 * @return {Array<Object>}
 */
function sortByIsoField(items, field, direction) {
  const sign = direction === "desc" ? -1 : 1;
  return [...items].sort((a, b) => {
    const ta = new Date(a[field]).getTime();
    const tb = new Date(b[field]).getTime();
    if (ta === tb) return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
    return sign * (ta - tb);
  });
}

/**
 * Public Going / Interested totals for event pins.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Array<Object>} pins deduped event pins
 * @return {Promise<Array<Object>>}
 */
async function attachEventInterestCounts(db, pins) {
  if (!Array.isArray(pins) || pins.length === 0) return [];
  const statsByEventId = new Map();
  for (let i = 0; i < pins.length; i += GET_ALL_CHUNK) {
    const chunk = pins.slice(i, i + GET_ALL_CHUNK);
    const refs = chunk.map((pin) => db.collection("eventInterestStats").doc(pin.eventId));
    const snaps = await db.getAll(...refs);
    for (const snap of snaps) {
      if (!snap.exists) continue;
      const data = snap.data() || {};
      statsByEventId.set(snap.id, {
        goingCount: Math.max(0, Number(data.goingCount) || 0),
        interestedCount: Math.max(0, Number(data.interestedCount) || 0),
      });
    }
  }
  return pins.map((pin) => {
    const stats = statsByEventId.get(pin.eventId) || {goingCount: 0, interestedCount: 0};
    return {...pin, ...stats};
  });
}

/**
 * Community stream for a viewport: past activity (newest first), then
 * upcoming training plans and events (soonest first).
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} params minLat, maxLat, minLng, maxLng, pastLimit?, upcomingLimit?, eventLimit?
 * @param {Object=} options
 * @param {Date=} options.now
 * @param {Function=} options.eventsInBounds override for tests
 * @return {Promise<Object>}
 */
async function executeCommunityActivityInBoundsQuery(db, params, options = {}) {
  const {minLat, maxLat, minLng, maxLng} = params || {};
  if (
    typeof minLat !== "number" ||
    typeof maxLat !== "number" ||
    typeof minLng !== "number" ||
    typeof maxLng !== "number"
  ) {
    throw new Error("minLat, maxLat, minLng, maxLng are required numbers");
  }

  const now = options.now || new Date();
  const pastLimit = clampLimit(params.pastLimit, IN_BOUNDS_DEFAULT_LIMIT);
  const upcomingLimit = clampLimit(params.upcomingLimit, IN_BOUNDS_DEFAULT_LIMIT);
  const eventLimit = clampLimit(params.eventLimit, EVENTS_DEFAULT_LIMIT);
  const segments = longitudeSegments(minLng, maxLng);

  const pastSnaps = await Promise.all(segments.map((segment) =>
    buildPastActivityQuery(db, {
      minLat,
      maxLat,
      minLng: segment.minLng,
      maxLng: segment.maxLng,
    }, pastLimit).get()));
  const upcomingSnaps = await Promise.all(segments.map((segment) =>
    buildUpcomingActivityQuery(db, {
      minLat,
      maxLat,
      minLng: segment.minLng,
      maxLng: segment.maxLng,
    }, now, upcomingLimit).get()));

  const mapDocs = (snaps) => {
    const items = [];
    for (const snap of snaps) {
      for (const doc of snap.docs) {
        const normalized = normalizeCommunityActivity(doc.id, doc.data());
        if (normalized) items.push(normalized);
      }
    }
    return items;
  };

  const past = sortByIsoField(mapDocs(pastSnaps), "occurredAt", "desc")
      .slice(0, pastLimit);
  const upcoming = sortByIsoField(mapDocs(upcomingSnaps), "startAt", "asc")
      .filter((item) => !item.endAt || new Date(item.endAt).getTime() >= now.getTime())
      .slice(0, upcomingLimit);

  const eventsInBounds = options.eventsInBounds ||
    ((queryParams) => executeEventsInBoundsQuery(db, queryParams));
  let events = [];
  try {
    const eventsResult = await eventsInBounds({
      minLat,
      maxLat,
      minLng,
      maxLng,
      limit: 200,
    });
    const pins = Array.isArray(eventsResult && eventsResult.pins) ? eventsResult.pins : [];
    const deduped = dedupePinsByEventId(pins).slice(0, eventLimit);
    events = await attachEventInterestCounts(db, deduped);
  } catch (err) {
    console.error("communityActivity events merge failed", err);
  }

  return {
    success: true,
    past,
    upcoming,
    events,
    pastCount: past.length,
    upcomingCount: upcoming.length,
    eventCount: events.length,
  };
}

/**
 * Deletes every communityActivity document (admin backfill with purge).
 * @param {FirebaseFirestore.Firestore} db
 * @return {Promise<number>}
 */
async function purgeCommunityActivity(db) {
  let deleted = 0;
  // Loop in pages so very large collections do not load into memory at once.
  for (;;) {
    const snapshot = await db.collection(COMMUNITY_ACTIVITY_COLLECTION)
        .limit(MAX_BATCH_OPERATIONS)
        .get();
    if (snapshot.empty) break;
    deleted += await deleteDocs(db, snapshot.docs);
    if (snapshot.size < MAX_BATCH_OPERATIONS) break;
  }
  return deleted;
}

/**
 * Rebuilds communityActivity from source collections for the retention window.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object=} options
 * @param {boolean=} options.purge delete existing documents first
 * @param {Date=} options.now
 * @return {Promise<Object>} counts per kind
 */
async function backfillCommunityActivity(db, options = {}) {
  const now = options.now || new Date();
  const since = new Date(now.getTime() - PAST_ACTIVITY_RETENTION_MS);
  const result = {
    purged: 0,
    spotsAdded: 0,
    photosAdded: 0,
    checkIns: 0,
    trainingPlans: 0,
    scanned: {spots: 0, auditLogs: 0, checkIns: 0, trainingPlans: 0},
  };

  if (options.purge === true) {
    result.purged = await purgeCommunityActivity(db);
  }

  const spotCache = new Map();
  const spotLoader = async (spotId) => {
    const key = trimmedString(spotId);
    if (!key) return null;
    if (!spotCache.has(key)) {
      spotCache.set(key, await loadSpotData(db, key));
    }
    return spotCache.get(key);
  };
  const profileCache = new Map();
  const profileLoader = async (userId) => {
    const key = trimmedString(userId);
    if (!key) return {};
    if (!profileCache.has(key)) {
      profileCache.set(key, await loadActorProfile(db, key));
    }
    return profileCache.get(key);
  };

  const spotsSnap = await db.collection("spots")
      .where("createdAt", ">=", since)
      .get();
  for (const doc of spotsSnap.docs) {
    result.scanned.spots += 1;
    const data = doc.data() || {};
    spotCache.set(doc.id, data);
    const actorProfile = await profileLoader(data.createdBy);
    const activity = buildSpotAddedActivity(doc.id, data, {now, actorProfile});
    if (!activity) continue;
    await writeCommunityActivity(db, activity);
    result.spotsAdded += 1;
  }

  for (const action of ["photoAdded", "spotEdit"]) {
    const logsSnap = await db.collection("auditLog")
        .where("action", "==", action)
        .where("timestamp", ">=", since)
        .orderBy("timestamp", "desc")
        .get();
    for (const doc of logsSnap.docs) {
      result.scanned.auditLogs += 1;
      const data = doc.data() || {};
      if (addedImageUrlsFromAuditLog(data).length === 0) continue;
      const spotData = await spotLoader(data.spotId);
      if (!isSpotEligibleForCommunityActivity(spotData)) continue;
      const actorProfile = await profileLoader(actorFromAuditLog(data).userId);
      const activity = buildSpotPhotoAddedActivity(doc.id, data, spotData, {now, actorProfile});
      if (!activity) continue;
      await writeCommunityActivity(db, activity);
      result.photosAdded += 1;
    }
  }

  const checkInsSnap = await db.collection("spotCheckIns")
      .where("isPrivate", "==", false)
      .where("checkedInAt", ">=", since)
      .get();
  for (const doc of checkInsSnap.docs) {
    result.scanned.checkIns += 1;
    const data = doc.data() || {};
    const spotData = await spotLoader(data.spotId);
    const activity = buildSpotCheckInActivity(doc.id, data, spotData);
    if (!activity) continue;
    await writeCommunityActivity(db, activity);
    result.checkIns += 1;
  }

  const plansSnap = await db.collection("spotTrainingPlans")
      .where("isPrivate", "==", false)
      .where("plannedEndAt", ">=", now)
      .get();
  for (const doc of plansSnap.docs) {
    result.scanned.trainingPlans += 1;
    const data = doc.data() || {};
    const spotData = await spotLoader(data.spotId);
    const activity = buildSpotTrainingPlanActivity(doc.id, data, spotData, {now});
    if (!activity) continue;
    await writeCommunityActivity(db, activity);
    result.trainingPlans += 1;
  }

  return result;
}

module.exports = {
  COMMUNITY_ACTIVITY_COLLECTION,
  KIND_SPOT_ADDED,
  KIND_SPOT_PHOTO_ADDED,
  KIND_SPOT_CHECK_IN,
  KIND_SPOT_TRAINING_PLAN,
  TIMELINE_PAST,
  TIMELINE_UPCOMING,
  PAST_ACTIVITY_RETENTION_MS,
  spotAddedActivityId,
  spotPhotoActivityId,
  checkInActivityId,
  trainingPlanActivityId,
  isSpotEligibleForCommunityActivity,
  isCheckInEligibleForCommunityActivity,
  isTrainingPlanEligibleForCommunityActivity,
  addedImageUrlsFromAuditLog,
  actorFromAuditLog,
  buildSpotAddedActivity,
  buildSpotPhotoAddedActivity,
  buildSpotCheckInActivity,
  buildSpotTrainingPlanActivity,
  loadActorProfile,
  syncSpotAddedActivity,
  syncSpotPhotoAddedActivity,
  syncSpotCheckInActivity,
  syncSpotTrainingPlanActivity,
  syncCommunityActivityForSpotChange,
  deleteCommunityActivityForSpot,
  normalizeCommunityActivity,
  longitudeSegments,
  buildPastActivityQuery,
  buildUpcomingActivityQuery,
  attachEventInterestCounts,
  executeCommunityActivityInBoundsQuery,
  backfillCommunityActivity,
};
