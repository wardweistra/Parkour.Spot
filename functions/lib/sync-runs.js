/**
 * Durable sync-run records for spot and event sync observability.
 * Written only by Cloud Functions; clients read via admin-only Firestore rules.
 */

const SOURCE_KIND_SPOT = "spot";
const SOURCE_KIND_EVENT = "event";

const STATUS_RUNNING = "running";
const STATUS_SUCCEEDED = "succeeded";
const STATUS_FAILED = "failed";

const SYNC_TYPE_LIGHT = "light";
const SYNC_TYPE_FULL = "full";
const SYNC_TYPE_EVENT = "sync";

const TRIGGER_MANUAL = "manual";
const TRIGGER_SCHEDULED = "scheduled";
const TRIGGER_RESUME = "resume";

const ISSUE_YOUTUBE_MISSING_THUMBNAIL = "youtube_missing_thumbnail";
const ISSUE_YOUTUBE_UNCACHED_THUMBNAIL = "youtube_uncached_thumbnail";

/**
 * @return {Object} Empty cumulative stats for a spot sync run
 */
function emptySpotStats() {
  return {
    total: 0,
    created: 0,
    updated: 0,
    unchanged: 0,
    removed: 0,
    skipped: 0,
    geocoded: 0,
    geocodingFailed: 0,
    geocodingSuccessRate: "0%",
  };
}

/**
 * @return {Object} Empty cumulative stats for an event sync run
 */
function emptyEventStats() {
  return {
    totalParsed: 0,
    totalUnique: 0,
    duplicatesInFeed: 0,
    duplicatesRemoved: 0,
    created: 0,
    changed: 0,
    unchanged: 0,
    coordinatesBackfilled: 0,
    imagesBackfilled: 0,
    placeBackfilled: 0,
  };
}

/**
 * Resolves a run id from a source document (pointer or syncProgress).
 * @param {Object} source
 * @return {string|null}
 */
function resolveRunIdFromSource(source) {
  if (!source || typeof source !== "object") {
    return null;
  }
  if (typeof source.currentSyncRunId === "string" &&
      source.currentSyncRunId.trim().length > 0) {
    return source.currentSyncRunId.trim();
  }
  const progressRunId = source.syncProgress && source.syncProgress.runId;
  if (typeof progressRunId === "string" && progressRunId.trim().length > 0) {
    return progressRunId.trim();
  }
  return null;
}

/**
 * Builds geocodingSuccessRate from cumulative counters.
 * @param {Object} stats
 * @return {string}
 */
function formatGeocodingSuccessRate(stats) {
  const total = typeof stats.total === "number" ? stats.total : 0;
  const geocoded = typeof stats.geocoded === "number" ? stats.geocoded : 0;
  if (total <= 0) {
    return "0%";
  }
  return ((geocoded / total) * 100).toFixed(1) + "%";
}

/**
 * Creates a new syncRuns document and returns its id.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} FieldValue
 * @param {Object} params
 * @return {Promise<string>}
 */
async function createSyncRun(db, FieldValue, params) {
  const {
    sourceKind,
    sourceId,
    sourceName,
    syncType,
    trigger = TRIGGER_MANUAL,
    stats = null,
  } = params;

  const initialStats = stats || (
    sourceKind === SOURCE_KIND_EVENT ? emptyEventStats() : emptySpotStats()
  );

  const ref = db.collection("syncRuns").doc();
  await ref.set({
    sourceKind,
    sourceId,
    sourceName: sourceName || sourceId,
    syncType,
    status: STATUS_RUNNING,
    trigger,
    startedAt: FieldValue.serverTimestamp(),
    finishedAt: null,
    invocationCount: 1,
    stats: initialStats,
    added: [],
    updated: [],
    removed: [],
    issues: [],
    errorMessage: null,
  });
  return ref.id;
}

/**
 * Loads a sync run document.
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} runId
 * @return {Promise<{id: string, data: Object}|null>}
 */
async function loadSyncRun(db, runId) {
  if (typeof runId !== "string" || runId.trim().length === 0) {
    return null;
  }
  const snap = await db.collection("syncRuns").doc(runId.trim()).get();
  if (!snap.exists) {
    return null;
  }
  return {id: snap.id, data: snap.data() || {}};
}

/**
 * Increments invocationCount on an existing run and returns loaded data.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} FieldValue
 * @param {string} runId
 * @return {Promise<{id: string, data: Object}|null>}
 */
async function bumpInvocation(db, FieldValue, runId) {
  const ref = db.collection("syncRuns").doc(runId);
  await ref.update({
    invocationCount: FieldValue.increment(1),
    status: STATUS_RUNNING,
  });
  return loadSyncRun(db, runId);
}

/**
 * Persists cumulative progress onto a running sync run (partial or mid-batch).
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} runId
 * @param {Object} progress
 * @return {Promise<void>}
 */
async function persistRunningProgress(db, runId, progress) {
  const {
    stats,
    added = [],
    updated = [],
    removed = [],
    issues = [],
  } = progress;

  const update = {
    status: STATUS_RUNNING,
    added,
    updated,
    removed,
    issues,
  };
  if (stats && typeof stats === "object") {
    update.stats = {
      ...stats,
      geocodingSuccessRate: formatGeocodingSuccessRate(stats),
    };
  }
  await db.collection("syncRuns").doc(runId).update(update);
}

/**
 * Marks a sync run succeeded and updates source pointers.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} FieldValue
 * @param {Object} params
 * @return {Promise<Object>} Final stats written to the run
 */
async function finalizeSyncRunSucceeded(db, FieldValue, params) {
  const {
    runId,
    sourceRef,
    stats,
    added = [],
    updated = [],
    removed = [],
    issues = [],
    sourceExtraUpdate = {},
  } = params;

  const finalStats = stats && typeof stats === "object" ? {
    ...stats,
    geocodingSuccessRate: Object.prototype.hasOwnProperty.call(
        stats,
        "geocodingSuccessRate",
    ) ?
      stats.geocodingSuccessRate :
      formatGeocodingSuccessRate(stats),
  } : {};

  await db.collection("syncRuns").doc(runId).update({
    status: STATUS_SUCCEEDED,
    finishedAt: FieldValue.serverTimestamp(),
    stats: finalStats,
    added,
    updated,
    removed,
    issues,
    errorMessage: null,
  });

  await sourceRef.update({
    ...sourceExtraUpdate,
    lastSyncAt: FieldValue.serverTimestamp(),
    lastSyncStats: finalStats,
    lastCompletedRunId: runId,
    currentSyncRunId: FieldValue.delete(),
    lastError: FieldValue.delete(),
  });

  return finalStats;
}

/**
 * Marks a sync run failed and updates source pointers.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} FieldValue
 * @param {Object} params
 * @return {Promise<void>}
 */
async function failSyncRun(db, FieldValue, params) {
  const {
    runId,
    sourceRef,
    errorMessage,
    clearInProgress = true,
    stats = null,
    added = null,
    updated = null,
    removed = null,
    issues = null,
  } = params;

  const message = typeof errorMessage === "string" && errorMessage.length > 0 ?
    errorMessage.slice(0, 2000) :
    "Unknown sync error";

  if (runId) {
    const runUpdate = {
      status: STATUS_FAILED,
      finishedAt: FieldValue.serverTimestamp(),
      errorMessage: message,
    };
    if (stats && typeof stats === "object") {
      runUpdate.stats = {
        ...stats,
        geocodingSuccessRate: formatGeocodingSuccessRate(stats),
      };
    }
    if (Array.isArray(added)) runUpdate.added = added;
    if (Array.isArray(updated)) runUpdate.updated = updated;
    if (Array.isArray(removed)) runUpdate.removed = removed;
    if (Array.isArray(issues)) runUpdate.issues = issues;

    try {
      await db.collection("syncRuns").doc(runId).update(runUpdate);
    } catch (error) {
      console.error(`Failed to mark sync run ${runId} as failed:`, error);
    }
  }

  const sourceUpdate = {
    lastError: {
      message,
      at: FieldValue.serverTimestamp(),
    },
    currentSyncRunId: FieldValue.delete(),
  };
  if (runId) {
    sourceUpdate.lastFailedRunId = runId;
  }

  if (clearInProgress) {
    sourceUpdate.syncInProgress = false;
    sourceUpdate.syncProgress = FieldValue.delete();
    sourceUpdate.syncType = FieldValue.delete();
    sourceUpdate.syncStartedAt = FieldValue.delete();
  }

  try {
    await sourceRef.update(sourceUpdate);
  } catch (error) {
    console.error("Failed to update source after sync failure:", error);
  }
}

/**
 * Restores in-memory spot counters from a persisted run document.
 * @param {Object} runData
 * @return {Object}
 */
function restoreSpotProgressFromRun(runData) {
  const stats = runData && runData.stats && typeof runData.stats === "object" ?
    runData.stats :
    emptySpotStats();
  return {
    created: Number(stats.created) || 0,
    updated: Number(stats.updated) || 0,
    unchanged: Number(stats.unchanged) || 0,
    removed: Number(stats.removed) || 0,
    skipped: Number(stats.skipped) || 0,
    geocoded: Number(stats.geocoded) || 0,
    geocodingFailed: Number(stats.geocodingFailed) || 0,
    added: Array.isArray(runData.added) ? [...runData.added] : [],
    updatedSummaries: Array.isArray(runData.updated) ?
      [...runData.updated] : [],
    removedSummaries: Array.isArray(runData.removed) ?
      [...runData.removed] : [],
    issues: Array.isArray(runData.issues) ? [...runData.issues] : [],
  };
}

/**
 * Builds a plain-text report string (shared shape with Flutter copy action).
 * Pure helper for tests / server-side use.
 * @param {Object} run
 * @return {string}
 */
function formatSyncRunReportText(run) {
  if (!run || typeof run !== "object") {
    return "";
  }
  const lines = [];
  lines.push(`Source: ${run.sourceName || run.sourceId || "unknown"}`);
  lines.push(`Kind: ${run.sourceKind || "unknown"}`);
  lines.push(`Type: ${run.syncType || "unknown"}`);
  lines.push(`Status: ${run.status || "unknown"}`);
  if (run.invocationCount != null) {
    lines.push(`Invocations: ${run.invocationCount}`);
  }
  if (run.errorMessage) {
    lines.push(`Error: ${run.errorMessage}`);
  }
  if (run.stats && typeof run.stats === "object") {
    lines.push("Stats:");
    for (const [key, value] of Object.entries(run.stats)) {
      lines.push(`  ${key}: ${value}`);
    }
  }
  const listSection = (title, items) => {
    if (!Array.isArray(items) || items.length === 0) return;
    lines.push(`${title} (${items.length}):`);
    for (const item of items) {
      if (item && typeof item === "object") {
        lines.push(`  - ${item.name || item.id || JSON.stringify(item)}`);
      } else {
        lines.push(`  - ${item}`);
      }
    }
  };
  listSection("Added", run.added);
  listSection("Updated", run.updated);
  listSection("Removed", run.removed);
  if (Array.isArray(run.issues) && run.issues.length > 0) {
    lines.push(`Issues (${run.issues.length}):`);
    for (const issue of run.issues) {
      if (!issue || typeof issue !== "object") {
        lines.push(`  - ${issue}`);
        continue;
      }
      const parts = [
        issue.type,
        issue.videoId,
        issue.spotName,
        issue.reason,
      ].filter((p) => p != null && String(p).length > 0);
      lines.push(`  - ${parts.join(" | ")}`);
    }
  }
  return lines.join("\n");
}

/** Default retention for finished syncRuns. */
const DEFAULT_PRUNE_OLDER_THAN_DAYS = 30;
/** Max docs scanned/deleted per prune invocation. */
const DEFAULT_PRUNE_BATCH_LIMIT = 400;

const SYNC_RUN_POINTER_FIELDS = [
  "currentSyncRunId",
  "lastCompletedRunId",
  "lastFailedRunId",
];

/**
 * Collects sync run ids still referenced by spot/event sync sources.
 * @param {FirebaseFirestore.Firestore} db
 * @return {Promise<Set<string>>}
 */
async function collectProtectedSyncRunIds(db) {
  const protectedIds = new Set();
  const addFromSnapshot = (snap) => {
    if (!snap || !Array.isArray(snap.docs)) return;
    for (const doc of snap.docs) {
      const data = typeof doc.data === "function" ? doc.data() : null;
      if (!data || typeof data !== "object") continue;
      for (const field of SYNC_RUN_POINTER_FIELDS) {
        const value = data[field];
        if (typeof value === "string" && value.trim().length > 0) {
          protectedIds.add(value.trim());
        }
      }
    }
  };

  const spotSnap = await db.collection("syncSources").get();
  addFromSnapshot(spotSnap);
  const eventSnap = await db.collection("eventSyncSources").get();
  addFromSnapshot(eventSnap);
  return protectedIds;
}

/**
 * Deletes finished syncRuns older than the retention window.
 * Skips ids still pointed at by syncSources / eventSyncSources.
 * Running docs (`finishedAt` null) are excluded by the inequality query.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object=} options
 * @param {number=} options.olderThanDays
 * @param {number=} options.batchLimit
 * @param {Date=} options.now
 * @return {Promise<Object>} `{scanned, deleted, skippedProtected, cutoffIso}`
 */
async function pruneOldSyncRuns(db, options = {}) {
  const olderThanDays = typeof options.olderThanDays === "number" &&
      options.olderThanDays > 0 ?
    options.olderThanDays :
    DEFAULT_PRUNE_OLDER_THAN_DAYS;
  const batchLimit = typeof options.batchLimit === "number" &&
      options.batchLimit > 0 ?
    Math.min(Math.floor(options.batchLimit), 500) :
    DEFAULT_PRUNE_BATCH_LIMIT;
  const now = options.now instanceof Date ? options.now : new Date();
  const cutoff = new Date(now.getTime() - olderThanDays * 24 * 60 * 60 * 1000);

  const protectedIds = await collectProtectedSyncRunIds(db);

  const snap = await db.collection("syncRuns")
      .where("finishedAt", "<", cutoff)
      .orderBy("finishedAt", "asc")
      .limit(batchLimit)
      .get();

  const docs = Array.isArray(snap.docs) ? snap.docs : [];
  let skippedProtected = 0;
  const toDelete = [];
  for (const doc of docs) {
    if (protectedIds.has(doc.id)) {
      skippedProtected += 1;
      continue;
    }
    toDelete.push(doc.ref);
  }

  let deleted = 0;
  const writeChunkSize = 400;
  for (let i = 0; i < toDelete.length; i += writeChunkSize) {
    const chunk = toDelete.slice(i, i + writeChunkSize);
    const batch = db.batch();
    for (const ref of chunk) {
      batch.delete(ref);
    }
    await batch.commit();
    deleted += chunk.length;
  }

  return {
    scanned: docs.length,
    deleted,
    skippedProtected,
    cutoffIso: cutoff.toISOString(),
  };
}

module.exports = {
  SOURCE_KIND_SPOT,
  SOURCE_KIND_EVENT,
  STATUS_RUNNING,
  STATUS_SUCCEEDED,
  STATUS_FAILED,
  SYNC_TYPE_LIGHT,
  SYNC_TYPE_FULL,
  SYNC_TYPE_EVENT,
  TRIGGER_MANUAL,
  TRIGGER_SCHEDULED,
  TRIGGER_RESUME,
  ISSUE_YOUTUBE_MISSING_THUMBNAIL,
  ISSUE_YOUTUBE_UNCACHED_THUMBNAIL,
  DEFAULT_PRUNE_OLDER_THAN_DAYS,
  DEFAULT_PRUNE_BATCH_LIMIT,
  emptySpotStats,
  emptyEventStats,
  resolveRunIdFromSource,
  formatGeocodingSuccessRate,
  createSyncRun,
  loadSyncRun,
  bumpInvocation,
  persistRunningProgress,
  finalizeSyncRunSucceeded,
  failSyncRun,
  restoreSpotProgressFromRun,
  formatSyncRunReportText,
  collectProtectedSyncRunIds,
  pruneOldSyncRuns,
};
