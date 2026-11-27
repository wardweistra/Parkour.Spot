/* eslint-disable max-len */
/**
 * Queued, personalized email campaigns (first kind: the yearly review).
 *
 * `emailCampaigns/{campaignId}`:
 *   {
 *     kind: "yearReview", year: 2026, category: "newsletter",
 *     status: "queued" | "sending" | "done" | "cancelled",
 *     sendAt: Timestamp,            // nothing goes out before this
 *     dailyLimit: number,           // cap on emails per UTC day, all campaigns
 *     counts: {total, pending, sent, skipped, failed},
 *     createdBy, createdAt, updatedAt, lastRunAt, lastError,
 *   }
 * `emailCampaigns/{campaignId}/recipients/{uid}`:
 *   {status: "pending" | "sending" | "sent" | "skipped" | "failed",
 *    reason, attempts, messageId, locale, sentAt, updatedAt}
 * `emailSendCounters/{YYYY-MM-DD}`: {sent} across campaigns, for the cap.
 *
 * The recipient list is fixed when the campaign is created (everyone with
 * contributions that year). Everything that can change later (opt-out, email
 * address, verification, the numbers themselves) is read at send time.
 *
 * Delivery is at most once: a recipient is claimed ("sending") in a
 * transaction before the send, so overlapping runs never mail twice. A run
 * that dies mid-send leaves that recipient in "sending" for an admin to see.
 */

const {pickCounts, buildYearReviewDataForUser} = require("./year-review-data");
const {ANONYMOUS_USER_ID, FIRST_STATS_YEAR} = require("./user-stats");
const {buildYearReviewEmail} = require("./year-review-email");
const {
  isEmailCategoryEnabled,
  unsubscribeUrl,
  listUnsubscribeHeaders,
} = require("./email-preferences");

const CAMPAIGNS = "emailCampaigns";
const RECIPIENTS = "recipients";
const COUNTERS = "emailSendCounters";

const DEFAULT_DAILY_LIMIT = 300;
const MAX_ATTEMPTS = 3;
const BATCH_SIZE = 400;

/** Statuses a campaign can still send from. */
const ACTIVE_STATUSES = Object.freeze(["queued", "sending"]);

/**
 * @param {Date} date
 * @return {string} UTC day key.
 */
function dayKey(date) {
  return date.toISOString().slice(0, 10);
}

/**
 * @param {unknown} value
 * @return {number}
 */
function parseDailyLimit(value) {
  const n = Number(value);
  if (!Number.isFinite(n) || n <= 0) return DEFAULT_DAILY_LIMIT;
  return Math.min(Math.floor(n), 100000);
}

/**
 * @param {unknown} value ISO string or millis.
 * @param {Date} now
 * @return {Date}
 */
function parseSendAt(value, now) {
  if (value == null || value === "") return now;
  const date = new Date(typeof value === "number" ? value : String(value));
  if (Number.isNaN(date.getTime())) throw new Error("sendAt is not a valid date");
  return date;
}

/**
 * @param {Object} data `userStats/{uid}` data.
 * @param {number} year
 * @return {boolean} Whether that year has any counted contribution.
 */
function isActiveInYear(data, year) {
  const years = (data && data.years) || {};
  return pickCounts(years[String(year)] || {}).length > 0;
}

/**
 * Every uid with contributions in [year], from `userStats`.
 * @param {Object} db Firestore
 * @param {number} year
 * @return {Promise<string[]>}
 */
async function listActiveUserIds(db, year) {
  const snap = await db.collection("userStats").select("years").get();
  return snap.docs
      .filter((doc) => doc.id !== ANONYMOUS_USER_ID && isActiveInYear(doc.data(), year))
      .map((doc) => doc.id);
}

/**
 * Creates a yearly review campaign with one pending recipient per active user.
 * Refuses when a non-cancelled campaign for that year exists, so nobody gets
 * their review twice.
 *
 * @param {Object} options
 * @param {Object} options.db
 * @param {Object} options.FieldValue
 * @param {Object} options.Timestamp
 * @param {number} options.year
 * @param {unknown=} options.sendAt
 * @param {unknown=} options.dailyLimit
 * @param {string=} options.createdBy
 * @param {Date=} options.now
 * @return {Promise<{campaignId: string, total: number}>}
 */
async function createYearReviewCampaign({db, FieldValue, Timestamp, year, sendAt, dailyLimit, createdBy = null, now = new Date()}) {
  if (!Number.isInteger(year) || year < FIRST_STATS_YEAR || year > now.getUTCFullYear()) {
    throw new Error(`year must be between ${FIRST_STATS_YEAR} and ${now.getUTCFullYear()}`);
  }
  const existing = await db.collection(CAMPAIGNS)
      .where("kind", "==", "yearReview")
      .where("year", "==", year)
      .get();
  const blocking = existing.docs.find((doc) => (doc.data() || {}).status !== "cancelled");
  if (blocking) {
    throw new Error(`A ${year} yearly review campaign already exists (${blocking.id}). Cancel it first.`);
  }

  const userIds = await listActiveUserIds(db, year);
  const ref = db.collection(CAMPAIGNS).doc();
  await ref.set({
    kind: "yearReview",
    year,
    category: "newsletter",
    status: "queued",
    sendAt: Timestamp.fromDate(parseSendAt(sendAt, now)),
    dailyLimit: parseDailyLimit(dailyLimit),
    counts: {total: userIds.length, pending: userIds.length, sent: 0, skipped: 0, failed: 0},
    createdBy,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
    lastRunAt: null,
    lastError: null,
  });
  for (let i = 0; i < userIds.length; i += BATCH_SIZE) {
    const batch = db.batch();
    for (const uid of userIds.slice(i, i + BATCH_SIZE)) {
      batch.set(ref.collection(RECIPIENTS).doc(uid), {
        status: "pending",
        attempts: 0,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
  return {campaignId: ref.id, total: userIds.length};
}

/**
 * Stops a campaign; pending recipients stay pending and are never sent.
 * @param {Object} db
 * @param {Object} FieldValue
 * @param {string} campaignId
 * @return {Promise<void>}
 */
async function cancelCampaign(db, FieldValue, campaignId) {
  const ref = db.collection(CAMPAIGNS).doc(campaignId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error("Campaign not found");
    const status = (snap.data() || {}).status;
    if (!ACTIVE_STATUSES.includes(status)) throw new Error(`Campaign is already ${status}`);
    tx.update(ref, {status: "cancelled", updatedAt: FieldValue.serverTimestamp()});
  });
}

/**
 * Builds the email for one recipient, or says why there is none.
 *
 * @param {Object} options
 * @param {Object} options.db
 * @param {string} options.uid Whose review it is.
 * @param {number} options.year
 * @param {Function} options.getAuthUser uid → {email, emailVerified, disabled, displayName}.
 * @param {string} options.unsubscribeSecret
 * @param {string=} options.unsubscribeUid Whose preference the links change;
 *     defaults to [uid]. Test sends use the admin's own.
 * @param {boolean=} options.checkPreference
 * @param {Date=} options.now
 * @return {Promise<{skip: string}|{to: Object, message: Object, locale: string}>}
 */
async function prepareYearReviewMessage({db, uid, year, getAuthUser, unsubscribeSecret, unsubscribeUid = uid, checkPreference = true, now = new Date()}) {
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) return {skip: "no-user"};
  const userData = userSnap.data() || {};
  if (checkPreference && !isEmailCategoryEnabled(userData, "newsletter")) return {skip: "opted-out"};

  let authUser;
  try {
    authUser = await getAuthUser(uid);
  } catch (error) {
    if (error && error.code === "auth/user-not-found") return {skip: "no-auth-user"};
    throw error;
  }
  if (!authUser || !authUser.email) return {skip: "no-email"};
  if (authUser.disabled) return {skip: "disabled"};
  if (!authUser.emailVerified) return {skip: "unverified"};

  const data = await buildYearReviewDataForUser(db, {userId: uid, year});
  if (!data) return {skip: "no-activity"};
  if (!data.name) data.name = (authUser.displayName || "").trim();

  const url = unsubscribeUrl(unsubscribeUid, "newsletter", unsubscribeSecret);
  const email = buildYearReviewEmail(data, {
    locale: userData.preferredLanguageCode,
    unsubscribeUrl: url,
    now,
    cacheKey: dayKey(now),
  });
  return {
    to: {email: authUser.email, name: data.name || authUser.displayName || ""},
    locale: email.locale,
    message: {
      subject: email.subject,
      html: email.html,
      text: email.text,
      headers: listUnsubscribeHeaders(url),
      tags: [`year-review-${year}`],
    },
  };
}

/**
 * @param {Object} FieldValue
 * @param {string} from Status leaving.
 * @param {string} to Status entering.
 * @return {Object} Campaign update.
 */
function countMove(FieldValue, from, to) {
  if (from === to) return {};
  return {
    [`counts.${from}`]: FieldValue.increment(-1),
    [`counts.${to}`]: FieldValue.increment(1),
  };
}

/**
 * Claims, prepares, sends and records one recipient. Never throws.
 * @param {Object} ctx
 * @param {FirebaseFirestore.DocumentReference} recipientRef
 * @return {Promise<string>} Final status for this run.
 */
async function processRecipient(ctx, recipientRef) {
  const {db, FieldValue, campaignRef, campaign, send, now} = ctx;
  const uid = recipientRef.id;
  const claimed = await db.runTransaction(async (tx) => {
    const [campaignSnap, snap] = await Promise.all([tx.get(campaignRef), tx.get(recipientRef)]);
    // Cancelled while this run was going: claim nothing more.
    if (!ACTIVE_STATUSES.includes((campaignSnap.data() || {}).status)) return null;
    const data = snap.exists ? snap.data() || {} : {};
    if (data.status !== "pending") return null;
    tx.update(recipientRef, {
      status: "sending",
      attempts: (Number(data.attempts) || 0) + 1,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return {attempts: (Number(data.attempts) || 0) + 1};
  });
  if (!claimed) return "not-pending";

  const finish = async (status, fields) => {
    const batch = db.batch();
    batch.update(recipientRef, {status, ...fields, updatedAt: FieldValue.serverTimestamp()});
    batch.update(campaignRef, {...countMove(FieldValue, "pending", status), updatedAt: FieldValue.serverTimestamp()});
    if (status === "sent") {
      batch.set(db.collection(COUNTERS).doc(dayKey(now)), {sent: FieldValue.increment(1)}, {merge: true});
    }
    await batch.commit();
    return status;
  };

  try {
    const prepared = await prepareYearReviewMessage({
      db,
      uid,
      year: campaign.year,
      getAuthUser: ctx.getAuthUser,
      unsubscribeSecret: ctx.unsubscribeSecret,
      now,
    });
    if (prepared.skip) return await finish("skipped", {reason: prepared.skip});
    const {messageId} = await send({to: prepared.to, ...prepared.message});
    return await finish("sent", {messageId: messageId || null, locale: prepared.locale, sentAt: FieldValue.serverTimestamp(), reason: null});
  } catch (error) {
    const message = String((error && error.message) || error).slice(0, 500);
    if (error && error.retryable && claimed.attempts < MAX_ATTEMPTS) {
      await recipientRef.update({status: "pending", reason: message, updatedAt: FieldValue.serverTimestamp()});
      return "retry";
    }
    console.error("email campaign send failed", {campaignId: campaignRef.id, uid, error: message});
    return await finish("failed", {reason: message});
  }
}

/**
 * Sends what is due, oldest campaign first, within the daily cap.
 *
 * @param {Object} options
 * @param {Object} options.db
 * @param {Object} options.FieldValue
 * @param {Object} options.Timestamp
 * @param {Function} options.send `{to, subject, html, text, headers, tags}` → `{messageId}`.
 * @param {Function} options.getAuthUser
 * @param {string} options.unsubscribeSecret
 * @param {number=} options.maxPerRun
 * @param {number=} options.concurrency
 * @param {Date=} options.now
 * @return {Promise<Object>} Per-campaign tallies.
 */
async function processDueCampaigns({db, FieldValue, Timestamp, send, getAuthUser, unsubscribeSecret, maxPerRun = 150, concurrency = 5, now = new Date()}) {
  const due = await db.collection(CAMPAIGNS)
      .where("status", "in", ACTIVE_STATUSES)
      .where("sendAt", "<=", Timestamp.fromDate(now))
      .orderBy("sendAt")
      .get();
  const counterSnap = await db.collection(COUNTERS).doc(dayKey(now)).get();
  let sentToday = counterSnap.exists ? Number((counterSnap.data() || {}).sent) || 0 : 0;
  let budget = maxPerRun;
  const summary = {};

  for (const campaignDoc of due.docs) {
    const campaign = campaignDoc.data() || {};
    const campaignRef = campaignDoc.ref;
    const allowance = Math.min(budget, parseDailyLimit(campaign.dailyLimit) - sentToday);
    const tally = {sent: 0, skipped: 0, failed: 0, retry: 0, capped: allowance <= 0};
    summary[campaignDoc.id] = tally;
    if (allowance <= 0) continue;

    // Skips don't use the cap, so read a little more than the allowance.
    const pending = await campaignRef.collection(RECIPIENTS)
        .where("status", "==", "pending")
        .limit(Math.min(allowance * 2, 500))
        .get();
    if (pending.empty) {
      const stuck = await campaignRef.collection(RECIPIENTS).where("status", "==", "sending").limit(1).get();
      await campaignRef.update({
        status: stuck.empty ? "done" : "sending",
        lastRunAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      continue;
    }
    if (campaign.status === "queued") {
      await campaignRef.update({status: "sending", updatedAt: FieldValue.serverTimestamp()});
    }

    const ctx = {db, FieldValue, campaignRef, campaign, send, getAuthUser, unsubscribeSecret, now};
    const queue = [...pending.docs];
    let sentHere = 0;
    let inFlight = 0;
    const worker = async () => {
      // In-flight sends count against the allowance so workers never overshoot it.
      while (queue.length && sentHere + inFlight < allowance) {
        inFlight++;
        const status = await processRecipient(ctx, queue.shift().ref);
        inFlight--;
        if (status === "sent") sentHere++;
        if (tally[status] !== undefined) tally[status]++;
      }
    };
    await Promise.all(Array.from({length: Math.max(1, concurrency)}, worker));
    sentToday += sentHere;
    budget -= sentHere;
    await campaignRef.update({lastRunAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp()});
    if (budget <= 0) break;
  }
  return summary;
}

module.exports = {
  CAMPAIGNS,
  RECIPIENTS,
  COUNTERS,
  DEFAULT_DAILY_LIMIT,
  dayKey,
  parseDailyLimit,
  parseSendAt,
  isActiveInYear,
  listActiveUserIds,
  createYearReviewCampaign,
  cancelCampaign,
  prepareYearReviewMessage,
  processRecipient,
  processDueCampaigns,
};
