const {
  shouldFanOutNearbyNewSpotNotifications,
  mergeUserIdsFromSnapshot,
  buildNotificationTitle,
  fanOutNearbyNewSpotNotifications,
} = require("../lib/nearby-new-spot-notifications");

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

describe("shouldFanOutNearbyNewSpotNotifications", () => {
  it("returns false for missing data", () => {
    expect(shouldFanOutNearbyNewSpotNotifications(undefined)).toBe(false);
  });
  it("returns false when hidden", () => {
    expect(shouldFanOutNearbyNewSpotNotifications({
      hidden: true,
      latitude: 1,
      longitude: 1,
    })).toBe(false);
  });
  it("returns false when spotSource is set", () => {
    expect(shouldFanOutNearbyNewSpotNotifications({
      spotSource: "kml",
      latitude: 1,
      longitude: 1,
    })).toBe(false);
  });
  it("returns false for invalid coordinates", () => {
    expect(shouldFanOutNearbyNewSpotNotifications({
      latitude: NaN,
      longitude: 0,
    })).toBe(false);
  });
  it("returns true for native spot with valid coords", () => {
    expect(shouldFanOutNearbyNewSpotNotifications({
      latitude: 52.37,
      longitude: 4.89,
      createdBy: "u1",
    })).toBe(true);
  });
});

describe("mergeUserIdsFromSnapshot", () => {
  it("dedupes user ids from snapshot docs", () => {
    const set = new Set();
    const snapshot = {
      docs: [
        mockDoc("a", 4.89),
        mockDoc("a", 4.90),
        mockDoc("b", 10.0),
      ],
    };
    mergeUserIdsFromSnapshot(snapshot, set);
    expect([...set].sort()).toEqual(["a", "b"]);
  });
});

describe("buildNotificationTitle", () => {
  it("uses Untitled spot when name empty", () => {
    expect(buildNotificationTitle({name: "  "})).toMatch(/^New spot nearby: Untitled spot$/);
  });
  it("respects max length", () => {
    const long = "x".repeat(300);
    const t = buildNotificationTitle({name: long});
    expect(t.length).toBeLessThanOrEqual(200);
    expect(t.startsWith("New spot nearby:")).toBe(true);
  });
});

describe("fanOutNearbyNewSpotNotifications", () => {
  it("skips when shouldFanOut is false", async () => {
    const db = {};
    const FieldValue = {serverTimestamp: () => ({})};
    const r = await fanOutNearbyNewSpotNotifications({
      db,
      FieldValue,
      spotId: "s1",
      spotData: {spotSource: "x", latitude: 1, longitude: 1},
    });
    expect(r.skipped).toBe(true);
  });

  it("notifies users with flag set", async () => {
    const written = [];
    const locSnap = {
      empty: false,
      size: 1,
      docs: [mockDoc("u1", 4.89, 52.37)],
    };
    const queryChain = {
      where: jest.fn(() => queryChain),
      limit: jest.fn(() => queryChain),
      startAfter: jest.fn(() => queryChain),
      get: jest.fn(async () => locSnap),
    };
    const db = {
      collectionGroup: jest.fn(() => queryChain),
      getAll: jest.fn(async () => [{
        exists: true,
        data: () => ({notifyNewSpotsNearby: true}),
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
              collection: jest.fn(() => ({
                doc: jest.fn(() => ({path: `users/${uid}/notifications/x`})),
              })),
            })),
          };
        }
        return {};
      }),
    };

    const FieldValue = {serverTimestamp: () => ({_ts: true})};
    const r = await fanOutNearbyNewSpotNotifications({
      db,
      FieldValue,
      spotId: "spotA",
      spotData: {
        name: "Test",
        latitude: 52.37,
        longitude: 4.89,
      },
    });

    expect(r.notified).toBe(1);
    expect(written.length).toBe(1);
    expect(written[0].data.deeplinkKind).toBe("spot");
    expect(written[0].data.deeplinkId).toBe("spotA");
    expect(written[0].data.read).toBe(false);
  });
});
