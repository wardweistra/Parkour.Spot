const {hashApiKey} = require("../lib/api-helpers");
const {
  SpotApiError,
  extractApiKeyFromRequest,
  parseLimit,
  createSpotApi,
  API_CLIENTS_COLLECTION,
} = require("../lib/spot-api");

describe("extractApiKeyFromRequest", () => {
  it("reads Authorization Bearer", () => {
    expect(extractApiKeyFromRequest({
      headers: {authorization: "Bearer ps_abc"},
    })).toBe("ps_abc");
  });
  it("reads X-API-Key", () => {
    expect(extractApiKeyFromRequest({
      headers: {"x-api-key": "ps_key"},
    })).toBe("ps_key");
  });
  it("returns empty string when missing", () => {
    expect(extractApiKeyFromRequest({headers: {}})).toBe("");
  });
});

describe("parseLimit", () => {
  it("clamps to 1–100 and defaults", () => {
    expect(parseLimit(undefined, 20)).toBe(20);
    expect(parseLimit(0, 20)).toBe(1);
    expect(parseLimit(150, 20)).toBe(100);
    expect(parseLimit("7", 20)).toBe(7);
  });
});

describe("createSpotApi", () => {
  function spotSnapshot(id, data) {
    if (!data) return {exists: false, id, data: () => undefined};
    return {exists: true, id, data: () => data};
  }

  function mockDb({
    clientDocs = [],
    spotDoc = null,
    spotsById = {},
    listsById = {},
  } = {}) {
    const usageSets = [];
    const clientUpdates = [];
    const spotDataFor = (id) => {
      if (Object.prototype.hasOwnProperty.call(spotsById, id)) {
        return spotsById[id];
      }
      if (spotDoc && spotDoc.id === id) return spotDoc.data;
      return null;
    };
    const db = {
      collection: (name) => {
        if (name === API_CLIENTS_COLLECTION) {
          return {
            where: () => ({
              where: () => ({
                limit: () => ({
                  get: async () => ({
                    empty: clientDocs.length === 0,
                    docs: clientDocs,
                  }),
                }),
              }),
            }),
            doc: (id) => ({
              id,
              collection: () => ({
                doc: (dateId) => ({path: `${id}/usage/${dateId}`}),
              }),
            }),
          };
        }
        if (name === "spotLists") {
          return {
            doc: (id) => ({
              id,
              get: async () => {
                if (!Object.prototype.hasOwnProperty.call(listsById, id)) {
                  return {exists: false, id};
                }
                return {exists: true, id, data: () => listsById[id]};
              },
            }),
          };
        }
        if (name === "spots") {
          return {
            doc: (id) => ({
              id,
              get: async () => spotSnapshot(id, spotDataFor(id)),
            }),
          };
        }
        throw new Error(`unexpected collection ${name}`);
      },
      getAll: async (...refs) => refs.map((ref) =>
        spotSnapshot(ref.id, spotDataFor(ref.id))),
      runTransaction: async (fn) => {
        const transaction = {
          update: (ref, data) => clientUpdates.push({ref, data}),
          set: (ref, data, opts) => usageSets.push({ref, data, opts}),
        };
        await fn(transaction);
      },
    };
    return {db, usageSets, clientUpdates};
  }

  it("authenticateApiClient rejects missing key", async () => {
    const {db} = mockDb();
    const api = createSpotApi({
      db,
      bucket: {},
      FieldValue: {serverTimestamp: () => "ts", increment: (n) => n},
      executeSearchSpotsByTitle: jest.fn(),
      executeTopSpotsInBoundsQuery: jest.fn(),
    });
    await expect(api.authenticateApiClient({headers: {}}))
        .rejects.toMatchObject({status: 401, name: "SpotApiError"});
  });

  it("authenticateApiClient accepts active key", async () => {
    const key = "ps_testkey";
    const {db} = mockDb({
      clientDocs: [{id: "client1", data: () => ({apiKeyHash: hashApiKey(key)})}],
    });
    const api = createSpotApi({
      db,
      bucket: {},
      FieldValue: {serverTimestamp: () => "ts", increment: (n) => n},
      executeSearchSpotsByTitle: jest.fn(),
      executeTopSpotsInBoundsQuery: jest.fn(),
    });
    await expect(api.authenticateApiClient({
      headers: {"x-api-key": key},
    })).resolves.toEqual({clientId: "client1"});
  });

  it("searchSpotsForApi by query", async () => {
    const executeSearchSpotsByTitle = jest.fn().mockResolvedValue({
      success: true,
      spots: [{id: "s1", name: "Wall", imageUrls: []}],
    });
    const {db} = mockDb();
    const api = createSpotApi({
      db,
      bucket: {},
      FieldValue: {serverTimestamp: () => "ts", increment: (n) => n},
      executeSearchSpotsByTitle,
      executeTopSpotsInBoundsQuery: jest.fn(),
    });
    const result = await api.searchSpotsForApi({query: "wa", limit: 5});
    expect(executeSearchSpotsByTitle).toHaveBeenCalledWith({
      query: "wa",
      limit: 5,
    });
    expect(result).toEqual({
      spots: [{id: "s1", name: "Wall", imageUrls: []}],
      totalCount: 1,
      shownCount: 1,
    });
  });

  it("searchSpotsForApi rejects short query", async () => {
    const {db} = mockDb();
    const api = createSpotApi({
      db,
      bucket: {},
      FieldValue: {serverTimestamp: () => "ts", increment: (n) => n},
      executeSearchSpotsByTitle: jest.fn(),
      executeTopSpotsInBoundsQuery: jest.fn(),
    });
    await expect(api.searchSpotsForApi({query: "a"}))
        .rejects.toBeInstanceOf(SpotApiError);
  });

  it("searchSpotsForApi by bounds", async () => {
    const executeTopSpotsInBoundsQuery = jest.fn().mockResolvedValue({
      success: true,
      spots: [{id: "b1"}],
      totalCount: 3,
      shownCount: 1,
    });
    const {db} = mockDb();
    const api = createSpotApi({
      db,
      bucket: {},
      FieldValue: {serverTimestamp: () => "ts", increment: (n) => n},
      executeSearchSpotsByTitle: jest.fn(),
      executeTopSpotsInBoundsQuery,
    });
    const result = await api.searchSpotsForApi({
      minLat: 1, maxLat: 2, minLng: 3, maxLng: 4,
    });
    expect(result.totalCount).toBe(3);
    expect(result.shownCount).toBe(1);
    expect(executeTopSpotsInBoundsQuery).toHaveBeenCalled();
  });

  it("getSpotForApi returns serialized spot", async () => {
    const {db} = mockDb({
      spotDoc: {
        id: "spot1",
        data: {
          name: "Rails",
          hidden: false,
          duplicateOf: null,
          imageUrls: [],
        },
      },
    });
    const api = createSpotApi({
      db,
      bucket: {},
      FieldValue: {serverTimestamp: () => "ts", increment: (n) => n},
      executeSearchSpotsByTitle: jest.fn(),
      executeTopSpotsInBoundsQuery: jest.fn(),
    });
    const spot = await api.getSpotForApi("spot1");
    expect(spot).toMatchObject({
      id: "spot1",
      name: "Rails",
      hidden: false,
      duplicateOf: null,
    });
  });

  it("getSpotForApi 404 when missing", async () => {
    const {db} = mockDb();
    const api = createSpotApi({
      db,
      bucket: {},
      FieldValue: {serverTimestamp: () => "ts", increment: (n) => n},
      executeSearchSpotsByTitle: jest.fn(),
      executeTopSpotsInBoundsQuery: jest.fn(),
    });
    await expect(api.getSpotForApi("missing"))
        .rejects.toMatchObject({status: 404});
  });

  const photoUrl = "https://storage.googleapis.com/bucket/spots/photo.jpg";

  function imageBucket() {
    return {
      file(path) {
        return {
          exists: async () => [path === "spots/resized/photo_1200x1200.webp"],
        };
      },
    };
  }

  function listApi({listsById = {}, spotsById = {}, bucket = {}} = {}) {
    const {db} = mockDb({listsById, spotsById});
    return createSpotApi({
      db,
      bucket,
      FieldValue: {serverTimestamp: () => "ts", increment: (n) => n},
      executeSearchSpotsByTitle: jest.fn(),
      executeTopSpotsInBoundsQuery: jest.fn(),
    });
  }

  it("listSpotsForSpotList returns section order, notes, and images", async () => {
    const api = listApi({
      bucket: imageBucket(),
      listsById: {
        essentials: {
          name: "Essentials",
          visibility: "public",
          spotIds: ["ignored-because-sections"],
          sections: [
            {
              entries: [
                {spotId: " wall ", note: " warm up "},
                {spotId: "missing"},
                {spotId: "wall", note: "later note"},
              ],
            },
            {
              entries: [{spotId: "rail", note: "precision"}],
            },
          ],
        },
      },
      spotsById: {
        wall: {
          name: "Wall",
          hidden: false,
          duplicateOf: null,
          imageUrls: [photoUrl],
        },
        rail: {
          name: "Rail",
          hidden: true,
          duplicateOf: "wall",
          imageUrls: [],
        },
      },
    });
    const result = await api.listSpotsForSpotList(" essentials ");
    expect(result.list).toEqual({
      id: "essentials",
      name: "Essentials",
      visibility: "public",
    });
    expect(result.spots.map((spot) => spot.id)).toEqual(["wall", "rail"]);
    expect(result.spots[0].listNote).toBe("warm up");
    expect(result.spots[0].imageUrls[0]).toContain("photo_1200x1200.webp");
    expect(result.spots[1]).toMatchObject({
      id: "rail",
      hidden: true,
      duplicateOf: "wall",
      listNote: "precision",
    });
    expect(result.spots[1].imageUrls).toEqual([]);
    expect(result.totalCount).toBe(2);
    expect(result.shownCount).toBe(2);
  });

  it("listSpotsForSpotList uses spotIds when there are no sections", async () => {
    const api = listApi({
      listsById: {
        flat: {
          name: "Flat",
          visibility: "unlisted",
          spotIds: ["rail", "wall", "missing"],
        },
      },
      spotsById: {
        wall: {name: "Wall", hidden: false, imageUrls: []},
        rail: {name: "Rail", hidden: false, imageUrls: []},
      },
    });
    const result = await api.listSpotsForSpotList("flat");
    expect(result.list.visibility).toBe("unlisted");
    expect(result.spots.map((spot) => spot.id)).toEqual(["rail", "wall"]);
    expect(result.spots.every((spot) => spot.listNote === undefined)).toBe(true);
    expect(result.totalCount).toBe(2);
    expect(result.shownCount).toBe(2);
  });

  it("listSpotsForSpotList returns an empty public list", async () => {
    const api = listApi({
      listsById: {
        empty: {name: "Empty", visibility: "public", spotIds: []},
      },
    });
    const result = await api.listSpotsForSpotList("empty");
    expect(result.spots).toEqual([]);
    expect(result.totalCount).toBe(0);
    expect(result.shownCount).toBe(0);
  });

  it("listSpotsForSpotList loads every spot across getAll chunks", async () => {
    const spotsById = {};
    const spotIds = [];
    for (let i = 0; i < 11; i++) {
      const id = `s${i}`;
      spotIds.push(id);
      spotsById[id] = {name: id, hidden: false, imageUrls: []};
    }
    const api = listApi({
      listsById: {
        long: {name: "Long", spotIds},
      },
      spotsById,
    });
    const result = await api.listSpotsForSpotList("long");
    expect(result.list.visibility).toBe("unlisted");
    expect(result.spots.map((spot) => spot.id)).toEqual(spotIds);
    expect(result.totalCount).toBe(11);
  });

  it("listSpotsForSpotList 404 for unknown and private lists", async () => {
    const api = listApi({
      listsById: {
        secret: {name: "Secret", visibility: "private", spotIds: ["wall"]},
      },
      spotsById: {
        wall: {name: "Wall", hidden: false, imageUrls: []},
      },
    });
    await expect(api.listSpotsForSpotList("missing"))
        .rejects.toMatchObject({status: 404, message: "Spot list not found"});
    await expect(api.listSpotsForSpotList("secret"))
        .rejects.toMatchObject({status: 404, message: "Spot list not found"});
  });

  it("listSpotsForSpotList 400 for a blank id", async () => {
    const api = listApi();
    await expect(api.listSpotsForSpotList("  "))
        .rejects.toMatchObject({status: 400, message: "listId is required"});
    await expect(api.listSpotsForSpotList(null))
        .rejects.toMatchObject({status: 400});
  });

  it("recordApiClientUsage writes usage", async () => {
    const {db, usageSets, clientUpdates} = mockDb();
    const api = createSpotApi({
      db,
      bucket: {},
      FieldValue: {
        serverTimestamp: () => "ts",
        increment: (n) => ({__inc: n}),
      },
      executeSearchSpotsByTitle: jest.fn(),
      executeTopSpotsInBoundsQuery: jest.fn(),
    });
    await api.recordApiClientUsage("client1");
    expect(clientUpdates).toHaveLength(1);
    expect(usageSets).toHaveLength(1);
    expect(usageSets[0].data.count).toEqual({__inc: 1});
  });
});
