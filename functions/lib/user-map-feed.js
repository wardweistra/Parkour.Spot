/* eslint-disable max-len */
/**
 * Per-user secret KML feed for check-ins, training plans, and spot lists.
 */

const {hashApiKey, generateMapToken} = require("./api-helpers");

const MAP_FEEDS_COLLECTION = "mapFeeds";
const MAP_FEED_BY_TOKEN_COLLECTION = "mapFeedByToken";
const PUBLIC_ORIGIN = "https://parkour.spot";
const DOC_NAME = "ParkourSpot — My spots & sessions";
const MY_SPOTS_URL = `${PUBLIC_ORIGIN}/profile/lists`;
const MY_SESSIONS_URL = `${PUBLIC_ORIGIN}/profile/check-ins`;

/** Lower number = higher priority on the map. */
const CATEGORY = {
  CHECKED_IN: "checkedIn",
  PLANNING: "planning",
  WANT_TO_VISIT: "wantToVisit",
  BEEN_TO: "beenTo",
};

const CATEGORY_PRIORITY = {
  [CATEGORY.CHECKED_IN]: 1,
  [CATEGORY.PLANNING]: 2,
  [CATEGORY.WANT_TO_VISIT]: 3,
  [CATEGORY.BEEN_TO]: 4,
};

const CATEGORY_LABEL = {
  [CATEGORY.CHECKED_IN]: "Now checked in at",
  [CATEGORY.PLANNING]: "Planning to train at",
  [CATEGORY.WANT_TO_VISIT]: "Want to visit",
  [CATEGORY.BEEN_TO]: "Been to",
};

const CATEGORY_ICON = {
  [CATEGORY.CHECKED_IN]: `${PUBLIC_ORIGIN}/map-feed/checked-in.png`,
  [CATEGORY.PLANNING]: `${PUBLIC_ORIGIN}/map-feed/planning.png`,
  [CATEGORY.WANT_TO_VISIT]: `${PUBLIC_ORIGIN}/map-feed/want-to-visit.png`,
  [CATEGORY.BEEN_TO]: `${PUBLIC_ORIGIN}/map-feed/been-to.png`,
};

const FOLDER_ORDER = [
  CATEGORY.CHECKED_IN,
  CATEGORY.PLANNING,
  CATEGORY.WANT_TO_VISIT,
  CATEGORY.BEEN_TO,
];

/** Subscription URL serves a NetworkLink; data URL serves placemarks. */
const MAP_FEED_KIND = {
  NETWORK_LINK: "networkLink",
  DATA: "data",
};

/** How often clients should refetch the data KML (seconds). */
const MAP_FEED_REFRESH_INTERVAL_SECONDS = 900;

/**
 * Public subscription URL (NetworkLink KML that points at the data feed).
 * @param {string} token
 * @return {string}
 */
function mapFeedUrl(token) {
  return `${PUBLIC_ORIGIN}/map/${encodeURIComponent(token)}.kml`;
}

/**
 * Live placemark KML fetched by the NetworkLink.
 * @param {string} token
 * @return {string}
 */
function mapFeedDataUrl(token) {
  return `${PUBLIC_ORIGIN}/map/${encodeURIComponent(token)}/data.kml`;
}

/**
 * @param {string} raw
 * @return {string|null}
 */
function decodePathSegment(raw) {
  if (typeof raw !== "string") return null;
  try {
    return decodeURIComponent(raw).trim() || null;
  } catch (e) {
    return raw.trim() || null;
  }
}

/**
 * @param {string} path
 * @return {{token: string, kind: string}|null}
 */
function parseMapFeedPath(path) {
  if (typeof path !== "string") return null;
  const normalized = path.split("?")[0];
  // Prefer data path so /map/{token}/data.kml is not treated as a token.
  const dataMatch = normalized.match(
      /\/map\/([^/]+)\/data(?:\.kml)?\/?$/i,
  );
  if (dataMatch) {
    const token = decodePathSegment(dataMatch[1]);
    return token ? {token, kind: MAP_FEED_KIND.DATA} : null;
  }
  const linkMatch = normalized.match(/\/map\/([^/]+?)(?:\.kml)?\/?$/i);
  if (linkMatch) {
    const token = decodePathSegment(linkMatch[1]);
    return token ? {token, kind: MAP_FEED_KIND.NETWORK_LINK} : null;
  }
  return null;
}

/**
 * @param {string} path
 * @return {string|null}
 */
function extractMapTokenFromPath(path) {
  const parsed = parseMapFeedPath(path);
  return parsed ? parsed.token : null;
}

/**
 * Small KML that clients subscribe to; refreshes from the data URL.
 * @param {string} token
 * @return {string}
 */
function buildNetworkLinkKml(token) {
  const href = escapeXmlText(mapFeedDataUrl(token));
  const name = escapeXmlText(DOC_NAME);
  return [
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<kml xmlns=\"http://www.opengis.net/kml/2.2\">",
    "<NetworkLink>",
    `<name>${name}</name>`,
    "<visibility>1</visibility>",
    "<open>1</open>",
    "<description><![CDATA[" +
      "Live ParkourSpot map (check-ins, plans, Want to visit, Been to). " +
      "Apps that support network link KML refresh this feed automatically." +
      "]]></description>",
    "<Link>",
    `<href>${href}</href>`,
    "<refreshMode>onInterval</refreshMode>",
    `<refreshInterval>${MAP_FEED_REFRESH_INTERVAL_SECONDS}</refreshInterval>`,
    "</Link>",
    "</NetworkLink>",
    "</kml>",
  ].join("");
}

/**
 * @param {string} value
 * @return {string}
 */
function escapeXmlText(value) {
  return String(value)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&apos;");
}

/**
 * @param {*} value
 * @return {Date|null}
 */
function toJsDate(value) {
  if (!value) return null;
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }
  if (typeof value.toDate === "function") {
    const d = value.toDate();
    return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
  }
  if (typeof value === "string" || typeof value === "number") {
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

/**
 * @param {string|null|undefined} value
 * @return {string|null}
 */
function trimmedId(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * @param {Date} date
 * @return {string}
 */
function formatIsoUtc(date) {
  return date.toISOString().replace(/\.\d{3}Z$/, "Z");
}

/**
 * @param {string} spotId
 * @return {string}
 */
function spotUrl(spotId) {
  return `${PUBLIC_ORIGIN}/spot/${encodeURIComponent(spotId)}`;
}

/**
 * @param {Object<string, {category: string, spotId: string, meta: Object}>} bySpot
 * @param {string} spotId
 * @param {string} category
 * @param {Object} meta
 */
function assignCategory(bySpot, spotId, category, meta) {
  const id = trimmedId(spotId);
  if (!id) return;
  const priority = CATEGORY_PRIORITY[category];
  if (!priority) return;
  const existing = bySpot[id];
  if (!existing || priority < CATEGORY_PRIORITY[existing.category]) {
    bySpot[id] = {spotId: id, category, meta: meta || {}};
  }
}

/**
 * @param {Array<Object>} entries
 * @return {Array<Object>}
 */
function sortEntriesForDisplay(entries) {
  return [...entries].sort((a, b) => {
    const pri = CATEGORY_PRIORITY[a.category] - CATEGORY_PRIORITY[b.category];
    if (pri !== 0) return pri;
    const nameA = String(a.name || "").toLowerCase();
    const nameB = String(b.name || "").toLowerCase();
    return nameA.localeCompare(nameB);
  });
}

/**
 * @param {string} category
 * @param {Object} entry
 * @return {string}
 */
function buildPlacemarkDescription(category, entry) {
  const spotLink = spotUrl(entry.spotId);
  const name = escapeXmlText(entry.name || "Spot");
  const lines = [
    `<p><strong>${escapeXmlText(CATEGORY_LABEL[category])}</strong></p>`,
    `<p><a href="${spotLink}">${name}</a></p>`,
  ];
  const meta = entry.meta || {};
  if (category === CATEGORY.CHECKED_IN && meta.expectedEndAt instanceof Date) {
    lines.push(
        `<p>Until ${escapeXmlText(formatIsoUtc(meta.expectedEndAt))}</p>`,
    );
  }
  if (category === CATEGORY.PLANNING) {
    if (meta.plannedStartAt instanceof Date &&
        meta.plannedEndAt instanceof Date) {
      lines.push(
          "<p>Planned " +
          `${escapeXmlText(formatIsoUtc(meta.plannedStartAt))} – ` +
          `${escapeXmlText(formatIsoUtc(meta.plannedEndAt))}</p>`,
      );
    }
  }
  lines.push(
      `<p><a href="${spotLink}">Open spot in ParkourSpot</a></p>`,
  );
  if (category === CATEGORY.CHECKED_IN ||
      category === CATEGORY.PLANNING) {
    lines.push(
        `<p><a href="${MY_SESSIONS_URL}">Manage in My sessions</a></p>`,
    );
  } else {
    lines.push(
        `<p><a href="${MY_SPOTS_URL}">Manage in My spots</a></p>`,
    );
  }
  return lines.join("");
}

/**
 * @param {Object} entry
 * @return {string}
 */
function buildPlacemarkXml(entry) {
  const styleId = `style-${entry.category}`;
  const name = escapeXmlText(entry.name || "Spot");
  const description = buildPlacemarkDescription(entry.category, entry);
  const lat = entry.latitude;
  const lng = entry.longitude;
  return [
    "<Placemark>",
    `<name>${name}</name>`,
    `<styleUrl>#${styleId}</styleUrl>`,
    `<description><![CDATA[${description}]]></description>`,
    "<Point>",
    `<coordinates>${lng},${lat},0</coordinates>`,
    "</Point>",
    "</Placemark>",
  ].join("");
}

/**
 * @return {string}
 */
function buildLegendDescriptionHtml() {
  const items = FOLDER_ORDER.map((cat) => {
    const label = escapeXmlText(CATEGORY_LABEL[cat]);
    const icon = CATEGORY_ICON[cat];
    return `<li><img src="${icon}" alt="" width="24" height="30" ` +
      `style="vertical-align:middle;margin-right:6px"/> ${label}</li>`;
  }).join("");
  return [
    "<p>Live map from your ParkourSpot account. " +
    "Categories are shown in priority order when a spot appears in more " +
    "than one list.</p>",
    `<ul>${items}</ul>`,
    `<p><a href="${MY_SPOTS_URL}">My spots</a> · ` +
    `<a href="${MY_SESSIONS_URL}">My sessions</a></p>`,
    "<p>Updated live when your maps app reloads this network link.</p>",
  ].join("");
}

/**
 * @param {Array<Object>} entries
 * @return {string}
 */
function buildKmlDocument(entries) {
  const styles = FOLDER_ORDER.map((cat) => {
    const icon = escapeXmlText(CATEGORY_ICON[cat]);
    return [
      `<Style id="style-${cat}">`,
      "<IconStyle>",
      "<scale>1</scale>",
      `<Icon><href>${icon}</href></Icon>`,
      "</IconStyle>",
      "</Style>",
    ].join("");
  }).join("");

  const byCategory = Object.fromEntries(
      FOLDER_ORDER.map((cat) => [cat, []]),
  );
  for (const entry of entries) {
    if (byCategory[entry.category]) {
      byCategory[entry.category].push(entry);
    }
  }

  const folders = FOLDER_ORDER.map((cat) => {
    const folderEntries = byCategory[cat];
    if (!folderEntries.length) return "";
    const placemarks = folderEntries.map(buildPlacemarkXml).join("");
    return [
      "<Folder>",
      `<name>${escapeXmlText(CATEGORY_LABEL[cat])}</name>`,
      placemarks,
      "</Folder>",
    ].join("");
  }).join("");

  return [
    "<?xml version=\"1.0\" encoding=\"UTF-8\"?>",
    "<kml xmlns=\"http://www.opengis.net/kml/2.2\">",
    "<Document>",
    `<name>${escapeXmlText(DOC_NAME)}</name>`,
    `<description><![CDATA[${buildLegendDescriptionHtml()}]]></description>`,
    styles,
    folders,
    "</Document>",
    "</kml>",
  ].join("");
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @param {Date} now
 * @return {Promise<Object<string, {category: string, spotId: string, meta: Object}>>}
 */
async function loadSpotCategoriesForUser(db, userId, now) {
  const bySpot = {};

  const threshold = now;
  const checkInsSnap = await db.collection("spotCheckIns")
      .where("userId", "==", userId)
      .where("expectedEndAt", ">=", threshold)
      .orderBy("expectedEndAt", "desc")
      .limit(100)
      .get();

  for (const doc of checkInsSnap.docs) {
    const data = doc.data() || {};
    const spotId = trimmedId(data.spotId);
    const checkedInAt = toJsDate(data.checkedInAt);
    const expectedEndAt = toJsDate(data.expectedEndAt);
    if (!spotId || !checkedInAt || !expectedEndAt) continue;
    if (now < checkedInAt || now > expectedEndAt) continue;
    assignCategory(bySpot, spotId, CATEGORY.CHECKED_IN, {
      expectedEndAt,
      spotName: trimmedId(data.spotName),
    });
  }

  const plansSnap = await db.collection("spotTrainingPlans")
      .where("userId", "==", userId)
      .where("plannedEndAt", ">=", threshold)
      .orderBy("plannedEndAt", "desc")
      .limit(100)
      .get();

  for (const doc of plansSnap.docs) {
    const data = doc.data() || {};
    const spotId = trimmedId(data.spotId);
    const plannedEndAt = toJsDate(data.plannedEndAt);
    if (!spotId || !plannedEndAt || plannedEndAt <= now) continue;
    assignCategory(bySpot, spotId, CATEGORY.PLANNING, {
      plannedStartAt: toJsDate(data.plannedStartAt),
      plannedEndAt,
      spotName: trimmedId(data.spotName),
    });
  }

  const userSnap = await db.collection("users").doc(userId).get();
  const userData = userSnap.exists ? (userSnap.data() || {}) : {};
  const want = Array.isArray(userData.wantToVisit) ? userData.wantToVisit : [];
  const visited = Array.isArray(userData.visited) ? userData.visited : [];

  for (const rawId of want) {
    assignCategory(bySpot, rawId, CATEGORY.WANT_TO_VISIT, {});
  }
  for (const rawId of visited) {
    assignCategory(bySpot, rawId, CATEGORY.BEEN_TO, {});
  }

  return bySpot;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object<string, Object>} spotsById
 * @param {string} spotId
 * @return {Promise<Object|null>}
 */
async function resolveSpotRecord(db, spotsById, spotId) {
  const id = trimmedId(spotId);
  if (!id) return null;
  if (spotsById[id]) return spotsById[id];

  const snap = await db.collection("spots").doc(id).get();
  if (!snap.exists) return null;
  const record = {id, ...snap.data()};
  spotsById[id] = record;

  const nativeId = trimmedId(record.duplicateOf);
  if (nativeId && !spotsById[nativeId]) {
    const nativeSnap = await db.collection("spots").doc(nativeId).get();
    if (nativeSnap.exists) {
      spotsById[nativeId] = {id: nativeId, ...nativeSnap.data()};
    }
  }
  return record;
}

/**
 * @param {Object} record
 * @param {Object<string, Object>} spotsById
 * @return {{latitude: number, longitude: number, name: string, linkSpotId: string}|null}
 */
function spotDisplayFromRecord(record, spotsById) {
  if (!record) return null;
  let lat = typeof record.latitude === "number" ? record.latitude :
    Number(record.latitude);
  let lng = typeof record.longitude === "number" ? record.longitude :
    Number(record.longitude);
  let name = trimmedId(record.name) || "Spot";
  let linkSpotId = trimmedId(record.id) || trimmedId(record.spotId);

  const nativeId = trimmedId(record.duplicateOf);
  if (nativeId && spotsById[nativeId]) {
    const native = spotsById[nativeId];
    linkSpotId = nativeId;
    if (!Number.isFinite(lat) || !Number.isFinite(lng) ||
        (lat === 0 && lng === 0)) {
      lat = Number(native.latitude);
      lng = Number(native.longitude);
    }
    if (!trimmedId(record.name) && trimmedId(native.name)) {
      name = native.name;
    }
  }

  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  if (Math.abs(lat) > 90 || Math.abs(lng) > 180) return null;
  if (lat === 0 && lng === 0) return null;
  if (!linkSpotId) return null;

  return {latitude: lat, longitude: lng, name, linkSpotId};
}

/**
 * @param {Object<string, {category: string, spotId: string, meta: Object}>} bySpot
 * @param {Object<string, Object>} spotsById
 * @return {Array<Object>}
 */
function entriesFromCategories(bySpot, spotsById) {
  const entries = [];
  for (const item of Object.values(bySpot)) {
    const record = spotsById[item.spotId];
    const display = spotDisplayFromRecord(record, spotsById);
    if (!display) continue;
    const metaName = trimmedId(item.meta?.spotName);
    entries.push({
      category: item.category,
      spotId: display.linkSpotId,
      name: metaName || display.name,
      latitude: display.latitude,
      longitude: display.longitude,
      meta: item.meta,
    });
  }
  return sortEntriesForDisplay(entries);
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @return {Promise<Array<Object>>}
 */
async function loadFeedEntriesForUser(db, userId) {
  const now = new Date();
  const bySpot = await loadSpotCategoriesForUser(db, userId, now);
  const spotIds = Object.keys(bySpot);
  if (spotIds.length === 0) return [];

  const spotsById = {};
  const chunkSize = 30;
  for (let i = 0; i < spotIds.length; i += chunkSize) {
    const chunk = spotIds.slice(i, i + chunkSize);
    await Promise.all(chunk.map(async (spotId) => {
      await resolveSpotRecord(db, spotsById, spotId);
    }));
  }

  return entriesFromCategories(bySpot, spotsById);
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {*} FieldValue
 * @param {string} userId
 * @return {Promise<{token: string, url: string, created: boolean}>}
 */
async function getOrCreateMapFeed(db, FieldValue, userId) {
  const feedRef = db.collection(MAP_FEEDS_COLLECTION).doc(userId);
  const existing = await feedRef.get();
  if (existing.exists) {
    const data = existing.data() || {};
    const token = trimmedId(data.token);
    if (token) {
      return {token, url: mapFeedUrl(token), created: false};
    }
  }

  const token = generateMapToken();
  const tokenHash = hashApiKey(token);
  const batch = db.batch();
  batch.set(feedRef, {
    token,
    tokenHash,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  batch.set(db.collection(MAP_FEED_BY_TOKEN_COLLECTION).doc(tokenHash), {
    userId,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {token, url: mapFeedUrl(token), created: true};
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {*} FieldValue
 * @param {string} userId
 * @return {Promise<{token: string, url: string}>}
 */
async function regenerateMapFeed(db, FieldValue, userId) {
  const feedRef = db.collection(MAP_FEEDS_COLLECTION).doc(userId);
  const existing = await feedRef.get();
  const oldHash = existing.exists ?
    trimmedId((existing.data() || {}).tokenHash) :
    null;

  const token = generateMapToken();
  const tokenHash = hashApiKey(token);
  const batch = db.batch();
  if (oldHash && oldHash !== tokenHash) {
    batch.delete(db.collection(MAP_FEED_BY_TOKEN_COLLECTION).doc(oldHash));
  }
  batch.set(feedRef, {
    token,
    tokenHash,
    createdAt: existing.exists ?
      ((existing.data() || {}).createdAt || FieldValue.serverTimestamp()) :
      FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  batch.set(db.collection(MAP_FEED_BY_TOKEN_COLLECTION).doc(tokenHash), {
    userId,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  return {token, url: mapFeedUrl(token)};
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} token
 * @return {Promise<string|null>} userId
 */
async function resolveUserIdFromMapToken(db, token) {
  const trimmed = trimmedId(token);
  if (!trimmed) return null;
  const tokenHash = hashApiKey(trimmed);
  const snap = await db
      .collection(MAP_FEED_BY_TOKEN_COLLECTION)
      .doc(tokenHash)
      .get();
  if (!snap.exists) return null;
  return trimmedId((snap.data() || {}).userId);
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} userId
 * @return {Promise<string>}
 */
async function buildKmlForUser(db, userId) {
  const entries = await loadFeedEntriesForUser(db, userId);
  return buildKmlDocument(entries);
}

module.exports = {
  MAP_FEEDS_COLLECTION,
  MAP_FEED_BY_TOKEN_COLLECTION,
  PUBLIC_ORIGIN,
  DOC_NAME,
  MY_SPOTS_URL,
  MY_SESSIONS_URL,
  CATEGORY,
  CATEGORY_PRIORITY,
  CATEGORY_LABEL,
  MAP_FEED_KIND,
  MAP_FEED_REFRESH_INTERVAL_SECONDS,
  mapFeedUrl,
  mapFeedDataUrl,
  parseMapFeedPath,
  extractMapTokenFromPath,
  escapeXmlText,
  assignCategory,
  sortEntriesForDisplay,
  buildNetworkLinkKml,
  buildKmlDocument,
  buildLegendDescriptionHtml,
  loadFeedEntriesForUser,
  getOrCreateMapFeed,
  regenerateMapFeed,
  resolveUserIdFromMapToken,
  buildKmlForUser,
  spotDisplayFromRecord,
};
