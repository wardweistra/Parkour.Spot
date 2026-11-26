const {
  parseReviewYear,
  normalizeHandle,
  parseYearReviewCardRequest,
  parseYearReviewPagePath,
  yearReviewPath,
  serializeYearReview,
} = require("../lib/year-review-request");

const now = new Date("2026-12-02T10:00:00Z");

describe("parseReviewYear", () => {
  it("accepts started years with stats only", () => {
    expect(parseReviewYear("2026", now)).toBe(2026);
    expect(parseReviewYear(2025, now)).toBe(2025);
    expect(parseReviewYear("2027", now)).toBeNull();
    expect(parseReviewYear("2024", now)).toBeNull();
    expect(parseReviewYear("2026abc", now)).toBeNull();
    expect(parseReviewYear(undefined, now)).toBeNull();
  });
});

describe("normalizeHandle", () => {
  it("strips @, decodes, and rejects unsafe values", () => {
    expect(normalizeHandle("@noor")).toBe("noor");
    expect(normalizeHandle("%40noor")).toBe("noor");
    expect(normalizeHandle("0FpSqVIRK9MOGl3oWlSXb4Ziymx2")).toBe("0FpSqVIRK9MOGl3oWlSXb4Ziymx2");
    expect(normalizeHandle("a/b")).toBe("");
    expect(normalizeHandle("")).toBe("");
    expect(normalizeHandle(42)).toBe("");
  });
});

describe("parseYearReviewCardRequest", () => {
  it("reads Hosting paths", () => {
    expect(parseYearReviewCardRequest("/year/2026/@noor/story.jpg", {}, now)).toEqual({
      handle: "noor", year: 2026, format: "story", locale: null,
    });
    expect(parseYearReviewCardRequest("/year/2026/%40noor/square.jpg", {locale: "nl"}, now)).toEqual({
      handle: "noor", year: 2026, format: "square", locale: "nl",
    });
  });

  it("reads query parameters when called directly", () => {
    expect(parseYearReviewCardRequest("/", {user: "noor", year: "2026", format: "square"}, now))
        .toMatchObject({handle: "noor", year: 2026, format: "square"});
    expect(parseYearReviewCardRequest("/", {user: "noor", year: "2026"}, now))
        .toMatchObject({format: "story"});
  });

  it("rejects unknown files, years and handles", () => {
    expect(parseYearReviewCardRequest("/year/2026/@noor/story.png", {}, now)).toBeNull();
    expect(parseYearReviewCardRequest("/year/2031/@noor/story.jpg", {}, now)).toBeNull();
    expect(parseYearReviewCardRequest("/", {user: "noor", year: "2026", format: "poster"}, now)).toBeNull();
    expect(parseYearReviewCardRequest("/", {year: "2026"}, now)).toBeNull();
  });
});

describe("page paths", () => {
  it("parses /year/<year>/<user> only", () => {
    expect(parseYearReviewPagePath(["year", "2026", "@noor"], now)).toEqual({handle: "noor", year: 2026});
    expect(parseYearReviewPagePath(["year", "2026"], now)).toBeNull();
    expect(parseYearReviewPagePath(["user", "2026", "noor"], now)).toBeNull();
  });

  it("builds page and card paths from username or uid", () => {
    expect(yearReviewPath({year: 2026, username: "noor", userId: "u1"})).toBe("/year/2026/@noor");
    expect(yearReviewPath({year: 2026, username: null, userId: "u1"}, "story.jpg")).toBe("/year/2026/u1/story.jpg");
  });
});

describe("serializeYearReview", () => {
  it("returns JSON-safe data with paths and the running-year flag", () => {
    const json = serializeYearReview({
      userId: "u1",
      username: "noor",
      name: "Noor",
      year: 2026,
      counts: [{key: "spotsAdded", count: 1}],
      lead: {kind: "spotsAdded", count: 1},
      places: ["Utrecht"],
      frames: [{spotId: "s1", kind: "spotsAdded", name: "Leeuwesteyn", city: "Utrecht", imageUrl: "img", date: new Date("2026-06-05T00:00:00Z")}],
      moreCount: 0,
    }, {sentence: "In 2026 Noor put 1 spot on the map in Utrecht", now});
    expect(json).toMatchObject({
      sentence: "In 2026 Noor put 1 spot on the map in Utrecht",
      soFar: true,
      storyPath: "/year/2026/@noor/story.jpg",
      squarePath: "/year/2026/@noor/square.jpg",
      pagePath: "/year/2026/@noor",
    });
    expect(json.frames[0].date).toBe("2026-06-05T00:00:00.000Z");
    expect(JSON.parse(JSON.stringify(json))).toEqual(json);
  });
});
