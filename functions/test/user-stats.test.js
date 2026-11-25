const {
  USER_STATS_KEYS,
  emptyUserStats,
  utcYearRange,
  userIdsAffectedByWrite,
  reportStatsFromReports,
  computeUserStats,
  recomputeUserStats,
  handleUserStatsSourceWrite,
  backfillUserStats,
} = require("../lib/user-stats");

/**
 * Minimal in-memory Firestore: where (==, >=, <), select, orderBy(__name__),
 * startAfter, limit, count().get(), get(), doc().get()/set(merge).
 */
function createFakeDb(seed = {}) {
  const collections = new Map();
  for (const [name, docs] of Object.entries(seed)) {
    collections.set(name, new Map(Object.entries(docs)));
  }
  const docsOf = (name) => {
    if (!collections.has(name)) collections.set(name, new Map());
    return collections.get(name);
  };
  const toComparable = (v) => (v instanceof Date ? v.getTime() : v);
  const matches = (data, [field, op, value]) => {
    const actual = toComparable(data[field]);
    const expected = toComparable(value);
    if (op === "==") return actual === expected;
    if (actual === undefined || actual === null) return false;
    if (op === ">=") return actual >= expected;
    if (op === "<") return actual < expected;
    throw new Error(`unsupported op ${op}`);
  };

  const makeQuery = (name, state = {filters: [], limit: null, after: null}) => ({
    where: (f, op, v) => makeQuery(name, {...state, filters: [...state.filters, [f, op, v]]}),
    select: () => makeQuery(name, state),
    orderBy: () => makeQuery(name, state),
    limit: (n) => makeQuery(name, {...state, limit: n}),
    startAfter: (id) => makeQuery(name, {...state, after: id}),
    _run() {
      let entries = [...docsOf(name).entries()]
          .filter(([, data]) => state.filters.every((f) => matches(data, f)))
          .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
      if (state.after) entries = entries.filter(([id]) => id > state.after);
      if (state.limit) entries = entries.slice(0, state.limit);
      return entries;
    },
    async get() {
      const entries = this._run();
      return {
        empty: entries.length === 0,
        size: entries.length,
        docs: entries.map(([id, data]) => ({id, data: () => data})),
      };
    },
    count() {
      return {get: async () => ({data: () => ({count: this._run().length})})};
    },
  });

  return {
    getAll: async (...args) => args
        .filter((ref) => ref && ref._name)
        .map((ref) => ({
          id: ref._id,
          exists: docsOf(ref._name).has(ref._id),
          data: () => docsOf(ref._name).get(ref._id),
        })),
    collection: (name) => ({
      ...makeQuery(name),
      doc: (id) => ({
        _name: name,
        _id: id,
        get: async () => ({exists: docsOf(name).has(id), data: () => docsOf(name).get(id)}),
        set: async (data, options) => {
          const prev = options && options.merge ? (docsOf(name).get(id) || {}) : {};
          const merged = {...prev, ...data};
          if (prev.years && data.years) merged.years = {...prev.years, ...data.years};
          docsOf(name).set(id, merged);
        },
      }),
    }),
    _get: (name, id) => docsOf(name).get(id),
  };
}

const FieldValue = {serverTimestamp: () => "SERVER_TIMESTAMP"};
const d = (iso) => new Date(iso);

describe("utcYearRange", () => {
  it("spans the UTC calendar year, end exclusive", () => {
    const {start, end} = utcYearRange(2026);
    expect(start.toISOString()).toBe("2026-01-01T00:00:00.000Z");
    expect(end.toISOString()).toBe("2027-01-01T00:00:00.000Z");
  });
});

describe("userIdsAffectedByWrite", () => {
  it("returns the creator on create and on delete", () => {
    expect(userIdsAffectedByWrite("spots", null, {createdBy: "u1"})).toEqual(["u1"]);
    expect(userIdsAffectedByWrite("spots", {createdBy: "u1"}, null)).toEqual(["u1"]);
  });

  it("ignores updates that touch no counted field", () => {
    const before = {userId: "u1", createdAt: d("2026-03-01"), comment: "a"};
    const after = {userId: "u1", createdAt: d("2026-03-01"), comment: "b"};
    expect(userIdsAffectedByWrite("ratings", before, after)).toEqual([]);
  });

  it("recomputes when a counted field changes", () => {
    expect(userIdsAffectedByWrite(
        "spotCheckIns",
        {userId: "u1", isPrivate: false},
        {userId: "u1", isPrivate: true},
    )).toEqual(["u1"]);
  });

  it("treats equal timestamps of different types as unchanged", () => {
    const ts = {toDate: () => d("2026-05-05T10:00:00Z")};
    expect(userIdsAffectedByWrite(
        "spotLists",
        {createdBy: "u1", visibility: "public", createdAt: ts},
        {createdBy: "u1", visibility: "public", createdAt: d("2026-05-05T10:00:00Z")},
    )).toEqual([]);
  });

  it("returns both users when ownership moves", () => {
    expect(userIdsAffectedByWrite(
        "spotReports", {reporterUserId: "a"}, {reporterUserId: "b"},
    )).toEqual(["a", "b"]);
  });

  it("skips anonymous and missing users, and unknown collections", () => {
    expect(userIdsAffectedByWrite("spotReports", null, {reporterUserId: "__anonymous__"})).toEqual([]);
    expect(userIdsAffectedByWrite("spots", null, {})).toEqual([]);
    expect(userIdsAffectedByWrite("auditLog", null, {userId: "u1"})).toEqual([]);
  });
});

describe("reportStatsFromReports", () => {
  const targets = {
    userId: "u1",
    spotCreators: new Map([["s1", "other"], ["s2", "other"], ["s3", "other"], ["s4", "other"], ["own", "u1"]]),
    eventCreators: new Map([["e1", "other"], ["e2", "other"], ["ownEvent", "u1"]]),
  };

  it("counts distinct improved spots (edits or photos), photos and approved event edits", () => {
    const result = reportStatsFromReports(
        [
          {spotId: "s1", acceptedEditFields: ["name"], updatedAt: d("2026-02-01")},
          {spotId: "s1", acceptedEditFields: ["description"], updatedAt: d("2026-04-01")},
          {spotId: "s2", acceptedEditFields: ["goodFor"], updatedAt: d("2025-10-01")},
          {spotId: "s3", acceptedEditFields: [], acceptedPhotoUrls: ["a", "b", "a"], updatedAt: d("2026-06-01")},
          {spotId: "s4", acceptedEditFields: [], updatedAt: d("2026-06-01")}, // nothing accepted
        ],
        [
          {status: "Approved", targetEventId: "e1", reviewedAt: d("2026-07-01")},
          {status: "Rejected", targetEventId: "e2", reviewedAt: d("2026-07-01")},
          {status: "Approved", reviewedAt: d("2026-07-01")}, // new-event submission
        ],
        targets,
    );
    expect(result.allTime).toEqual({spotsImproved: 3, photosAdded: 2, eventsImproved: 1});
    expect(result.years["2026"]).toEqual({spotsImproved: 2, photosAdded: 2, eventsImproved: 1});
    expect(result.years["2025"]).toEqual({spotsImproved: 1, photosAdded: 0, eventsImproved: 0});
  });

  it("skips improvements to own spots and events but keeps photos on own spots", () => {
    const result = reportStatsFromReports(
        [{spotId: "own", acceptedEditFields: ["name"], acceptedPhotoUrls: ["p"], updatedAt: d("2026-02-01")}],
        [{status: "Approved", targetEventId: "ownEvent", reviewedAt: d("2026-07-01")}],
        targets,
    );
    expect(result.allTime).toEqual({spotsImproved: 0, photosAdded: 1, eventsImproved: 0});
  });

  it("skips spots and events that no longer exist", () => {
    const result = reportStatsFromReports(
        [{spotId: "gone", acceptedEditFields: ["name"], acceptedPhotoUrls: ["p"], updatedAt: d("2026-02-01")}],
        [{status: "Approved", targetEventId: "goneEvent", reviewedAt: d("2026-07-01")}],
        targets,
    );
    expect(result.allTime).toEqual({spotsImproved: 0, photosAdded: 0, eventsImproved: 0});
  });
});

describe("computeUserStats", () => {
  const seed = () => ({
    spots: {
      s1: {createdBy: "u1", createdAt: d("2026-02-12")},
      s2: {createdBy: "u1", createdAt: d("2025-11-16")},
      s3: {createdBy: "u1", createdAt: d("2026-06-05"), createdFromCreateNative: true},
      s4: {createdBy: "other", createdAt: d("2026-06-05")},
      // Hidden by a moderator: off the map, so not a contribution.
      s5: {createdBy: "u1", createdAt: d("2026-03-03"), hidden: true},
      // Hidden dedup: already excluded as dedup, must not be subtracted twice.
      s6: {createdBy: "u1", createdAt: d("2026-03-04"), hidden: true, createdFromCreateNative: true},
      s7: {createdBy: "other", createdAt: d("2026-01-01"), hidden: true},
    },
    events: {
      e1: {createdBy: "u1", createdAt: d("2026-09-01")},
    },
    ratings: {
      r1: {userId: "u1", createdAt: d("2026-01-01T00:00:00Z")},
      r2: {userId: "u1", createdAt: d("2025-12-31T23:59:59Z")},
    },
    spotLists: {
      l1: {createdBy: "u1", visibility: "public", createdAt: d("2026-03-01")},
      l2: {createdBy: "u1", visibility: "private", createdAt: d("2026-03-01")},
      l3: {createdBy: "u1", visibility: "unlisted", createdAt: d("2026-03-01")},
    },
    spotCheckIns: {
      c1: {userId: "u1", checkedInAt: d("2026-05-01")},
      c2: {userId: "u1", checkedInAt: d("2026-05-02"), isPrivate: true},
      c3: {userId: "u1", checkedInAt: d("2026-05-03"), isPrivate: false},
    },
    spotTrainingPlans: {
      p1: {userId: "u1", plannedStartAt: d("2026-08-01"), isPrivate: false},
      p2: {userId: "u1", plannedStartAt: d("2026-08-02"), isPrivate: true},
    },
    spotReports: {
      rep1: {reporterUserId: "u1", spotId: "s4", acceptedEditFields: ["name"], acceptedPhotoUrls: ["x"], updatedAt: d("2026-04-01")},
      // Suggestion on a hidden spot: neither an improvement nor a photo.
      rep2: {reporterUserId: "u1", spotId: "s7", acceptedEditFields: ["name"], acceptedPhotoUrls: ["y"], updatedAt: d("2026-04-02")},
    },
    eventReports: {},
  });

  it("computes all-time and per-year counts, excluding private and dedup", async () => {
    // s3 is a moderator "Create native" dedup: neither added nor stored.
    const stats = await computeUserStats(createFakeDb(seed()), "u1", [2025, 2026]);
    expect(stats.allTime).toEqual({
      ...emptyUserStats(),
      spotsAdded: 2,
      spotsImproved: 1,
      photosAdded: 1,
      eventsCreated: 1,
      ratings: 2,
      lists: 2,
      checkIns: 2,
      trainingPlans: 1,
    });
    expect(stats.years["2026"]).toMatchObject({
      spotsAdded: 1,
      ratings: 1,
      checkIns: 2,
      lists: 2,
    });
    expect(stats.years["2025"]).toMatchObject({spotsAdded: 1, ratings: 1, checkIns: 0});
    expect(stats.years["2026"].spotsImproved).toBe(1);
    expect(stats.years["2026"].photosAdded).toBe(1);
    expect(Object.keys(stats.allTime).sort()).toEqual([...USER_STATS_KEYS].sort());
    expect(stats.allTime).not.toHaveProperty("spotsDeduplicated");
  });

  it("writes the current year only on recompute, leaving earlier years frozen", async () => {
    const db = createFakeDb({
      ...seed(),
      userStats: {u1: {years: {"2025": {...emptyUserStats(), spotsAdded: 99}}}},
    });
    await recomputeUserStats(db, FieldValue, "u1", {now: d("2026-12-02")});
    const doc = db._get("userStats", "u1");
    expect(doc.years["2025"].spotsAdded).toBe(99);
    expect(doc.years["2026"].spotsAdded).toBe(1);
    expect(doc.allTime.spotsAdded).toBe(2);
    expect(doc.updatedAt).toBe("SERVER_TIMESTAMP");
  });

  it("does not create a document for a user with no contributions", async () => {
    const db = createFakeDb(seed());
    const result = await recomputeUserStats(db, FieldValue, "nobody", {now: d("2026-06-01")});
    expect(result.written).toBe(false);
    expect(db._get("userStats", "nobody")).toBeUndefined();
  });

  it("zeroes an existing document when the last contribution is removed", async () => {
    const db = createFakeDb({userStats: {gone: {allTime: {...emptyUserStats(), ratings: 1}}}});
    const result = await recomputeUserStats(db, FieldValue, "gone", {now: d("2026-06-01")});
    expect(result.written).toBe(true);
    expect(db._get("userStats", "gone").allTime.ratings).toBe(0);
  });
});

describe("handleUserStatsSourceWrite", () => {
  it("recomputes the affected user and swallows failures", async () => {
    const db = createFakeDb({ratings: {r1: {userId: "u1", createdAt: d("2026-02-01")}}});
    const ids = await handleUserStatsSourceWrite(
        db, FieldValue, "ratings", null, {userId: "u1", createdAt: d("2026-02-01")},
    );
    expect(ids).toEqual(["u1"]);
    expect(db._get("userStats", "u1").allTime.ratings).toBe(1);

    const broken = {collection: () => {
      throw new Error("boom");
    }};
    jest.spyOn(console, "error").mockImplementation(() => {});
    await expect(handleUserStatsSourceWrite(
        broken, FieldValue, "ratings", null, {userId: "u1"},
    )).resolves.toEqual(["u1"]);
    console.error.mockRestore();
  });
});

describe("backfillUserStats", () => {
  it("pages through users, writes contributors only, and finishes with a null cursor", async () => {
    const db = createFakeDb({
      users: {a: {}, b: {}, c: {}},
      ratings: {r1: {userId: "a", createdAt: d("2025-09-01")}, r2: {userId: "c", createdAt: d("2026-02-01")}},
    });
    const result = await backfillUserStats(db, FieldValue, {pageSize: 2, now: d("2026-11-25")});
    expect(result).toEqual({processed: 3, written: 2, failed: 0, nextCursor: null});
    expect(db._get("userStats", "a").years["2025"].ratings).toBe(1);
    expect(db._get("userStats", "a").years["2026"].ratings).toBe(0);
    expect(db._get("userStats", "c").years["2026"].ratings).toBe(1);
    expect(db._get("userStats", "b")).toBeUndefined();
  });

  it("hands back its cursor unchanged when the time budget is already spent", async () => {
    const db = createFakeDb({users: {a: {}, b: {}, c: {}}});
    const result = await backfillUserStats(db, FieldValue, {
      startAfter: "a",
      pageSize: 1,
      timeBudgetMs: -1,
    });
    expect(result).toEqual({processed: 0, written: 0, failed: 0, nextCursor: "a"});
  });
});
