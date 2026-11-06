/* eslint-disable max-len */
/**
 * Rolling 90-day check-in volume + public recent-trainers roster per spot.
 *
 * Collection: `spotTrainingStats/{spotId}`
 *   - checkInCount: all check-ins in the window (public + private)
 *   - peopleCount: unique userIds in the window (public + private)
 *   - recentPeople: capped unique public trainers (most recent first)
 *
 * Private check-ins contribute to counts only; they never appear in recentPeople.
 * Written by Cloud Functions only; publicly readable.
 */

const {Timestamp} = require("firebase-admin/firestore");

const STATS_COLLECTION = "spotTrainingStats";
/** Same window as Explore Activities past retention. */
const WINDOW_MS = 90 * 24 * 60 * 60 * 1000;
const WINDOW_DAYS = 90;
/** Cap public faces stored on the stats doc (strip + dialog). */
const MAX_RECENT_PEOPLE = 40;

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
 * @param {*} value
 * @return {Date|null}
 */
function normalizeDate(value) {
  if (!value) return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }
  if (typeof value.toDate === "function") {
    try {
      const d = value.toDate();
      return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
    } catch (_) {
      return null;
    }
  }
  if (typeof value === "number" && Number.isFinite(value)) {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  if (typeof value === "string") {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

/**
 * Aggregate check-in docs already filtered to the retention window.
 * @param {Array} docs Firestore docs or `{data: Function|Object}` fixtures
 * @return {{checkInCount: number, peopleCount: number, recentPeople: Array}}
 */
function aggregateSpotTrainingFromCheckIns(docs) {
  const allUserIds = new Set();
  let checkInCount = 0;
  /** @type {Map<string, {userId: string, displayName: ?string, photoURL: ?string, lastCheckedInAt: Date}>} */
  const publicByUser = new Map();

  for (const doc of docs) {
    const data = typeof doc.data === "function" ? doc.data() : doc.data;
    if (!data || typeof data !== "object") continue;
    const userId = trimmedString(data.userId);
    if (!userId) continue;
    const checkedInAt = normalizeDate(data.checkedInAt);
    if (!checkedInAt) continue;

    checkInCount += 1;
    allUserIds.add(userId);

    if (data.isPrivate !== false) continue;

    const existing = publicByUser.get(userId);
    if (!existing || checkedInAt.getTime() > existing.lastCheckedInAt.getTime()) {
      publicByUser.set(userId, {
        userId,
        displayName: trimmedString(data.displayName),
        photoURL: trimmedString(data.photoURL),
        lastCheckedInAt: checkedInAt,
      });
    }
  }

  const recentPeople = Array.from(publicByUser.values())
      .sort((a, b) => b.lastCheckedInAt.getTime() - a.lastCheckedInAt.getTime())
      .slice(0, MAX_RECENT_PEOPLE)
      .map((p) => ({
        userId: p.userId,
        displayName: p.displayName,
        photoURL: p.photoURL,
        lastCheckedInAt: p.lastCheckedInAt,
      }));

  return {
    checkInCount,
    peopleCount: allUserIds.size,
    recentPeople,
  };
}

/**
 * Spot ids touched by a check-in write (create / update / delete).
 * @param {Object|null|undefined} beforeData
 * @param {Object|null|undefined} afterData
 * @return {string[]}
 */
function spotIdsForCheckInWrite(beforeData, afterData) {
  const ids = new Set();
  const beforeId = beforeData ? trimmedString(beforeData.spotId) : null;
  const afterId = afterData ? trimmedString(afterData.spotId) : null;
  if (beforeId) ids.add(beforeId);
  if (afterId) ids.add(afterId);
  return Array.from(ids);
}

/**
 * Load check-ins for [spotId] in the rolling window and write/delete stats.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} spotId
 * @param {Object=} options
 * @param {Date=} options.now
 * @return {Promise<{spotId: string, checkInCount: number, peopleCount: number, recentPeopleCount: number, deleted: boolean}>}
 */
async function recomputeSpotTrainingStats(db, spotId, options = {}) {
  const trimmed = trimmedString(spotId);
  if (!trimmed) {
    return {
      spotId: "",
      checkInCount: 0,
      peopleCount: 0,
      recentPeopleCount: 0,
      deleted: false,
    };
  }

  const now = options.now instanceof Date ? options.now : new Date();
  const since = new Date(now.getTime() - WINDOW_MS);
  const statsRef = db.collection(STATS_COLLECTION).doc(trimmed);

  const snap = await db.collection("spotCheckIns")
      .where("spotId", "==", trimmed)
      .where("checkedInAt", ">=", Timestamp.fromDate(since))
      .orderBy("checkedInAt", "desc")
      .get();

  const aggregated = aggregateSpotTrainingFromCheckIns(snap.docs);

  if (aggregated.checkInCount === 0 && aggregated.peopleCount === 0) {
    await statsRef.delete().catch(() => undefined);
    return {
      spotId: trimmed,
      checkInCount: 0,
      peopleCount: 0,
      recentPeopleCount: 0,
      deleted: true,
    };
  }

  await statsRef.set({
    spotId: trimmed,
    checkInCount: aggregated.checkInCount,
    peopleCount: aggregated.peopleCount,
    windowDays: WINDOW_DAYS,
    recentPeople: aggregated.recentPeople.map((p) => ({
      userId: p.userId,
      displayName: p.displayName,
      photoURL: p.photoURL,
      lastCheckedInAt: Timestamp.fromDate(p.lastCheckedInAt),
    })),
    updatedAt: Timestamp.fromDate(now),
  }, {merge: false});

  return {
    spotId: trimmed,
    checkInCount: aggregated.checkInCount,
    peopleCount: aggregated.peopleCount,
    recentPeopleCount: aggregated.recentPeople.length,
    deleted: false,
  };
}

/**
 * Recompute stats for every spot id touched by a check-in write.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object|null|undefined} beforeData
 * @param {Object|null|undefined} afterData
 * @param {Object=} options
 * @return {Promise<Array<Object>>}
 */
async function handleSpotCheckInWrittenForTrainingStats(
    db,
    beforeData,
    afterData,
    options = {},
) {
  const spotIds = spotIdsForCheckInWrite(beforeData, afterData);
  const results = [];
  for (const spotId of spotIds) {
    results.push(await recomputeSpotTrainingStats(db, spotId, options));
  }
  return results;
}

/**
 * Refresh all existing stats docs (ages sessions out of the 90-day window).
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object=} options
 * @param {Date=} options.now
 * @param {number=} options.pageSize
 * @return {Promise<{scanned: number, updated: number, deleted: number, failed: number}>}
 */
async function refreshExistingSpotTrainingStats(db, options = {}) {
  const pageSize = Number.isFinite(options.pageSize) && options.pageSize > 0 ?
    Math.floor(options.pageSize) :
    400;
  let scanned = 0;
  let updated = 0;
  let deleted = 0;
  let failed = 0;
  let lastDoc = null;

  for (;;) {
    let q = db.collection(STATS_COLLECTION).orderBy("__name__").limit(pageSize);
    if (lastDoc) q = q.startAfter(lastDoc);
    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      scanned += 1;
      try {
        const result = await recomputeSpotTrainingStats(db, doc.id, options);
        if (result.deleted) deleted += 1;
        else updated += 1;
      } catch (err) {
        failed += 1;
        console.error("refreshExistingSpotTrainingStats failed", {
          spotId: doc.id,
          err,
        });
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < pageSize) break;
  }

  return {scanned, updated, deleted, failed};
}

/**
 * Backfill: discover spots with check-ins in the window, then recompute each.
 * Also refreshes any orphaned stats docs (no longer in window → deleted).
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object=} options
 * @param {Date=} options.now
 * @param {number=} options.pageSize
 * @return {Promise<{spotIds: number, updated: number, deleted: number, failed: number}>}
 */
async function recomputeAllSpotTrainingStats(db, options = {}) {
  const now = options.now instanceof Date ? options.now : new Date();
  const since = new Date(now.getTime() - WINDOW_MS);
  const pageSize = Number.isFinite(options.pageSize) && options.pageSize > 0 ?
    Math.floor(options.pageSize) :
    400;

  const spotIds = new Set();
  let lastDoc = null;
  for (;;) {
    let q = db.collection("spotCheckIns")
        .where("checkedInAt", ">=", Timestamp.fromDate(since))
        .orderBy("checkedInAt", "desc")
        .select("spotId")
        .limit(pageSize);
    if (lastDoc) q = q.startAfter(lastDoc);
    const page = await q.get();
    if (page.empty) break;
    for (const doc of page.docs) {
      const spotId = trimmedString((doc.data() || {}).spotId);
      if (spotId) spotIds.add(spotId);
    }
    lastDoc = page.docs[page.docs.length - 1];
    if (page.size < pageSize) break;
  }

  const existing = await db.collection(STATS_COLLECTION).select().get();
  for (const doc of existing.docs) {
    spotIds.add(doc.id);
  }

  let updated = 0;
  let deleted = 0;
  let failed = 0;
  for (const spotId of spotIds) {
    try {
      const result = await recomputeSpotTrainingStats(db, spotId, {now});
      if (result.deleted) deleted += 1;
      else updated += 1;
    } catch (err) {
      failed += 1;
      console.error("recomputeAllSpotTrainingStats failed", {spotId, err});
    }
  }

  return {
    spotIds: spotIds.size,
    updated,
    deleted,
    failed,
  };
}

module.exports = {
  STATS_COLLECTION,
  WINDOW_MS,
  WINDOW_DAYS,
  MAX_RECENT_PEOPLE,
  trimmedString,
  normalizeDate,
  aggregateSpotTrainingFromCheckIns,
  spotIdsForCheckInWrite,
  recomputeSpotTrainingStats,
  handleSpotCheckInWrittenForTrainingStats,
  refreshExistingSpotTrainingStats,
  recomputeAllSpotTrainingStats,
};
