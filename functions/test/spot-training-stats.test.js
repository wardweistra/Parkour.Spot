const {
  WINDOW_DAYS,
  MAX_RECENT_PEOPLE,
  aggregateSpotTrainingFromCheckIns,
  spotIdsForCheckInWrite,
  recomputeSpotTrainingStats,
} = require("../lib/spot-training-stats");

function checkInDoc(data) {
  return {data: () => data};
}

describe("aggregateSpotTrainingFromCheckIns", () => {
  const t1 = new Date("2026-10-01T12:00:00Z");
  const t2 = new Date("2026-10-15T12:00:00Z");
  const t3 = new Date("2026-11-01T12:00:00Z");

  it("counts all check-ins and unique people including private", () => {
    const result = aggregateSpotTrainingFromCheckIns([
      checkInDoc({
        userId: "u1",
        isPrivate: false,
        checkedInAt: t3,
        displayName: "Ada",
        photoURL: "https://example/a.png",
      }),
      checkInDoc({
        userId: "u1",
        isPrivate: true,
        checkedInAt: t2,
        displayName: "Ada",
      }),
      checkInDoc({
        userId: "u2",
        isPrivate: true,
        checkedInAt: t1,
        displayName: "Private Pete",
      }),
    ]);

    expect(result.checkInCount).toBe(3);
    expect(result.peopleCount).toBe(2);
    expect(result.recentPeople).toEqual([
      {
        userId: "u1",
        displayName: "Ada",
        photoURL: "https://example/a.png",
        lastCheckedInAt: t3,
      },
    ]);
  });

  it("keeps the most recent public visit per user", () => {
    const result = aggregateSpotTrainingFromCheckIns([
      checkInDoc({
        userId: "u1",
        isPrivate: false,
        checkedInAt: t1,
        displayName: "Old",
        photoURL: "old.png",
      }),
      checkInDoc({
        userId: "u1",
        isPrivate: false,
        checkedInAt: t3,
        displayName: "New",
        photoURL: "new.png",
      }),
    ]);

    expect(result.recentPeople).toHaveLength(1);
    expect(result.recentPeople[0].displayName).toBe("New");
    expect(result.recentPeople[0].lastCheckedInAt).toEqual(t3);
  });

  it("excludes private-only people from recentPeople", () => {
    const result = aggregateSpotTrainingFromCheckIns([
      checkInDoc({
        userId: "u9",
        isPrivate: true,
        checkedInAt: t3,
        displayName: "Hidden",
      }),
      checkInDoc({
        userId: "u9",
        isPrivate: undefined,
        checkedInAt: t2,
        displayName: "Also hidden",
      }),
    ]);

    expect(result.checkInCount).toBe(2);
    expect(result.peopleCount).toBe(1);
    expect(result.recentPeople).toEqual([]);
  });

  it("caps recentPeople and sorts most recent first", () => {
    const docs = [];
    for (let i = 0; i < MAX_RECENT_PEOPLE + 5; i += 1) {
      docs.push(checkInDoc({
        userId: `u${i}`,
        isPrivate: false,
        checkedInAt: new Date(t1.getTime() + i * 1000),
        displayName: `User ${i}`,
      }));
    }
    const result = aggregateSpotTrainingFromCheckIns(docs);
    expect(result.recentPeople).toHaveLength(MAX_RECENT_PEOPLE);
    expect(result.recentPeople[0].userId).toBe(`u${MAX_RECENT_PEOPLE + 4}`);
    expect(result.peopleCount).toBe(MAX_RECENT_PEOPLE + 5);
  });

  it("skips docs without userId or checkedInAt", () => {
    const result = aggregateSpotTrainingFromCheckIns([
      checkInDoc({userId: "u1", isPrivate: false}),
      checkInDoc({isPrivate: false, checkedInAt: t1}),
      checkInDoc({userId: "  ", isPrivate: false, checkedInAt: t1}),
    ]);
    expect(result.checkInCount).toBe(0);
    expect(result.peopleCount).toBe(0);
  });
});

describe("spotIdsForCheckInWrite", () => {
  it("collects before and after spot ids", () => {
    expect(spotIdsForCheckInWrite(
        {spotId: "a"},
        {spotId: "b"},
    ).sort()).toEqual(["a", "b"]);
  });

  it("handles delete and create", () => {
    expect(spotIdsForCheckInWrite({spotId: "a"}, null)).toEqual(["a"]);
    expect(spotIdsForCheckInWrite(null, {spotId: "b"})).toEqual(["b"]);
  });
});

describe("recomputeSpotTrainingStats", () => {
  it("writes stats when check-ins exist and deletes when empty", async () => {
    const now = new Date("2026-11-06T12:00:00Z");
    const writes = [];
    let deleted = false;
    const docs = [
      checkInDoc({
        userId: "u1",
        isPrivate: false,
        checkedInAt: new Date("2026-10-20T12:00:00Z"),
        displayName: "Ada",
        photoURL: null,
      }),
    ];

    const db = {
      collection: jest.fn((name) => {
        if (name === "spotCheckIns") {
          return {
            where: jest.fn().mockReturnThis(),
            orderBy: jest.fn().mockReturnThis(),
            get: jest.fn(async () => ({docs})),
          };
        }
        if (name === "spotTrainingStats") {
          return {
            doc: jest.fn((id) => ({
              id,
              set: jest.fn(async (data) => {
                writes.push(data);
              }),
              delete: jest.fn(async () => {
                deleted = true;
              }),
            })),
          };
        }
        throw new Error(`unexpected collection ${name}`);
      }),
    };

    const written = await recomputeSpotTrainingStats(db, "spot-1", {now});
    expect(written.deleted).toBe(false);
    expect(written.checkInCount).toBe(1);
    expect(written.peopleCount).toBe(1);
    expect(writes).toHaveLength(1);
    expect(writes[0].windowDays).toBe(WINDOW_DAYS);
    expect(writes[0].recentPeople).toHaveLength(1);
    expect(writes[0].recentPeople[0].userId).toBe("u1");

    docs.length = 0;
    const cleared = await recomputeSpotTrainingStats(db, "spot-1", {now});
    expect(cleared.deleted).toBe(true);
    expect(deleted).toBe(true);
  });

  it("no-ops for empty spot id", async () => {
    const db = {collection: jest.fn()};
    const result = await recomputeSpotTrainingStats(db, "  ");
    expect(result.spotId).toBe("");
    expect(db.collection).not.toHaveBeenCalled();
  });
});
