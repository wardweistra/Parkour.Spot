const {
  buildDescription,
  normalizeSearchQuery,
  getSearchQueryTokens,
  spotSearchTermDocId,
  cleanDescription,
  extractYoutubeVideoIdsFromDescription,
  extractImageUrls,
} = require("../lib/text-processing");

describe("buildDescription", () => {
  it("returns default when spot is null", () => {
    expect(buildDescription(null)).toContain("Discover, map, and share the best parkour spots");
  });
  it("includes address when present", () => {
    expect(buildDescription({address: "123 Main St"})).toContain("📍 123 Main St");
  });
  it("includes rating when valid", () => {
    const s = {averageRating: 4.5, ratingCount: 10};
    expect(buildDescription(s)).toContain("⭐ 4.5");
  });
  it("clips long descriptions", () => {
    const long = "a".repeat(300);
    expect(buildDescription({description: long})).toContain("…");
  });
});

describe("normalizeSearchQuery", () => {
  it("lowercases and strips punctuation", () => {
    expect(normalizeSearchQuery("  Amsterdam!  ")).toBe("amsterdam");
  });
  it("returns empty for invalid input", () => {
    expect(normalizeSearchQuery("")).toBe("");
    expect(normalizeSearchQuery(null)).toBe("");
  });
});

describe("getSearchQueryTokens", () => {
  it("returns tokens from buildSpotSearchWords", () => {
    const tokens = getSearchQueryTokens("Amsterdam Parkour");
    expect(tokens).toContain("amsterdam");
    expect(tokens).toContain("parkour");
  });
});

describe("spotSearchTermDocId", () => {
  it("returns deterministic id", () => {
    expect(spotSearchTermDocId("spot1", "amsterdam")).toBe("spot1_amsterdam");
  });
});

describe("cleanDescription", () => {
  it("removes HTML tags", () => {
    expect(cleanDescription("<p>Hello</p>")).toBe("Hello");
  });
  it("converts br to newlines", () => {
    expect(cleanDescription("A<br/>B")).toContain("\n");
  });
  it("decodes HTML entities", () => {
    expect(cleanDescription("&amp;")).toContain("&");
  });
});

describe("extractYoutubeVideoIdsFromDescription", () => {
  it("extracts from youtu.be", () => {
    expect(extractYoutubeVideoIdsFromDescription("https://youtu.be/abc123"))
        .toEqual(["abc123"]);
  });
  it("extracts from watch URL", () => {
    expect(extractYoutubeVideoIdsFromDescription("https://youtube.com/watch?v=xyz789"))
        .toEqual(["xyz789"]);
  });
  it("returns empty for no matches", () => {
    expect(extractYoutubeVideoIdsFromDescription("no URLs here")).toEqual([]);
  });
});

describe("extractImageUrls", () => {
  it("extracts img src from description", () => {
    const placemark = {
      description: "<img src=\"https://img.youtube.com/vi/abc/hqdefault.jpg\">",
    };
    const urls = extractImageUrls(placemark);
    expect(urls.length).toBeGreaterThan(0);
    expect(urls[0]).toContain("img.youtube.com");
  });
  it("filters non-Google URLs", () => {
    const placemark = {
      description: "<img src=\"https://evil.com/image.jpg\">",
    };
    const urls = extractImageUrls(placemark);
    expect(urls).toEqual([]);
  });
});
