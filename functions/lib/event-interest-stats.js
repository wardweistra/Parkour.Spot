/* eslint-disable max-len */
/**
 * Denormalized Going / Interested totals for events.
 * Source of truth remains `users/{userId}/eventInterests/{eventId}`.
 */

const STATUSES = Object.freeze(["going", "interested"]);

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
  await applyEventInterestStatsChange(db, eventId, deltas);
}

module.exports = {
  normalizeInterestStatus,
  eventIdFromInterest,
  interestCountDeltas,
  applyInterestCountDeltas,
  applyEventInterestStatsChange,
  handleEventInterestWritten,
};
