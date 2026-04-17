const {
  shouldFanOutNearbyCheckInNotifications,
  hasValidSpotCoordinates,
  mergeUserIdsFromSnapshot,
  buildTemplateArgs,
  fanOutNearbyCheckInNotifications,
  NOTIFICATION_KIND_NEARBY_CHECK_IN,
} = require("../lib/nearby-check-in-notifications");

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

describe("shouldFanOutNearbyCheckInNotifications", () => {
  it("returns false for missing data", () => {
    expect(shouldFanOutNearbyCheckInNotifications(undefined)).toBe(false);
  });

  it("returns false for private check-in", () => {
    expect(shouldFanOutNearbyCheckInNotifications({
      spotId: "s1",
      isPrivate: true,
    })).toBe(false);
  });

  it("returns false for missing spotId", () => {
    expect(shouldFanOutNearbyCheckInNotifications({
      isPrivate: false,
    })).toBe(false);
  });

  it("returns true for public check-in with spotId", () => {
    expect(shouldFanOutNearbyCheckInNotifications({
      spotId: "s1",
      isPrivate: false,
    })).toBe(true);
  });
});

describe("hasValidSpotCoordinates", () => {
  it("rejects hidden spots", () => {
    expect(hasValidSpotCoordinates({
      hidden: true,
      latitude: 52.37,
      longitude: 4.89,
    })).toBe(false);
  });

  it("accepts visible spots with valid coords", () => {
    expect(hasValidSpotCoordinates({
      hidden: false,
      latitude: 52.37,
      longitude: 4.89,
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

describe("buildTemplateArgs", () => {
  it("prefers check-in spotName over spot doc name", () => {
    expect(buildTemplateArgs(
        {displayName: " Alex ", spotName: " Session "},
        {name: "Fallback"},
    )).toEqual({actorName: "Alex", spotName: "Session"});
  });

  it("falls back to spot doc name when check-in spotName empty", () => {
    expect(buildTemplateArgs(
        {displayName: "", spotName: "  "},
        {name: " Wall "},
    )).toEqual({actorName: "", spotName: "Wall"});
  });
});

describe("fanOutNearbyCheckInNotifications", () => {
  it("skips when shouldFanOut is false", async () => {
    const db = {};
    const FieldValue = {serverTimestamp: () => ({})};
    const r = await fanOutNearbyCheckInNotifications({
      db,
      FieldValue,
      checkInId: "c1",
      checkInData: {spotId: "s1", isPrivate: true},
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
        data: () => ({notifyCheckInsNearby: true}),
      }]),
      batch: jest.fn(() => {
        const ops = {commit: jest.fn(async () => {})};
        ops.set = jest.fn((ref, data) => {
          written.push({ref, data});
        });
        return ops;
      }),
      collection: jest.fn((name) => {
        if (name === "spots") {
          return {
            doc: jest.fn(() => ({
              get: jest.fn(async () => ({
                exists: true,
                data: () => ({
                  name: "Mock Spot",
                  latitude: 52.37,
                  longitude: 4.89,
                }),
              })),
            })),
          };
        }
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
    const r = await fanOutNearbyCheckInNotifications({
      db,
      FieldValue,
      checkInId: "checkInA",
      checkInData: {
        userId: "u2",
        spotId: "spotA",
        spotName: "Session Spot",
        displayName: "Alex",
        isPrivate: false,
      },
    });

    expect(r.notified).toBe(1);
    expect(written.length).toBe(1);
    expect(written[0].data.notificationKind).toBe(
        NOTIFICATION_KIND_NEARBY_CHECK_IN,
    );
    expect(written[0].data.templateArgs).toEqual({
      actorName: "Alex",
      spotName: "Session Spot",
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
        if (name === "spots") {
          return {
            doc: jest.fn(() => ({
              get: jest.fn(async () => ({
                exists: true,
                data: () => ({
                  name: "Mock Spot",
                  latitude: 52.37,
                  longitude: 4.89,
                }),
              })),
            })),
          };
        }
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
    const r = await fanOutNearbyCheckInNotifications({
      db,
      FieldValue,
      checkInId: "checkInA",
      checkInData: {
        userId: "u2",
        spotId: "spotA",
        spotName: "Session Spot",
        isPrivate: false,
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
        data: () => ({notifyCheckInsNearby: false}),
      }]),
      batch: jest.fn(() => {
        const ops = {commit: jest.fn(async () => {})};
        ops.set = jest.fn((ref, data) => {
          written.push({ref, data});
        });
        return ops;
      }),
      collection: jest.fn((name) => {
        if (name === "spots") {
          return {
            doc: jest.fn(() => ({
              get: jest.fn(async () => ({
                exists: true,
                data: () => ({
                  name: "Mock Spot",
                  latitude: 52.37,
                  longitude: 4.89,
                }),
              })),
            })),
          };
        }
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
    const r = await fanOutNearbyCheckInNotifications({
      db,
      FieldValue,
      checkInId: "checkInA",
      checkInData: {
        userId: "u2",
        spotId: "spotA",
        spotName: "Session Spot",
        isPrivate: false,
      },
    });

    expect(r.notified).toBe(0);
    expect(written.length).toBe(0);
  });

  it("does not notify check-in creator", async () => {
    const written = [];
    const locSnap = {
      empty: false,
      size: 1,
      docs: [mockDoc("u2", 4.89, 52.37)],
    };
    const queryChain = {
      where: jest.fn(() => queryChain),
      limit: jest.fn(() => queryChain),
      startAfter: jest.fn(() => queryChain),
      get: jest.fn(async () => locSnap),
    };
    const db = {
      collectionGroup: jest.fn(() => queryChain),
      getAll: jest.fn(async () => []),
      batch: jest.fn(() => {
        const ops = {commit: jest.fn(async () => {})};
        ops.set = jest.fn((ref, data) => {
          written.push({ref, data});
        });
        return ops;
      }),
      collection: jest.fn((name) => {
        if (name === "spots") {
          return {
            doc: jest.fn(() => ({
              get: jest.fn(async () => ({
                exists: true,
                data: () => ({
                  name: "Mock Spot",
                  latitude: 52.37,
                  longitude: 4.89,
                }),
              })),
            })),
          };
        }
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
    const r = await fanOutNearbyCheckInNotifications({
      db,
      FieldValue,
      checkInId: "checkInA",
      checkInData: {
        userId: "u2",
        spotId: "spotA",
        spotName: "Session Spot",
        isPrivate: false,
      },
    });

    expect(r.notified).toBe(0);
    expect(written.length).toBe(0);
  });
});
