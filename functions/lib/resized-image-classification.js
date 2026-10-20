/* eslint-disable max-len */
/**
 * Inventory-based classification of spot/event resized images.
 * Lists Storage resized/ prefixes once and classifies Firestore imageUrls
 * as has1200 | only630 | none without per-object metadata checks.
 */

const {getResizedPathInfo} = require("./url-helpers");

const STATUS_HAS_1200 = "has1200";
const STATUS_ONLY_630 = "only630";
const STATUS_NONE = "none";

/**
 * Empty basename inventory for spots and events resized variants.
 * @return {Object}
 */
function emptyResizedBasenameSets() {
  return {
    spots1200: new Set(),
    spots630: new Set(),
    events1200: new Set(),
    events630: new Set(),
  };
}

/**
 * Parses a resized object name under spots/resized/ or events/resized/.
 * @param {string} objectName Full object path, e.g. spots/resized/photo_1200x1200.webp
 * @return {Object|null}
 */
function parseResizedObjectName(objectName) {
  if (typeof objectName !== "string" || !objectName) return null;
  let prefix = null;
  let fileName = null;
  if (objectName.startsWith("spots/resized/")) {
    prefix = "spots";
    fileName = objectName.slice("spots/resized/".length);
  } else if (objectName.startsWith("events/resized/")) {
    prefix = "events";
    fileName = objectName.slice("events/resized/".length);
  } else {
    return null;
  }
  if (!fileName || fileName.endsWith("/")) return null;
  if (fileName.endsWith("_1200x1200.webp")) {
    return {
      prefix,
      baseName: fileName.slice(0, -"_1200x1200.webp".length),
      size: "1200",
    };
  }
  if (fileName.endsWith("_1200x630.webp")) {
    return {
      prefix,
      baseName: fileName.slice(0, -"_1200x630.webp".length),
      size: "630",
    };
  }
  return null;
}

/**
 * Adds one Storage object to basename sets when it is a known resized variant.
 * @param {Object} sets Basename sets from emptyResizedBasenameSets()
 * @param {string} objectName Storage object path
 */
function addResizedObjectToSets(sets, objectName) {
  const parsed = parseResizedObjectName(objectName);
  if (!parsed) return;
  const {prefix, baseName, size} = parsed;
  if (prefix === "spots") {
    if (size === "1200") sets.spots1200.add(baseName);
    else sets.spots630.add(baseName);
  } else if (size === "1200") {
    sets.events1200.add(baseName);
  } else {
    sets.events630.add(baseName);
  }
}

/**
 * Lists spots/resized/ and events/resized/ and builds basename sets.
 * @param {Object} bucket Cloud Storage bucket
 * @return {Promise<Object>}
 */
async function buildResizedBasenameSets(bucket) {
  const sets = emptyResizedBasenameSets();
  for (const prefix of ["spots/resized/", "events/resized/"]) {
    await new Promise((resolve, reject) => {
      const stream = bucket.getFilesStream({prefix});
      stream.on("data", (file) => {
        if (file && file.name) addResizedObjectToSets(sets, file.name);
      });
      stream.on("error", reject);
      stream.on("end", resolve);
    });
  }
  return sets;
}

/**
 * Classifies a Firestore image URL against resized basename inventory.
 * @param {string} url Image URL
 * @param {Object} sets Basename sets
 * @return {Object|null} null when URL is not a resizable spots/events Storage URL
 */
function classifyImageUrl(url, sets) {
  const info = getResizedPathInfo(url);
  if (!info) return null;
  const prefix = info.originalPath.startsWith("events/") ? "events" : "spots";
  const fileName = info.originalPath.split("/").pop() || "";
  const baseName = fileName.replace(/\.[^.]+$/, "");
  const has1200 = prefix === "spots" ?
    sets.spots1200.has(baseName) :
    sets.events1200.has(baseName);
  const has630 = prefix === "spots" ?
    sets.spots630.has(baseName) :
    sets.events630.has(baseName);
  let status = STATUS_NONE;
  if (has1200) status = STATUS_HAS_1200;
  else if (has630) status = STATUS_ONLY_630;
  return {
    status,
    originalPath: info.originalPath,
    resizedPath: info.resizedPath,
    baseName,
    prefix,
  };
}

/**
 * True when the image has no resized variant at all (needs resize trigger).
 * @param {string} url Image URL
 * @param {Object} sets Basename sets
 * @return {boolean}
 */
function needsResizeTrigger(url, sets) {
  const classified = classifyImageUrl(url, sets);
  return classified != null && classified.status === STATUS_NONE;
}

/**
 * @param {string} kind spot or event
 * @param {Object} doc Firestore-shaped doc with id and imageUrls
 * @param {Object} sets Basename sets
 * @param {Object} out Mutable accumulator
 */
function classifyDocIntoReport(kind, doc, sets, out) {
  const urls = Array.isArray(doc.imageUrls) ? doc.imageUrls : [];
  const noneUrls = [];
  let only630Count = 0;
  for (const url of urls) {
    if (typeof url !== "string" || !url.trim()) continue;
    const classified = classifyImageUrl(url, sets);
    if (!classified) continue;
    out.imageCounts[classified.status]++;
    if (classified.status === STATUS_HAS_1200) {
      out.entityFlags.has1200.add(doc.id);
    } else if (classified.status === STATUS_ONLY_630) {
      out.entityFlags.only630.add(doc.id);
      only630Count++;
    } else {
      out.entityFlags.none.add(doc.id);
      noneUrls.push(url);
    }
  }
  if (noneUrls.length > 0) {
    const key = `${kind}:${doc.id}`;
    out.noneRows.set(key, {
      kind,
      id: doc.id,
      name: doc.name || "",
      city: doc.city || "",
      countryCode: doc.countryCode || "",
      imageUrls: noneUrls,
    });
  }
  if (only630Count > 0) {
    const key = `${kind}:${doc.id}`;
    out.only630Rows.set(key, {
      kind,
      id: doc.id,
      name: doc.name || "",
      city: doc.city || "",
      countryCode: doc.countryCode || "",
      count: only630Count,
    });
  }
}

/**
 * @param {Object} imageCounts Per-status image counts
 * @param {Object} entityFlags Per-status entity id sets
 * @return {Object}
 */
function statusSummary(imageCounts, entityFlags) {
  return {
    has1200: {
      images: imageCounts.has1200,
      entities: entityFlags.has1200.size,
    },
    only630: {
      images: imageCounts.only630,
      entities: entityFlags.only630.size,
    },
    none: {
      images: imageCounts.none,
      entities: entityFlags.none.size,
    },
  };
}

/**
 * Builds the callable response from Firestore-shaped docs + basename sets.
 * @param {Object} input sets, spotDocs, eventDocs
 * @return {Object}
 */
function buildClassificationReport({sets, spotDocs, eventDocs}) {
  const spotsOut = {
    imageCounts: {has1200: 0, only630: 0, none: 0},
    noneRows: new Map(),
    only630Rows: new Map(),
    entityFlags: {
      has1200: new Set(),
      only630: new Set(),
      none: new Set(),
    },
  };
  const eventsOut = {
    imageCounts: {has1200: 0, only630: 0, none: 0},
    noneRows: new Map(),
    only630Rows: new Map(),
    entityFlags: {
      has1200: new Set(),
      only630: new Set(),
      none: new Set(),
    },
  };

  for (const doc of spotDocs || []) {
    classifyDocIntoReport("spot", doc, sets, spotsOut);
  }
  for (const doc of eventDocs || []) {
    classifyDocIntoReport("event", doc, sets, eventsOut);
  }

  const spotsSummary = statusSummary(spotsOut.imageCounts, spotsOut.entityFlags);
  const eventsSummary = statusSummary(eventsOut.imageCounts, eventsOut.entityFlags);

  return {
    summary: {
      spots: spotsSummary,
      events: eventsSummary,
      totals: {
        has1200: {
          images: spotsSummary.has1200.images + eventsSummary.has1200.images,
          entities: spotsSummary.has1200.entities + eventsSummary.has1200.entities,
        },
        only630: {
          images: spotsSummary.only630.images + eventsSummary.only630.images,
          entities: spotsSummary.only630.entities + eventsSummary.only630.entities,
        },
        none: {
          images: spotsSummary.none.images + eventsSummary.none.images,
          entities: spotsSummary.none.entities + eventsSummary.none.entities,
        },
      },
    },
    none: [
      ...spotsOut.noneRows.values(),
      ...eventsOut.noneRows.values(),
    ],
    only630: [
      ...spotsOut.only630Rows.values(),
      ...eventsOut.only630Rows.values(),
    ],
  };
}

module.exports = {
  STATUS_HAS_1200,
  STATUS_ONLY_630,
  STATUS_NONE,
  emptyResizedBasenameSets,
  parseResizedObjectName,
  addResizedObjectToSets,
  buildResizedBasenameSets,
  classifyImageUrl,
  needsResizeTrigger,
  buildClassificationReport,
};
