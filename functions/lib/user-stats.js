/* eslint-disable max-len */
/**
 * Per-user contribution totals in `userStats/{uid}`, read by the profile and
 * the yearly review.
 *
 * Document shape:
 *   {
 *     allTime: {<key>: number, ...},
 *     years: {"2026": {<key>: number, ...}, ...},
 *     updatedAt: Timestamp,
 *   }
 *
 * Every number is recomputed from its source collection (no incremental
 * counters), so a recompute is idempotent and repairs any drift. Triggers only
 * recompute `allTime` and the current UTC year; earlier years stay frozen once
 * the year is over. `backfillUserStats` recomputes every year since
 * [FIRST_STATS_YEAR].
 *
 * Only contributions others can see are counted: private check-ins, private
 * training plans and private lists are left out. Spots and events created via
 * moderator "Create native" deduplication are moderation work, not
 * contributions: they are excluded from added/created and not stored here
 * (the admin Sheets export counts them, see `user-contribution-stats.js`).
 */

const USER_STATS_COLLECTION = "userStats";

/** First year with contributions; backfill starts here. */
const FIRST_STATS_YEAR = 2025;

/** Matches Flutter `SpotService.anonymousContributorUserId`. */
const ANONYMOUS_USER_ID = "__anonymous__";

const USER_STATS_KEYS = Object.freeze([
  "spotsAdded",
  "spotsImproved",
  "photosAdded",
  "eventsCreated",
  "eventsImproved",
  "ratings",
  "lists",
  "checkIns",
  "trainingPlans",
]);

/**
 * Per source collection: which field names the contributing user, and which
 * fields affect that user's counts. A write that changes none of them (a sync
 * touching `updatedAt`, a rating's comment edit) triggers no recompute.
 */
const WATCHED_SOURCES = Object.freeze({
  spots: {userField: "createdBy", fields: ["createdFromCreateNative", "createdAt"]},
  events: {userField: "createdBy", fields: ["createdFromCreateNative", "createdAt"]},
  ratings: {userField: "userId", fields: ["createdAt"]},
  spotLists: {userField: "createdBy", fields: ["visibility", "createdAt"]},
  spotCheckIns: {userField: "userId", fields: ["isPrivate", "checkedInAt"]},
  spotTrainingPlans: {userField: "userId", fields: ["isPrivate", "plannedStartAt"]},
  spotReports: {
    userField: "reporterUserId",
    fields: ["spotId", "acceptedEditFields", "acceptedPhotoUrls", "updatedAt"],
  },
  eventReports: {
    userField: "reporterUserId",
    fields: ["status", "targetEventId", "reviewedAt"],
  },
});

/**
 * Counts that are "all docs by the user, minus an excluded subset", optionally
 * limited to a year by [dateField]. Subtracting handles docs that predate the
 * excluded flag (e.g. check-ins without `isPrivate`).
 */
const COUNT_SOURCES = Object.freeze([
  {
    collection: "spots",
    userField: "createdBy",
    dateField: "createdAt",
    split: {field: "createdFromCreateNative", value: true},
    restKey: "spotsAdded",
  },
  {
    collection: "events",
    userField: "createdBy",
    dateField: "createdAt",
    split: {field: "createdFromCreateNative", value: true},
    restKey: "eventsCreated",
  },
  {
    collection: "ratings",
    userField: "userId",
    dateField: "createdAt",
    restKey: "ratings",
  },
  {
    collection: "spotLists",
    userField: "createdBy",
    dateField: "createdAt",
    split: {field: "visibility", value: "private"},
    restKey: "lists",
  },
  {
    collection: "spotCheckIns",
    userField: "userId",
    dateField: "checkedInAt",
    split: {field: "isPrivate", value: true},
    restKey: "checkIns",
  },
  {
    collection: "spotTrainingPlans",
    userField: "userId",
    dateField: "plannedStartAt",
    split: {field: "isPrivate", value: true},
    restKey: "trainingPlans",
  },
]);

/**
 * @return {Object<string, number>} Every stats key set to 0.
 */
function emptyUserStats() {
  const stats = {};
  for (const key of USER_STATS_KEYS) stats[key] = 0;
  return stats;
}

/**
 * @param {Object<string, number>} stats
 * @return {boolean}
 */
function hasAnyContribution(stats) {
  return USER_STATS_KEYS.some((key) => (stats[key] || 0) > 0);
}

/**
 * @param {unknown} value
 * @return {string|null} Trimmed real user id, or null for empty/anonymous.
 */
function normalizeUserId(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed || trimmed === ANONYMOUS_USER_ID) return null;
  return trimmed;
}

/**
 * UTC calendar year bounds.
 * @param {number} year
 * @return {{start: Date, end: Date}} `start` inclusive, `end` exclusive.
 */
function utcYearRange(year) {
  return {
    start: new Date(Date.UTC(year, 0, 1)),
    end: new Date(Date.UTC(year + 1, 0, 1)),
  };
}

/**
 * @param {Date=} now
 * @return {number}
 */
function currentUtcYear(now = new Date()) {
  return now.getUTCFullYear();
}

/**
 * @param {number} fromYear
 * @param {number} toYear
 * @return {number[]}
 */
function yearsBetween(fromYear, toYear) {
  const years = [];
  for (let year = fromYear; year <= toYear; year++) years.push(year);
  return years;
}

/**
 * @param {unknown} value Firestore Timestamp, Date, or millis.
 * @return {Date|null}
 */
function toDate(value) {
  if (!value) return null;
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value === "number") return new Date(value);
  return null;
}

/**
 * @param {unknown} a
 * @param {unknown} b
 * @return {boolean}
 */
function sameValue(a, b) {
  const dateA = toDate(a);
  const dateB = toDate(b);
  if (dateA || dateB) {
    return !!dateA && !!dateB && dateA.getTime() === dateB.getTime();
  }
  return JSON.stringify(a === undefined ? null : a) ===
    JSON.stringify(b === undefined ? null : b);
}

/**
 * Users whose stats a write to [collection] may have changed.
 * @param {string} collection
 * @param {Object|null} before Data before the write (null on create).
 * @param {Object|null} after Data after the write (null on delete).
 * @return {string[]}
 */
function userIdsAffectedByWrite(collection, before, after) {
  const source = WATCHED_SOURCES[collection];
  if (!source) return [];
  const beforeUser = before ? normalizeUserId(before[source.userField]) : null;
  const afterUser = after ? normalizeUserId(after[source.userField]) : null;

  if (!before || !after) {
    return [beforeUser || afterUser].filter(Boolean);
  }
  if (beforeUser !== afterUser) {
    return [beforeUser, afterUser].filter(Boolean);
  }
  if (!afterUser) return [];
  const changed = source.fields.some(
      (field) => !sameValue(before[field], after[field]),
  );
  return changed ? [afterUser] : [];
}

/**
 * @param {Object} db Firestore
 * @param {string} collection
 * @param {Array<[string, string, unknown]>} filters
 * @return {Promise<number>}
 */
async function countMatching(db, collection, filters) {
  let query = db.collection(collection);
  for (const [field, op, value] of filters) {
    query = query.where(field, op, value);
  }
  const snapshot = await query.count().get();
  return snapshot.data().count || 0;
}

/**
 * Adds the [COUNT_SOURCES] counts for one user and scope to [stats].
 * @param {Object} db Firestore
 * @param {string} userId
 * @param {{start: Date, end: Date}|null} range Null for all time.
 * @param {Object<string, number>} stats Mutated.
 * @return {Promise<void>}
 */
async function addCountSourceStats(db, userId, range, stats) {
  await Promise.all(COUNT_SOURCES.map(async (source) => {
    const filters = [[source.userField, "==", userId]];
    if (range) {
      filters.push([source.dateField, ">=", range.start]);
      filters.push([source.dateField, "<", range.end]);
    }
    const total = await countMatching(db, source.collection, filters);
    let splitCount = 0;
    if (source.split && total > 0) {
      splitCount = await countMatching(db, source.collection, [
        filters[0],
        [source.split.field, "==", source.split.value],
        ...filters.slice(1),
      ]);
    }
    stats[source.restKey] += Math.max(0, total - splitCount);
  }));
}

/**
 * @param {unknown} value
 * @return {string[]} Unique non-empty strings.
 */
function uniqueStrings(value) {
  if (!Array.isArray(value)) return [];
  return [...new Set(
      value.filter((v) => typeof v === "string" && v.trim()).map((v) => v.trim()),
  )];
}

/**
 * @param {Date|null} date
 * @return {string|null}
 */
function yearKeyOf(date) {
  return date ? String(date.getUTCFullYear()) : null;
}

/**
 * Improvements and photos from one user's spot and event reports.
 *
 * - `spotsImproved`: distinct spots where the user had at least one suggested
 *   edit accepted. Dated by the report's `updatedAt` (the review write).
 * - `photosAdded`: accepted photo URLs across the user's spot reports.
 * - `eventsImproved`: distinct events with an approved edit report from the
 *   user. Dated by `reviewedAt`, falling back to `updatedAt`.
 *
 * @param {Array<Object>} spotReports Data of the user's spot reports.
 * @param {Array<Object>} eventReports Data of the user's event reports.
 * @return {{
 *   allTime: Object<string, number>,
 *   years: Object<string, Object<string, number>>,
 * }} Only the report-derived keys are set.
 */
function reportStatsFromReports(spotReports, eventReports) {
  const allTime = {spotsImproved: 0, photosAdded: 0, eventsImproved: 0};
  const years = {};
  const yearStats = (yearKey) => {
    if (!years[yearKey]) {
      years[yearKey] = {spotsImproved: 0, photosAdded: 0, eventsImproved: 0};
    }
    return years[yearKey];
  };

  const improvedSpots = new Set();
  const improvedSpotsByYear = new Map();
  for (const report of spotReports) {
    if (!report) continue;
    const yearKey = yearKeyOf(toDate(report.updatedAt) || toDate(report.createdAt));
    const photoCount = uniqueStrings(report.acceptedPhotoUrls).length;
    if (photoCount > 0) {
      allTime.photosAdded += photoCount;
      if (yearKey) yearStats(yearKey).photosAdded += photoCount;
    }
    const spotId = typeof report.spotId === "string" ? report.spotId.trim() : "";
    if (!spotId || uniqueStrings(report.acceptedEditFields).length === 0) continue;
    improvedSpots.add(spotId);
    if (yearKey) {
      if (!improvedSpotsByYear.has(yearKey)) improvedSpotsByYear.set(yearKey, new Set());
      improvedSpotsByYear.get(yearKey).add(spotId);
    }
  }
  allTime.spotsImproved = improvedSpots.size;
  for (const [yearKey, spotIds] of improvedSpotsByYear) {
    yearStats(yearKey).spotsImproved = spotIds.size;
  }

  const improvedEvents = new Set();
  const improvedEventsByYear = new Map();
  for (const report of eventReports) {
    if (!report || report.status !== "Approved") continue;
    const eventId = typeof report.targetEventId === "string" ?
      report.targetEventId.trim() :
      "";
    if (!eventId) continue;
    improvedEvents.add(eventId);
    const yearKey = yearKeyOf(toDate(report.reviewedAt) || toDate(report.updatedAt));
    if (yearKey) {
      if (!improvedEventsByYear.has(yearKey)) improvedEventsByYear.set(yearKey, new Set());
      improvedEventsByYear.get(yearKey).add(eventId);
    }
  }
  allTime.eventsImproved = improvedEvents.size;
  for (const [yearKey, eventIds] of improvedEventsByYear) {
    yearStats(yearKey).eventsImproved = eventIds.size;
  }

  return {allTime, years};
}

/**
 * @param {Object} db Firestore
 * @param {string} collection
 * @param {string} userId
 * @param {string[]} fields
 * @return {Promise<Array<Object>>}
 */
async function readReportsByUser(db, collection, userId, fields) {
  const snapshot = await db.collection(collection)
      .where("reporterUserId", "==", userId)
      .select(...fields)
      .get();
  return snapshot.docs.map((doc) => doc.data());
}

/**
 * Computes one user's stats for all time and each of [years].
 * @param {Object} db Firestore
 * @param {string} userId
 * @param {number[]} years
 * @return {Promise<{
 *   allTime: Object<string, number>,
 *   years: Object<string, Object<string, number>>,
 * }>}
 */
async function computeUserStats(db, userId, years) {
  const [spotReports, eventReports] = await Promise.all([
    readReportsByUser(db, "spotReports", userId, [
      "spotId", "acceptedEditFields", "acceptedPhotoUrls", "updatedAt", "createdAt",
    ]),
    readReportsByUser(db, "eventReports", userId, [
      "status", "targetEventId", "reviewedAt", "updatedAt",
    ]),
  ]);
  const reportStats = reportStatsFromReports(spotReports, eventReports);

  const allTime = {...emptyUserStats(), ...reportStats.allTime};
  const yearStats = {};
  for (const year of years) {
    yearStats[String(year)] = {
      ...emptyUserStats(),
      ...(reportStats.years[String(year)] || {}),
    };
  }

  await Promise.all([
    addCountSourceStats(db, userId, null, allTime),
    ...years.map((year) => addCountSourceStats(
        db, userId, utcYearRange(year), yearStats[String(year)],
    )),
  ]);

  return {allTime, years: yearStats};
}

/**
 * Recomputes and stores `userStats/{userId}` for all time and [years].
 * Skips creating a document for users with no contributions.
 * @param {Object} db Firestore
 * @param {Object} FieldValue
 * @param {string} userId
 * @param {Object=} options
 * @param {number[]=} options.years Defaults to the current UTC year only, so
 *     finished years stay frozen.
 * @param {Date=} options.now
 * @return {Promise<{written: boolean, stats: Object}>}
 */
async function recomputeUserStats(db, FieldValue, userId, options = {}) {
  const normalizedUserId = normalizeUserId(userId);
  if (!normalizedUserId) return {written: false, stats: null};
  const years = options.years || [currentUtcYear(options.now)];
  const stats = await computeUserStats(db, normalizedUserId, years);

  const ref = db.collection(USER_STATS_COLLECTION).doc(normalizedUserId);
  if (!hasAnyContribution(stats.allTime)) {
    const existing = await ref.get();
    if (!existing.exists) return {written: false, stats};
  }

  await ref.set({
    allTime: stats.allTime,
    years: stats.years,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  return {written: true, stats};
}

/**
 * Trigger entry point: recompute every user a write may have affected.
 * Never throws; stats must not break the source write's other triggers.
 * @param {Object} db Firestore
 * @param {Object} FieldValue
 * @param {string} collection
 * @param {Object|null} before
 * @param {Object|null} after
 * @return {Promise<string[]>} Recomputed user ids.
 */
async function handleUserStatsSourceWrite(db, FieldValue, collection, before, after) {
  const userIds = userIdsAffectedByWrite(collection, before, after);
  for (const userId of userIds) {
    try {
      await recomputeUserStats(db, FieldValue, userId);
    } catch (error) {
      console.error("recomputeUserStats failed", {
        collection,
        userId,
        error: error && error.message ? error.message : error,
      });
    }
  }
  return userIds;
}

/**
 * Recomputes every user's stats for every year since [FIRST_STATS_YEAR], in
 * pages of `users` documents. Resumable: pass the returned `nextCursor` back
 * as `startAfter` until it is null.
 * @param {Object} db Firestore
 * @param {Object} FieldValue
 * @param {Object=} options
 * @param {string=} options.startAfter User id to resume after.
 * @param {number=} options.timeBudgetMs
 * @param {number=} options.pageSize
 * @param {number=} options.concurrency
 * @param {Date=} options.now
 * @return {Promise<{
 *   processed: number,
 *   written: number,
 *   failed: number,
 *   nextCursor: (string|null),
 * }>}
 */
async function backfillUserStats(db, FieldValue, options = {}) {
  const {
    startAfter = null,
    timeBudgetMs = 480000,
    pageSize = 100,
    concurrency = 8,
    now = new Date(),
  } = options;
  const years = yearsBetween(FIRST_STATS_YEAR, currentUtcYear(now));
  const deadline = Date.now() + timeBudgetMs;
  let cursor = startAfter;
  let processed = 0;
  let written = 0;
  let failed = 0;

  while (Date.now() < deadline) {
    let query = db.collection("users").orderBy("__name__").select().limit(pageSize);
    if (cursor) query = query.startAfter(cursor);
    const snapshot = await query.get();
    if (snapshot.empty) return {processed, written, failed, nextCursor: null};

    const ids = snapshot.docs.map((doc) => doc.id);
    for (let i = 0; i < ids.length; i += concurrency) {
      const results = await Promise.allSettled(
          ids.slice(i, i + concurrency).map(
              (userId) => recomputeUserStats(db, FieldValue, userId, {years}),
          ),
      );
      for (const result of results) {
        processed++;
        if (result.status === "rejected") {
          failed++;
          console.error("backfillUserStats user failed", result.reason);
        } else if (result.value.written) {
          written++;
        }
      }
    }
    cursor = ids[ids.length - 1];
    if (snapshot.size < pageSize) {
      return {processed, written, failed, nextCursor: null};
    }
  }
  return {processed, written, failed, nextCursor: cursor};
}

module.exports = {
  USER_STATS_COLLECTION,
  USER_STATS_KEYS,
  FIRST_STATS_YEAR,
  WATCHED_SOURCES,
  emptyUserStats,
  hasAnyContribution,
  utcYearRange,
  userIdsAffectedByWrite,
  reportStatsFromReports,
  computeUserStats,
  recomputeUserStats,
  handleUserStatsSourceWrite,
  backfillUserStats,
};
