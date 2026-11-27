/* eslint-disable max-len */
/**
 * Data for the yearly review share card: who, which spots, which counts.
 *
 * Counts come from `userStats/{uid}.years.<year>` (lib/user-stats.js). The
 * photo frames come from the spots the person touched that year, most
 * meaningful first: spots they added, spots they added photos to, spots they
 * improved, spots they trained at, spots they rated.
 */

const {utcYearRange} = require("./user-stats");

/** Kinds that put a spot on the card, in priority order. */
const SPOT_KIND_PRIORITY = Object.freeze([
  "spotsAdded",
  "photosAdded",
  "spotsImproved",
  "checkIns",
  "ratings",
]);

/** Counts shown under the sentence, in priority order (first four non-zero). */
const COUNT_PRIORITY = Object.freeze([
  "spotsAdded",
  "photosAdded",
  "spotsImproved",
  "ratings",
  "checkIns",
  "eventsCreated",
  "eventsImproved",
  "lists",
]);

/** Kinds that can carry the lead sentence on their own. */
const LEAD_KINDS = Object.freeze([
  "spotsAdded",
  "photosAdded",
  "ratings",
  "checkIns",
  "eventsCreated",
]);

/** A kind leads the sentence when it is at least this share of the total. */
const LEAD_DOMINANCE = 0.75;

const MAX_FRAMES = 9;

/**
 * @param {unknown} value
 * @return {Date|null}
 */
function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") return value.toDate();
  return null;
}

/**
 * @param {unknown} value
 * @return {string}
 */
function trimmed(value) {
  return typeof value === "string" ? value.trim() : "";
}

/**
 * Up to [limit] non-zero counts in display order.
 * @param {Object<string, number>} stats
 * @param {number=} limit
 * @return {Array<{key: string, count: number}>}
 */
function pickCounts(stats, limit = 4) {
  return COUNT_PRIORITY
      .map((key) => ({key, count: Number(stats[key]) || 0}))
      .filter((entry) => entry.count > 0)
      .slice(0, limit);
}

/**
 * Which kind the lead sentence is about, and the number it names.
 * One kind leads when it dominates; otherwise the sentence counts the
 * distinct spots touched ("shaped 31 spots").
 * @param {Object<string, number>} stats
 * @param {number} distinctSpots
 * @return {{kind: string, count: number}}
 */
function pickLead(stats, distinctSpots) {
  const entries = LEAD_KINDS
      .map((kind) => ({kind, count: Number(stats[kind]) || 0}))
      .filter((entry) => entry.count > 0)
      .sort((a, b) => b.count - a.count);
  const total = COUNT_PRIORITY.reduce((sum, key) => sum + (Number(stats[key]) || 0), 0);
  const top = entries[0];
  if (top && (entries.length === 1 || top.count / total >= LEAD_DOMINANCE)) {
    return top;
  }
  if (distinctSpots > 0) return {kind: "mixed", count: distinctSpots};
  return top || {kind: "mixed", count: 0};
}

/**
 * Orders touched spots by kind priority, then by date, one entry per spot.
 * @param {Array<Object>} touches `{spotId, kind, date, photoUrls?}` entries.
 * @return {Array<{spotId: string, kind: string, date: (Date|null), photoUrls: string[]}>}
 */
function orderTouches(touches) {
  const rank = (kind) => {
    const index = SPOT_KIND_PRIORITY.indexOf(kind);
    return index === -1 ? SPOT_KIND_PRIORITY.length : index;
  };
  const sorted = [...touches].sort((a, b) =>
    rank(a.kind) - rank(b.kind) ||
    ((a.date ? a.date.getTime() : 0) - (b.date ? b.date.getTime() : 0)),
  );
  const seen = new Map();
  for (const touch of sorted) {
    if (!touch.spotId) continue;
    const existing = seen.get(touch.spotId);
    if (!existing) {
      seen.set(touch.spotId, {...touch, photoUrls: [...(touch.photoUrls || [])]});
    } else if (touch.photoUrls && touch.photoUrls.length) {
      existing.photoUrls.push(...touch.photoUrls);
    }
  }
  return [...seen.values()];
}

/**
 * The most frequent cities among touched spots.
 * @param {Array<Object>} spots Entries with an optional `city`.
 * @param {number=} limit
 * @return {string[]}
 */
function topCities(spots, limit = 3) {
  const counts = new Map();
  for (const spot of spots) {
    const city = trimmed(spot.city);
    if (city) counts.set(city, (counts.get(city) || 0) + 1);
  }
  return [...counts.entries()]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      .slice(0, limit)
      .map(([city]) => city);
}

/**
 * Every spot a user touched in [year], with the kind that put it on the card.
 * @param {Object} db Firestore
 * @param {string} userId
 * @param {number} year
 * @return {Promise<Array<{spotId: string, kind: string, date: (Date|null), photoUrls: string[]}>>}
 */
async function readYearTouches(db, userId, year) {
  const {start, end} = utcYearRange(year);
  const inYear = (date) => !!date && date >= start && date < end;
  const range = (query, field) => query.where(field, ">=", start).where(field, "<", end);

  const [added, reports, checkIns, ratings] = await Promise.all([
    range(db.collection("spots").where("createdBy", "==", userId), "createdAt")
        .select("createdAt", "createdFromCreateNative").get(),
    db.collection("spotReports").where("reporterUserId", "==", userId)
        .select("spotId", "acceptedEditFields", "acceptedPhotoUrls", "updatedAt").get(),
    range(db.collection("spotCheckIns").where("userId", "==", userId), "checkedInAt")
        .select("spotId", "checkedInAt", "isPrivate").get(),
    range(db.collection("ratings").where("userId", "==", userId), "createdAt")
        .select("spotId", "createdAt").get(),
  ]);

  const touches = [];
  for (const doc of added.docs) {
    const data = doc.data();
    if (data.createdFromCreateNative === true) continue;
    touches.push({spotId: doc.id, kind: "spotsAdded", date: toDate(data.createdAt)});
  }
  for (const doc of reports.docs) {
    const data = doc.data();
    const date = toDate(data.updatedAt);
    const spotId = trimmed(data.spotId);
    if (!spotId || !inYear(date)) continue;
    const photoUrls = Array.isArray(data.acceptedPhotoUrls) ?
      data.acceptedPhotoUrls.filter((url) => typeof url === "string" && url) :
      [];
    if (photoUrls.length) {
      touches.push({spotId, kind: "photosAdded", date, photoUrls});
    } else if (Array.isArray(data.acceptedEditFields) && data.acceptedEditFields.length) {
      touches.push({spotId, kind: "spotsImproved", date});
    }
  }
  for (const doc of checkIns.docs) {
    const data = doc.data();
    if (data.isPrivate === true) continue;
    touches.push({spotId: trimmed(data.spotId), kind: "checkIns", date: toDate(data.checkedInAt)});
  }
  for (const doc of ratings.docs) {
    const data = doc.data();
    touches.push({spotId: trimmed(data.spotId), kind: "ratings", date: toDate(data.createdAt)});
  }
  return orderTouches(touches);
}

/**
 * Spot docs for [spotIds] (name, city, images); missing and hidden skipped.
 * @param {Object} db Firestore
 * @param {string[]} spotIds
 * @return {Promise<Map<string, {name: string, city: string, imageUrls: string[]}>>}
 */
async function readSpots(db, spotIds) {
  const spots = new Map();
  for (let i = 0; i < spotIds.length; i += 100) {
    const refs = spotIds.slice(i, i + 100).map((id) => db.collection("spots").doc(id));
    const snapshots = await db.getAll(...refs, {
      fieldMask: ["name", "city", "imageUrls", "hidden"],
    });
    for (const snapshot of snapshots) {
      if (!snapshot.exists) continue;
      const data = snapshot.data() || {};
      if (data.hidden === true) continue;
      spots.set(snapshot.id, {
        name: trimmed(data.name),
        city: trimmed(data.city),
        imageUrls: Array.isArray(data.imageUrls) ?
          data.imageUrls.filter((url) => typeof url === "string" && url) :
          [],
      });
    }
  }
  return spots;
}

/**
 * Resolves a public profile by uid or username.
 * @param {Object} db Firestore
 * @param {string} userIdOrUsername
 * @return {Promise<{userId: string, profile: Object}|null>} Null when missing
 *     or private.
 */
async function resolvePublicProfile(db, userIdOrUsername) {
  const key = trimmed(userIdOrUsername).replace(/^@/, "");
  if (!key) return null;
  const byId = await db.collection("publicProfiles").doc(key).get();
  let doc = byId.exists ? byId : null;
  if (!doc) {
    const byUsername = await db.collection("publicProfiles")
        .where("username", "==", key.toLowerCase()).limit(1).get();
    doc = byUsername.empty ? null : byUsername.docs[0];
  }
  if (!doc) return null;
  const profile = doc.data() || {};
  if (profile.isPublicProfile === false) return null;
  return {userId: doc.id, profile};
}

/**
 * Everything the card needs, or null when there is no card to show (private
 * profile, or nothing contributed that year).
 * @param {Object} db Firestore
 * @param {Object} options
 * @param {string} options.userIdOrUsername
 * @param {number} options.year
 * @return {Promise<Object|null>}
 */
async function buildYearReviewData(db, {userIdOrUsername, year}) {
  const resolved = await resolvePublicProfile(db, userIdOrUsername);
  if (!resolved) return null;
  return buildForProfile(db, {...resolved, year, isPublicProfile: true});
}

/**
 * Same data for a known uid, whatever the profile's visibility. For the
 * person themselves (the yearly review email), never for public pages.
 * `isPublicProfile` tells the caller whether the public page and card exist.
 * @param {Object} db Firestore
 * @param {Object} options
 * @param {string} options.userId
 * @param {number} options.year
 * @return {Promise<Object|null>} Null when nothing was contributed that year.
 */
async function buildYearReviewDataForUser(db, {userId, year}) {
  const profileDoc = await db.collection("publicProfiles").doc(userId).get();
  const profile = profileDoc.exists ? profileDoc.data() || {} : {};
  const isPublicProfile = profileDoc.exists && profile.isPublicProfile !== false;
  return buildForProfile(db, {userId, profile, year, isPublicProfile});
}

/**
 * @param {Object} db Firestore
 * @param {{userId: string, profile: Object, year: number, isPublicProfile: boolean}} options
 * @return {Promise<Object|null>}
 */
async function buildForProfile(db, {userId, profile, year, isPublicProfile}) {
  const [statsDoc, userDoc, touches] = await Promise.all([
    db.collection("userStats").doc(userId).get(),
    db.collection("users").doc(userId).get(),
    readYearTouches(db, userId, year),
  ]);
  const yearStats = ((statsDoc.exists && statsDoc.data().years) || {})[String(year)] || {};
  const counts = pickCounts(yearStats);
  if (counts.length === 0) return null;

  const spotsById = await readSpots(db, touches.map((touch) => touch.spotId));
  const touchedSpots = touches
      .filter((touch) => spotsById.has(touch.spotId))
      .map((touch) => {
        const spot = spotsById.get(touch.spotId);
        // Prefer the person's own photo of the spot when they added one.
        const imageUrl = touch.photoUrls.find((url) => spot.imageUrls.includes(url)) ||
          spot.imageUrls[0] || null;
        return {...touch, ...spot, imageUrl};
      });

  const withImages = touchedSpots.filter((spot) => spot.imageUrl);
  const overflow = withImages.length > MAX_FRAMES;
  const frames = withImages.slice(0, overflow ? MAX_FRAMES - 1 : MAX_FRAMES);

  const userData = userDoc.exists ? userDoc.data() || {} : {};
  const name = trimmed(profile.displayName) || trimmed(profile.username) ||
    trimmed(userData.displayName) || "";
  return {
    userId,
    isPublicProfile,
    year,
    name,
    username: trimmed(profile.username) || null,
    preferredLocale: trimmed(userData.preferredLanguageCode) || null,
    counts,
    lead: pickLead(yearStats, touchedSpots.length),
    places: topCities(touchedSpots),
    frames: frames.map(({spotId, kind, date, name: spotName, city, imageUrl}) => ({
      spotId,
      kind,
      date,
      name: spotName,
      city,
      imageUrl,
    })),
    moreCount: overflow ? withImages.length - frames.length : 0,
  };
}

module.exports = {
  MAX_FRAMES,
  pickCounts,
  pickLead,
  orderTouches,
  topCities,
  readYearTouches,
  resolvePublicProfile,
  buildYearReviewData,
  buildYearReviewDataForUser,
};
