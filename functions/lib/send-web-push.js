/**
 * Shared FCM web-push send + invalid-token cleanup.
 * Used by the admin test-send callable and product inbox delivery.
 */

const FCM_UNRECOVERABLE_TOKEN_ERROR_CODES = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
]);

const DEFAULT_NOTIFICATION_ICON_URL = "https://parkour.spot/icons/Icon-192.png";
const DEFAULT_NOTIFICATION_BADGE_URL =
    "https://parkour.spot/icons/ParkourSpot-badge.png";

const SEND_CHUNK_SIZE = 500;

/**
 * @param {object} options
 * @param {string} options.token
 * @param {string} options.title
 * @param {string} options.body
 * @param {string} options.clickLink
 * @param {string} options.iconUrl
 * @param {string} options.badgeUrl
 * @param {string} [options.imageUrl]
 * @return {object} FCM message
 */
function buildWebPushMessage({
  token,
  title,
  body,
  clickLink,
  iconUrl,
  badgeUrl,
  imageUrl,
}) {
  return {
    token,
    notification: {title, body},
    data: {openUrl: clickLink},
    // Explicit webpush notification helps Chrome (incl. Android PWA) deliver
    // system notifications when the app is backgrounded; top-level
    // [notification] alone is not always enough for the SW payload.
    webpush: {
      notification: {
        title,
        body,
        icon: iconUrl,
        badge: badgeUrl,
        ...(imageUrl ? {image: imageUrl} : {}),
      },
      fcmOptions: {
        link: clickLink,
      },
    },
  };
}

/**
 * Send FCM web push to prepared targets and disable unrecoverable tokens.
 * Title/body may differ per target (localized product alerts).
 *
 * @param {object} options
 * @param {FirebaseFirestore.Firestore} options.db
 * @param {object} options.FieldValue
 * @param {object} options.messaging admin.messaging()
 * @param {string} options.uid
 * @param {object[]} options.targets each {id, token, title, body}
 * @param {string} options.clickLink
 * @param {string} [options.iconUrl]
 * @param {string} [options.badgeUrl]
 * @param {string} [options.imageUrl]
 * @return {Promise<object>} counts, failures, and deactivated subscription ids
 */
async function sendWebPushToTargets({
  db,
  FieldValue,
  messaging,
  uid,
  targets,
  clickLink,
  iconUrl,
  badgeUrl,
  imageUrl,
}) {
  const resolvedIcon = iconUrl || DEFAULT_NOTIFICATION_ICON_URL;
  const resolvedBadge = badgeUrl || DEFAULT_NOTIFICATION_BADGE_URL;
  /** @type {{subscriptionId: string, error: string, code?: string}[]} */
  const failures = [];
  /** @type {string[]} */
  const deactivatedSubscriptionIds = [];
  let successCount = 0;
  let failureCount = 0;

  if (!Array.isArray(targets) || targets.length === 0) {
    return {
      successCount: 0,
      failureCount: 0,
      failures,
      deactivatedSubscriptionIds,
    };
  }

  for (let offset = 0; offset < targets.length; offset += SEND_CHUNK_SIZE) {
    const chunk = targets.slice(offset, offset + SEND_CHUNK_SIZE);
    const messages = chunk.map((t) => buildWebPushMessage({
      token: t.token,
      title: t.title,
      body: t.body,
      clickLink,
      iconUrl: resolvedIcon,
      badgeUrl: resolvedBadge,
      imageUrl,
    }));
    const batchResponse = await messaging.sendEach(messages);
    successCount += batchResponse.successCount || 0;
    failureCount += batchResponse.failureCount || 0;
    const responses = batchResponse.responses || [];
    for (let i = 0; i < responses.length; i++) {
      const r = responses[i];
      if (r.success) {
        continue;
      }
      const err = r.error;
      const code = err && typeof err.code === "string" ? err.code : "";
      const message = err ? String(err.message || err) : "unknown";
      failures.push({
        subscriptionId: chunk[i].id,
        error: message,
        ...(code ? {code} : {}),
      });
      if (code && FCM_UNRECOVERABLE_TOKEN_ERROR_CODES.has(code)) {
        deactivatedSubscriptionIds.push(chunk[i].id);
      }
    }
  }

  const deactivatedUnique = [...new Set(deactivatedSubscriptionIds)];
  if (deactivatedUnique.length > 0) {
    try {
      const batch = db.batch();
      const subsCol = db.collection("users").doc(uid)
          .collection("pushSubscriptions");
      const now = FieldValue.serverTimestamp();
      for (const subId of deactivatedUnique) {
        batch.set(subsCol.doc(subId), {
          enabled: false,
          token: null,
          updatedAt: now,
        }, {merge: true});
      }
      await batch.commit();
    } catch (cleanupErr) {
      console.error("sendWebPush token cleanup error:", cleanupErr);
    }
  }

  return {
    successCount,
    failureCount,
    failures,
    deactivatedSubscriptionIds: deactivatedUnique,
  };
}

module.exports = {
  sendWebPushToTargets,
  buildWebPushMessage,
  FCM_UNRECOVERABLE_TOKEN_ERROR_CODES,
  DEFAULT_NOTIFICATION_ICON_URL,
  DEFAULT_NOTIFICATION_BADGE_URL,
  SEND_CHUNK_SIZE,
};
