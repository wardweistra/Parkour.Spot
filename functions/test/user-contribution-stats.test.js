const {
  emptyUserContributionStats,
  getUserContributionStats,
  accumulateSpotContribution,
  accumulateEventContribution,
  accumulateContributionsFromCollection,
  buildUserContributionStats,
} = require("../lib/user-contribution-stats");

describe("accumulateSpotContribution", () => {
  it("counts regular spot creation as spotsAdded", () => {
    const statsByUser = new Map();
    accumulateSpotContribution(statsByUser, {
      createdBy: "user-1",
      createdFromCreateNative: false,
    });

    expect(getUserContributionStats(statsByUser, "user-1")).toEqual({
      ...emptyUserContributionStats(),
      spotsAdded: 1,
    });
  });

  it("counts create-native spots as spotsDeduplicated, not spotsAdded", () => {
    const statsByUser = new Map();
    accumulateSpotContribution(statsByUser, {
      createdBy: "mod-1",
      createdFromCreateNative: true,
    });

    expect(getUserContributionStats(statsByUser, "mod-1")).toEqual({
      ...emptyUserContributionStats(),
      spotsDeduplicated: 1,
    });
  });

  it("counts unique improvers excluding the creator", () => {
    const statsByUser = new Map();
    accumulateSpotContribution(statsByUser, {
      createdBy: "user-1",
      contributors: [
        {userId: "user-1", userName: "Creator"},
        {userId: "user-2", userName: "Improver"},
        {userId: "user-2", userName: "Improver Dup"},
        {userId: "user-3", userName: "Other"},
        {userId: "", userName: "Invalid"},
        null,
      ],
    });

    expect(getUserContributionStats(statsByUser, "user-1").spotsImproved).toBe(0);
    expect(getUserContributionStats(statsByUser, "user-2").spotsImproved).toBe(1);
    expect(getUserContributionStats(statsByUser, "user-3").spotsImproved).toBe(1);
  });

  it("ignores invalid documents", () => {
    const statsByUser = new Map();
    accumulateSpotContribution(statsByUser, null);
    accumulateSpotContribution(statsByUser, undefined);
    accumulateSpotContribution(statsByUser, {});
    expect(statsByUser.size).toBe(0);
  });
});

describe("accumulateEventContribution", () => {
  it("counts regular event creation as eventsCreated", () => {
    const statsByUser = new Map();
    accumulateEventContribution(statsByUser, {
      createdBy: "user-1",
    });

    expect(getUserContributionStats(statsByUser, "user-1")).toEqual({
      ...emptyUserContributionStats(),
      eventsCreated: 1,
    });
  });

  it("counts create-native events as eventsDeduplicated, not eventsCreated", () => {
    const statsByUser = new Map();
    accumulateEventContribution(statsByUser, {
      createdBy: "mod-1",
      createdFromCreateNative: true,
    });

    expect(getUserContributionStats(statsByUser, "mod-1")).toEqual({
      ...emptyUserContributionStats(),
      eventsDeduplicated: 1,
    });
  });

  it("counts unique event improvers excluding the creator", () => {
    const statsByUser = new Map();
    accumulateEventContribution(statsByUser, {
      createdBy: "user-1",
      contributors: [
        {userId: "user-1", userName: "Creator"},
        {userId: "user-2", userName: "Improver"},
      ],
    });

    expect(getUserContributionStats(statsByUser, "user-1").eventsImproved).toBe(0);
    expect(getUserContributionStats(statsByUser, "user-2").eventsImproved).toBe(1);
  });
});

describe("accumulateContributionsFromCollection", () => {
  it("pages through documents and accumulates stats", async () => {
    const page1 = {
      empty: false,
      size: 2,
      docs: [{id: "a"}, {id: "b"}],
      forEach(callback) {
        callback({
          data: () => ({createdBy: "user-1", createdFromCreateNative: false}),
        });
        callback({
          data: () => ({createdBy: "mod-1", createdFromCreateNative: true}),
        });
      },
    };
    const page2 = {
      empty: true,
      size: 0,
      docs: [],
      forEach() {},
    };

    let calls = 0;
    const query = {
      select() {
        return this;
      },
      limit() {
        return this;
      },
      startAfter() {
        return this;
      },
      async get() {
        calls += 1;
        return calls === 1 ? page1 : page2;
      },
    };

    const db = {
      collection(name) {
        expect(name).toBe("spots");
        return query;
      },
    };

    const statsByUser = new Map();
    const scanned = await accumulateContributionsFromCollection({
      db,
      collectionName: "spots",
      statsByUser,
      accumulate: accumulateSpotContribution,
      pageSize: 2,
    });

    expect(scanned).toBe(2);
    expect(getUserContributionStats(statsByUser, "user-1").spotsAdded).toBe(1);
    expect(getUserContributionStats(statsByUser, "mod-1").spotsDeduplicated).toBe(1);
  });
});

describe("buildUserContributionStats", () => {
  it("aggregates spots and events", async () => {
    const spotQuery = {
      select() {
        return this;
      },
      limit() {
        return this;
      },
      startAfter() {
        return this;
      },
      async get() {
        return {
          empty: false,
          size: 1,
          docs: [{id: "spot-1"}],
          forEach(callback) {
            callback({
              data: () => ({
                createdBy: "user-1",
                contributors: [{userId: "user-2", userName: "Improver"}],
              }),
            });
          },
        };
      },
    };
    const eventQuery = {
      select() {
        return this;
      },
      limit() {
        return this;
      },
      startAfter() {
        return this;
      },
      async get() {
        return {
          empty: false,
          size: 1,
          docs: [{id: "event-1"}],
          forEach(callback) {
            callback({
              data: () => ({
                createdBy: "user-1",
                createdFromCreateNative: false,
                contributors: [{userId: "user-3", userName: "Event Improver"}],
              }),
            });
          },
        };
      },
    };

    const db = {
      collection(name) {
        if (name === "spots") return spotQuery;
        if (name === "events") return eventQuery;
        throw new Error(`Unexpected collection: ${name}`);
      },
    };

    const statsByUser = await buildUserContributionStats(db);
    expect(getUserContributionStats(statsByUser, "user-1")).toEqual({
      ...emptyUserContributionStats(),
      spotsAdded: 1,
      eventsCreated: 1,
    });
    expect(getUserContributionStats(statsByUser, "user-2").spotsImproved).toBe(1);
    expect(getUserContributionStats(statsByUser, "user-3").eventsImproved).toBe(1);
  });
});
