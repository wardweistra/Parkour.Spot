const {
  shouldFanOutNearbyNewSpotNotifications,
  buildTemplateArgs,
  fanOutNearbyNewSpotNotifications,
  NOTIFICATION_KIND_NEARBY_NEW_SPOT,
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
  it("returns false when spot was created from Create Native", () => {
    expect(shouldFanOutNearbyNewSpotNotifications({
      createdFromCreateNative: true,
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

describe("buildTemplateArgs", () => {
  it("returns trimmed names or empty strings for client-side l10n", () => {
    expect(buildTemplateArgs({
      createdByName: " Alex ",
      name: " Wall ",
    })).toEqual({actorName: "Alex", spotName: "Wall"});
    expect(buildTemplateArgs({})).toEqual({actorName: "", spotName: ""});
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
        createdByName: "Alex",
      },
    });

    expect(r.notified).toBe(1);
    expect(written.length).toBe(1);
    expect(written[0].data.notificationKind).toBe(
        NOTIFICATION_KIND_NEARBY_NEW_SPOT,
    );
    expect(written[0].data.templateArgs).toEqual({
      actorName: "Alex",
      spotName: "Test",
    });
    expect(written[0].data.deeplinkKind).toBe("spot");
    expect(written[0].data.deeplinkId).toBe("spotA");
    expect(written[0].data.read).toBe(false);
    expect(written[0].data.title).toBeUndefined();
    expect(written[0].data.body).toBeUndefined();
  });

  it("notifies users when flag is missing (default on)", async () => {
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
        data: () => ({}),
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
  });

  it("does not notify users when flag is explicitly false", async () => {
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
        data: () => ({notifyNewSpotsNearby: false}),
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

    expect(r.notified).toBe(0);
    expect(written.length).toBe(0);
  });
});
