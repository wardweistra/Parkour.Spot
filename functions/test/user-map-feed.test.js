const {
  hashApiKey,
  generateMapToken,
} = require("../lib/api-helpers");
const {
  mapFeedUrl,
  extractMapTokenFromPath,
  assignCategory,
  buildKmlDocument,
  buildLegendDescriptionHtml,
  CATEGORY,
  getOrCreateMapFeed,
  regenerateMapFeed,
  resolveUserIdFromMapToken,
  spotDisplayFromRecord,
  MY_SPOTS_URL,
  MY_SESSIONS_URL,
} = require("../lib/user-map-feed");

describe("generateMapToken", () => {
  it("uses psm_ prefix and 32 hex chars", () => {
    const token = generateMapToken();
    expect(token).toMatch(/^psm_[a-f0-9]{32}$/);
  });
});

describe("extractMapTokenFromPath", () => {
  it("parses /map/{token}.kml", () => {
    expect(extractMapTokenFromPath("/map/psm_abc.kml")).toBe("psm_abc");
  });
  it("parses path without .kml suffix", () => {
    expect(extractMapTokenFromPath("/map/psm_abc")).toBe("psm_abc");
  });
  it("returns null for unrelated paths", () => {
    expect(extractMapTokenFromPath("/calendar/psc_x.ics")).toBeNull();
  });
});

describe("mapFeedUrl", () => {
  it("builds parkour.spot map URL", () => {
    expect(mapFeedUrl("psm_test")).toBe(
        "https://parkour.spot/map/psm_test.kml",
    );
  });
});

describe("assignCategory", () => {
  it("keeps highest-priority category per spot", () => {
    const bySpot = {};
    assignCategory(bySpot, "s1", CATEGORY.BEEN_TO, {});
    assignCategory(bySpot, "s1", CATEGORY.WANT_TO_VISIT, {});
    assignCategory(bySpot, "s1", CATEGORY.PLANNING, {});
    assignCategory(bySpot, "s1", CATEGORY.CHECKED_IN, {});
    expect(bySpot.s1.category).toBe(CATEGORY.CHECKED_IN);

    assignCategory(bySpot, "s2", CATEGORY.CHECKED_IN, {});
    assignCategory(bySpot, "s2", CATEGORY.PLANNING, {});
    expect(bySpot.s2.category).toBe(CATEGORY.CHECKED_IN);
  });
});

describe("buildLegendDescriptionHtml", () => {
  it("links to My spots and My sessions", () => {
    const html = buildLegendDescriptionHtml();
    expect(html).toContain(MY_SPOTS_URL);
    expect(html).toContain(MY_SESSIONS_URL);
    expect(html).toContain("Now checked in at");
    expect(html).toContain("Been to");
  });
});

describe("buildKmlDocument", () => {
  it("includes spot links and manage links in descriptions", () => {
    const kml = buildKmlDocument([
      {
        category: CATEGORY.CHECKED_IN,
        spotId: "spotA",
        name: "River spot",
        latitude: 52.1,
        longitude: 5.1,
        meta: {expectedEndAt: new Date("2026-10-12T18:00:00Z")},
      },
      {
        category: CATEGORY.WANT_TO_VISIT,
        spotId: "spotB",
        name: "Wall spot",
        latitude: 52.2,
        longitude: 5.2,
        meta: {},
      },
    ]);
    expect(kml).toContain("https://parkour.spot/spot/spotA");
    expect(kml).toContain("Manage in My sessions");
    expect(kml).toContain("https://parkour.spot/spot/spotB");
    expect(kml).toContain("Manage in My spots");
    expect(kml).toContain("<Folder>");
    expect(kml).toContain("style-checkedIn");
  });
});

describe("spotDisplayFromRecord", () => {
  it("uses native coordinates for duplicate listings", () => {
    const spotsById = {
      dup: {
        id: "dup",
        name: "Dup",
        duplicateOf: "native",
        latitude: 0,
        longitude: 0,
      },
      native: {
        id: "native",
        name: "Native wall",
        latitude: 48.8,
        longitude: 2.3,
      },
    };
    const display = spotDisplayFromRecord(spotsById.dup, spotsById);
    expect(display.linkSpotId).toBe("native");
    expect(display.latitude).toBe(48.8);
    expect(display.longitude).toBe(2.3);
  });
});

describe("map feed token storage", () => {
  it("creates and rotates tokens like calendar feeds", async () => {
    const docs = new Map();
    const feedRef = (userId) => ({
      get: async () => ({
        exists: docs.has(`mapFeeds/${userId}`),
        data: () => docs.get(`mapFeeds/${userId}`),
      }),
    });
    const tokenRef = (hash) => ({
      get: async () => ({
        exists: docs.has(`mapFeedByToken/${hash}`),
        data: () => docs.get(`mapFeedByToken/${hash}`),
      }),
    });
    const db = {
      collection: (name) => ({
        doc: (id) => {
          if (name === "mapFeeds") {
            return {
              ...feedRef(id),
              set: async (data, opts) => {
                const prev = docs.get(`mapFeeds/${id}`) || {};
                docs.set(
                    `mapFeeds/${id}`,
                    opts?.merge ? {...prev, ...data} : data,
                );
              },
            };
          }
          if (name === "mapFeedByToken") {
            return {
              ...tokenRef(id),
              set: async (data) => docs.set(`mapFeedByToken/${id}`, data),
              delete: async () => docs.delete(`mapFeedByToken/${id}`),
            };
          }
          throw new Error(`unexpected collection ${name}`);
        },
      }),
      batch: () => {
        const ops = [];
        return {
          set: (ref, data, opts) => ops.push(() => ref.set(data, opts)),
          delete: (ref) => ops.push(() => ref.delete()),
          commit: async () => {
            for (const op of ops) await op();
          },
        };
      },
    };
    const FieldValue = {serverTimestamp: () => new Date()};

    const first = await getOrCreateMapFeed(db, FieldValue, "user1");
    expect(first.token).toMatch(/^psm_/);
    expect(first.url).toBe(mapFeedUrl(first.token));
    expect(docs.get("mapFeeds/user1").token).toBe(first.token);
    expect(docs.get(`mapFeedByToken/${hashApiKey(first.token)}`).userId)
        .toBe("user1");

    const resolved = await resolveUserIdFromMapToken(db, first.token);
    expect(resolved).toBe("user1");

    const oldHash = hashApiKey(first.token);
    const next = await regenerateMapFeed(db, FieldValue, "user1");
    expect(next.token).not.toBe(first.token);
    expect(docs.has(`mapFeedByToken/${oldHash}`)).toBe(false);
    expect(docs.get(`mapFeedByToken/${hashApiKey(next.token)}`).userId)
        .toBe("user1");
  });
});
