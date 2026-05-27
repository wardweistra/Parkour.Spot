const {
  pickSpotIdsForTitleSearch,
  buildSpotIdMatchCounts,
  isSpotSearchIndexEligible,
  isEventSearchIndexEligible,
} = require("../lib/spot-search");

describe("isSpotSearchIndexEligible", () => {
  it("allows visible canonical spots", () => {
    expect(isSpotSearchIndexEligible({
      name: "South Bank",
      hidden: false,
      duplicateOf: null,
    })).toBe(true);
  });

  it("rejects hidden, duplicate, and unnamed spots", () => {
    expect(isSpotSearchIndexEligible({name: "X", hidden: true})).toBe(false);
    expect(isSpotSearchIndexEligible({name: "X", duplicateOf: "orig"})).toBe(false);
    expect(isSpotSearchIndexEligible({name: "  ", hidden: false})).toBe(false);
  });
});

describe("isEventSearchIndexEligible", () => {
  const future = new Date(Date.now() + 86400000);

  it("allows upcoming non-duplicate events", () => {
    expect(isEventSearchIndexEligible({
      title: "Jam",
      startAt: future,
      duplicateOf: null,
    })).toBe(true);
  });

  it("rejects duplicates and past events", () => {
    const past = new Date(Date.now() - 86400000);
    expect(isEventSearchIndexEligible({
      title: "Jam",
      startAt: future,
      duplicateOf: "native1",
    })).toBe(false);
    expect(isEventSearchIndexEligible({
      title: "Jam",
      startAt: past,
    })).toBe(false);
  });
});

describe("pickSpotIdsForTitleSearch", () => {
  it("prefers full token matches when present", () => {
    const counts = new Map([
      ["full", 2],
      ["partial", 1],
    ]);
    const result = pickSpotIdsForTitleSearch(counts, 2);
    expect(result.useFullTokenMatchOnly).toBe(true);
    expect(result.spotIds).toEqual(["full"]);
  });

  it("falls back to partial ordering when no full match", () => {
    const counts = new Map([
      ["b", 1],
      ["a", 1],
    ]);
    const result = pickSpotIdsForTitleSearch(counts, 2);
    expect(result.useFullTokenMatchOnly).toBe(false);
    expect(result.spotIds).toEqual(["b", "a"]);
  });
});

describe("buildSpotIdMatchCounts", () => {
  it("counts union when no query hit the limit", async () => {
    const tokenResults = [
      {token: "imax", spotIds: new Set(["a", "b"]), hitLimit: false},
      {token: "london", spotIds: new Set(["a"]), hitLimit: false},
    ];
    const {spotIdToMatchCount, refined} = await buildSpotIdMatchCounts(
        ["imax", "london"],
        tokenResults,
        null,
    );
    expect(refined).toBe(false);
    expect(spotIdToMatchCount.get("a")).toBe(2);
    expect(spotIdToMatchCount.get("b")).toBe(1);
  });

  it("verifies missing tokens for candidates when a query hits the limit", async () => {
    const tokenResults = [
      {token: "imax", spotIds: new Set(["canonical", "dup"]), hitLimit: false},
      {token: "london", spotIds: new Set(["dup"]), hitLimit: true},
    ];
    const hasTerm = async (spotId, token) =>
      spotId === "canonical" && token === "london";
    const {spotIdToMatchCount, refined} = await buildSpotIdMatchCounts(
        ["imax", "london"],
        tokenResults,
        hasTerm,
    );
    expect(refined).toBe(true);
    expect(spotIdToMatchCount.get("canonical")).toBe(2);
    expect(spotIdToMatchCount.get("dup")).toBe(2);
  });
});
