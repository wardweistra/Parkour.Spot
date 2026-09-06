/**
 * Shared FCM send + invalid-token cleanup.
 * Used by the admin test-send callable and product inbox delivery.
 * Builds webpush or native (android/ios) message shapes from
 * subscription platform.
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
 * Normalize subscription platform to a known send path.
 * @param {unknown} platform
 * @return {"web"|"android"|"ios"}
 */
function normalizePushPlatform(platform) {
  if (platform === "android" || platform === "ios") {
    return platform;
  }
  return "web";
}

/**
 * @param {object} options
 * @param {string} options.token
 * @param {string} options.title
 * @param {string} options.body
 * @param {string} options.clickLink
 * @param {string} options.iconUrl
 * @param {string} options.badgeUrl
 * @param {string} [options.imageUrl]
 * @param {string} [options.platform]
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
  platform,
}) {
  const resolvedPlatform = normalizePushPlatform(platform);
  const base = {
    token,
    notification: {title, body},
    data: {openUrl: String(clickLink || "")},
  };

  if (resolvedPlatform === "android") {
    return {
      ...base,
      android: {
        priority: "high",
        notification: {
          title,
          body,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          ...(imageUrl ? {imageUrl} : {}),
        },
      },
    };
  }

  if (resolvedPlatform === "ios") {
    return {
      ...base,
      apns: {
        payload: {
          aps: {
            alert: {title, body},
            sound: "default",
          },
        },
        fcmOptions: {
          ...(imageUrl ? {image: imageUrl} : {}),
        },
      },
    };
  }

  // Web (PWA) — explicit webpush block for Chrome / Android PWA background.
  return {
    ...base,
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
 * Send FCM to prepared targets and disable unrecoverable tokens.
 * Title/body may differ per target (localized product alerts).
 *
 * @param {object} options
 * @param {FirebaseFirestore.Firestore} options.db
 * @param {object} options.FieldValue
 * @param {object} options.messaging admin.messaging()
 * @param {string} options.uid
 * @param {object[]} options.targets each {id, token, title, body, platform?}
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
      platform: t.platform,
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
  normalizePushPlatform,
  FCM_UNRECOVERABLE_TOKEN_ERROR_CODES,
  DEFAULT_NOTIFICATION_ICON_URL,
  DEFAULT_NOTIFICATION_BADGE_URL,
  SEND_CHUNK_SIZE,
};
