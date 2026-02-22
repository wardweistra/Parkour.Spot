const {
  cleanUndefinedValues,
  buildSpotSearchWords,
  normalizeStringArray,
  normalizeSpotAttributeDefaults,
  mergeSpotAttributeDefaults,
  mergeUniqueStringArrays,
  areStringArraysEqual,
  applySpotAttributeDefaultsToSpotData,
  buildSpotAttributeUpdateData,
} = require("../lib/spot-attributes");

describe("cleanUndefinedValues", () => {
  it("removes undefined values", () => {
    expect(cleanUndefinedValues({a: 1, b: undefined, c: 3})).toEqual({a: 1, c: 3});
  });
  it("keeps null", () => {
    expect(cleanUndefinedValues({a: null})).toEqual({a: null});
  });
});

describe("buildSpotSearchWords", () => {
  it("splits and normalizes spot name", () => {
    const words = buildSpotSearchWords("Amsterdam Parkour Spot");
    expect(words).toContain("amsterdam");
    expect(words).toContain("parkour");
    expect(words).toContain("spot");
  });
  it("filters stop words", () => {
    const words = buildSpotSearchWords("the spot in amsterdam");
    expect(words).not.toContain("the");
    expect(words).not.toContain("in");
  });
  it("filters short words", () => {
    const words = buildSpotSearchWords("a bc def");
    expect(words).not.toContain("bc");
    expect(words).toContain("def");
  });
  it("returns empty array for empty/invalid input", () => {
    expect(buildSpotSearchWords("")).toEqual([]);
    expect(buildSpotSearchWords(null)).toEqual([]);
  });
});

describe("normalizeStringArray", () => {
  it("trims and lowercases", () => {
    expect(normalizeStringArray(["  Foo ", "BAR"])).toEqual(["foo", "bar"]);
  });
  it("filters by allowedValues when provided", () => {
    const allowed = new Set(["walls_low", "walls_high"]);
    expect(normalizeStringArray(["walls_low", "invalid"], allowed)).toEqual(["walls_low"]);
  });
});

describe("normalizeSpotAttributeDefaults", () => {
  it("normalizes valid spotAccess", () => {
    const result = normalizeSpotAttributeDefaults({spotAccess: "  PUBLIC  "});
    expect(result.spotAccess).toBe("public");
  });
  it("normalizes spotFeatures with allowed values", () => {
    const result = normalizeSpotAttributeDefaults({spotFeatures: ["walls_low", "invalid"]});
    expect(result.spotFeatures).toEqual(["walls_low"]);
  });
  it("returns null for invalid input", () => {
    expect(normalizeSpotAttributeDefaults(null)).toBeNull();
    expect(normalizeSpotAttributeDefaults([])).toBeNull();
  });
});

describe("mergeSpotAttributeDefaults", () => {
  it("merges base and override", () => {
    const base = {spotFeatures: ["walls_low"]};
    const override = {goodFor: ["vaults"]};
    const merged = mergeSpotAttributeDefaults(base, override);
    expect(merged.spotFeatures).toContain("walls_low");
    expect(merged.goodFor).toContain("vaults");
  });
  it("override access wins", () => {
    const base = {spotAccess: "public"};
    const override = {spotAccess: "restricted"};
    expect(mergeSpotAttributeDefaults(base, override).spotAccess).toBe("restricted");
  });
});

describe("mergeUniqueStringArrays", () => {
  it("unions arrays without duplicates", () => {
    expect(mergeUniqueStringArrays(["a", "b"], ["b", "c"])).toEqual(["a", "b", "c"]);
  });
});

describe("areStringArraysEqual", () => {
  it("returns true for equal arrays", () => {
    expect(areStringArraysEqual(["a", "b"], ["a", "b"])).toBe(true);
  });
  it("returns false for different arrays", () => {
    expect(areStringArraysEqual(["a"], ["b"])).toBe(false);
    expect(areStringArraysEqual(["a", "b"], ["a"])).toBe(false);
  });
});

describe("applySpotAttributeDefaultsToSpotData", () => {
  it("applies spotAccess and returns true when changed", () => {
    const spot = {};
    expect(applySpotAttributeDefaultsToSpotData(spot, {spotAccess: "public"})).toBe(true);
    expect(spot.spotAccess).toBe("public");
  });
  it("returns false when nothing changes", () => {
    const spot = {spotAccess: "public"};
    expect(applySpotAttributeDefaultsToSpotData(spot, {spotAccess: "public"})).toBe(false);
  });
});

describe("buildSpotAttributeUpdateData", () => {
  it("builds update object with provided updatedAt", () => {
    const ts = {_placeholder: "serverTimestamp"};
    const data = buildSpotAttributeUpdateData(
        {spotAccess: "public", spotFeatures: ["walls_low"]},
        ts,
    );
    expect(data.updatedAt).toBe(ts);
    expect(data.spotAccess).toBe("public");
    expect(data.spotFeatures).toEqual(["walls_low"]);
  });
});
