/**
 * Write in-app inbox docs then send localized web push to enabled
 * pushSubscriptions. Inbox write always happens first; push failures are
 * logged and do not roll back inbox docs.
 */

const {
  localizedNotificationCopy,
  resolvePushLocale,
  normalizeLocale,
} = require("./notification-copy");
const {
  sendWebPushToTargets,
  DEFAULT_NOTIFICATION_ICON_URL,
  DEFAULT_NOTIFICATION_BADGE_URL,
} = require("./send-web-push");

const BATCH_SIZE = 500;
const PUBLIC_ORIGIN = "https://parkour.spot";
const MIN_TOKEN_LENGTH = 10;

/**
 * @param {string} deeplinkKind
 * @param {string} deeplinkId
 * @param {string} [notificationId] inbox doc id; appended as `nid` when present
 * @return {string}
 */
function clickUrlForDeeplink(deeplinkKind, deeplinkId, notificationId) {
  const id = typeof deeplinkId === "string" ? deeplinkId.trim() : "";
  const path = deeplinkKind === "event" ?
    `${PUBLIC_ORIGIN}/event/${id}` :
    `${PUBLIC_ORIGIN}/spot/${id}`;
  const nid = typeof notificationId === "string" ? notificationId.trim() : "";
  if (!nid) {
    return path;
  }
  return `${path}?nid=${encodeURIComponent(nid)}`;
}

/**
 * Inbox document fields (no title/body; client localizes).
 * @param {object} payload
 * @param {object} FieldValue
 * @return {object}
 */
function inboxDocFields(payload, FieldValue) {
  return {
    notificationKind: payload.notificationKind,
    templateArgs: payload.templateArgs,
    deeplinkKind: payload.deeplinkKind,
    deeplinkId: payload.deeplinkId,
    createdAt: FieldValue.serverTimestamp(),
    read: false,
  };
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {object} FieldValue
 * @param {string[]} userIds
 * @param {object} payload
 * @return {Promise<Object<string, string>>} uid -> inbox document id
 */
async function writeInboxNotifications(db, FieldValue, userIds, payload) {
  const fields = inboxDocFields(payload, FieldValue);
  /** @type {Object<string, string>} */
  const idsByUser = {};
  let batch = db.batch();
  let ops = 0;
  for (const uid of userIds) {
    const ref = db.collection("users").doc(uid)
        .collection("notifications").doc();
    idsByUser[uid] = ref.id;
    batch.set(ref, fields);
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
  return idsByUser;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} uid
 * @return {Promise<Array<{id: string, token: string, locale: *,
 *   platform: * }>>}
 */
async function loadEnabledPushSubscriptions(db, uid) {
  const snap = await db.collection("users").doc(uid)
      .collection("pushSubscriptions")
      .get();
  if (!snap || snap.empty) {
    return [];
  }
  const out = [];
  for (const doc of snap.docs || []) {
    const data = doc.data() || {};
    if (data.enabled !== true) {
      continue;
    }
    const token = data.token;
    if (typeof token !== "string" || token.length < MIN_TOKEN_LENGTH) {
      continue;
    }
    out.push({
      id: doc.id,
      token,
      locale: data.locale,
      platform: data.platform,
    });
  }
  return out;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} uid
 * @return {Promise<string|null>}
 */
async function loadPreferredLanguageCode(db, uid) {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap || !snap.exists) {
    return null;
  }
  const data = snap.data() || {};
  return typeof data.preferredLanguageCode === "string" ?
    data.preferredLanguageCode :
    null;
}

/**
 * @param {object} [messaging]
 * @return {object}
 */
function resolveMessaging(messaging) {
  if (messaging) {
    return messaging;
  }
  const admin = require("firebase-admin");
  return admin.messaging();
}

/**
 * Send web push for an already-written inbox payload. Never throws.
 *
 * @param {object} options
 * @param {FirebaseFirestore.Firestore} options.db
 * @param {object} options.FieldValue
 * @param {string} options.uid
 * @param {object} options.payload
 * @param {string} [options.notificationId]
 * @param {object} [options.messaging]
 * @return {Promise<void>}
 */
async function sendPushForPayload({
  db,
  FieldValue,
  uid,
  payload,
  notificationId,
  messaging,
}) {
  try {
    const subs = await loadEnabledPushSubscriptions(db, uid);
    if (subs.length === 0) {
      return;
    }
    let preferredLanguageCode = null;
    const needsFallback = subs.some((s) => !normalizeLocale(s.locale));
    if (needsFallback) {
      preferredLanguageCode = await loadPreferredLanguageCode(db, uid);
    }
    const clickLink = clickUrlForDeeplink(
        payload.deeplinkKind,
        payload.deeplinkId,
        notificationId,
    );
    const targets = subs.map((sub) => {
      const locale = resolvePushLocale(sub.locale, preferredLanguageCode);
      const copy = localizedNotificationCopy({
        notificationKind: payload.notificationKind,
        templateArgs: payload.templateArgs,
        locale,
      });
      return {
        id: sub.id,
        token: sub.token,
        title: copy.title,
        body: copy.body,
        platform: sub.platform,
      };
    });
    await sendWebPushToTargets({
      db,
      FieldValue,
      messaging: resolveMessaging(messaging),
      uid,
      targets,
      clickLink,
      iconUrl: DEFAULT_NOTIFICATION_ICON_URL,
      badgeUrl: DEFAULT_NOTIFICATION_BADGE_URL,
    });
  } catch (error) {
    console.error("sendPushForPayload failed:", {uid, error});
  }
}

/**
 * Write inbox docs for each uid, then attempt web push. Push errors do not
 * fail this function after inbox writes succeed.
 *
 * @param {object} options
 * @param {FirebaseFirestore.Firestore} options.db
 * @param {object} options.FieldValue
 * @param {string[]} options.userIds
 * @param {object} options.payload
 * @param {string} options.payload.notificationKind
 * @param {object} options.payload.templateArgs
 * @param {string} options.payload.deeplinkKind
 * @param {string} options.payload.deeplinkId
 * @param {object} [options.messaging]
 * @return {Promise<{notified: number}>}
 */
async function deliverNotifications({
  db,
  FieldValue,
  userIds,
  payload,
  messaging,
}) {
  const ids = Array.isArray(userIds) ?
    userIds.filter((uid) => typeof uid === "string" && uid.length > 0) :
    [];
  if (ids.length === 0) {
    return {notified: 0};
  }
  const idsByUser = await writeInboxNotifications(db, FieldValue, ids, payload);
  for (const uid of ids) {
    await sendPushForPayload({
      db,
      FieldValue,
      uid,
      payload,
      notificationId: idsByUser[uid],
      messaging,
    });
  }
  return {notified: ids.length};
}

module.exports = {
  deliverNotifications,
  sendPushForPayload,
  clickUrlForDeeplink,
  inboxDocFields,
  writeInboxNotifications,
};
