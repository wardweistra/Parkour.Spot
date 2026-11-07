const {slugify, spotPath} = require("../utils");

describe("slugify", () => {
  it("slugifies latin city names", () => {
    expect(slugify("Amsterdam")).toBe("amsterdam");
    expect(slugify("München")).toBe("munchen");
  });

  it("transliterates greek city names", () => {
    expect(slugify("Ηράκλειο")).toBe("irakleio");
    expect(slugify("Θεσσαλονίκη")).toBe("thessaloniki");
  });

  it("returns empty when nothing ascii remains", () => {
    expect(slugify("Москва")).toBe("");
  });
});

describe("spotPath", () => {
  it("builds /cc/city/id when city slugifies", () => {
    expect(spotPath("abc123", "NL", "Amsterdam")).toBe("/nl/amsterdam/abc123");
    expect(spotPath("991hF1AL1pEGkWQDjB8S", "GR", "Ηράκλειο"))
        .toBe("/gr/irakleio/991hF1AL1pEGkWQDjB8S");
  });

  it("falls back to /spot/:id when city is missing or empty after slugify", () => {
    expect(spotPath("abc123", "GR", null)).toBe("/spot/abc123");
    expect(spotPath("abc123", "GR", "   ")).toBe("/spot/abc123");
    expect(spotPath("abc123", "RU", "Москва")).toBe("/spot/abc123");
    expect(spotPath("abc123", null, "Amsterdam")).toBe("/spot/abc123");
  });
});
