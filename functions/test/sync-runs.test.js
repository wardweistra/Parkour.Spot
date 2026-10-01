const {
  SOURCE_KIND_SPOT,
  SOURCE_KIND_EVENT,
  STATUS_RUNNING,
  STATUS_SUCCEEDED,
  STATUS_FAILED,
  SYNC_TYPE_FULL,
  SYNC_TYPE_EVENT,
  TRIGGER_MANUAL,
  ISSUE_YOUTUBE_MISSING_THUMBNAIL,
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
} = require("../lib/sync-runs");

function createMockDb() {
  const docs = new Map();

  const makeDocRef = (collectionName, id) => {
    const key = `${collectionName}/${id}`;
    return {
      id,
      set: jest.fn(async (data) => {
        docs.set(key, {...data});
      }),
      update: jest.fn(async (data) => {
        const existing = docs.get(key) || {};
        const next = {...existing};
        for (const [field, value] of Object.entries(data)) {
          if (value && value.__op === "increment") {
            next[field] = (Number(next[field]) || 0) + value.amount;
          } else if (value && value.__op === "delete") {
            delete next[field];
          } else if (field.includes(".")) {
            // Ignore dotted paths for this mock; not needed in tests
            next[field] = value;
          } else {
            next[field] = value;
          }
        }
        docs.set(key, next);
      }),
      get: jest.fn(async () => {
        const data = docs.get(key);
        return {
          exists: data != null,
          id,
          data: () => (data ? {...data} : undefined),
        };
      }),
    };
  };

  let autoId = 0;
  const db = {
    _docs: docs,
    collection: (name) => ({
      doc: (id) => {
        if (id == null) {
          autoId += 1;
          return makeDocRef(name, `auto_${autoId}`);
        }
        return makeDocRef(name, id);
      },
    }),
  };

  const FieldValue = {
    serverTimestamp: () => ({__op: "serverTimestamp"}),
    delete: () => ({__op: "delete"}),
    increment: (amount) => ({__op: "increment", amount}),
  };

  return {db, FieldValue, docs};
}

describe("sync-runs helpers", () => {
  describe("resolveRunIdFromSource", () => {
    it("prefers currentSyncRunId", () => {
      expect(resolveRunIdFromSource({
        currentSyncRunId: "run-a",
        syncProgress: {runId: "run-b"},
      })).toBe("run-a");
    });

    it("falls back to syncProgress.runId", () => {
      expect(resolveRunIdFromSource({
        syncProgress: {runId: "run-b"},
      })).toBe("run-b");
    });

    it("returns null when missing", () => {
      expect(resolveRunIdFromSource({})).toBeNull();
      expect(resolveRunIdFromSource(null)).toBeNull();
    });
  });

  describe("formatGeocodingSuccessRate", () => {
    it("formats percentage from counters", () => {
      expect(formatGeocodingSuccessRate({total: 10, geocoded: 5}))
          .toBe("50.0%");
    });

    it("returns 0% when total is 0", () => {
      expect(formatGeocodingSuccessRate({total: 0, geocoded: 0}))
          .toBe("0%");
    });
  });

  describe("restoreSpotProgressFromRun", () => {
    it("restores counters and arrays", () => {
      const restored = restoreSpotProgressFromRun({
        stats: {
          created: 2,
          updated: 3,
          unchanged: 1,
          removed: 0,
          skipped: 4,
          geocoded: 5,
          geocodingFailed: 1,
        },
        added: [{id: "a", name: "A"}],
        updated: [{id: "b", name: "B"}],
        removed: [],
        issues: [{type: ISSUE_YOUTUBE_MISSING_THUMBNAIL, videoId: "xyz"}],
      });
      expect(restored.created).toBe(2);
      expect(restored.updated).toBe(3);
      expect(restored.skipped).toBe(4);
      expect(restored.added).toEqual([{id: "a", name: "A"}]);
      expect(restored.issues).toHaveLength(1);
    });
  });

  describe("create / persist / finalize / fail lifecycle", () => {
    it("accumulates across partial persists and finalizes", async () => {
      const {db, FieldValue, docs} = createMockDb();
      const sourceRef = db.collection("syncSources").doc("src1");
      await sourceRef.set({name: "Test source"});

      const runId = await createSyncRun(db, FieldValue, {
        sourceKind: SOURCE_KIND_SPOT,
        sourceId: "src1",
        sourceName: "Test source",
        syncType: SYNC_TYPE_FULL,
        trigger: TRIGGER_MANUAL,
        stats: {...emptySpotStats(), total: 100},
      });

      expect(runId).toBeTruthy();
      let run = await loadSyncRun(db, runId);
      expect(run.data.status).toBe(STATUS_RUNNING);
      expect(run.data.invocationCount).toBe(1);

      await persistRunningProgress(db, runId, {
        stats: {
          total: 100,
          created: 2,
          updated: 1,
          unchanged: 0,
          removed: 0,
          skipped: 0,
          geocoded: 1,
          geocodingFailed: 0,
        },
        added: [{id: "s1", name: "Spot 1"}],
        updated: [{id: "s2", name: "Spot 2"}],
        removed: [],
        issues: [{
          type: ISSUE_YOUTUBE_MISSING_THUMBNAIL,
          videoId: "abc",
          spotName: "Spot 1",
        }],
      });

      await bumpInvocation(db, FieldValue, runId);

      await persistRunningProgress(db, runId, {
        stats: {
          total: 100,
          created: 5,
          updated: 4,
          unchanged: 10,
          removed: 1,
          skipped: 2,
          geocoded: 3,
          geocodingFailed: 1,
        },
        added: [
          {id: "s1", name: "Spot 1"},
          {id: "s3", name: "Spot 3"},
        ],
        updated: [
          {id: "s2", name: "Spot 2"},
          {id: "s4", name: "Spot 4"},
        ],
        removed: [{id: "s5", name: "Spot 5"}],
        issues: [
          {
            type: ISSUE_YOUTUBE_MISSING_THUMBNAIL,
            videoId: "abc",
            spotName: "Spot 1",
          },
          {
            type: ISSUE_YOUTUBE_MISSING_THUMBNAIL,
            videoId: "def",
            spotName: "Spot 3",
          },
        ],
      });

      const finalStats = await finalizeSyncRunSucceeded(db, FieldValue, {
        runId,
        sourceRef,
        stats: {
          total: 100,
          created: 5,
          updated: 4,
          unchanged: 10,
          removed: 1,
          skipped: 2,
          geocoded: 3,
          geocodingFailed: 1,
        },
        added: [
          {id: "s1", name: "Spot 1"},
          {id: "s3", name: "Spot 3"},
        ],
        updated: [
          {id: "s2", name: "Spot 2"},
          {id: "s4", name: "Spot 4"},
        ],
        removed: [{id: "s5", name: "Spot 5"}],
        issues: [
          {
            type: ISSUE_YOUTUBE_MISSING_THUMBNAIL,
            videoId: "abc",
            spotName: "Spot 1",
          },
          {
            type: ISSUE_YOUTUBE_MISSING_THUMBNAIL,
            videoId: "def",
            spotName: "Spot 3",
          },
        ],
        sourceExtraUpdate: {
          syncInProgress: false,
        },
      });

      expect(finalStats.created).toBe(5);
      expect(finalStats.geocodingSuccessRate).toBe("3.0%");

      run = await loadSyncRun(db, runId);
      expect(run.data.status).toBe(STATUS_SUCCEEDED);
      expect(run.data.invocationCount).toBe(2);
      expect(run.data.added).toHaveLength(2);
      expect(run.data.issues).toHaveLength(2);

      const source = docs.get("syncSources/src1");
      expect(source.lastCompletedRunId).toBe(runId);
      expect(source.lastSyncStats.created).toBe(5);
      expect(source.currentSyncRunId).toBeUndefined();
      expect(source.lastError).toBeUndefined();
    });

    it("marks run and source failed", async () => {
      const {db, FieldValue, docs} = createMockDb();
      const sourceRef = db.collection("syncSources").doc("src2");
      await sourceRef.set({
        name: "Failing",
        syncInProgress: true,
        currentSyncRunId: "pending",
      });

      const runId = await createSyncRun(db, FieldValue, {
        sourceKind: SOURCE_KIND_EVENT,
        sourceId: "src2",
        sourceName: "Failing",
        syncType: SYNC_TYPE_EVENT,
        stats: emptyEventStats(),
      });

      await failSyncRun(db, FieldValue, {
        runId,
        sourceRef,
        errorMessage: "Feed download failed",
        clearInProgress: true,
      });

      const run = await loadSyncRun(db, runId);
      expect(run.data.status).toBe(STATUS_FAILED);
      expect(run.data.errorMessage).toBe("Feed download failed");

      const source = docs.get("syncSources/src2");
      expect(source.lastFailedRunId).toBe(runId);
      expect(source.lastError.message).toBe("Feed download failed");
      expect(source.syncInProgress).toBe(false);
      expect(source.currentSyncRunId).toBeUndefined();
    });
  });

  describe("formatSyncRunReportText", () => {
    it("includes youtube issues and stats", () => {
      const text = formatSyncRunReportText({
        sourceName: "Demo",
        sourceKind: SOURCE_KIND_SPOT,
        syncType: SYNC_TYPE_FULL,
        status: STATUS_SUCCEEDED,
        invocationCount: 2,
        stats: {created: 1, updated: 0},
        added: [{id: "1", name: "Alpha"}],
        updated: [],
        removed: [],
        issues: [{
          type: ISSUE_YOUTUBE_MISSING_THUMBNAIL,
          videoId: "yt123",
          spotName: "Alpha",
        }],
      });
      expect(text).toContain("Source: Demo");
      expect(text).toContain("Invocations: 2");
      expect(text).toContain("created: 1");
      expect(text).toContain("Alpha");
      expect(text).toContain("yt123");
      expect(text).toContain(ISSUE_YOUTUBE_MISSING_THUMBNAIL);
    });
  });
});
