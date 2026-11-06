/* eslint-disable max-len */
/**
 * Denormalized Going / Interested totals and public people roster for events.
 * Source of truth remains `users/{userId}/eventInterests/{eventId}`.
 *
 * Totals for an event include RSVPs on that event and on any events marked as
 * duplicates of it (`duplicateOf == eventId`), matching how spot ratings roll
 * up to the native spot. The same user is counted once; Going wins over
 * Interested when they marked both listings.
 *
 * Public roster: `eventInterestStats/{eventId}/people/{userId}` with status and
 * denormalized profile fields (Cloud Functions only).
 */

const {FieldValue} = require("firebase-admin/firestore");

const STATUSES = Object.freeze(["going", "interested"]);
const IN_QUERY_LIMIT = 30;
const BATCH_LIMIT = 400;

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
 * Public profile fields for the people roster (same rules as community activity
 * actors: private profiles keep displayName, clear photoURL).
 * @param {Object} db Firestore instance
 * @param {string|null} userId
 * @return {Promise<{displayName: ?string, photoURL: ?string}>}
 */
async function loadInterestPersonProfile(db, userId) {
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
    console.warn("eventInterest.loadInterestPersonProfile failed", {
      userId: trimmed,
      err,
    });
    return {displayName: null, photoURL: null};
  }
}

/**
 * @param {*} value
 * @return {"going"|"interested"|null}
 */
function normalizeInterestStatus(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return STATUSES.includes(trimmed) ? trimmed : null;
}

/**
 * @param {Object|null|undefined} data
 * @return {string|null}
 */
function normalizeDuplicateOf(data) {
  if (!data || typeof data.duplicateOf !== "string") return null;
  const trimmed = data.duplicateOf.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * @param {Object|null|undefined} data
 * @param {string|undefined} fallbackEventId
 * @return {string|null}
 */
function eventIdFromInterest(data, fallbackEventId) {
  if (typeof fallbackEventId === "string" && fallbackEventId.trim()) {
    return fallbackEventId.trim();
  }
  if (!data || typeof data.eventId !== "string") return null;
  const trimmed = data.eventId.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * Count deltas to apply when an interest doc is created, updated, or deleted.
 * @param {Object|null|undefined} beforeData
 * @param {Object|null|undefined} afterData
 * @return {{goingCount: number, interestedCount: number}|null}
 */
function interestCountDeltas(beforeData, afterData) {
  const beforeStatus = beforeData ?
    normalizeInterestStatus(beforeData.status) :
    null;
  const afterStatus = afterData ?
    normalizeInterestStatus(afterData.status) :
    null;
  if (beforeStatus === afterStatus) return null;
  const deltas = {goingCount: 0, interestedCount: 0};
  if (beforeStatus) deltas[`${beforeStatus}Count`] -= 1;
  if (afterStatus) deltas[`${afterStatus}Count`] += 1;
  return deltas;
}

/**
 * @param {Object} stats
 * @param {{goingCount: number, interestedCount: number}} deltas
 * @return {{goingCount: number, interestedCount: number}}
 */
function applyInterestCountDeltas(stats, deltas) {
  const going = Number(stats && stats.goingCount) || 0;
  const interested = Number(stats && stats.interestedCount) || 0;
  return {
    goingCount: Math.max(0, going + (deltas.goingCount || 0)),
    interestedCount: Math.max(0, interested + (deltas.interestedCount || 0)),
  };
}

/**
 * Event IDs whose Going / Interested totals should be recomputed after a
 * duplicateOf change (or deletion).
 * @param {string} eventId
 * @param {Object|null|undefined} beforeData
 * @param {Object|null|undefined} afterData null when the event was deleted
 * @return {string[]}
 */
function idsToRecomputeForDuplicateOfChange(eventId, beforeData, afterData) {
  const beforeDup = normalizeDuplicateOf(beforeData);
  const afterDup = afterData ? normalizeDuplicateOf(afterData) : null;
  const eventDeleted = !afterData;
  if (beforeDup === afterDup && !eventDeleted) return [];
  const ids = new Set();
  if (eventId && !eventDeleted) ids.add(eventId);
  if (beforeDup) ids.add(beforeDup);
  if (afterDup) ids.add(afterDup);
  return [...ids];
}

/**
 * @param {Object} doc Firestore document snapshot
 * @return {string|null}
 */
function userIdFromInterestDoc(doc) {
  const data = typeof doc.data === "function" ? (doc.data() || {}) : (doc || {});
  if (typeof data.userId === "string" && data.userId.trim()) {
    return data.userId.trim();
  }
  const parent = doc && doc.ref && doc.ref.parent && doc.ref.parent.parent;
  const id = parent && parent.id;
  return typeof id === "string" && id.trim() ? id.trim() : null;
}

/**
 * @param {*} value
 * @return {number} millis, or 0 when unknown
 */
function timestampMillis(value) {
  if (!value) return 0;
  if (typeof value.toMillis === "function") return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  if (typeof value.seconds === "number") {
    return (value.seconds * 1000) + Math.floor((value.nanoseconds || 0) / 1e6);
  }
  return 0;
}

/**
 * Unique-by-user status map. Going wins when the same user marked both on
 * native and duplicate listings.
 * @param {Array<Object>} interestDocs
 * @return {Map<string, {status: string, updatedAt: (Object|null)}>}
 */
function aggregateInterestByUser(interestDocs) {
  const byUser = new Map();
  const docs = Array.isArray(interestDocs) ? interestDocs : [];
  for (const doc of docs) {
    const data = typeof doc.data === "function" ? (doc.data() || {}) : (doc || {});
    const status = normalizeInterestStatus(data.status);
    if (!status) continue;
    const userId = userIdFromInterestDoc(doc) ||
      (typeof data.userId === "string" ? data.userId.trim() : "");
    if (!userId) continue;
    const updatedAt = data.updatedAt || data.createdAt || null;
    const prev = byUser.get(userId);
    if (!prev) {
      byUser.set(userId, {status, updatedAt});
      continue;
    }
    if (prev.status === "going") {
      if (status === "going" &&
          timestampMillis(updatedAt) > timestampMillis(prev.updatedAt)) {
        byUser.set(userId, {status: "going", updatedAt});
      }
      continue;
    }
    if (status === "going") {
      byUser.set(userId, {status, updatedAt});
      continue;
    }
    if (timestampMillis(updatedAt) > timestampMillis(prev.updatedAt)) {
      byUser.set(userId, {status, updatedAt});
    }
  }
  return byUser;
}

/**
 * Unique-by-user Going / Interested counts. Going wins when the same user
 * marked both on native and duplicate listings.
 * @param {Array<Object>} interestDocs
 * @return {{goingCount: number, interestedCount: number}}
 */
function aggregateInterestCounts(interestDocs) {
  const byUser = aggregateInterestByUser(interestDocs);
  let goingCount = 0;
  let interestedCount = 0;
  for (const entry of byUser.values()) {
    if (entry.status === "going") goingCount += 1;
    else interestedCount += 1;
  }
  return {goingCount, interestedCount};
}

/**
 * @param {Object} db Firestore instance
 * @param {Array<{type: string, ref: Object, data: (Object|undefined)}>} ops
 * @return {Promise<void>}
 */
async function commitBatchedOps(db, ops) {
  const list = Array.isArray(ops) ? ops : [];
  for (let i = 0; i < list.length; i += BATCH_LIMIT) {
    const chunk = list.slice(i, i + BATCH_LIMIT);
    const batch = db.batch();
    for (const op of chunk) {
      if (op.type === "delete") {
        batch.delete(op.ref);
      } else {
        batch.set(op.ref, op.data, {merge: true});
      }
    }
    await batch.commit();
  }
}

/**
 * Sync public people roster under eventInterestStats/{eventId}/people.
 * @param {Object} db Firestore instance
 * @param {string} eventId
 * @param {Map<string, {status: string, updatedAt: (Object|null)}>} byUser
 * @return {Promise<void>}
 */
async function syncEventInterestPeople(db, eventId, byUser) {
  if (!eventId) return;
  const peopleCol = db.collection("eventInterestStats").doc(eventId)
      .collection("people");
  const existingSnap = await peopleCol.get();
  const existingIds = new Set(
      (existingSnap.docs || []).map((doc) => doc.id).filter(Boolean),
  );
  const desiredIds = new Set(byUser.keys());

  const profileCache = new Map();
  const ops = [];
  for (const [userId, entry] of byUser.entries()) {
    let profile = profileCache.get(userId);
    if (!profile) {
      profile = await loadInterestPersonProfile(db, userId);
      profileCache.set(userId, profile);
    }
    const data = {
      userId,
      status: entry.status,
      displayName: profile.displayName || null,
      photoURL: profile.photoURL || null,
      updatedAt: entry.updatedAt || FieldValue.serverTimestamp(),
    };
    ops.push({type: "set", ref: peopleCol.doc(userId), data});
  }
  for (const existingId of existingIds) {
    if (!desiredIds.has(existingId)) {
      ops.push({type: "delete", ref: peopleCol.doc(existingId)});
    }
  }
  await commitBatchedOps(db, ops);
}

/**
 * Deletes the public people roster for an event (e.g. when the event is removed).
 * @param {Object} db Firestore instance
 * @param {string} eventId
 * @return {Promise<void>}
 */
async function deleteEventInterestPeople(db, eventId) {
  if (!eventId) return;
  const peopleCol = db.collection("eventInterestStats").doc(eventId)
      .collection("people");
  const snap = await peopleCol.get();
  const docs = snap.docs || [];
  if (docs.length === 0) return;
  await commitBatchedOps(
      db,
      docs.map((doc) => ({type: "delete", ref: doc.ref})),
  );
}

/**
 * @param {Object} db Firestore instance
 * @param {string} eventId
 * @return {Promise<string[]>}
 */
async function duplicateEventIdsOf(db, eventId) {
  const snap = await db.collection("events")
      .where("duplicateOf", "==", eventId)
      .get();
  return snap.docs.map((doc) => doc.id);
}

/**
 * @param {Object} db Firestore instance
 * @param {string[]} eventIds
 * @return {Promise<Array<Object>>}
 */
async function loadInterestsForEventIds(db, eventIds) {
  const ids = (eventIds || []).filter((id) => typeof id === "string" && id);
  const all = [];
  for (let i = 0; i < ids.length; i += IN_QUERY_LIMIT) {
    const chunk = ids.slice(i, i + IN_QUERY_LIMIT);
    const snap = await db.collectionGroup("eventInterests")
        .where("eventId", "in", chunk)
        .get();
    snap.forEach((doc) => all.push(doc));
  }
  return all;
}

/**
 * Recomputes public Going / Interested totals and people roster for one event,
 * including RSVPs on events marked as duplicates of it.
 * @param {Object} db Firestore instance
 * @param {string} eventId
 * @return {Promise<{goingCount: number, interestedCount: number}|null>}
 */
async function recomputeEventInterestAggregates(db, eventId) {
  if (!eventId) return null;
  const duplicateIds = await duplicateEventIdsOf(db, eventId);
  const interests = await loadInterestsForEventIds(
      db,
      [eventId, ...duplicateIds],
  );
  const byUser = aggregateInterestByUser(interests);
  const counts = {
    goingCount: 0,
    interestedCount: 0,
  };
  for (const entry of byUser.values()) {
    if (entry.status === "going") counts.goingCount += 1;
    else counts.interestedCount += 1;
  }
  await db.collection("eventInterestStats").doc(eventId).set(counts, {merge: true});
  await syncEventInterestPeople(db, eventId, byUser);
  return counts;
}

/**
 * @param {Object} db Firestore instance
 * @param {string} eventId
 * @return {Promise<string|null>}
 */
async function duplicateOfForEvent(db, eventId) {
  if (!eventId) return null;
  const snap = await db.collection("events").doc(eventId).get();
  if (!snap.exists) return null;
  return normalizeDuplicateOf(snap.data());
}

/**
 * @param {Object} db Firestore instance
 * @param {string} eventId
 * @return {Promise<void>}
 */
async function recomputeEventInterestAndNative(db, eventId) {
  if (!eventId) return;
  await recomputeEventInterestAggregates(db, eventId);
  const duplicateOf = await duplicateOfForEvent(db, eventId);
  if (duplicateOf && duplicateOf !== eventId) {
    await recomputeEventInterestAggregates(db, duplicateOf);
  }
}

/**
 * @param {Object} db Firestore instance
 * @return {Promise<string[]>}
 */
async function collectEventIdsForInterestRecompute(db) {
  const ids = new Set();
  const statsSnap = await db.collection("eventInterestStats").get();
  statsSnap.forEach((doc) => {
    if (doc.id) ids.add(doc.id);
  });
  const duplicatesSnap = await db.collection("events")
      .where("duplicateOf", "!=", null)
      .get();
  duplicatesSnap.forEach((doc) => {
    if (doc.id) ids.add(doc.id);
    const dupOf = normalizeDuplicateOf(doc.data());
    if (dupOf) ids.add(dupOf);
  });
  return [...ids];
}

/**
 * @param {Object} db Firestore instance
 * @return {Promise<{processed: number, updated: number, failed: number}>}
 */
async function recomputeAllEventInterestAggregates(db) {
  const eventIds = await collectEventIdsForInterestRecompute(db);
  let updated = 0;
  let failed = 0;
  for (const eventId of eventIds) {
    try {
      await recomputeEventInterestAggregates(db, eventId);
      updated += 1;
    } catch (err) {
      console.error("Failed recomputing event interest stats for", eventId, err);
      failed += 1;
    }
  }
  return {processed: eventIds.length, updated, failed};
}

/**
 * @param {Object} db Firestore instance
 * @param {string} eventId
 * @param {{goingCount: number, interestedCount: number}} deltas
 * @return {Promise<void>}
 */
async function applyEventInterestStatsChange(db, eventId, deltas) {
  if (!eventId || !deltas) return;
  if ((deltas.goingCount || 0) === 0 && (deltas.interestedCount || 0) === 0) {
    return;
  }
  const ref = db.collection("eventInterestStats").doc(eventId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.exists ? (snap.data() || {}) : {};
    tx.set(ref, applyInterestCountDeltas(current, deltas), {merge: true});
  });
}

/**
 * @param {Object} db Firestore instance
 * @param {Object} event onDocumentWritten event
 * @return {Promise<void>}
 */
async function handleEventInterestWritten(db, event) {
  const beforeExists = !!(event.data && event.data.before && event.data.before.exists);
  const afterExists = !!(event.data && event.data.after && event.data.after.exists);
  const beforeData = beforeExists ? event.data.before.data() : null;
  const afterData = afterExists ? event.data.after.data() : null;
  const eventId = eventIdFromInterest(
      afterData || beforeData,
      event.params && event.params.eventId,
  );
  const deltas = interestCountDeltas(beforeData, afterData);
  if (!eventId || !deltas) return;
  await recomputeEventInterestAndNative(db, eventId);
}

/**
 * Recompute Going / Interested totals when an event is linked, unlinked, or
 * deleted as a duplicate.
 * @param {Object} db Firestore instance
 * @param {string} eventId
 * @param {Object|null|undefined} beforeData
 * @param {Object|null|undefined} afterData
 * @return {Promise<void>}
 */
async function handleEventDuplicateOfChanged(db, eventId, beforeData, afterData) {
  const ids = idsToRecomputeForDuplicateOfChange(eventId, beforeData, afterData);
  for (const id of ids) {
    await recomputeEventInterestAggregates(db, id);
  }
  if (!afterData && eventId) {
    await deleteEventInterestPeople(db, eventId);
    await db.collection("eventInterestStats").doc(eventId).delete();
  }
}

module.exports = {
  IN_QUERY_LIMIT,
  normalizeInterestStatus,
  normalizeDuplicateOf,
  eventIdFromInterest,
  interestCountDeltas,
  applyInterestCountDeltas,
  applyEventInterestStatsChange,
  idsToRecomputeForDuplicateOfChange,
  aggregateInterestByUser,
  aggregateInterestCounts,
  syncEventInterestPeople,
  deleteEventInterestPeople,
  recomputeEventInterestAggregates,
  recomputeEventInterestAndNative,
  collectEventIdsForInterestRecompute,
  recomputeAllEventInterestAggregates,
  handleEventInterestWritten,
  handleEventDuplicateOfChanged,
};
