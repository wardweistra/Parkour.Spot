const {
  humanizeAttributeKey,
  parseJumpflixIds,
  normalizeJumpflixVideoLinks,
  buildYoutubeLinks,
  buildSpotSeoContent,
} = require("../lib/spot-seo-content");

describe("humanizeAttributeKey", () => {
  it("replaces underscores and capitalizes", () => {
    expect(humanizeAttributeKey("walls_low")).toBe("Walls low");
  });
  it("returns empty for blank", () => {
    expect(humanizeAttributeKey("")).toBe("");
  });
});

describe("parseJumpflixIds", () => {
  it("returns empty for missing data", () => {
    expect(parseJumpflixIds(null)).toEqual([]);
    expect(parseJumpflixIds({})).toEqual([]);
  });
  it("parses numbers and numeric strings", () => {
    expect(parseJumpflixIds({jumpflixIds: [12, "34", "x"]})).toEqual([12, 34]);
  });
});

describe("normalizeJumpflixVideoLinks", () => {
  it("uses title and url when present", () => {
    expect(normalizeJumpflixVideoLinks([
      {id: "1", title: "Parkour Changed Our Lives", url: "https://www.jumpflix.tv/movie/foo"},
    ])).toEqual([{
      title: "Parkour Changed Our Lives",
      url: "https://www.jumpflix.tv/movie/foo",
    }]);
  });
  it("falls back to id-based title and url", () => {
    expect(normalizeJumpflixVideoLinks([{id: "99"}])).toEqual([{
      title: "Jumpflix film 99",
      url: "https://www.jumpflix.tv/movie/99",
    }]);
  });
  it("skips empty entries", () => {
    expect(normalizeJumpflixVideoLinks([null, {}])).toEqual([]);
  });
});

describe("buildYoutubeLinks", () => {
  it("builds watch urls for plausible ids", () => {
    expect(buildYoutubeLinks({youtubeVideoIds: ["b8DmLVa1zpU", "bad"]})).toEqual([{
      title: "YouTube video b8DmLVa1zpU",
      url: "https://www.youtube.com/watch?v=b8DmLVa1zpU",
    }]);
  });
});

describe("buildSpotSeoContent", () => {
  const baseSpot = {
    id: "SS2h1MTqkpxA0c4PPfaZ",
    name: "South Bank - Imax 1",
    description: "<p>Famous walls</p>",
    address: "GV4P+4H London, UK",
    city: "London",
    countryCode: "gb",
    latitude: 51.5,
    longitude: -0.1,
    averageRating: 5,
    ratingCount: 12,
    spotAccess: "public",
    spotFeatures: ["walls_low", "bars_medium"],
    goodFor: ["vaults"],
    spotFacilities: {covered: "no", lighting: "yes"},
    youtubeVideoIds: ["b8DmLVa1zpU"],
    spotSourceName: "PK London",
    imageUrls: ["https://example.com/spot.jpg"],
  };

  it("returns null without a named spot", () => {
    expect(buildSpotSeoContent({})).toBeNull();
    expect(buildSpotSeoContent({spot: {name: "  "}})).toBeNull();
  });

  it("builds a full view-model", () => {
    const seo = buildSpotSeoContent({
      spot: baseSpot,
      breadcrumbs: [{name: "Home", url: "/"}, {name: "London", url: "/gb/london"}],
      jumpflixVideos: [{
        id: "7",
        title: "Parkour Changed Our Lives",
        url: "https://www.jumpflix.tv/movie/parkour-changed-our-lives",
      }],
    });

    expect(seo.title).toBe("South Bank - Imax 1");
    expect(seo.locationLine).toBe("London, GB");
    expect(seo.description).toBe("Famous walls");
    expect(seo.address).toBe("GV4P+4H London, UK");
    expect(seo.mapUrl).toContain("51.5");
    expect(seo.rating).toEqual({value: 5, count: 12});
    expect(seo.access).toBe("Public");
    expect(seo.features).toEqual(["Walls low", "Bars medium"]);
    expect(seo.goodFor).toEqual(["Vaults"]);
    expect(seo.facilities).toEqual([
      {label: "Covered", value: "no"},
      {label: "Lighting", value: "yes"},
    ]);
    expect(seo.youtubeVideos).toHaveLength(1);
    expect(seo.jumpflixVideos[0].title).toBe("Parkour Changed Our Lives");
    expect(seo.sourceName).toBe("PK London");
    expect(seo.breadcrumbs).toHaveLength(2);
    expect(seo.imageUrl).toBe("https://example.com/spot.jpg");
  });

  it("omits empty optional sections", () => {
    const seo = buildSpotSeoContent({
      spot: {
        name: "Bare spot",
        description: "",
        latitude: 1,
        longitude: 2,
      },
    });
    expect(seo.description).toBeNull();
    expect(seo.address).toBeNull();
    expect(seo.rating).toBeNull();
    expect(seo.access).toBeNull();
    expect(seo.features).toEqual([]);
    expect(seo.jumpflixVideos).toEqual([]);
    expect(seo.sourceName).toBeNull();
  });
});
