const {
  KIND_SPOT_ADDED,
  KIND_SPOT_PHOTO_ADDED,
  KIND_SPOT_CHECK_IN,
  KIND_SPOT_TRAINING_PLAN,
  TIMELINE_PAST,
  TIMELINE_UPCOMING,
  PAST_ACTIVITY_RETENTION_MS,
  addedImageUrlsFromAuditLog,
  actorFromAuditLog,
  buildSpotAddedActivity,
  buildSpotPhotoAddedActivity,
  buildSpotCheckInActivity,
  buildSpotTrainingPlanActivity,
  syncSpotCheckInActivity,
  syncSpotTrainingPlanActivity,
  syncCommunityActivityForSpotChange,
  normalizeCommunityActivity,
  longitudeSegments,
  executeCommunityActivityInBoundsQuery,
} = require("../lib/community-activity");

const NOW = new Date("2026-05-10T12:00:00.000Z");

const SPOT = {
  name: " Museumplein ",
  city: "Amsterdam",
  countryCode: "nl",
  latitude: 52.358,
  longitude: 4.881,
  hidden: false,
  createdBy: "user-1",
  createdByName: "Alex",
  createdAt: new Date("2026-05-09T10:00:00.000Z"),
  imageUrls: ["https://img/a.jpg", "https://img/b.jpg", "https://img/c.jpg", "https://img/d.jpg"],
};

describe("buildSpotAddedActivity", () => {
  it("materializes a past item with spot and actor fields", () => {
    const activity = buildSpotAddedActivity("spot-1", SPOT, {
      now: NOW,
      actorProfile: {photoURL: "https://img/alex.png"},
    });
    expect(activity.id).toBe("spot_added_spot-1");
    expect(activity.data).toMatchObject({
      kind: KIND_SPOT_ADDED,
      timeline: TIMELINE_PAST,
      spotId: "spot-1",
      spotName: "Museumplein",
      city: "Amsterdam",
      countryCode: "NL",
      latitude: 52.358,
      longitude: 4.881,
      actorUserId: "user-1",
      actorDisplayName: "Alex",
      actorPhotoURL: "https://img/alex.png",
      occurredAt: SPOT.createdAt,
    });
    expect(activity.data.imageUrls).toEqual([
      "https://img/a.jpg",
      "https://img/b.jpg",
      "https://img/c.jpg",
    ]);
    expect(activity.data.expiresAt.getTime()).toBe(
        SPOT.createdAt.getTime() + PAST_ACTIVITY_RETENTION_MS,
    );
  });

  it("skips imported, create-native, hidden, duplicate, or anonymous spots", () => {
    expect(buildSpotAddedActivity("s", {...SPOT, spotSource: "osm"})).toBeNull();
    expect(buildSpotAddedActivity("s", {...SPOT, createdFromCreateNative: true})).toBeNull();
    expect(buildSpotAddedActivity("s", {...SPOT, hidden: true})).toBeNull();
    expect(buildSpotAddedActivity("s", {...SPOT, duplicateOf: "other"})).toBeNull();
    expect(buildSpotAddedActivity("s", {...SPOT, createdBy: ""})).toBeNull();
    expect(buildSpotAddedActivity("s", {...SPOT, latitude: 123})).toBeNull();
  });

  it("falls back to now when createdAt is missing", () => {
    const activity = buildSpotAddedActivity("s", {...SPOT, createdAt: undefined}, {now: NOW});
    expect(activity.data.occurredAt).toBe(NOW);
  });
});

describe("addedImageUrlsFromAuditLog", () => {
  it("reads photoAdded metadata", () => {
    expect(addedImageUrlsFromAuditLog({
      action: "photoAdded",
      metadata: {photoUrls: ["https://img/1.jpg", " https://img/1.jpg ", "https://img/2.jpg"]},
    })).toEqual(["https://img/1.jpg", "https://img/2.jpg"]);
  });

  it("diffs spotEdit imageUrls changes", () => {
    expect(addedImageUrlsFromAuditLog({
      action: "spotEdit",
      changes: {
        imageUrls: {
          from: ["https://img/1.jpg"],
          to: ["https://img/1.jpg", "https://img/3.jpg"],
        },
      },
    })).toEqual(["https://img/3.jpg"]);
  });

  it("ignores removals and other actions", () => {
    expect(addedImageUrlsFromAuditLog({
      action: "spotEdit",
      changes: {imageUrls: {from: ["a", "b"], to: ["a"]}},
    })).toEqual([]);
    expect(addedImageUrlsFromAuditLog({action: "spotHidden"})).toEqual([]);
    expect(addedImageUrlsFromAuditLog(null)).toEqual([]);
  });
});

describe("actorFromAuditLog", () => {
  it("credits the suggester for approved photos", () => {
    expect(actorFromAuditLog({
      action: "photoAdded",
      userId: "mod-1",
      userName: "Mod",
      metadata: {contributor: {userId: "user-9", userName: "Sam"}},
    })).toEqual({userId: "user-9", displayName: "Sam"});
  });

  it("credits the editor for spotEdit", () => {
    expect(actorFromAuditLog({
      action: "spotEdit",
      userId: "mod-1",
      userName: "Mod",
    })).toEqual({userId: "mod-1", displayName: "Mod"});
  });
});

describe("buildSpotPhotoAddedActivity", () => {
  const log = {
    action: "photoAdded",
    spotId: "spot-1",
    userId: "mod-1",
    userName: "Mod",
    timestamp: new Date("2026-05-10T09:00:00.000Z"),
    metadata: {
      photoUrls: ["https://img/p1.jpg", "https://img/p2.jpg"],
      contributor: {userId: "user-9", userName: "Sam"},
    },
  };

  it("materializes a photo item with count and preview urls", () => {
    const activity = buildSpotPhotoAddedActivity("log-1", log, SPOT, {now: NOW});
    expect(activity.id).toBe("spot_photo_log-1");
    expect(activity.data).toMatchObject({
      kind: KIND_SPOT_PHOTO_ADDED,
      timeline: TIMELINE_PAST,
      spotId: "spot-1",
      spotName: "Museumplein",
      actorUserId: "user-9",
      actorDisplayName: "Sam",
      photoCount: 2,
      imageUrls: ["https://img/p1.jpg", "https://img/p2.jpg"],
      occurredAt: log.timestamp,
    });
  });

  it("returns null without added urls or an eligible spot", () => {
    expect(buildSpotPhotoAddedActivity("l", {...log, metadata: {photoUrls: []}}, SPOT)).toBeNull();
    expect(buildSpotPhotoAddedActivity("l", log, {...SPOT, hidden: true})).toBeNull();
    expect(buildSpotPhotoAddedActivity("l", log, null)).toBeNull();
  });
});

describe("buildSpotCheckInActivity", () => {
  const checkIn = {
    userId: "user-2",
    spotId: "spot-1",
    isPrivate: false,
    displayName: "Kim",
    photoURL: "https://img/kim.png",
    checkedInAt: new Date("2026-05-10T11:00:00.000Z"),
    expectedEndAt: new Date("2026-05-10T13:00:00.000Z"),
    comment: "  Flow session ",
  };

  it("materializes a past item with the session end", () => {
    const activity = buildSpotCheckInActivity("ci-1", checkIn, SPOT);
    expect(activity.id).toBe("check_in_ci-1");
    expect(activity.data).toMatchObject({
      kind: KIND_SPOT_CHECK_IN,
      timeline: TIMELINE_PAST,
      occurredAt: checkIn.checkedInAt,
      endAt: checkIn.expectedEndAt,
      actorUserId: "user-2",
      actorDisplayName: "Kim",
      actorPhotoURL: "https://img/kim.png",
      comment: "Flow session",
    });
  });

  it("skips private check-ins", () => {
    expect(buildSpotCheckInActivity("ci", {...checkIn, isPrivate: true}, SPOT)).toBeNull();
    expect(buildSpotCheckInActivity("ci", {...checkIn, isPrivate: undefined}, SPOT)).toBeNull();
  });
});

describe("buildSpotTrainingPlanActivity", () => {
  const plan = {
    userId: "user-3",
    spotId: "spot-1",
    isPrivate: false,
    displayName: "Lee",
    plannedStartAt: new Date("2026-05-11T15:00:00.000Z"),
    plannedEndAt: new Date("2026-05-11T17:00:00.000Z"),
    createdAt: new Date("2026-05-10T08:00:00.000Z"),
  };

  it("materializes an upcoming item ordered by start", () => {
    const activity = buildSpotTrainingPlanActivity("plan-1", plan, SPOT, {now: NOW});
    expect(activity.id).toBe("training_plan_plan-1");
    expect(activity.data).toMatchObject({
      kind: KIND_SPOT_TRAINING_PLAN,
      timeline: TIMELINE_UPCOMING,
      startAt: plan.plannedStartAt,
      endAt: plan.plannedEndAt,
      occurredAt: plan.createdAt,
      actorUserId: "user-3",
    });
    expect(activity.data.expiresAt.getTime()).toBeGreaterThan(plan.plannedEndAt.getTime());
  });

  it("skips plans that already ended or are private", () => {
    const past = {
      ...plan,
      plannedStartAt: new Date("2026-05-09T15:00:00.000Z"),
      plannedEndAt: new Date("2026-05-09T17:00:00.000Z"),
    };
    expect(buildSpotTrainingPlanActivity("p", past, SPOT, {now: NOW})).toBeNull();
    expect(buildSpotTrainingPlanActivity("p", {...plan, isPrivate: true}, SPOT, {now: NOW})).toBeNull();
  });
});

/**
 * Minimal Firestore double: doc get/set/delete plus where/orderBy/limit
 * queries over an in-memory map keyed by collection.
 * @param {Object<string, Object<string, Object>>} seed
 * @return {Object}
 */
function fakeDb(seed) {
  const store = new Map();
  for (const [collection, docs] of Object.entries(seed)) {
    store.set(collection, new Map(Object.entries(docs)));
  }
  const colMap = (name) => {
    if (!store.has(name)) store.set(name, new Map());
    return store.get(name);
  };
  const matches = (data, filters) => filters.every(({field, op, value}) => {
    const actual = data[field];
    const time = (v) => (v instanceof Date ? v.getTime() : v);
    switch (op) {
      case "==": return actual === value;
      case ">=": return actual != null && time(actual) >= time(value);
      case "<=": return actual != null && time(actual) <= time(value);
      default: throw new Error(`unsupported op ${op}`);
    }
  });
  const makeQuery = (name, filters = [], orders = [], max = null) => ({
    where: (field, op, value) => makeQuery(name, [...filters, {field, op, value}], orders, max),
    orderBy: (field, direction = "asc") => makeQuery(name, filters, [...orders, {field, direction}], max),
    limit: (n) => makeQuery(name, filters, orders, n),
    get: async () => {
      let docs = [...colMap(name).entries()]
          .filter(([, data]) => matches(data, filters))
          .map(([id, data]) => ({
            id,
            data: () => data,
            exists: true,
            ref: {
              delete: async () => colMap(name).delete(id),
              update: async (fields) => {
                colMap(name).set(id, {...colMap(name).get(id), ...fields});
              },
            },
          }));
      if (orders.length > 0) {
        docs.sort((a, b) => {
          for (const {field, direction} of orders) {
            const av = a.data()[field];
            const bv = b.data()[field];
            const at = av instanceof Date ? av.getTime() : av;
            const bt = bv instanceof Date ? bv.getTime() : bv;
            if (at === bt) continue;
            const cmp = at < bt ? -1 : 1;
            return direction === "desc" ? -cmp : cmp;
          }
          return 0;
        });
      }
      if (max != null) docs = docs.slice(0, max);
      return {docs, empty: docs.length === 0, size: docs.length};
    },
  });
  const db = {
    collection: (name) => ({
      ...makeQuery(name),
      doc: (id) => ({
        id,
        get: async () => {
          const data = colMap(name).get(id);
          return {id, exists: data !== undefined, data: () => data};
        },
        set: async (data) => {
          colMap(name).set(id, data);
        },
        update: async (fields) => {
          colMap(name).set(id, {...colMap(name).get(id), ...fields});
        },
        delete: async () => {
          colMap(name).delete(id);
        },
      }),
    }),
    batch: () => {
      const ops = [];
      return {
        delete: (ref) => ops.push(() => ref.delete()),
        update: (ref, fields) => ops.push(() => ref.update ? ref.update(fields) : null),
        set: (ref, data) => ops.push(() => ref.set(data)),
        commit: async () => {
          for (const op of ops) await op();
        },
      };
    },
    getAll: async (...refs) => Promise.all(refs.map((ref) => ref.get())),
    _store: store,
  };
  return db;
}

describe("syncSpotCheckInActivity", () => {
  const checkIn = {
    userId: "user-2",
    spotId: "spot-1",
    isPrivate: false,
    displayName: "Kim",
    checkedInAt: new Date("2026-05-10T11:00:00.000Z"),
    expectedEndAt: new Date("2026-05-10T13:00:00.000Z"),
  };

  it("writes on public create and deletes when made private or removed", async () => {
    const db = fakeDb({spots: {"spot-1": SPOT}});
    const written = await syncSpotCheckInActivity(db, "ci-1", checkIn);
    expect(written).toEqual({written: true, deleted: false});
    expect(db._store.get("communityActivity").has("check_in_ci-1")).toBe(true);

    await syncSpotCheckInActivity(db, "ci-1", {...checkIn, isPrivate: true});
    expect(db._store.get("communityActivity").has("check_in_ci-1")).toBe(false);

    await syncSpotCheckInActivity(db, "ci-1", checkIn);
    await syncSpotCheckInActivity(db, "ci-1", null);
    expect(db._store.get("communityActivity").has("check_in_ci-1")).toBe(false);
  });

  it("does not write for hidden spots", async () => {
    const db = fakeDb({spots: {"spot-1": {...SPOT, hidden: true}}});
    const result = await syncSpotCheckInActivity(db, "ci-1", checkIn);
    expect(result.written).toBe(false);
    expect(db._store.get("communityActivity").size).toBe(0);
  });
});

describe("syncSpotTrainingPlanActivity", () => {
  it("removes the upcoming item when the plan is deleted (converted to a check-in)", async () => {
    const plan = {
      userId: "user-3",
      spotId: "spot-1",
      isPrivate: false,
      plannedStartAt: new Date("2026-05-11T15:00:00.000Z"),
      plannedEndAt: new Date("2026-05-11T17:00:00.000Z"),
    };
    const db = fakeDb({spots: {"spot-1": SPOT}});
    await syncSpotTrainingPlanActivity(db, "plan-1", plan, {now: NOW});
    expect(db._store.get("communityActivity").has("training_plan_plan-1")).toBe(true);
    await syncSpotTrainingPlanActivity(db, "plan-1", null, {now: NOW});
    expect(db._store.get("communityActivity").has("training_plan_plan-1")).toBe(false);
  });
});

describe("syncCommunityActivityForSpotChange", () => {
  const seedActivity = () => fakeDb({
    communityActivity: {
      "check_in_a": {spotId: "spot-1", kind: KIND_SPOT_CHECK_IN, latitude: 1, longitude: 1},
      "spot_added_spot-1": {spotId: "spot-1", kind: KIND_SPOT_ADDED, latitude: 1, longitude: 1},
      "check_in_b": {spotId: "spot-2", kind: KIND_SPOT_CHECK_IN, latitude: 2, longitude: 2},
    },
  });

  it("deletes activity when a spot is hidden or deleted", async () => {
    const db = seedActivity();
    const result = await syncCommunityActivityForSpotChange(db, "spot-1", SPOT, {...SPOT, hidden: true});
    expect(result).toEqual({deleted: 2, updated: 0});
    expect([...db._store.get("communityActivity").keys()]).toEqual(["check_in_b"]);

    const db2 = seedActivity();
    await syncCommunityActivityForSpotChange(db2, "spot-1", SPOT, null);
    expect([...db2._store.get("communityActivity").keys()]).toEqual(["check_in_b"]);
  });

  it("skips updates to spots that were already ineligible", async () => {
    const db = seedActivity();
    const hidden = {...SPOT, hidden: true};
    const result = await syncCommunityActivityForSpotChange(db, "spot-1", hidden, {...hidden, name: "x"});
    expect(result).toEqual({deleted: 0, updated: 0});
    expect(db._store.get("communityActivity").size).toBe(3);
  });

  it("re-denormalizes coordinates and name when a spot moves", async () => {
    const db = seedActivity();
    const moved = {...SPOT, latitude: 48.85, longitude: 2.35, name: "Paris wall", city: "Paris", countryCode: "fr"};
    const result = await syncCommunityActivityForSpotChange(db, "spot-1", SPOT, moved);
    expect(result).toEqual({deleted: 0, updated: 2});
    const doc = db._store.get("communityActivity").get("check_in_a");
    expect(doc).toMatchObject({
      latitude: 48.85,
      longitude: 2.35,
      spotName: "Paris wall",
      city: "Paris",
      countryCode: "FR",
    });
    expect(db._store.get("communityActivity").get("check_in_b").latitude).toBe(2);
  });

  it("does nothing when unrelated fields change", async () => {
    const db = seedActivity();
    const result = await syncCommunityActivityForSpotChange(db, "spot-1", SPOT, {...SPOT, description: "new"});
    expect(result).toEqual({deleted: 0, updated: 0});
  });
});

describe("normalizeCommunityActivity", () => {
  it("serializes dates and drops invalid docs", () => {
    const normalized = normalizeCommunityActivity("id-1", {
      kind: KIND_SPOT_CHECK_IN,
      timeline: TIMELINE_PAST,
      latitude: 52.3,
      longitude: 4.9,
      occurredAt: new Date("2026-05-10T11:00:00.000Z"),
      endAt: {toDate: () => new Date("2026-05-10T13:00:00.000Z")},
      spotId: "spot-1",
      actorDisplayName: " Kim ",
      imageUrls: [],
    });
    expect(normalized).toEqual({
      id: "id-1",
      kind: KIND_SPOT_CHECK_IN,
      timeline: TIMELINE_PAST,
      latitude: 52.3,
      longitude: 4.9,
      occurredAt: "2026-05-10T11:00:00.000Z",
      endAt: "2026-05-10T13:00:00.000Z",
      spotId: "spot-1",
      actorDisplayName: "Kim",
    });
    expect(normalizeCommunityActivity("x", {kind: "k", timeline: "past", spotId: "s"})).toBeNull();
    expect(normalizeCommunityActivity("x", {
      kind: "k", timeline: "past", spotId: "s", occurredAt: new Date(), latitude: 200, longitude: 0,
    })).toBeNull();
  });
});

describe("longitudeSegments", () => {
  it("returns one segment for normal bounds", () => {
    expect(longitudeSegments(4, 5)).toEqual([{minLng: 4, maxLng: 5}]);
  });

  it("splits viewports crossing the antimeridian", () => {
    expect(longitudeSegments(170, -170)).toEqual([
      {minLng: 170, maxLng: 180},
      {minLng: -180, maxLng: -170},
    ]);
  });

  it("covers the globe for full-wrap bounds", () => {
    expect(longitudeSegments(-180, 180)).toEqual([{minLng: -180, maxLng: 180}]);
  });
});

describe("executeCommunityActivityInBoundsQuery", () => {
  const inBounds = {latitude: 52.36, longitude: 4.88};
  const outside = {latitude: 48.85, longitude: 2.35};
  const seed = {
    communityActivity: {
      "check_in_old": {
        kind: KIND_SPOT_CHECK_IN, timeline: TIMELINE_PAST, spotId: "s1", ...inBounds,
        occurredAt: new Date("2026-05-08T10:00:00.000Z"),
      },
      "check_in_new": {
        kind: KIND_SPOT_CHECK_IN, timeline: TIMELINE_PAST, spotId: "s1", ...inBounds,
        occurredAt: new Date("2026-05-10T10:00:00.000Z"),
      },
      "spot_added_far": {
        kind: KIND_SPOT_ADDED, timeline: TIMELINE_PAST, spotId: "s9", ...outside,
        occurredAt: new Date("2026-05-10T11:00:00.000Z"),
      },
      "plan_soon": {
        kind: KIND_SPOT_TRAINING_PLAN, timeline: TIMELINE_UPCOMING, spotId: "s1", ...inBounds,
        occurredAt: new Date("2026-05-09T10:00:00.000Z"),
        startAt: new Date("2026-05-10T14:00:00.000Z"),
        endAt: new Date("2026-05-10T16:00:00.000Z"),
      },
      "plan_later": {
        kind: KIND_SPOT_TRAINING_PLAN, timeline: TIMELINE_UPCOMING, spotId: "s2", ...inBounds,
        occurredAt: new Date("2026-05-09T10:00:00.000Z"),
        startAt: new Date("2026-05-12T14:00:00.000Z"),
        endAt: new Date("2026-05-12T16:00:00.000Z"),
      },
      "plan_ended": {
        kind: KIND_SPOT_TRAINING_PLAN, timeline: TIMELINE_UPCOMING, spotId: "s1", ...inBounds,
        occurredAt: new Date("2026-05-09T10:00:00.000Z"),
        startAt: new Date("2026-05-10T08:00:00.000Z"),
        endAt: new Date("2026-05-10T09:00:00.000Z"),
      },
    },
    eventInterestStats: {
      "event-1": {goingCount: 3, interestedCount: 5},
    },
  };
  const bounds = {minLat: 52, maxLat: 53, minLng: 4, maxLng: 5};

  it("returns newest-first past items, soonest-first upcoming items, and events with counts", async () => {
    const db = fakeDb(seed);
    const eventsInBounds = jest.fn(async () => ({
      pins: [
        {id: "p2", eventId: "event-2", startAt: "2026-05-20T10:00:00.000Z", title: "Later jam", latitude: 52.3, longitude: 4.9, kind: "venue"},
        {id: "p1", eventId: "event-1", startAt: "2026-05-11T10:00:00.000Z", title: "Jam", latitude: 52.3, longitude: 4.9, kind: "venue"},
        {id: "p1b", eventId: "event-1", startAt: "2026-05-11T10:00:00.000Z", title: "Jam", latitude: 52.31, longitude: 4.91, kind: "spot", spotId: "s1"},
      ],
    }));

    const result = await executeCommunityActivityInBoundsQuery(db, bounds, {
      now: NOW,
      eventsInBounds,
    });

    expect(result.success).toBe(true);
    expect(result.past.map((i) => i.id)).toEqual(["check_in_new", "check_in_old"]);
    expect(result.past[0].occurredAt).toBe("2026-05-10T10:00:00.000Z");
    expect(result.upcoming.map((i) => i.id)).toEqual(["plan_soon", "plan_later"]);
    expect(result.events.map((e) => e.eventId)).toEqual(["event-1", "event-2"]);
    expect(result.events[0]).toMatchObject({goingCount: 3, interestedCount: 5});
    expect(result.events[1]).toMatchObject({goingCount: 0, interestedCount: 0});
    expect(eventsInBounds).toHaveBeenCalledWith(expect.objectContaining(bounds));
  });

  it("honours limits and tolerates event lookup failures", async () => {
    const db = fakeDb(seed);
    const result = await executeCommunityActivityInBoundsQuery(
        db,
        {...bounds, pastLimit: 1, upcomingLimit: 1},
        {
          now: NOW,
          eventsInBounds: async () => {
            throw new Error("boom");
          },
        },
    );
    expect(result.past.map((i) => i.id)).toEqual(["check_in_new"]);
    expect(result.upcoming.map((i) => i.id)).toEqual(["plan_soon"]);
    expect(result.events).toEqual([]);
  });

  it("rejects missing bounds", async () => {
    await expect(executeCommunityActivityInBoundsQuery(fakeDb({}), {minLat: 1}))
        .rejects.toThrow("minLat, maxLat, minLng, maxLng are required numbers");
  });
});
