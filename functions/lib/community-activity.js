/* eslint-disable max-len */
/**
 * Region-scoped community activity for the Explore "Community" stream.
 *
 * Source documents (spots, spotCheckIns, spotTrainingPlans, auditLog photo
 * entries, ended events) are not queryable by map bounds together, so Cloud
 * Functions materialize one flat document per activity in `communityActivity`
 * with latitude/longitude denormalized. The Explore sheet then runs the same
 * latitude/longitude range queries it already uses for spots and eventMapPins.
 *
 * Documents are written by Cloud Functions only (see firestore.rules).
 *
 * Upcoming events are not duplicated here: they are read from `eventMapPins`
 * (already geo-indexed) and merged in by `executeCommunityActivityInBoundsQuery`.
 * Ended events are materialized as `event_ended` past items for 90 days.
 */

const {
  normalizeDate,
  hasValidCoordinates,
  isSpotEligibleForPin,
  spotLocationFieldsChanged,
  isEventPast,
  resolveEventMainLocation,
  loadEventLinkedLocationInputs,
  deleteEventMapPins,
} = require("./event-map-pins");
const {
  resolveLongitudeBounds,
  pageEventPinsInBounds,
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
const KIND_EVENT_ENDED = "event_ended";

const ALL_ACTIVITY_KINDS = new Set([
  KIND_SPOT_ADDED,
  KIND_SPOT_PHOTO_ADDED,
  KIND_SPOT_CHECK_IN,
  KIND_SPOT_TRAINING_PLAN,
  KIND_EVENT_ENDED,
]);

/** Kinds stored on past `communityActivity` documents. */
const PAST_ACTIVITY_KINDS = new Set([
  KIND_SPOT_ADDED,
  KIND_SPOT_PHOTO_ADDED,
  KIND_SPOT_CHECK_IN,
  KIND_EVENT_ENDED,
]);

/** Kinds stored on upcoming `communityActivity` documents (training plans). */
const UPCOMING_ACTIVITY_KINDS = new Set([
  KIND_SPOT_TRAINING_PLAN,
]);

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
/** Default upcoming merged page size (plans + events). */
const UPCOMING_PAGE_DEFAULT = 10;
/** Default past page size (initial load and load-more). */
const PAST_PAGE_DEFAULT = 10;
/** Default first-page past size — same as a normal past page. */
const PAST_INITIAL_DEFAULT = PAST_PAGE_DEFAULT;
const IN_BOUNDS_MAX_LIMIT = 100;
const GET_ALL_CHUNK = 10;
const PAST_PIN_SWEEP_DEFAULT_LIMIT = 200;

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
 * @param {string} eventId
 * @return {string}
 */
function eventEndedActivityId(eventId) {
  return `event_ended_${eventId}`;
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

/** Sentinel matching Flutter `SpotService.anonymousContributorUserId`. */
const ANONYMOUS_CONTRIBUTOR_USER_ID = "__anonymous__";

/**
 * True when a userId should not be treated as a real account.
 * @param {?string} userId
 * @return {boolean}
 */
function isAnonymousContributorUserId(userId) {
  const trimmed = trimmedString(userId);
  return !trimmed || trimmed === ANONYMOUS_CONTRIBUTOR_USER_ID;
}

/**
 * Who should be credited for an auditLog photo addition.
 * `photoAdded` credits the suggester in `metadata.contributor` only — never
 * the approving moderator. Missing/anonymous contributor → null actor
 * (client shows "Someone"). `spotEdit` credits the editor.
 * @param {Object} logData
 * @return {{userId: ?string, displayName: ?string}}
 */
function actorFromAuditLog(logData) {
  const action = trimmedString(logData && logData.action);
  if (action === "photoAdded") {
    const metadata = logData.metadata && typeof logData.metadata === "object" ?
      logData.metadata :
      {};
    const contributor = metadata.contributor && typeof metadata.contributor === "object" ?
      metadata.contributor :
      null;
    const contributorUserId = contributor ?
      trimmedString(contributor.userId) :
      null;
    if (contributorUserId && !isAnonymousContributorUserId(contributorUserId)) {
      return {
        userId: contributorUserId,
        displayName: trimmedString(contributor.userName),
      };
    }
    return {userId: null, displayName: null};
  }
  return {
    userId: trimmedString(logData && logData.userId),
    displayName: trimmedString(logData && logData.userName),
  };
}

/**
 * Prefer the linked spot report's reporter over audit metadata so purge+backfill
 * repairs older logs that wrongly stamped the moderator as contributor.
 * Guest reports (no reporterUserId) yield an anonymous null actor.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} logData
 * @return {Promise<{userId: ?string, displayName: ?string}>}
 */
async function resolvePhotoAddedActor(db, logData) {
  const reportId = trimmedString(logData && logData.reportId);
  if (reportId) {
    try {
      const snap = await db.collection("spotReports").doc(reportId).get();
      if (snap.exists) {
        const data = snap.data() || {};
        const reporterUserId = trimmedString(data.reporterUserId);
        if (reporterUserId && !isAnonymousContributorUserId(reporterUserId)) {
          return {
            userId: reporterUserId,
            displayName: trimmedString(data.reporterName),
          };
        }
        return {userId: null, displayName: null};
      }
    } catch (e) {
      console.error("resolvePhotoAddedActor report lookup failed", {reportId, e});
    }
  }
  return actorFromAuditLog(logData);
}

/**
 * "Y added a new photo to this spot".
 * Missing actor → anonymous "Someone" in the client (no actorUserId).
 * @param {string} auditLogId
 * @param {Object} logData
 * @param {Object|null} spotData
 * @param {Object=} options
 * @param {Date=} options.now
 * @param {{userId: ?string, displayName: ?string}=} options.actor
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
  const actor = options.actor || actorFromAuditLog(logData);

  const now = options.now || new Date();
  const occurredAt = normalizeDate(logData.timestamp) || now;
  const profile = options.actorProfile || {};
  const hasRealActor = actor.userId && !isAnonymousContributorUserId(actor.userId);

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
        userId: hasRealActor ? actor.userId : null,
        displayName: hasRealActor ?
          (actor.displayName || profile.displayName) :
          null,
        photoURL: hasRealActor ? profile.photoURL : null,
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
 * Main location for an ended-event activity: prefer server-owned
 * resolvedLocation, then venue coordinates on the event.
 * @param {Object} eventData
 * @return {Object|null}
 */
function locationFromEventResolvedOrVenue(eventData) {
  if (!eventData || typeof eventData !== "object") return null;
  const resolved = eventData.resolvedLocation;
  if (
    resolved &&
    typeof resolved === "object" &&
    hasValidCoordinates(resolved.latitude, resolved.longitude)
  ) {
    const countryCode = trimmedString(resolved.countryCode);
    return withoutNulls({
      source: trimmedString(resolved.source) || "spot",
      latitude: resolved.latitude,
      longitude: resolved.longitude,
      city: trimmedString(resolved.city),
      countryCode: countryCode ? countryCode.toUpperCase() : null,
      spotId: trimmedString(resolved.spotId),
      spotName: trimmedString(resolved.spotName),
    });
  }
  if (hasValidCoordinates(eventData.latitude, eventData.longitude)) {
    const countryCode = trimmedString(eventData.countryCode);
    return withoutNulls({
      source: "venue",
      latitude: eventData.latitude,
      longitude: eventData.longitude,
      city: trimmedString(eventData.city),
      countryCode: countryCode ? countryCode.toUpperCase() : null,
    });
  }
  return null;
}

/**
 * @param {Object|null|undefined} eventData
 * @param {Date=} now
 * @return {boolean}
 */
function isEventEligibleForEndedActivity(eventData, now = new Date()) {
  if (!eventData || typeof eventData !== "object") return false;
  if (eventData.hidden === true) return false;
  const duplicateOf = eventData.duplicateOf;
  if (typeof duplicateOf === "string" && duplicateOf.trim().length > 0) {
    return false;
  }
  if (!isEventPast(eventData, now)) return false;
  const occurredAt = normalizeDate(eventData.endAt) ||
    normalizeDate(eventData.startAt);
  if (!occurredAt) return false;
  return occurredAt.getTime() >= now.getTime() - PAST_ACTIVITY_RETENTION_MS;
}

/**
 * "This event has ended" — one past activity at the event's main location.
 * @param {string} eventId
 * @param {Object} eventData
 * @param {Object|null} location from resolveEventMainLocation / resolvedLocation
 * @param {Object=} options
 * @param {Date=} options.now
 * @return {{id: string, data: Object}|null}
 */
function buildEventEndedActivity(eventId, eventData, location, options = {}) {
  const now = options.now || new Date();
  const trimmedEventId = trimmedString(eventId);
  if (!trimmedEventId) return null;
  if (!isEventEligibleForEndedActivity(eventData, now)) return null;
  if (
    !location ||
    !hasValidCoordinates(location.latitude, location.longitude)
  ) {
    return null;
  }

  const startAt = normalizeDate(eventData.startAt);
  if (!startAt) return null;
  const endAt = normalizeDate(eventData.endAt);
  const occurredAt = endAt || startAt;
  if (occurredAt.getTime() < now.getTime() - PAST_ACTIVITY_RETENTION_MS) {
    return null;
  }

  const title = trimmedString(eventData.title) || "Event";
  const countryCode = trimmedString(location.countryCode);
  const pinKind = location.source === "venue" ? "venue" : "spot";
  const imageUrls = normalizeUrlList(eventData.imageUrls);
  const timeZone = trimmedString(eventData.timeZone);
  const description = trimmedString(eventData.description);

  return {
    id: eventEndedActivityId(trimmedEventId),
    data: withoutNulls({
      kind: KIND_EVENT_ENDED,
      timeline: TIMELINE_PAST,
      sourceId: trimmedEventId,
      eventId: trimmedEventId,
      title,
      pinKind,
      occurredAt,
      startAt,
      endAt,
      expiresAt: new Date(occurredAt.getTime() + PAST_ACTIVITY_RETENTION_MS),
      latitude: location.latitude,
      longitude: location.longitude,
      city: trimmedString(location.city),
      countryCode: countryCode ? countryCode.toUpperCase() : null,
      spotId: trimmedString(location.spotId),
      spotName: trimmedString(location.spotName),
      isDateOnly: eventData.isDateOnly === true ? true : null,
      timeZone,
      description: description ?
        (description.length > 500 ? description.slice(0, 500) : description) :
        null,
      imageUrls: imageUrls.length > 0 ? imageUrls : null,
    }),
  };
}

/**
 * Upserts or clears the past activity for an ended event.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} eventId
 * @param {Object|null} eventData null when deleted
 * @param {Object=} options
 * @param {Date=} options.now
 * @param {{listsById: Map, spotsById: Map}=} options.inputs
 * @param {Object|null=} options.location
 * @return {Promise<{written: boolean, deleted: boolean}>}
 */
async function syncEventEndedActivity(db, eventId, eventData, options = {}) {
  const now = options.now || new Date();
  const activityId = eventEndedActivityId(eventId);
  if (!isEventEligibleForEndedActivity(eventData, now)) {
    await deleteCommunityActivity(db, activityId);
    return {written: false, deleted: true};
  }

  let location = options.location || locationFromEventResolvedOrVenue(eventData);
  if (!location) {
    const inputs = options.inputs ||
      await loadEventLinkedLocationInputs(db, eventData);
    location = resolveEventMainLocation(
        eventData,
        inputs.spotsById,
        inputs.listsById,
    );
  }

  const activity = buildEventEndedActivity(eventId, eventData, location, {now});
  if (!activity) {
    await deleteCommunityActivity(db, activityId);
    return {written: false, deleted: true};
  }
  await writeCommunityActivity(db, activity);
  return {written: true, deleted: false};
}

/**
 * Hourly sweep: past eventMapPins that aged out without an event write.
 * Upserts event_ended community activity, then deletes those pins.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object=} options
 * @param {Date=} options.now
 * @param {number=} options.limit
 * @return {Promise<{scanned: number, eventsProcessed: number, pinsDeleted: number}>}
 */
async function sweepPastEventMapPinsForCommunityActivity(db, options = {}) {
  const now = options.now || new Date();
  const limit = Number.isFinite(options.limit) && options.limit > 0 ?
    Math.floor(options.limit) :
    PAST_PIN_SWEEP_DEFAULT_LIMIT;

  const snap = await db.collection("eventMapPins")
      .where("startAt", "<", now)
      .orderBy("startAt", "asc")
      .limit(limit)
      .get();

  const pinDocsByEventId = new Map();
  for (const doc of snap.docs) {
    const data = doc.data() || {};
    if (!isEventPast(data, now)) continue;
    const eventId = trimmedString(data.eventId);
    if (!eventId) continue;
    if (!pinDocsByEventId.has(eventId)) pinDocsByEventId.set(eventId, []);
    pinDocsByEventId.get(eventId).push(doc);
  }

  let eventsProcessed = 0;
  let pinsDeleted = 0;
  for (const [eventId, pinDocs] of pinDocsByEventId) {
    const eventSnap = await db.collection("events").doc(eventId).get();
    const eventData = eventSnap.exists ? (eventSnap.data() || {}) : null;
    await syncEventEndedActivity(db, eventId, eventData, {now});
    eventsProcessed += 1;
    // Prefer full pin delete by eventId so concurrent rematerialize stays clean.
    await deleteEventMapPins(db, eventId);
    pinsDeleted += pinDocs.length;
  }

  return {
    scanned: snap.size,
    eventsProcessed,
    pinsDeleted,
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
  const actor = await resolvePhotoAddedActor(db, logData);
  const actorProfile = actor.userId ?
    await loadActorProfile(db, actor.userId) :
    {};
  const activity = buildSpotPhotoAddedActivity(auditLogId, logData, spotData, {
    now: options.now,
    actor,
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

  const imageUrls = normalizeUrlList(data.imageUrls);
  const photoCount = typeof data.photoCount === "number" && data.photoCount > 0 ?
    Math.floor(data.photoCount) :
    null;

  if (kind === KIND_EVENT_ENDED) {
    const eventId = trimmedString(data.eventId);
    const title = trimmedString(data.title);
    const startAt = toIso(data.startAt);
    if (!eventId || !title || !startAt) return null;
    const pinKind = data.pinKind === "spot" ? "spot" : "venue";
    return withoutNulls({
      id: docId,
      kind,
      timeline,
      eventId,
      title,
      pinKind,
      latitude: data.latitude,
      longitude: data.longitude,
      occurredAt,
      startAt,
      endAt: toIso(data.endAt),
      isDateOnly: data.isDateOnly === true ? true : null,
      timeZone: trimmedString(data.timeZone),
      description: trimmedString(data.description),
      spotId: trimmedString(data.spotId),
      spotName: trimmedString(data.spotName),
      city: trimmedString(data.city),
      countryCode: trimmedString(data.countryCode),
      imageUrls: imageUrls.length > 0 ? imageUrls : null,
      goingCount: typeof data.goingCount === "number" ?
        Math.max(0, Math.floor(data.goingCount)) :
        null,
      interestedCount: typeof data.interestedCount === "number" ?
        Math.max(0, Math.floor(data.interestedCount)) :
        null,
    });
  }

  const spotId = trimmedString(data.spotId);
  if (!spotId) return null;

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
 * @param {*} value
 * @param {boolean} fallback
 * @return {boolean}
 */
function clampBool(value, fallback) {
  if (typeof value === "boolean") return value;
  return fallback;
}

/**
 * Optional Explore kind lens: validated unique Firestore `kind` strings, or
 * null when the client wants every kind (All).
 * @param {*} raw
 * @return {string[]|null}
 */
function parseKindsFilter(raw) {
  if (!Array.isArray(raw)) return null;
  const kinds = [];
  const seen = new Set();
  for (const value of raw) {
    if (typeof value !== "string" || !ALL_ACTIVITY_KINDS.has(value)) continue;
    if (seen.has(value)) continue;
    seen.add(value);
    kinds.push(value);
  }
  return kinds.length > 0 ? kinds : null;
}

/**
 * @param {FirebaseFirestore.Query} query
 * @param {string[]|null|undefined} kinds
 * @return {FirebaseFirestore.Query}
 */
function applyKindFilter(query, kinds) {
  if (!Array.isArray(kinds) || kinds.length === 0) return query;
  if (kinds.length === 1) {
    return query.where("kind", "==", kinds[0]);
  }
  return query.where("kind", "in", kinds);
}

/**
 * Past activity filters (no order/limit).
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} bounds
 * @param {string[]=} kinds optional kind equality / in-filter
 * @return {FirebaseFirestore.Query}
 */
function buildPastActivityBaseQuery(db, bounds, kinds) {
  return applyKindFilter(
      db.collection(COMMUNITY_ACTIVITY_COLLECTION)
          .where("timeline", "==", TIMELINE_PAST)
          .where("latitude", ">=", bounds.minLat)
          .where("latitude", "<=", bounds.maxLat)
          .where("longitude", ">=", bounds.minLng)
          .where("longitude", "<=", bounds.maxLng),
      kinds,
  );
}

/**
 * Past activity ordered for the existing composite index
 * (timeline, occurredAt DESC, latitude DESC, longitude DESC). Also used for
 * count() so aggregates reuse that index instead of a bare lat/lng range.
 * When [kinds] is set, uses the kind-aware composite instead.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} bounds
 * @param {string[]=} kinds
 * @return {FirebaseFirestore.Query}
 */
function buildPastActivityOrderedQuery(db, bounds, kinds) {
  return buildPastActivityBaseQuery(db, bounds, kinds)
      .orderBy("occurredAt", "desc")
      .orderBy("latitude", "desc")
      .orderBy("longitude", "desc");
}

/**
 * Past activity, newest first.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} bounds
 * @param {number} limit
 * @param {Object=} cursor {occurredAt, latitude, longitude}
 * @param {string[]=} kinds
 * @return {FirebaseFirestore.Query}
 */
function buildPastActivityQuery(db, bounds, limit, cursor, kinds) {
  let query = buildPastActivityOrderedQuery(db, bounds, kinds);
  if (cursor && cursor.occurredAt) {
    const occurredAt = normalizeDate(cursor.occurredAt) || cursor.occurredAt;
    query = query.startAfter(
        occurredAt,
        cursor.latitude,
        cursor.longitude,
    );
  }
  return query.limit(limit);
}

/**
 * Upcoming activity filters (no order/limit).
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} bounds
 * @param {Date} now
 * @param {string[]=} kinds
 * @return {FirebaseFirestore.Query}
 */
function buildUpcomingActivityBaseQuery(db, bounds, now, kinds) {
  return applyKindFilter(
      db.collection(COMMUNITY_ACTIVITY_COLLECTION)
          .where("timeline", "==", TIMELINE_UPCOMING)
          .where("endAt", ">=", now)
          .where("latitude", ">=", bounds.minLat)
          .where("latitude", "<=", bounds.maxLat)
          .where("longitude", ">=", bounds.minLng)
          .where("longitude", "<=", bounds.maxLng),
      kinds,
  );
}

/**
 * Upcoming activity ordered for the existing composite index
 * (timeline, startAt ASC, endAt ASC, latitude ASC, longitude ASC).
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} bounds
 * @param {Date} now
 * @param {string[]=} kinds
 * @return {FirebaseFirestore.Query}
 */
function buildUpcomingActivityOrderedQuery(db, bounds, now, kinds) {
  return buildUpcomingActivityBaseQuery(db, bounds, now, kinds)
      .orderBy("startAt", "asc")
      .orderBy("endAt", "asc")
      .orderBy("latitude", "asc")
      .orderBy("longitude", "asc");
}

/**
 * Upcoming activity that has not ended, soonest first.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} bounds
 * @param {Date} now
 * @param {number} limit
 * @param {Object=} cursor {startAt, endAt, latitude, longitude}
 * @param {string[]=} kinds
 * @return {FirebaseFirestore.Query}
 */
function buildUpcomingActivityQuery(db, bounds, now, limit, cursor, kinds) {
  let query = buildUpcomingActivityOrderedQuery(db, bounds, now, kinds);
  if (cursor && cursor.startAt) {
    const startAt = normalizeDate(cursor.startAt) || cursor.startAt;
    const endAt = cursor.endAt != null ?
      (normalizeDate(cursor.endAt) || cursor.endAt) :
      startAt;
    query = query.startAfter(
        startAt,
        endAt,
        cursor.latitude,
        cursor.longitude,
    );
  }
  return query.limit(limit);
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
 * Loads Going / Interested totals for the given event ids.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string[]} eventIds
 * @return {Promise<Map<string, {goingCount: number, interestedCount: number}>>}
 */
async function loadEventInterestStatsById(db, eventIds) {
  const statsByEventId = new Map();
  const uniqueIds = [...new Set(
      eventIds.filter((id) => typeof id === "string" && id.length > 0),
  )];
  for (let i = 0; i < uniqueIds.length; i += GET_ALL_CHUNK) {
    const chunk = uniqueIds.slice(i, i + GET_ALL_CHUNK);
    const refs = chunk.map((eventId) =>
      db.collection("eventInterestStats").doc(eventId));
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
  return statsByEventId;
}

/**
 * Public Going / Interested totals for event pins.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Array<Object>} pins deduped event pins
 * @return {Promise<Array<Object>>}
 */
async function attachEventInterestCounts(db, pins) {
  if (!Array.isArray(pins) || pins.length === 0) return [];
  const statsByEventId = await loadEventInterestStatsById(
      db,
      pins.map((pin) => pin.eventId),
  );
  return pins.map((pin) => {
    const stats = statsByEventId.get(pin.eventId) ||
      {goingCount: 0, interestedCount: 0};
    return {...pin, ...stats};
  });
}

/**
 * Attach interest totals onto past `event_ended` activity rows.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Array<Object>} pastItems
 * @return {Promise<Array<Object>>}
 */
async function attachPastEventInterestCounts(db, pastItems) {
  if (!Array.isArray(pastItems) || pastItems.length === 0) return pastItems;
  const ended = pastItems.filter((item) => item.kind === KIND_EVENT_ENDED);
  if (ended.length === 0) return pastItems;
  const statsByEventId = await loadEventInterestStatsById(
      db,
      ended.map((item) => item.eventId),
  );
  return pastItems.map((item) => {
    if (item.kind !== KIND_EVENT_ENDED) return item;
    const stats = statsByEventId.get(item.eventId) ||
      {goingCount: 0, interestedCount: 0};
    return {...item, ...stats};
  });
}

/**
 * @param {Array<{docs: Array}>} snaps
 * @return {Array<Object>}
 */
function mapActivitySnaps(snaps) {
  const items = [];
  const seen = new Set();
  for (const snap of snaps) {
    for (const doc of snap.docs) {
      if (seen.has(doc.id)) continue;
      seen.add(doc.id);
      const normalized = normalizeCommunityActivity(doc.id, doc.data());
      if (normalized) items.push(normalized);
    }
  }
  return items;
}

/**
 * Sum .count() across longitude segments for a base query builder.
 * @param {Array<{minLng: number, maxLng: number}>} segments
 * @param {function(Object): FirebaseFirestore.Query} buildQuery
 * @return {Promise<number>}
 */
async function sumSegmentCounts(segments, buildQuery) {
  const snaps = await Promise.all(segments.map(async (segment) => {
    const query = buildQuery(segment);
    const aggregate = await query.count().get();
    return aggregate.data().count || 0;
  }));
  return snaps.reduce((sum, n) => sum + n, 0);
}

/**
 * @param {Object} item normalized past activity
 * @return {Object}
 */
function pastCursorFromItem(item) {
  return {
    occurredAt: item.occurredAt,
    latitude: item.latitude,
    longitude: item.longitude,
    id: item.id,
  };
}

/**
 * @param {Object} item normalized upcoming plan
 * @return {Object}
 */
function upcomingCursorFromItem(item) {
  return {
    startAt: item.startAt,
    endAt: item.endAt || item.startAt,
    latitude: item.latitude,
    longitude: item.longitude,
    id: item.id,
  };
}

/**
 * @param {Object} pin event pin
 * @return {Object}
 */
function eventCursorFromPin(pin) {
  return {
    startAt: pin.startAt,
    eventId: pin.eventId,
  };
}

/**
 * Fetch a past page across longitude segments (newest first).
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} bounds
 * @param {Array} segments
 * @param {number} limit
 * @param {Object=} cursor
 * @param {string[]=} kinds
 * @return {Promise<{items: Array, hasMore: boolean}>}
 */
async function fetchPastActivityPage(
    db, bounds, segments, limit, cursor, kinds,
) {
  const fetchLimit = limit + 1;
  const snaps = await Promise.all(segments.map((segment) =>
    buildPastActivityQuery(db, {
      minLat: bounds.minLat,
      maxLat: bounds.maxLat,
      minLng: segment.minLng,
      maxLng: segment.maxLng,
    }, fetchLimit, cursor, kinds).get()));
  const merged = sortByIsoField(mapActivitySnaps(snaps), "occurredAt", "desc");
  const hasMore = merged.length > limit;
  return {items: merged.slice(0, limit), hasMore};
}

/**
 * Fetch an upcoming plans page across longitude segments (soonest first).
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} bounds
 * @param {Array} segments
 * @param {Date} now
 * @param {number} limit
 * @param {Object=} cursor
 * @param {string[]=} kinds
 * @return {Promise<{items: Array, hasMore: boolean}>}
 */
async function fetchUpcomingPlansPage(
    db, bounds, segments, now, limit, cursor, kinds,
) {
  if (Array.isArray(kinds) && kinds.length === 0) {
    return {items: [], hasMore: false};
  }
  const fetchLimit = limit + 1;
  const snaps = await Promise.all(segments.map((segment) =>
    buildUpcomingActivityQuery(db, {
      minLat: bounds.minLat,
      maxLat: bounds.maxLat,
      minLng: segment.minLng,
      maxLng: segment.maxLng,
    }, now, fetchLimit, cursor, kinds).get()));
  const merged = sortByIsoField(mapActivitySnaps(snaps), "startAt", "asc")
      .filter((item) => !item.endAt || new Date(item.endAt).getTime() >= now.getTime());
  const hasMore = merged.length > limit;
  return {items: merged.slice(0, limit), hasMore};
}

/**
 * Merge plans + events into one soonest-first page and advance source cursors.
 * @param {Array<Object>} plans
 * @param {boolean} plansHasMore
 * @param {Array<Object>} events
 * @param {boolean} eventsHasMore
 * @param {number} pageSize
 * @param {Object=} prevUpcomingCursor
 * @param {Object=} prevEventCursor
 * @return {Object}
 */
function mergeUpcomingPage(
    plans,
    plansHasMore,
    events,
    eventsHasMore,
    pageSize,
    prevUpcomingCursor,
    prevEventCursor,
) {
  const planEntries = plans.map((item) => ({type: "plan", item, startAt: item.startAt, id: item.id}));
  const eventEntries = events.map((pin) => ({
    type: "event",
    item: pin,
    startAt: pin.startAt,
    id: pin.eventId,
  }));
  const merged = [...planEntries, ...eventEntries].sort((a, b) => {
    const ta = new Date(a.startAt).getTime();
    const tb = new Date(b.startAt).getTime();
    if (ta !== tb) return ta - tb;
    return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
  });

  const page = merged.slice(0, pageSize);
  const upcoming = [];
  const pageEvents = [];
  let upcomingCursor = prevUpcomingCursor || null;
  let eventCursor = prevEventCursor || null;
  let consumedPlan = false;
  let consumedEvent = false;

  for (const entry of page) {
    if (entry.type === "plan") {
      upcoming.push(entry.item);
      upcomingCursor = upcomingCursorFromItem(entry.item);
      consumedPlan = true;
    } else {
      pageEvents.push(entry.item);
      eventCursor = eventCursorFromPin(entry.item);
      consumedEvent = true;
    }
  }

  const unconsumed = merged.length > page.length;
  const hasMoreUpcoming = unconsumed ||
    (consumedPlan && plansHasMore) ||
    (consumedEvent && eventsHasMore) ||
    (!consumedPlan && plansHasMore) ||
    (!consumedEvent && eventsHasMore);

  return {
    upcoming,
    events: pageEvents,
    upcomingCursor: upcoming.length > 0 || consumedPlan ?
      upcomingCursor :
      prevUpcomingCursor || null,
    eventCursor: pageEvents.length > 0 || consumedEvent ?
      eventCursor :
      prevEventCursor || null,
    hasMoreUpcoming,
  };
}

/**
 * Community stream for a viewport: past activity (newest first), then
 * upcoming training plans and events (soonest first).
 *
 * Supports totals (Firestore count aggregates) and cursor paging:
 * - Initial: pastLimit default 10, upcoming page default 10, includeCounts true
 * - Load more past: fetchPast true, pastCursor, pastLimit default 10
 * - Load more upcoming: fetchUpcoming true, upcoming/event cursors
 *
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} params minLat, maxLat, minLng, maxLng, pastLimit?,
 *   upcomingLimit?, upcomingPageSize?, eventLimit?, includeCounts?,
 *   fetchPast?, fetchUpcoming?, pastCursor?, upcomingCursor?, eventCursor?,
 *   kinds? (Firestore kind strings; omit for All), includeEvents?
 * @param {Object=} options
 * @param {Date=} options.now
 * @param {Function=} options.eventsInBounds legacy override returning {pins}
 * @param {Function=} options.pageEvents override for paged event pins
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
  const bounds = {minLat, maxLat, minLng, maxLng};
  const segments = longitudeSegments(minLng, maxLng);

  const includeCounts = clampBool(params.includeCounts, true);
  const fetchPast = clampBool(params.fetchPast, true);
  const fetchUpcoming = clampBool(params.fetchUpcoming, true);

  const kindsFilter = parseKindsFilter(params.kinds);
  const pastKinds = kindsFilter ?
    kindsFilter.filter((kind) => PAST_ACTIVITY_KINDS.has(kind)) :
    null;
  const upcomingKinds = kindsFilter ?
    kindsFilter.filter((kind) => UPCOMING_ACTIVITY_KINDS.has(kind)) :
    null;
  // Area totals stay unfiltered so the Explore header count stays stable.
  // Upcoming event pins are included for All, or when the Events lens asks
  // for event_ended (past events + live/upcoming pins share that lens).
  const includeEvents = kindsFilter == null ?
    clampBool(params.includeEvents, true) :
    (kindsFilter.includes(KIND_EVENT_ENDED) || params.includeEvents === true);

  const pastLimit = clampLimit(
      params.pastLimit,
      params.pastCursor ? PAST_PAGE_DEFAULT : PAST_INITIAL_DEFAULT,
  );
  const upcomingPageSize = clampLimit(
      params.upcomingPageSize ?? params.upcomingLimit ?? params.eventLimit,
      UPCOMING_PAGE_DEFAULT,
  );

  const pastCursor = params.pastCursor && typeof params.pastCursor === "object" ?
    params.pastCursor :
    null;
  const upcomingCursor = params.upcomingCursor &&
    typeof params.upcomingCursor === "object" ?
    params.upcomingCursor :
    null;
  const eventCursor = params.eventCursor && typeof params.eventCursor === "object" ?
    params.eventCursor :
    null;

  // pastTotal / upcomingPlanTotal follow the active kinds lens so "Show N
  // earlier" is honest. totalCount stays area-wide for the Explore header.
  let pastTotal = 0;
  let upcomingPlanTotal = 0;
  let eventTotal = 0;
  let areaPastTotal = 0;
  let areaUpcomingPlanTotal = 0;
  let areaEventTotal = 0;

  if (includeCounts) {
    // count() must use the same orderBy as page queries so Firestore can use
    // the existing communityActivity composites (not a bare lat/lng range).
    areaPastTotal = await sumSegmentCounts(segments, (segment) =>
      buildPastActivityOrderedQuery(db, {
        minLat,
        maxLat,
        minLng: segment.minLng,
        maxLng: segment.maxLng,
      }));
    areaUpcomingPlanTotal = await sumSegmentCounts(segments, (segment) =>
      buildUpcomingActivityOrderedQuery(db, {
        minLat,
        maxLat,
        minLng: segment.minLng,
        maxLng: segment.maxLng,
      }, now));

    if (pastKinds == null) {
      pastTotal = areaPastTotal;
    } else if (pastKinds.length === 0) {
      pastTotal = 0;
    } else {
      pastTotal = await sumSegmentCounts(segments, (segment) =>
        buildPastActivityOrderedQuery(db, {
          minLat,
          maxLat,
          minLng: segment.minLng,
          maxLng: segment.maxLng,
        }, pastKinds));
    }

    if (upcomingKinds == null) {
      upcomingPlanTotal = areaUpcomingPlanTotal;
    } else if (upcomingKinds.length === 0) {
      upcomingPlanTotal = 0;
    } else {
      upcomingPlanTotal = await sumSegmentCounts(segments, (segment) =>
        buildUpcomingActivityOrderedQuery(db, {
          minLat,
          maxLat,
          minLng: segment.minLng,
          maxLng: segment.maxLng,
        }, now, upcomingKinds));
    }
  }

  let past = [];
  let hasMorePast = false;
  let nextPastCursor = null;
  const shouldFetchPast = fetchPast &&
    (pastKinds == null || pastKinds.length > 0);
  if (shouldFetchPast) {
    const pastPage = await fetchPastActivityPage(
        db, bounds, segments, pastLimit, pastCursor, pastKinds || undefined);
    past = await attachPastEventInterestCounts(db, pastPage.items);
    hasMorePast = pastPage.hasMore;
    if (past.length > 0) {
      nextPastCursor = pastCursorFromItem(past[past.length - 1]);
    }
  }

  let upcoming = [];
  let events = [];
  let hasMoreUpcoming = false;
  let nextUpcomingCursor = upcomingCursor;
  let nextEventCursor = eventCursor;

  if (fetchUpcoming) {
    const plansPage = await fetchUpcomingPlansPage(
        db,
        bounds,
        segments,
        now,
        upcomingPageSize,
        upcomingCursor,
        upcomingKinds == null ? undefined : upcomingKinds,
    );

    let eventPins = [];
    let eventsSourceHasMore = false;
    try {
      const pageEvents = options.pageEvents ||
        ((queryParams) => pageEventPinsInBounds(db, queryParams, {
          now,
          listPins: options.listEventPins,
        }));
      // Legacy test hook: eventsInBounds returns {pins} for the whole viewport.
      if (options.eventsInBounds && !options.pageEvents) {
        const eventsResult = await options.eventsInBounds({
          minLat,
          maxLat,
          minLng,
          maxLng,
          limit: 200,
        });
        const pins = Array.isArray(eventsResult && eventsResult.pins) ?
          eventsResult.pins :
          [];
        let sorted = dedupePinsByEventId(pins);
        if (includeCounts) {
          areaEventTotal = sorted.length;
          // Event-pin total is only lens-scoped when the Events lens is on;
          // Sessions/Contributions keep 0 here so page math stays clean.
          eventTotal = includeEvents ? areaEventTotal : 0;
        }
        if (includeEvents) {
          if (eventCursor && eventCursor.startAt) {
            const afterMs = new Date(eventCursor.startAt).getTime();
            const afterId = eventCursor.eventId || "";
            sorted = sorted.filter((pin) => {
              const startMs = new Date(pin.startAt).getTime();
              if (startMs > afterMs) return true;
              if (startMs < afterMs) return false;
              return pin.eventId > afterId;
            });
          }
          eventsSourceHasMore = sorted.length > upcomingPageSize;
          eventPins = sorted.slice(0, upcomingPageSize);
        }
      } else if (includeEvents || includeCounts) {
        const paged = await pageEvents({
          minLat,
          maxLat,
          minLng,
          maxLng,
          limit: includeEvents ? upcomingPageSize : 1,
          afterStartAt: includeEvents && eventCursor ?
            eventCursor.startAt :
            undefined,
          afterEventId: includeEvents && eventCursor ?
            eventCursor.eventId :
            undefined,
        });
        if (includeEvents) {
          eventPins = Array.isArray(paged.pins) ? paged.pins : [];
          eventsSourceHasMore = paged.hasMore === true;
        }
        if (includeCounts && typeof paged.eventTotal === "number") {
          areaEventTotal = paged.eventTotal;
          eventTotal = includeEvents ? areaEventTotal : 0;
        }
      }
    } catch (err) {
      console.error("communityActivity events merge failed", err);
      eventPins = [];
      eventsSourceHasMore = false;
    }

    const enrichedEvents = await attachEventInterestCounts(db, eventPins);
    const merged = mergeUpcomingPage(
        plansPage.items,
        plansPage.hasMore,
        enrichedEvents,
        eventsSourceHasMore,
        upcomingPageSize,
        upcomingCursor,
        eventCursor,
    );
    upcoming = merged.upcoming;
    events = merged.events;
    hasMoreUpcoming = merged.hasMoreUpcoming;
    nextUpcomingCursor = merged.upcomingCursor;
    nextEventCursor = merged.eventCursor;
  }

  const totalCount = includeCounts ?
    areaPastTotal + areaUpcomingPlanTotal + areaEventTotal :
    null;

  return {
    success: true,
    past,
    upcoming,
    events,
    pastCount: past.length,
    upcomingCount: upcoming.length,
    eventCount: events.length,
    pastTotal: includeCounts ? pastTotal : null,
    upcomingPlanTotal: includeCounts ? upcomingPlanTotal : null,
    eventTotal: includeCounts ? eventTotal : null,
    totalCount,
    hasMorePast,
    hasMoreUpcoming,
    pastCursor: hasMorePast ? nextPastCursor : null,
    upcomingCursor: hasMoreUpcoming ? nextUpcomingCursor : null,
    eventCursor: hasMoreUpcoming ? nextEventCursor : null,
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
    eventsEnded: 0,
    scanned: {spots: 0, auditLogs: 0, checkIns: 0, trainingPlans: 0, events: 0},
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
      const actor = await resolvePhotoAddedActor(db, data);
      const actorProfile = actor.userId ? await profileLoader(actor.userId) : {};
      const activity = buildSpotPhotoAddedActivity(doc.id, data, spotData, {
        now,
        actor,
        actorProfile,
      });
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

  // Events that started within the retention window (covers ended events with
  // or without endAt). Filter to past + eligible in memory.
  const eventsSnap = await db.collection("events")
      .where("startAt", ">=", since)
      .get();
  for (const doc of eventsSnap.docs) {
    result.scanned.events += 1;
    const data = doc.data() || {};
    const syncResult = await syncEventEndedActivity(db, doc.id, data, {now});
    if (syncResult.written) result.eventsEnded += 1;
  }

  return result;
}

module.exports = {
  COMMUNITY_ACTIVITY_COLLECTION,
  KIND_SPOT_ADDED,
  KIND_SPOT_PHOTO_ADDED,
  KIND_SPOT_CHECK_IN,
  KIND_SPOT_TRAINING_PLAN,
  KIND_EVENT_ENDED,
  TIMELINE_PAST,
  TIMELINE_UPCOMING,
  PAST_ACTIVITY_RETENTION_MS,
  PAST_INITIAL_DEFAULT,
  PAST_PAGE_DEFAULT,
  UPCOMING_PAGE_DEFAULT,
  spotAddedActivityId,
  spotPhotoActivityId,
  checkInActivityId,
  trainingPlanActivityId,
  eventEndedActivityId,
  isSpotEligibleForCommunityActivity,
  isCheckInEligibleForCommunityActivity,
  isTrainingPlanEligibleForCommunityActivity,
  isEventEligibleForEndedActivity,
  locationFromEventResolvedOrVenue,
  addedImageUrlsFromAuditLog,
  actorFromAuditLog,
  resolvePhotoAddedActor,
  isAnonymousContributorUserId,
  buildSpotAddedActivity,
  buildSpotPhotoAddedActivity,
  buildSpotCheckInActivity,
  buildSpotTrainingPlanActivity,
  buildEventEndedActivity,
  loadActorProfile,
  syncSpotAddedActivity,
  syncSpotPhotoAddedActivity,
  syncSpotCheckInActivity,
  syncSpotTrainingPlanActivity,
  syncEventEndedActivity,
  syncCommunityActivityForSpotChange,
  sweepPastEventMapPinsForCommunityActivity,
  deleteCommunityActivityForSpot,
  normalizeCommunityActivity,
  longitudeSegments,
  buildPastActivityQuery,
  buildUpcomingActivityQuery,
  buildPastActivityBaseQuery,
  buildUpcomingActivityBaseQuery,
  parseKindsFilter,
  applyKindFilter,
  attachEventInterestCounts,
  attachPastEventInterestCounts,
  executeCommunityActivityInBoundsQuery,
  backfillCommunityActivity,
};
