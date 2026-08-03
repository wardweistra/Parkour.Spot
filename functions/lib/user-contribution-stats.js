/* eslint-disable max-len */
/**
 * Per-user contribution counters for the nightly Users Google Sheets export.
 *
 * Spots/events created via moderator "Create native" deduplication are counted
 * separately and excluded from the regular "added/created" totals (matching
 * profile and admin user stats elsewhere in the app).
 *
 * Improvers are users listed in `contributors` who are not the document creator.
 */

/**
 * Zero-filled contribution stats for one user.
 * @return {{
 *   spotsAdded: number,
 *   spotsImproved: number,
 *   spotsDeduplicated: number,
 *   eventsCreated: number,
 *   eventsImproved: number,
 *   eventsDeduplicated: number,
 * }}
 */
function emptyUserContributionStats() {
  return {
    spotsAdded: 0,
    spotsImproved: 0,
    spotsDeduplicated: 0,
    eventsCreated: 0,
    eventsImproved: 0,
    eventsDeduplicated: 0,
  };
}

/**
 * @param {Map<string, object>} statsByUser
 * @param {string} userId
 * @return {object}
 */
function getOrCreateUserContributionStats(statsByUser, userId) {
  let stats = statsByUser.get(userId);
  if (!stats) {
    stats = emptyUserContributionStats();
    statsByUser.set(userId, stats);
  }
  return stats;
}

/**
 * @param {Map<string, object>} statsByUser
 * @param {string} userId
 * @return {object}
 */
function getUserContributionStats(statsByUser, userId) {
  return statsByUser.get(userId) || emptyUserContributionStats();
}

/**
 * Credit unique improvers from a contributors array, excluding the creator.
 * @param {Map<string, object>} statsByUser
 * @param {unknown} contributors
 * @param {string} createdBy
 * @param {"spotsImproved"|"eventsImproved"} field
 */
function accumulateImprovers(statsByUser, contributors, createdBy, field) {
  if (!Array.isArray(contributors)) {
    return;
  }

  const seen = new Set();
  for (const contributor of contributors) {
    if (!contributor || typeof contributor !== "object") {
      continue;
    }
    const userId = typeof contributor.userId === "string" ?
      contributor.userId.trim() :
      "";
    if (!userId || userId === createdBy || seen.has(userId)) {
      continue;
    }
    seen.add(userId);
    getOrCreateUserContributionStats(statsByUser, userId)[field] += 1;
  }
}

/**
 * Accumulate contribution stats from one spot document.
 * @param {Map<string, object>} statsByUser
 * @param {object|null|undefined} spotData
 */
function accumulateSpotContribution(statsByUser, spotData) {
  if (!spotData || typeof spotData !== "object") {
    return;
  }

  const createdBy = typeof spotData.createdBy === "string" ?
    spotData.createdBy.trim() :
    "";
  const fromCreateNative = spotData.createdFromCreateNative === true;

  if (createdBy) {
    const stats = getOrCreateUserContributionStats(statsByUser, createdBy);
    if (fromCreateNative) {
      stats.spotsDeduplicated += 1;
    } else {
      stats.spotsAdded += 1;
    }
  }

  accumulateImprovers(
      statsByUser,
      spotData.contributors,
      createdBy,
      "spotsImproved",
  );
}

/**
 * Accumulate contribution stats from one event document.
 * @param {Map<string, object>} statsByUser
 * @param {object|null|undefined} eventData
 */
function accumulateEventContribution(statsByUser, eventData) {
  if (!eventData || typeof eventData !== "object") {
    return;
  }

  const createdBy = typeof eventData.createdBy === "string" ?
    eventData.createdBy.trim() :
    "";
  const fromCreateNative = eventData.createdFromCreateNative === true;

  if (createdBy) {
    const stats = getOrCreateUserContributionStats(statsByUser, createdBy);
    if (fromCreateNative) {
      stats.eventsDeduplicated += 1;
    } else {
      stats.eventsCreated += 1;
    }
  }

  accumulateImprovers(
      statsByUser,
      eventData.contributors,
      createdBy,
      "eventsImproved",
  );
}

/**
 * Page through a collection and accumulate contribution stats.
 * @param {object} options
 * @param {object} options.db Firestore instance
 * @param {string} options.collectionName
 * @param {Map<string, object>} options.statsByUser
 * @param {Function} options.accumulate Accumulator for one document's data
 * @param {number=} options.pageSize
 * @return {Promise<number>} documents scanned
 */
async function accumulateContributionsFromCollection({
  db,
  collectionName,
  statsByUser,
  accumulate,
  pageSize = 500,
}) {
  let lastDoc = null;
  let scanned = 0;
  let hasMore = true;

  while (hasMore) {
    let query = db.collection(collectionName)
        .select("createdBy", "createdFromCreateNative", "contributors")
        .limit(pageSize);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();
    if (snapshot.empty) {
      hasMore = false;
      continue;
    }

    snapshot.forEach((doc) => {
      accumulate(statsByUser, doc.data());
    });

    scanned += snapshot.size;
    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < pageSize) {
      hasMore = false;
    }
  }

  return scanned;
}

/**
 * Build per-user contribution stats from spots and events collections.
 * @param {object} db Firestore instance
 * @return {Promise<Map<string, object>>}
 */
async function buildUserContributionStats(db) {
  const statsByUser = new Map();

  const spotsScanned = await accumulateContributionsFromCollection({
    db,
    collectionName: "spots",
    statsByUser,
    accumulate: accumulateSpotContribution,
  });
  const eventsScanned = await accumulateContributionsFromCollection({
    db,
    collectionName: "events",
    statsByUser,
    accumulate: accumulateEventContribution,
  });

  console.log(
      `Contribution stats: scanned ${spotsScanned} spots and ` +
      `${eventsScanned} events for ${statsByUser.size} contributing users`,
  );

  return statsByUser;
}

module.exports = {
  emptyUserContributionStats,
  getOrCreateUserContributionStats,
  getUserContributionStats,
  accumulateSpotContribution,
  accumulateEventContribution,
  accumulateContributionsFromCollection,
  buildUserContributionStats,
};
