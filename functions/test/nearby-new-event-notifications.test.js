const {
  shouldFanOutNearbyNewEventNotifications,
  buildTemplateArgs,
  excludeUserIdFromEvent,
  fanOutNearbyNewEventNotifications,
  NOTIFICATION_KIND_NEARBY_NEW_EVENT,
  EXTERNAL_EVENT_SYNC_CREATED_BY,
} = require("../lib/nearby-new-event-notifications");

const futureStart = new Date("2026-12-01T10:00:00.000Z");
const pastStart = new Date("2020-01-01T10:00:00.000Z");
const now = new Date("2026-06-01T00:00:00.000Z");

function nativeEvent(overrides = {}) {
  return {
    title: "Jam",
    startAt: futureStart,
    latitude: 52.37,
    longitude: 4.89,
    createdBy: "creator-1",
    ...overrides,
  };
}

function mockDoc(userId, lng, lat = 52.37) {
  return {
    data: () => ({longitude: lng, latitude: lat}),
    ref: {
      parent: {
        parent: {id: userId},
      },
    },
  };
}

function mockDocSnap(data, exists = true) {
  return {
    exists,
    data: () => data || {},
  };
}

function mockNearbyDb({
  written,
  loiDocs,
  userData = {},
  spotsById = new Map(),
  listsById = new Map(),
}) {
  const locSnap = {
    empty: loiDocs.length === 0,
    size: loiDocs.length,
    docs: loiDocs,
  };
  const queryChain = {
    where: jest.fn(() => queryChain),
    limit: jest.fn(() => queryChain),
    startAfter: jest.fn(() => queryChain),
    get: jest.fn(async () => locSnap),
  };
  return {
    collectionGroup: jest.fn(() => queryChain),
    getAll: jest.fn(async () => [{
      exists: true,
      data: () => userData,
    }]),
    batch: jest.fn(() => {
      const ops = {commit: jest.fn(async () => {})};
      ops.set = jest.fn((ref, data) => {
        written.push({ref, data});
      });
      return ops;
    }),
    collection: jest.fn((name) => {
      if (name === "users") {
        return {
          doc: jest.fn((uid) => ({
            collection: jest.fn((sub) => {
              if (sub === "pushSubscriptions") {
                return {
                  get: jest.fn(async () => ({empty: true, docs: []})),
                };
              }
              return {
                doc: jest.fn(() => ({path: `users/${uid}/notifications/x`})),
              };
            }),
          })),
        };
      }
      if (name === "spots") {
        return {
          doc: jest.fn((id) => ({
            get: jest.fn(async () => {
              if (!spotsById.has(id)) {
                return mockDocSnap(null, false);
              }
              return mockDocSnap(spotsById.get(id), true);
            }),
          })),
        };
      }
      if (name === "spotLists") {
        return {
          doc: jest.fn((id) => ({
            get: jest.fn(async () => {
              if (!listsById.has(id)) {
                return mockDocSnap(null, false);
              }
              return mockDocSnap(listsById.get(id), true);
            }),
          })),
        };
      }
      return {};
    }),
  };
}

describe("shouldFanOutNearbyNewEventNotifications", () => {
  it("returns false for missing after data", () => {
    expect(shouldFanOutNearbyNewEventNotifications({
      beforeData: null,
      afterData: undefined,
      now,
    })).toBe(false);
  });

  it("returns true for native create", () => {
    expect(shouldFanOutNearbyNewEventNotifications({
      beforeData: null,
      afterData: nativeEvent(),
      now,
    })).toBe(true);
  });

  it("returns false for native create from Create Native", () => {
    expect(shouldFanOutNearbyNewEventNotifications({
      beforeData: null,
      afterData: nativeEvent({createdFromCreateNative: true}),
      now,
    })).toBe(false);
  });

  it("returns false for sync create", () => {
    expect(shouldFanOutNearbyNewEventNotifications({
      beforeData: null,
      afterData: nativeEvent({
        eventSourceId: "src-1",
        needsModeratorReview: true,
        createdBy: EXTERNAL_EVENT_SYNC_CREATED_BY,
      }),
      now,
    })).toBe(false);
  });

  it("returns true when a sync event is marked reviewed", () => {
    expect(shouldFanOutNearbyNewEventNotifications({
      beforeData: nativeEvent({
        eventSourceId: "src-1",
        needsModeratorReview: true,
      }),
      afterData: nativeEvent({
        eventSourceId: "src-1",
        needsModeratorReview: false,
      }),
      now,
    })).toBe(true);
  });

  it("returns false for later edits after review", () => {
    expect(shouldFanOutNearbyNewEventNotifications({
      beforeData: nativeEvent({
        eventSourceId: "src-1",
        needsModeratorReview: false,
        title: "Old",
      }),
      afterData: nativeEvent({
        eventSourceId: "src-1",
        needsModeratorReview: false,
        title: "New",
      }),
      now,
    })).toBe(false);
  });

  it("returns false for native updates", () => {
    expect(shouldFanOutNearbyNewEventNotifications({
      beforeData: nativeEvent({title: "Old"}),
      afterData: nativeEvent({title: "New"}),
      now,
    })).toBe(false);
  });

  it("returns false when hidden", () => {
    expect(shouldFanOutNearbyNewEventNotifications({
      beforeData: null,
      afterData: nativeEvent({hidden: true}),
      now,
    })).toBe(false);
  });

  it("returns false when duplicateOf is set", () => {
    expect(shouldFanOutNearbyNewEventNotifications({
      beforeData: null,
      afterData: nativeEvent({duplicateOf: "other"}),
      now,
    })).toBe(false);
  });

  it("returns false when the event is past", () => {
    expect(shouldFanOutNearbyNewEventNotifications({
      beforeData: null,
      afterData: nativeEvent({startAt: pastStart, endAt: pastStart}),
      now,
    })).toBe(false);
  });
});

describe("buildTemplateArgs", () => {
  it("returns trimmed title or empty string", () => {
    expect(buildTemplateArgs({title: " Jam "})).toEqual({eventName: "Jam"});
    expect(buildTemplateArgs({})).toEqual({eventName: ""});
  });
});

describe("excludeUserIdFromEvent", () => {
  it("returns the creator id for native events", () => {
    expect(excludeUserIdFromEvent({createdBy: "u1"})).toBe("u1");
  });

  it("does not exclude the external sync sentinel", () => {
    expect(excludeUserIdFromEvent({
      createdBy: EXTERNAL_EVENT_SYNC_CREATED_BY,
    })).toBe("");
  });
});

describe("fanOutNearbyNewEventNotifications", () => {
  it("skips when shouldFanOut is false", async () => {
    const r = await fanOutNearbyNewEventNotifications({
      db: {},
      FieldValue: {serverTimestamp: () => ({})},
      eventId: "e1",
      beforeData: null,
      eventData: nativeEvent({eventSourceId: "src-1"}),
      now,
    });
    expect(r.skipped).toBe(true);
  });

  it("skips when there are no main coordinates", async () => {
    const db = mockNearbyDb({
      written: [],
      loiDocs: [],
      spotsById: new Map(),
      listsById: new Map(),
    });
    const r = await fanOutNearbyNewEventNotifications({
      db,
      FieldValue: {serverTimestamp: () => ({})},
      eventId: "e1",
      beforeData: null,
      eventData: nativeEvent({latitude: null, longitude: null, spotIds: []}),
      now,
    });
    expect(r.skipped).toBe(true);
  });

  it("notifies nearby users for a native create with venue coords", async () => {
    const written = [];
    const db = mockNearbyDb({
      written,
      loiDocs: [mockDoc("u1", 4.89, 52.37)],
      userData: {notifyEventsNearby: true},
    });
    const FieldValue = {serverTimestamp: () => ({_ts: true})};
    const r = await fanOutNearbyNewEventNotifications({
      db,
      FieldValue,
      eventId: "evt-1",
      beforeData: null,
      eventData: nativeEvent({title: " Summer jam "}),
      now,
    });

    expect(r.notified).toBe(1);
    expect(written.length).toBe(1);
    expect(written[0].data.notificationKind).toBe(
        NOTIFICATION_KIND_NEARBY_NEW_EVENT,
    );
    expect(written[0].data.templateArgs).toEqual({eventName: "Summer jam"});
    expect(written[0].data.deeplinkKind).toBe("event");
    expect(written[0].data.deeplinkId).toBe("evt-1");
    expect(written[0].data.read).toBe(false);
    expect(written[0].data.title).toBeUndefined();
    expect(written[0].data.body).toBeUndefined();
  });

  it("notifies when a sync event is marked reviewed", async () => {
    const written = [];
    const db = mockNearbyDb({
      written,
      loiDocs: [mockDoc("u1", 4.89, 52.37)],
      userData: {},
    });
    const r = await fanOutNearbyNewEventNotifications({
      db,
      FieldValue: {serverTimestamp: () => ({_ts: true})},
      eventId: "evt-sync",
      beforeData: nativeEvent({
        eventSourceId: "src-1",
        needsModeratorReview: true,
        createdBy: EXTERNAL_EVENT_SYNC_CREATED_BY,
      }),
      eventData: nativeEvent({
        eventSourceId: "src-1",
        needsModeratorReview: false,
        createdBy: EXTERNAL_EVENT_SYNC_CREATED_BY,
      }),
      now,
    });
    expect(r.notified).toBe(1);
    expect(written.length).toBe(1);
  });

  it("uses the first eligible linked spot when there is no venue", async () => {
    const written = [];
    const db = mockNearbyDb({
      written,
      loiDocs: [mockDoc("u1", 4.89, 52.37)],
      userData: {},
      spotsById: new Map([
        ["spot-1", {latitude: 52.37, longitude: 4.89, hidden: false}],
      ]),
    });
    const r = await fanOutNearbyNewEventNotifications({
      db,
      FieldValue: {serverTimestamp: () => ({_ts: true})},
      eventId: "evt-spot",
      beforeData: null,
      eventData: nativeEvent({
        latitude: undefined,
        longitude: undefined,
        spotIds: ["spot-1"],
      }),
      now,
    });
    expect(r.notified).toBe(1);
  });

  it("expands a public spot list for main coordinates", async () => {
    const written = [];
    const db = mockNearbyDb({
      written,
      loiDocs: [mockDoc("u1", 4.89, 52.37)],
      userData: {},
      listsById: new Map([
        ["list-1", {visibility: "public", spotIds: ["spot-b"]}],
      ]),
      spotsById: new Map([
        ["spot-b", {latitude: 52.37, longitude: 4.89, hidden: false}],
      ]),
    });
    const r = await fanOutNearbyNewEventNotifications({
      db,
      FieldValue: {serverTimestamp: () => ({_ts: true})},
      eventId: "evt-list",
      beforeData: null,
      eventData: nativeEvent({
        latitude: undefined,
        longitude: undefined,
        spotIds: [],
        spotListIds: ["list-1"],
      }),
      now,
    });
    expect(r.notified).toBe(1);
  });

  it("does not notify the event creator", async () => {
    const written = [];
    const db = mockNearbyDb({
      written,
      loiDocs: [mockDoc("creator-1", 4.89, 52.37)],
      userData: {},
    });
    const r = await fanOutNearbyNewEventNotifications({
      db,
      FieldValue: {serverTimestamp: () => ({_ts: true})},
      eventId: "evt-1",
      beforeData: null,
      eventData: nativeEvent({createdBy: "creator-1"}),
      now,
    });
    expect(r.notified).toBe(0);
    expect(written.length).toBe(0);
  });

  it("does not notify users when flag is explicitly false", async () => {
    const written = [];
    const db = mockNearbyDb({
      written,
      loiDocs: [mockDoc("u1", 4.89, 52.37)],
      userData: {notifyEventsNearby: false},
    });
    const r = await fanOutNearbyNewEventNotifications({
      db,
      FieldValue: {serverTimestamp: () => ({_ts: true})},
      eventId: "evt-1",
      beforeData: null,
      eventData: nativeEvent(),
      now,
    });
    expect(r.notified).toBe(0);
    expect(written.length).toBe(0);
  });
});
