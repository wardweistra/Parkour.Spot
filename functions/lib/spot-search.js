const {spotSearchTermDocId} = require("./text-processing");
const {isEventPast} = require("./event-map-pins");

const TERM_QUERY_LIMIT = 200;
const PURGE_BATCH_SIZE = 450;

/**
 * Deletes all documents in a search-terms collection (batched).
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} collectionName
 * @return {Promise<number>}
 */
async function purgeSearchTermsCollection(db, collectionName) {
  let totalDeleted = 0;
  let hasMore = true;
  while (hasMore) {
    const snapshot = await db.collection(collectionName)
        .limit(PURGE_BATCH_SIZE)
        .get();
    if (snapshot.empty) {
      hasMore = false;
      break;
    }
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    totalDeleted += snapshot.size;
    hasMore = snapshot.size >= PURGE_BATCH_SIZE;
  }
  return totalDeleted;
}

/**
 * Mirrors map/explore spot visibility (duplicateOf null, not hidden, has name).
 * @param {Object|null|undefined} spotData
 * @return {boolean}
 */
function isSpotSearchIndexEligible(spotData) {
  if (!spotData || typeof spotData !== "object") return false;
  if (spotData.hidden === true) return false;
  const duplicateOf = spotData.duplicateOf;
  if (typeof duplicateOf === "string" && duplicateOf.trim().length > 0) {
    return false;
  }
  const spotName = typeof spotData.name === "string" ?
    spotData.name.trim() :
    "";
  return spotName.length > 0;
}

/**
 * Mirrors map pins and event autocomplete eligibility.
 * @param {Object|null|undefined} eventData
 * @param {Date=} now
 * @return {boolean}
 */
function isEventSearchIndexEligible(eventData, now = new Date()) {
  if (!eventData || typeof eventData !== "object") return false;
  if (eventData.hidden === true) return false;
  const duplicateOf = eventData.duplicateOf;
  if (typeof duplicateOf === "string" && duplicateOf.trim().length > 0) {
    return false;
  }
  if (isEventPast(eventData, now)) return false;
  if (!eventData.startAt) return false;
  const eventTitle = typeof eventData.title === "string" ?
    eventData.title.trim() :
    "";
  return eventTitle.length > 0;
}

/**
 * @param {Map<string, number>} spotIdToMatchCount
 * @param {number} requiredTokenCount
 * @return {Object}
 */
function pickSpotIdsForTitleSearch(spotIdToMatchCount, requiredTokenCount) {
  const spotsWithAll = [...spotIdToMatchCount.entries()]
      .filter(([, count]) => count === requiredTokenCount)
      .map(([id]) => id);
  if (spotsWithAll.length > 0) {
    return {spotIds: spotsWithAll, useFullTokenMatchOnly: true, spotsWithAll};
  }
  const spotIds = [...spotIdToMatchCount.entries()]
      .sort((a, b) => b[1] - a[1])
      .map(([id]) => id);
  return {spotIds, useFullTokenMatchOnly: false, spotsWithAll: []};
}

/**
 * When any token query hits the limit, verify extra tokens for candidates from
 * complete (non-truncated) token result sets.
 *
 * @param {string[]} tokens
 * @param {Object[]} tokenResults
 * @param {Function} hasTerm
 * @return {Promise<Object>}
 */
async function buildSpotIdMatchCounts(tokens, tokenResults, hasTerm) {
  const anyHitLimit = tokenResults.some((r) => r.hitLimit);
  if (!anyHitLimit || tokens.length < 2) {
    const spotIdToMatchCount = new Map();
    for (const {spotIds} of tokenResults) {
      for (const spotId of spotIds) {
        const prev = spotIdToMatchCount.get(spotId) || 0;
        spotIdToMatchCount.set(spotId, prev + 1);
      }
    }
    return {spotIdToMatchCount, refined: false};
  }

  const completeResults = tokenResults.filter((r) => !r.hitLimit);
  const candidateSpotIds = new Set();
  if (completeResults.length > 0) {
    for (const tr of completeResults) {
      for (const spotId of tr.spotIds) {
        candidateSpotIds.add(spotId);
      }
    }
  } else {
    let smallest = tokenResults[0];
    for (const tr of tokenResults) {
      if (tr.spotIds.size < smallest.spotIds.size) {
        smallest = tr;
      }
    }
    for (const spotId of smallest.spotIds) {
      candidateSpotIds.add(spotId);
    }
  }

  const spotIdToMatchCount = new Map();
  for (const spotId of candidateSpotIds) {
    let matchCount = 0;
    for (const token of tokens) {
      const tr = tokenResults.find((r) => r.token === token);
      if (!tr) continue;
      if (tr.spotIds.has(spotId)) {
        matchCount++;
      } else if (hasTerm && await hasTerm(spotId, token)) {
        matchCount++;
      }
    }
    if (matchCount > 0) {
      spotIdToMatchCount.set(spotId, matchCount);
    }
  }
  return {spotIdToMatchCount, refined: true};
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} spotId
 * @param {string} token
 * @return {Promise<boolean>}
 */
async function spotHasSearchTerm(db, spotId, token) {
  const docId = spotSearchTermDocId(spotId, token);
  const ref = db.collection("spotSearchTerms").doc(docId);
  const doc = await ref.get();
  return doc.exists;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} token
 * @return {Promise<Object>}
 */
async function querySpotIdsForSearchToken(db, token) {
  const queryEnd = token + "\uf8ff";
  const termsSnapshot = await db.collection("spotSearchTerms")
      .where("term", ">=", token)
      .where("term", "<", queryEnd)
      .limit(TERM_QUERY_LIMIT)
      .get();
  const spotIds = new Set();
  let missingSpotId = 0;
  termsSnapshot.docs.forEach((doc) => {
    const spotId = doc.data().spotId;
    if (!spotId) {
      missingSpotId++;
      return;
    }
    spotIds.add(spotId);
  });
  return {
    token,
    spotIds,
    termDocs: termsSnapshot.size,
    hitLimit: termsSnapshot.size >= TERM_QUERY_LIMIT,
    missingSpotId,
  };
}

/**
 * @param {FirebaseFirestore.DocumentSnapshot[]} spotDocs
 * @param {Map<string, number>} spotIdToMatchCount
 * @return {Object}
 */
function collectSpotMatchResults(spotDocs, spotIdToMatchCount) {
  const matches = [];
  const filteredOut = [];
  const canonicalFromDuplicate = new Map();
  const seenIds = new Set();

  spotDocs.forEach((doc) => {
    const matchCount = spotIdToMatchCount.get(doc.id) || 0;
    if (!doc.exists) {
      filteredOut.push({spotId: doc.id, matchCount, reason: "not_exists"});
      return;
    }
    const data = doc.data();
    if (data.duplicateOf) {
      filteredOut.push({
        spotId: doc.id,
        matchCount,
        reason: "duplicateOf",
        duplicateOf: data.duplicateOf,
      });
      const canonicalId = data.duplicateOf;
      const prev = canonicalFromDuplicate.get(canonicalId) || 0;
      canonicalFromDuplicate.set(canonicalId, Math.max(prev, matchCount));
      return;
    }
    if (data.hidden) {
      filteredOut.push({spotId: doc.id, matchCount, reason: "hidden"});
      return;
    }
    const name = typeof data.name === "string" ? data.name.trim() : "";
    if (!name) {
      filteredOut.push({spotId: doc.id, matchCount, reason: "empty_name"});
      return;
    }
    if (seenIds.has(doc.id)) return;
    seenIds.add(doc.id);
    const ranking = typeof data.ranking === "number" ? data.ranking : 0;
    matches.push({id: doc.id, ...data, ranking, matchCount});
  });

  return {matches, filteredOut, canonicalFromDuplicate};
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {Map<string, number>} canonicalFromDuplicate
 * @param {Set<string>} seenIds
 * @return {Promise<Object[]>}
 */
async function fetchCanonicalSpotsFromDuplicates(
    db,
    canonicalFromDuplicate,
    seenIds,
) {
  const canonicalIds = [...canonicalFromDuplicate.keys()]
      .filter((id) => !seenIds.has(id));
  if (canonicalIds.length === 0) return [];

  const refs = canonicalIds.map((id) => db.collection("spots").doc(id));
  const docs = await db.getAll(...refs);
  const resolved = [];
  docs.forEach((doc) => {
    if (!doc.exists) return;
    const data = doc.data();
    if (data.duplicateOf || data.hidden) return;
    const name = typeof data.name === "string" ? data.name.trim() : "";
    if (!name) return;
    const ranking = typeof data.ranking === "number" ? data.ranking : 0;
    const matchCount = canonicalFromDuplicate.get(doc.id) || 0;
    resolved.push({id: doc.id, ...data, ranking, matchCount});
    seenIds.add(doc.id);
  });
  return resolved;
}

module.exports = {
  TERM_QUERY_LIMIT,
  PURGE_BATCH_SIZE,
  purgeSearchTermsCollection,
  isSpotSearchIndexEligible,
  isEventSearchIndexEligible,
  pickSpotIdsForTitleSearch,
  buildSpotIdMatchCounts,
  spotHasSearchTerm,
  querySpotIdsForSearchToken,
  collectSpotMatchResults,
  fetchCanonicalSpotsFromDuplicates,
};
