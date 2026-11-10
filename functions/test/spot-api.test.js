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
  function mockDb({clientDocs = [], spotDoc = null} = {}) {
    const usageSets = [];
    const clientUpdates = [];
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
        if (name === "spots") {
          return {
            doc: (id) => ({
              get: async () => {
                if (!spotDoc || spotDoc.id !== id) {
                  return {exists: false};
                }
                return {
                  exists: true,
                  id: spotDoc.id,
                  data: () => spotDoc.data,
                };
              },
            }),
          };
        }
        throw new Error(`unexpected collection ${name}`);
      },
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
