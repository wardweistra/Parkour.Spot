/* eslint-disable max-len */
/**
 * Remind users to check in when their training plan window has started and they
 * have not yet checked in at that spot.
 */

const NOTIFICATION_KIND_TRAINING_PLAN_CHECK_IN_REMINDER =
  "training_plan_check_in_reminder";

const {Timestamp} = require("firebase-admin/firestore");
const {sendPushForPayload} = require("./deliver-notification");

const QUERY_PAGE_SIZE = 300;
const GET_USER_CHUNK = 10;

/**
 * @param {FirebaseFirestore.Timestamp} ts
 * @return {number}
 */
function tsMillis(ts) {
  return typeof ts.toMillis === "function" ? ts.toMillis() : 0;
}

/**
 * @param {object} planData
 * @param {FirebaseFirestore.Timestamp} nowTs
 * @return {boolean}
 */
function planIsInActiveWindow(planData, nowTs) {
  if (!planData) return false;
  const start = planData.plannedStartAt;
  const end = planData.plannedEndAt;
  if (!start || !end) return false;
  const nowMs = tsMillis(nowTs);
  return tsMillis(start) <= nowMs && tsMillis(end) > nowMs;
}

/**
 * Whether we already sent a reminder for this plan's current planned start.
 * @param {object} planData
 * @return {boolean}
 */
function reminderAlreadySentForCurrentStart(planData) {
  const sent = planData.planReminderSentAt;
  const start = planData.plannedStartAt;
  if (!sent || !start) return false;
  return tsMillis(sent) === tsMillis(start);
}

/**
 * @param {object} planData
 * @param {object} spotData
 * @return {{spotName: string}}
 */
function buildTemplateArgs(planData, spotData) {
  const fromPlan =
    typeof planData.spotName === "string" ? planData.spotName.trim() : "";
  const fromSpot =
    typeof spotData.name === "string" ? spotData.name.trim() : "";
  const spotName = fromPlan || fromSpot || "";
  return {spotName};
}

/**
 * @param {object} spotData
 * @return {boolean}
 */
function spotOkForReminder(spotData) {
  if (!spotData || spotData.hidden === true) {
    return false;
  }
  return true;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @param {string} spotId
 * @param {FirebaseFirestore.Timestamp} nowTs
 * @return {Promise<boolean>} true if user has an active check-in at the spot
 */
async function hasActiveCheckInAtSpot(db, userId, spotId, nowTs) {
  const snap = await db
      .collection("spotCheckIns")
      .where("userId", "==", userId)
      .where("spotId", "==", spotId)
      .where("expectedEndAt", ">", nowTs)
      .limit(5)
      .get();
  if (snap.empty) return false;
  const nowMs = tsMillis(nowTs);
  for (const doc of snap.docs) {
    const d = doc.data() || {};
    const checkedInAt = d.checkedInAt;
    if (!checkedInAt) continue;
    if (tsMillis(checkedInAt) <= nowMs) {
      return true;
    }
  }
  return false;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string[]} userIds
 * @return {Promise<string[]>}
 */
async function filterUserIdsWantingReminder(db, userIds) {
  const out = [];
  for (let i = 0; i < userIds.length; i += GET_USER_CHUNK) {
    const chunk = userIds.slice(i, i + GET_USER_CHUNK);
    const refs = chunk.map((uid) => db.collection("users").doc(uid));
    const snaps = await db.getAll(...refs);
    for (let j = 0; j < snaps.length; j++) {
      const doc = snaps[j];
      if (!doc.exists) continue;
      const data = doc.data();
      if (data && data.notifyTrainingPlanCheckInReminders !== false) {
        out.push(chunk[j]);
      }
    }
  }
  return out;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {Map<string, object|null>} cache
 * @param {string} spotId
 * @return {Promise<object|null>}
 */
async function getSpotCached(db, cache, spotId) {
  if (cache.has(spotId)) {
    return cache.get(spotId);
  }
  const s = await db.collection("spots").doc(spotId).get();
  const v = s.exists ? s.data() || {} : null;
  cache.set(spotId, v);
  return v;
}

/**
 * @param {object} options
 * @param {FirebaseFirestore.Firestore} options.db
 * @param {FirebaseFirestore.FieldValue} options.FieldValue
 * @param {Date=} options.now
 * @param {Function=} options.sendPush override for tests; defaults to sendPushForPayload
 * @return {Promise<{notified: number, skipped: number}>}
 */
async function runTrainingPlanCheckInReminders({db, FieldValue, now, sendPush}) {
  const nowDate = now instanceof Date ? now : new Date();
  const nowTs = Timestamp.fromDate(nowDate);
  const pushFn = typeof sendPush === "function" ? sendPush : sendPushForPayload;

  let lastDoc = null;
  let notified = 0;
  let skipped = 0;

  for (;;) {
    let q = db
        .collection("spotTrainingPlans")
        .where("plannedStartAt", "<=", nowTs)
        .where("plannedEndAt", ">", nowTs)
        .orderBy("plannedStartAt", "asc")
        .limit(QUERY_PAGE_SIZE);
    if (lastDoc) {
      q = q.startAfter(lastDoc);
    }
    const snap = await q.get();
    if (snap.empty) {
      break;
    }

    const plansToProcess = [];
    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const userId = typeof data.userId === "string" ? data.userId : "";
      const spotId = typeof data.spotId === "string" ? data.spotId : "";
      if (!userId || !spotId) {
        skipped++;
        continue;
      }
      if (!planIsInActiveWindow(data, nowTs)) {
        skipped++;
        continue;
      }
      if (reminderAlreadySentForCurrentStart(data)) {
        skipped++;
        continue;
      }
      plansToProcess.push({ref: doc.ref, id: doc.id, data});
    }

    const spotCache = new Map();

    const userIds = [...new Set(plansToProcess.map((p) => p.data.userId))];
    const allowed = new Set(await filterUserIdsWantingReminder(db, userIds));

    for (const item of plansToProcess) {
      const {ref, data} = item;
      const userId = data.userId;
      const spotId = data.spotId;

      if (!allowed.has(userId)) {
        skipped++;
        continue;
      }

      const spotData = await getSpotCached(db, spotCache, spotId);
      if (!spotOkForReminder(spotData)) {
        skipped++;
        continue;
      }

      const hasCheckIn = await hasActiveCheckInAtSpot(db, userId, spotId, nowTs);
      if (hasCheckIn) {
        skipped++;
        continue;
      }

      try {
        let pushPayload = null;
        await db.runTransaction(async (t) => {
          const fresh = await t.get(ref);
          if (!fresh.exists) {
            return;
          }
          const planData = fresh.data() || {};
          if (!planIsInActiveWindow(planData, nowTs)) {
            return;
          }
          if (reminderAlreadySentForCurrentStart(planData)) {
            return;
          }
          const start = planData.plannedStartAt;
          if (!start) {
            return;
          }
          const notifRef = db
              .collection("users")
              .doc(userId)
              .collection("notifications")
              .doc();
          const templateArgs = buildTemplateArgs(planData, spotData || {});
          t.set(notifRef, {
            notificationKind: NOTIFICATION_KIND_TRAINING_PLAN_CHECK_IN_REMINDER,
            templateArgs,
            deeplinkKind: "spot",
            deeplinkId: spotId,
            createdAt: FieldValue.serverTimestamp(),
            read: false,
          });
          t.update(ref, {
            planReminderSentAt: start,
          });
          pushPayload = {
            notificationKind: NOTIFICATION_KIND_TRAINING_PLAN_CHECK_IN_REMINDER,
            templateArgs,
            deeplinkKind: "spot",
            deeplinkId: spotId,
          };
        });
        notified++;
        if (pushPayload) {
          try {
            await pushFn({
              db,
              FieldValue,
              uid: userId,
              payload: pushPayload,
            });
          } catch (pushErr) {
            console.error("training plan reminder push failed:", {
              planId: item.id,
              error: pushErr,
            });
          }
        }
      } catch (e) {
        console.error("training plan reminder transaction failed:", {
          planId: item.id,
          error: e,
        });
        skipped++;
      }
    }

    if (snap.size < QUERY_PAGE_SIZE) {
      break;
    }
    lastDoc = snap.docs[snap.docs.length - 1];
  }

  return {notified, skipped};
}

module.exports = {
  runTrainingPlanCheckInReminders,
  NOTIFICATION_KIND_TRAINING_PLAN_CHECK_IN_REMINDER,
  planIsInActiveWindow,
  reminderAlreadySentForCurrentStart,
  buildTemplateArgs,
};
