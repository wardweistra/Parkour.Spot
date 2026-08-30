/* eslint-disable max-len */
/**
 * Fan-out in-app notifications when a community event becomes visible near
 * users' enabled locations of interest (native create, or sync after review).
 */

const {
  findUserIdsNearPoint,
  filterUserIdsByFlag,
} = require("./nearby-audience");
const {
  isEventPast,
  loadEventMainCoordinates,
} = require("./event-map-pins");
const {deliverNotifications} = require("./deliver-notification");
const EXTERNAL_EVENT_SYNC_CREATED_BY = "external-event-sync";

/** @type {string} Stable id for client-side localization */
const NOTIFICATION_KIND_NEARBY_NEW_EVENT = "nearby_new_event";

/**
 * @param {object} eventData
 * @return {boolean}
 */
function isNativeEvent(eventData) {
  if (!eventData) {
    return false;
  }
  const sourceId = eventData.eventSourceId;
  return typeof sourceId !== "string" || sourceId.trim() === "";
}

/**
 * @param {object} eventData
 * @return {boolean}
 */
function hasDuplicateOf(eventData) {
  const duplicateOf = eventData && eventData.duplicateOf;
  return typeof duplicateOf === "string" && duplicateOf.trim().length > 0;
}

/**
 * Hidden, duplicate, or past events are not shown on the map.
 * @param {object} eventData
 * @param {Date=} now
 * @return {boolean}
 */
function isEventVisuallyEligible(eventData, now) {
  if (!eventData) {
    return false;
  }
  if (eventData.hidden === true) {
    return false;
  }
  if (hasDuplicateOf(eventData)) {
    return false;
  }
  if (isEventPast(eventData, now)) {
    return false;
  }
  return true;
}

/**
 * Native create (not Create Native), or needsModeratorReview true → false.
 * @param {object} options
 * @param {object|null|undefined} options.beforeData
 * @param {object} options.afterData
 * @param {Date=} options.now
 * @return {boolean}
 */
function shouldFanOutNearbyNewEventNotifications({
  beforeData,
  afterData,
  now,
} = {}) {
  if (!isEventVisuallyEligible(afterData, now)) {
    return false;
  }
  if (afterData.createdFromCreateNative === true) {
    return false;
  }
  const isCreate = beforeData == null;
  if (isCreate && isNativeEvent(afterData)) {
    return true;
  }
  if (!isCreate &&
      beforeData.needsModeratorReview === true &&
      afterData.needsModeratorReview === false) {
    return true;
  }
  return false;
}

/**
 * @param {object} eventData
 * @return {{eventName: string}}
 */
function buildTemplateArgs(eventData) {
  const eventName = typeof eventData.title === "string" ?
    eventData.title.trim() :
    "";
  return {eventName};
}

/**
 * @param {object} eventData
 * @return {string}
 */
function excludeUserIdFromEvent(eventData) {
  const createdBy = typeof eventData.createdBy === "string" ?
    eventData.createdBy.trim() :
    "";
  if (!createdBy || createdBy === EXTERNAL_EVENT_SYNC_CREATED_BY) {
    return "";
  }
  return createdBy;
}

/**
 * Writes per-user notifications for a newly visible community event.
 * @param {object} options
 * @param {object} options.db Firestore instance
 * @param {object} options.FieldValue admin FieldValue
 * @param {string} options.eventId
 * @param {object|null|undefined} options.beforeData
 * @param {object} options.eventData after snapshot fields
 * @param {Date=} options.now
 * @return {Promise<Object>} result with skipped or notified count
 */
async function fanOutNearbyNewEventNotifications({
  db,
  FieldValue,
  eventId,
  beforeData,
  eventData,
  now,
}) {
  if (!shouldFanOutNearbyNewEventNotifications({
    beforeData,
    afterData: eventData,
    now,
  })) {
    console.log("Nearby new-event notifications skipped:", {
      eventId,
      reason: "event not eligible (not native create / create native / not newly reviewed / hidden / duplicate / past)",
    });
    return {skipped: true};
  }

  const coords = await loadEventMainCoordinates(db, eventData);
  if (!coords) {
    console.log("Nearby new-event notifications skipped:", {
      eventId,
      reason: "no resolvable main coordinates",
    });
    return {skipped: true};
  }

  const {latitude: lat, longitude: lng} = coords;
  const excludeUserId = excludeUserIdFromEvent(eventData);
  console.log("Event visible, checking nearby locationsOfInterest:", {
    eventId,
    latitude: lat,
    longitude: lng,
  });

  const {userIds, matchedLocationCount} = await findUserIdsNearPoint({
    db,
    lat,
    lng,
    excludeUserId,
  });
  const usersToNotify = await filterUserIdsByFlag(
      db, userIds, "notifyEventsNearby",
  );
  console.log("Found locationsOfInterest and resolved notification audience:", {
    eventId,
    locationsOfInterestCount: matchedLocationCount,
    candidateUserCount: userIds.length,
    usersToNotifyCount: usersToNotify.length,
    usersToNotify,
  });
  if (usersToNotify.length === 0) {
    return {notified: 0};
  }

  const templateArgs = buildTemplateArgs(eventData);
  await deliverNotifications({
    db,
    FieldValue,
    userIds: usersToNotify,
    payload: {
      notificationKind: NOTIFICATION_KIND_NEARBY_NEW_EVENT,
      templateArgs,
      deeplinkKind: "event",
      deeplinkId: eventId,
    },
  });

  console.log("Nearby new-event notifications:", {
    eventId,
    candidateCount: userIds.length,
    notified: usersToNotify.length,
  });

  return {notified: usersToNotify.length};
}

module.exports = {
  fanOutNearbyNewEventNotifications,
  shouldFanOutNearbyNewEventNotifications,
  isNativeEvent,
  isEventVisuallyEligible,
  buildTemplateArgs,
  excludeUserIdFromEvent,
  EXTERNAL_EVENT_SYNC_CREATED_BY,
  NOTIFICATION_KIND_NEARBY_NEW_EVENT,
};
