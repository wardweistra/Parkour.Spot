const {
  SPOT_SYNC_LOCK_STALE_MS,
  MODE_START,
  MODE_RESUME,
  inspectLease,
  acquireSpotSyncLock,
} = require("../lib/spot-sync-lock");

function createMockDb() {
  const docs = new Map();

  const makeDocRef = (collectionName, id) => {
    const key = `${collectionName}/${id}`;
    return {
      id,
      path: key,
      set: jest.fn(async (data) => {
        docs.set(key, {...data});
      }),
      update: jest.fn(async (data) => {
        const existing = docs.get(key) || {};
        const next = {...existing};
        for (const [field, value] of Object.entries(data)) {
          if (value && value.__op === "delete") {
            delete next[field];
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

  const db = {
    collection: (name) => ({
      doc: (id) => makeDocRef(name, id),
    }),
    runTransaction: async (fn) => {
      const tx = {
        get: async (ref) => ref.get(),
        update: (ref, data) => {
          // Apply immediately so the transaction body sees committed state
          // the same way Firestore serializes conflicting writers.
          return ref.update(data);
        },
      };
      return fn(tx);
    },
  };

  const FieldValue = {
    serverTimestamp: () => ({__op: "serverTimestamp", at: Date.now()}),
    delete: () => ({__op: "delete"}),
  };

  return {db, FieldValue, docs};
}

describe("spot-sync-lock", () => {
  describe("inspectLease", () => {
    const now = Date.parse("2026-10-09T12:00:00.000Z");

    it("reports no lease when syncStartedAt is missing", () => {
      expect(inspectLease({syncInProgress: true}, now)).toEqual({
        held: false,
        startedAt: null,
        ageMs: 0,
      });
    });

    it("reports held when lease is fresh", () => {
      const startedAt = new Date(now - 60 * 1000);
      const result = inspectLease({syncStartedAt: startedAt}, now);
      expect(result.held).toBe(true);
      expect(result.ageMs).toBe(60 * 1000);
    });

    it("reports not held when lease is stale", () => {
      const startedAt = new Date(now - SPOT_SYNC_LOCK_STALE_MS - 1);
      const result = inspectLease({syncStartedAt: startedAt}, now);
      expect(result.held).toBe(false);
      expect(result.ageMs).toBe(SPOT_SYNC_LOCK_STALE_MS + 1);
    });
  });

  describe("acquireSpotSyncLock", () => {
    const nowMs = Date.parse("2026-10-09T12:00:00.000Z");

    it("allows start when source is idle", async () => {
      const {db, FieldValue, docs} = createMockDb();
      const sourceRef = db.collection("syncSources").doc("src1");
      await sourceRef.set({name: "Shanghai", syncInProgress: false});

      await acquireSpotSyncLock(db, FieldValue, sourceRef, {
        mode: MODE_START,
        nowMs,
      });

      const source = docs.get("syncSources/src1");
      expect(source.syncInProgress).toBe(true);
      expect(source.syncStartedAt).toEqual(
          expect.objectContaining({__op: "serverTimestamp"}),
      );
    });

    it("refuses start while sync is in progress without a stale lease", async () => {
      const {db, FieldValue} = createMockDb();
      const sourceRef = db.collection("syncSources").doc("src1");
      await sourceRef.set({
        name: "Shanghai",
        syncInProgress: true,
        // Partial return cleared the lease; start must still refuse.
      });

      await expect(
          acquireSpotSyncLock(db, FieldValue, sourceRef, {
            mode: MODE_START,
            nowMs,
          }),
      ).rejects.toThrow(/already in progress/i);
    });

    it("refuses start while another worker holds a fresh lease", async () => {
      const {db, FieldValue} = createMockDb();
      const sourceRef = db.collection("syncSources").doc("src1");
      await sourceRef.set({
        syncInProgress: true,
        syncStartedAt: new Date(nowMs - 5 * 60 * 1000),
      });

      await expect(
          acquireSpotSyncLock(db, FieldValue, sourceRef, {
            mode: MODE_START,
            nowMs,
          }),
      ).rejects.toThrow(/already in progress/i);
    });

    it("allows start to recover a stale lease", async () => {
      const {db, FieldValue, docs} = createMockDb();
      const sourceRef = db.collection("syncSources").doc("src1");
      await sourceRef.set({
        syncInProgress: true,
        syncStartedAt: new Date(nowMs - SPOT_SYNC_LOCK_STALE_MS - 1000),
      });

      await acquireSpotSyncLock(db, FieldValue, sourceRef, {
        mode: MODE_START,
        nowMs,
      });

      const source = docs.get("syncSources/src1");
      expect(source.syncInProgress).toBe(true);
      expect(source.syncStartedAt).toEqual(
          expect.objectContaining({__op: "serverTimestamp"}),
      );
    });

    it("refuses resume when no sync is in progress", async () => {
      const {db, FieldValue} = createMockDb();
      const sourceRef = db.collection("syncSources").doc("src1");
      await sourceRef.set({syncInProgress: false});

      await expect(
          acquireSpotSyncLock(db, FieldValue, sourceRef, {
            mode: MODE_RESUME,
            nowMs,
          }),
      ).rejects.toThrow(/no sync in progress/i);
    });

    it("refuses resume while another worker holds a fresh lease", async () => {
      const {db, FieldValue} = createMockDb();
      const sourceRef = db.collection("syncSources").doc("src1");
      await sourceRef.set({
        syncInProgress: true,
        syncStartedAt: new Date(nowMs - 30 * 1000),
      });

      await expect(
          acquireSpotSyncLock(db, FieldValue, sourceRef, {
            mode: MODE_RESUME,
            nowMs,
          }),
      ).rejects.toThrow(/another sync worker/i);
    });

    it("allows resume after partial lease clear", async () => {
      const {db, FieldValue, docs} = createMockDb();
      const sourceRef = db.collection("syncSources").doc("src1");
      await sourceRef.set({
        syncInProgress: true,
        // Lease cleared on partial return
      });

      await acquireSpotSyncLock(db, FieldValue, sourceRef, {
        mode: MODE_RESUME,
        nowMs,
      });

      const source = docs.get("syncSources/src1");
      expect(source.syncInProgress).toBe(true);
      expect(source.syncStartedAt).toEqual(
          expect.objectContaining({__op: "serverTimestamp"}),
      );
    });

    it("allows resume when prior lease is stale", async () => {
      const {db, FieldValue, docs} = createMockDb();
      const sourceRef = db.collection("syncSources").doc("src1");
      await sourceRef.set({
        syncInProgress: true,
        syncStartedAt: new Date(nowMs - SPOT_SYNC_LOCK_STALE_MS - 5000),
      });

      await acquireSpotSyncLock(db, FieldValue, sourceRef, {
        mode: MODE_RESUME,
        nowMs,
      });

      expect(docs.get("syncSources/src1").syncStartedAt).toEqual(
          expect.objectContaining({__op: "serverTimestamp"}),
      );
    });

    it("refuses a second start after the first claim succeeds", async () => {
      const {db, FieldValue} = createMockDb();
      const sourceRef = db.collection("syncSources").doc("src1");
      await sourceRef.set({syncInProgress: false});

      await acquireSpotSyncLock(db, FieldValue, sourceRef, {
        mode: MODE_START,
        nowMs,
      });

      await expect(
          acquireSpotSyncLock(db, FieldValue, sourceRef, {
            mode: MODE_START,
            nowMs,
          }),
      ).rejects.toThrow(/already in progress/i);
    });
  });
});
