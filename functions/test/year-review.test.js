const {
  resolveCardLocale,
  countLabel,
  leadSentence,
  yearLabel,
  heroCaption,
  joinPlaces,
  SUPPORTED_LOCALES,
} = require("../lib/year-review-copy");
const {
  pickCounts,
  pickLead,
  orderTouches,
  topCities,
  buildYearReviewData,
} = require("../lib/year-review-data");
const {
  frameRows,
  planCells,
  cellBoxes,
  cardUrl,
  countsRepeatLead,
} = require("../lib/year-review-card");

const d = (iso) => new Date(iso);

describe("year review copy", () => {
  it("resolves locales with a fallback to English", () => {
    expect(resolveCardLocale("nl")).toBe("nl");
    expect(resolveCardLocale("pt-BR")).toBe("pt");
    expect(resolveCardLocale("de_DE")).toBe("de");
    expect(resolveCardLocale("ko")).toBe("en");
    expect(resolveCardLocale(null)).toBe("en");
  });

  it("pluralizes count labels per locale", () => {
    expect(countLabel("en", "spotsAdded", 1)).toBe("spot added");
    expect(countLabel("en", "spotsAdded", 4)).toBe("spots added");
    expect(countLabel("fr", "photosAdded", 1)).toBe("photo ajoutée");
    expect(countLabel("nl", "photosAdded", 9)).toBe("foto's toegevoegd");
  });

  it("splits the lead sentence around the emphasised count", () => {
    expect(leadSentence({
      locale: "en", year: 2026, name: "Noor", kind: "spotsAdded", count: 1, places: ["Utrecht"],
    })).toEqual({before: "In 2026 Noor put ", emphasis: "1 spot", after: " on the map in Utrecht"});
    expect(leadSentence({
      locale: "en", year: 2026, name: "Sam", kind: "mixed", count: 31, places: ["Utrecht", "Nieuwegein", "Amsterdam"],
    })).toEqual({before: "In 2026 Sam shaped ", emphasis: "31 spots", after: " across Utrecht, Nieuwegein and Amsterdam"});
  });

  it("has every lead, label and caption in every locale", () => {
    for (const locale of SUPPORTED_LOCALES) {
      for (const kind of ["spotsAdded", "photosAdded", "ratings", "checkIns", "eventsCreated", "mixed"]) {
        const sentence = leadSentence({locale, year: 2026, name: "N", kind, count: 2, places: []});
        expect(sentence.before + sentence.after).not.toMatch(/\{|\}/);
        expect(sentence.emphasis).toMatch(/^2 /);
      }
      expect(countLabel(locale, "lists", 2)).not.toBe("lists");
      expect(heroCaption(locale, "spotsAdded", d("2026-06-05"))).toMatch(/5|juni|June|junio|juin|junho|Juni/);
    }
  });

  it("joins places and labels the running year", () => {
    expect(joinPlaces("nl", ["A", "B", "C"])).toBe("A, B en C");
    expect(yearLabel("en", 2026, true)).toBe("2026 so far");
    expect(yearLabel("en", 2026, false)).toBe("2026");
  });
});

describe("year review data", () => {
  it("picks up to four non-zero counts in priority order", () => {
    expect(pickCounts({ratings: 23, spotsAdded: 4, lists: 1, checkIns: 2, photosAdded: 9})).toEqual([
      {key: "spotsAdded", count: 4},
      {key: "photosAdded", count: 9},
      {key: "ratings", count: 23},
      {key: "checkIns", count: 2},
    ]);
  });

  it("leads with a dominant kind, otherwise counts distinct spots", () => {
    expect(pickLead({spotsAdded: 271, ratings: 5}, 276)).toEqual({kind: "spotsAdded", count: 271});
    expect(pickLead({ratings: 2}, 2)).toEqual({kind: "ratings", count: 2});
    expect(pickLead({spotsAdded: 4, photosAdded: 9, ratings: 23}, 31)).toEqual({kind: "mixed", count: 31});
  });

  it("orders touches by kind priority and keeps one entry per spot", () => {
    const ordered = orderTouches([
      {spotId: "a", kind: "ratings", date: d("2026-01-01")},
      {spotId: "b", kind: "spotsAdded", date: d("2026-05-01")},
      {spotId: "a", kind: "photosAdded", date: d("2026-03-01"), photoUrls: ["p1"]},
      {spotId: "c", kind: "spotsAdded", date: d("2026-02-01")},
    ]);
    expect(ordered.map((t) => [t.spotId, t.kind])).toEqual([
      ["c", "spotsAdded"],
      ["b", "spotsAdded"],
      ["a", "photosAdded"],
    ]);
    expect(ordered[2].photoUrls).toEqual(["p1"]);
  });

  it("names the most frequent cities", () => {
    expect(topCities([
      {city: "Utrecht"}, {city: "Nieuwegein"}, {city: "Utrecht"}, {city: ""}, {city: "Amsterdam"}, {city: "Breda"},
    ])).toEqual(["Utrecht", "Amsterdam", "Breda"]);
  });

  it("builds card data from Firestore, hiding private profiles", async () => {
    const db = createFakeDb({
      publicProfiles: {
        u1: {username: "noor", displayName: "Noor", isPublicProfile: true},
        u2: {username: "hidden", displayName: "Hidden", isPublicProfile: false},
      },
      users: {u1: {preferredLanguageCode: "nl"}},
      userStats: {u1: {years: {"2026": {spotsAdded: 1, ratings: 1}}}},
      spots: {
        s1: {createdBy: "u1", createdAt: d("2026-06-05"), name: "Leeuwesteyn", city: "Utrecht", imageUrls: ["img1"]},
        s2: {createdBy: "other", createdAt: d("2025-01-01"), name: "Rated", city: "Nieuwegein", imageUrls: []},
        s3: {createdBy: "u1", createdAt: d("2026-07-01"), createdFromCreateNative: true, name: "Dedup", imageUrls: ["x"]},
      },
      spotReports: {},
      spotCheckIns: {},
      ratings: {r1: {userId: "u1", spotId: "s2", createdAt: d("2026-08-01")}},
    });
    const data = await buildYearReviewData(db, {userIdOrUsername: "@noor", year: 2026});
    expect(data).toMatchObject({
      userId: "u1",
      name: "Noor",
      username: "noor",
      preferredLocale: "nl",
      places: ["Nieuwegein", "Utrecht"],
      moreCount: 0,
    });
    expect(data.frames.map((f) => f.spotId)).toEqual(["s1"]);
    expect(data.lead).toEqual({kind: "mixed", count: 2});
    expect(await buildYearReviewData(db, {userIdOrUsername: "hidden", year: 2026})).toBeNull();
    expect(await buildYearReviewData(db, {userIdOrUsername: "noor", year: 2025})).toBeNull();
  });
});

describe("year review card layout", () => {
  it("lays out 1 to 9 cells in uneven rows", () => {
    for (let n = 1; n <= 9; n++) {
      expect(frameRows(n).reduce((a, b) => a + b, 0)).toBe(n);
    }
    expect(frameRows(3)).toEqual([1, 2]);
  });

  it("turns the last cell into a +N tile when spots overflow", () => {
    const frames = Array.from({length: 9}, (_, i) => ({spotId: `s${i}`}));
    expect(planCells(frames, 22, 9)).toMatchObject({more: 23});
    expect(planCells(frames, 22, 9).photos).toHaveLength(8);
    expect(planCells(frames, 22, 6).photos).toHaveLength(5);
    expect(planCells(frames.slice(0, 4), 0, 9)).toMatchObject({more: 0});
  });

  it("fills the field width in every row", () => {
    const boxes = cellBoxes(5, 952, 1040);
    const firstRow = boxes.filter((b) => b.row === 0);
    expect(firstRow.reduce((sum, b) => sum + b.width, 0) + 12 * (firstRow.length - 1)).toBeLessThanOrEqual(952);
    expect(boxes).toHaveLength(5);
  });

  it("drops a counts row that only repeats the sentence", () => {
    expect(countsRepeatLead([{key: "spotsAdded", count: 1}], {kind: "spotsAdded", count: 1})).toBe(true);
    expect(countsRepeatLead([{key: "spotsAdded", count: 1}, {key: "ratings", count: 2}], {kind: "mixed", count: 3})).toBe(false);
  });

  it("prints the username link, or just the site without a username", () => {
    expect(cardUrl({year: 2026, username: "noor", userId: "u1"})).toBe("parkour.spot/year/2026/@noor");
    expect(cardUrl({year: 2026, username: null, userId: "u1"})).toBe("parkour.spot");
  });
});

describe("renderYearReviewCard", () => {
  // Rendered in a child Node process: satori's Yoga build is an ES module that
  // Node 22 can require() but Jest cannot.
  const {execFileSync} = require("child_process");
  const path = require("path");
  const render = (options) => JSON.parse(execFileSync(process.execPath, [
    path.join(__dirname, "fixtures", "render-year-review-card.js"),
    JSON.stringify(options),
  ], {encoding: "utf8", timeout: 60000}));

  it.each([
    ["story", 1080, 1920],
    ["square", 1080, 1080],
  ])("renders a %s JPEG at its size", (format, width, height) => {
    expect(render({format, locale: "en"})).toEqual({format: "jpeg", width, height});
  }, 70000);

  it("still renders when every image fails to load", () => {
    expect(render({format: "story", locale: "de", failImages: true})).toEqual({
      format: "jpeg",
      width: 1080,
      height: 1920,
    });
  }, 70000);
});

/**
 * In-memory Firestore covering what buildYearReviewData uses.
 * @param {Object} seed
 * @return {Object}
 */
function createFakeDb(seed) {
  const docs = (name) => Object.entries(seed[name] || {});
  const cmp = (v) => (v instanceof Date ? v.getTime() : v);
  const query = (name, filters = [], limit = null) => ({
    where: (f, op, v) => query(name, [...filters, [f, op, v]], limit),
    select: () => query(name, filters, limit),
    limit: (n) => query(name, filters, n),
    async get() {
      let rows = docs(name).filter(([, data]) => filters.every(([f, op, v]) => {
        const a = cmp(data[f]);
        const b = cmp(v);
        if (op === "==") return a === b;
        if (a === undefined) return false;
        return op === ">=" ? a >= b : a < b;
      }));
      if (limit) rows = rows.slice(0, limit);
      return {empty: rows.length === 0, docs: rows.map(([id, data]) => ({id, data: () => data}))};
    },
  });
  return {
    collection: (name) => ({
      ...query(name),
      doc: (id) => ({
        _name: name,
        _id: id,
        get: async () => ({id, exists: !!(seed[name] || {})[id], data: () => (seed[name] || {})[id]}),
      }),
    }),
    getAll: async (...refs) => refs.filter((ref) => ref && ref._name).map((ref) => ({
      id: ref._id,
      exists: !!(seed[ref._name] || {})[ref._id],
      data: () => (seed[ref._name] || {})[ref._id],
    })),
  };
}
