/* eslint-disable max-len */
/**
 * Email preferences and signed unsubscribe links.
 *
 * Preferences live on `users/{uid}.emailPrefs`:
 *   {
 *     newsletter: boolean,            // Wrapped and other newsletter-style mail
 *     newsletterUpdatedAt: Timestamp, // when the person last changed it
 *   }
 * A missing key means the category's default. Future per-event email
 * notifications add categories here (e.g. `eventsNearby`, default false) so
 * the same toggle, unsubscribe link and send-time check cover them.
 *
 * Unsubscribe links carry `u` (uid), `c` (category) and `t`, an HMAC of both
 * with EMAIL_UNSUBSCRIBE_SECRET. They never expire: an old email's link must
 * keep working.
 */

const crypto = require("crypto");

const PUBLIC_ORIGIN = "https://parkour.spot";
const UNSUBSCRIBE_PATH = "/email/unsubscribe";

/** Category key → default when the person never chose. */
const EMAIL_CATEGORIES = Object.freeze({
  newsletter: Object.freeze({defaultEnabled: true}),
});

/**
 * @param {unknown} category
 * @return {boolean}
 */
function isKnownEmailCategory(category) {
  return typeof category === "string" &&
    Object.prototype.hasOwnProperty.call(EMAIL_CATEGORIES, category);
}

/**
 * @param {Object|null|undefined} userData `users/{uid}` data.
 * @param {string} category
 * @return {boolean} Whether the person gets this category's email.
 */
function isEmailCategoryEnabled(userData, category) {
  if (!isKnownEmailCategory(category)) return false;
  const prefs = userData && typeof userData.emailPrefs === "object" && userData.emailPrefs ?
    userData.emailPrefs :
    {};
  const value = prefs[category];
  return typeof value === "boolean" ? value : EMAIL_CATEGORIES[category].defaultEnabled;
}

/**
 * @param {string} uid
 * @param {string} category
 * @param {string} secret
 * @return {string} base64url HMAC
 */
function signUnsubscribeToken(uid, category, secret) {
  if (!secret) throw new Error("EMAIL_UNSUBSCRIBE_SECRET is not set");
  return crypto.createHmac("sha256", secret)
      .update(`unsubscribe:${uid}:${category}`)
      .digest("base64url");
}

/**
 * @param {Object} params `{u, c, t}` from the link.
 * @param {string} secret
 * @return {{uid: string, category: string}|null}
 */
function verifyUnsubscribeParams(params, secret) {
  const uid = typeof params.u === "string" ? params.u.trim() : "";
  const category = typeof params.c === "string" ? params.c.trim() : "";
  const token = typeof params.t === "string" ? params.t.trim() : "";
  if (!uid || !/^[A-Za-z0-9_-]{1,128}$/.test(uid)) return null;
  if (!isKnownEmailCategory(category) || !token || !secret) return null;
  const expected = Buffer.from(signUnsubscribeToken(uid, category, secret));
  const given = Buffer.from(token);
  if (expected.length !== given.length) return null;
  return crypto.timingSafeEqual(expected, given) ? {uid, category} : null;
}

/**
 * @param {string} uid
 * @param {string} category
 * @param {string} secret
 * @return {string} Absolute unsubscribe URL.
 */
function unsubscribeUrl(uid, category, secret) {
  const query = new URLSearchParams({
    u: uid,
    c: category,
    t: signUnsubscribeToken(uid, category, secret),
  });
  return `${PUBLIC_ORIGIN}${UNSUBSCRIBE_PATH}?${query.toString()}`;
}

/**
 * Headers for one-click unsubscribe (RFC 8058), required by Gmail and Yahoo
 * for bulk senders.
 * @param {string} url From [unsubscribeUrl].
 * @return {Object<string, string>}
 */
function listUnsubscribeHeaders(url) {
  return {
    "List-Unsubscribe": `<${url}>`,
    "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
  };
}

/**
 * Turns a category on or off. Idempotent.
 * @param {Object} db Firestore
 * @param {Object} FieldValue
 * @param {string} uid
 * @param {string} category
 * @param {boolean} enabled
 * @return {Promise<boolean>} False when the user no longer exists.
 */
async function setEmailCategory(db, FieldValue, uid, category, enabled) {
  const ref = db.collection("users").doc(uid);
  const snap = await ref.get();
  if (!snap.exists) return false;
  await ref.set({
    emailPrefs: {
      [category]: enabled,
      [`${category}UpdatedAt`]: FieldValue.serverTimestamp(),
    },
  }, {merge: true});
  return true;
}

module.exports = {
  EMAIL_CATEGORIES,
  UNSUBSCRIBE_PATH,
  isKnownEmailCategory,
  isEmailCategoryEnabled,
  signUnsubscribeToken,
  verifyUnsubscribeParams,
  unsubscribeUrl,
  listUnsubscribeHeaders,
  setEmailCategory,
};
