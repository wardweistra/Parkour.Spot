const {
  getCountryNameWithArticle,
  calculateDistance,
  calculateBounds,
} = require("../lib/geo");

describe("getCountryNameWithArticle", () => {
  it("adds \"the\" for countries that require it when withArticle is true", () => {
    expect(getCountryNameWithArticle("NL", true)).toBe("the Netherlands");
    expect(getCountryNameWithArticle("US", true)).toMatch(/^the United States/);
    expect(getCountryNameWithArticle("GB", true)).toMatch(/^the United Kingdom/);
  });
  it("omits article when withArticle is false", () => {
    expect(getCountryNameWithArticle("NL", false)).toBe("Netherlands");
    expect(getCountryNameWithArticle("US", false)).toMatch(/^United States/);
  });
  it("returns plain country name for countries without article", () => {
    expect(getCountryNameWithArticle("DE", true)).toBe("Germany");
    expect(getCountryNameWithArticle("FR", true)).toBe("France");
  });
  it("handles lowercase country codes", () => {
    expect(getCountryNameWithArticle("nl", true)).toBe("the Netherlands");
  });
});

describe("calculateDistance", () => {
  it("returns 0 for same coordinates", () => {
    expect(calculateDistance(52.37, 4.89, 52.37, 4.89)).toBe(0);
  });
  it("returns positive distance for different points", () => {
    const d = calculateDistance(52.37, 4.89, 52.38, 4.90);
    expect(d).toBeGreaterThan(0);
    expect(d).toBeLessThan(2000); // Roughly 1-2 km
  });
});

describe("calculateBounds", () => {
  it("returns symmetric bounds around center", () => {
    const bounds = calculateBounds(52.37, 4.89, 50);
    expect(bounds.minLat).toBeLessThan(52.37);
    expect(bounds.maxLat).toBeGreaterThan(52.37);
    expect(bounds.minLng).toBeLessThan(4.89);
    expect(bounds.maxLng).toBeGreaterThan(4.89);
    expect(bounds.minLat + bounds.maxLat).toBeCloseTo(52.37 * 2, 5);
    expect(bounds.minLng + bounds.maxLng).toBeCloseTo(4.89 * 2, 5);
  });
  it("uses custom distanceMeters", () => {
    const bounds50 = calculateBounds(52.37, 4.89, 50);
    const bounds100 = calculateBounds(52.37, 4.89, 100);
    expect(Math.abs(bounds100.maxLat - bounds100.minLat))
        .toBeGreaterThan(Math.abs(bounds50.maxLat - bounds50.minLat));
  });
});
