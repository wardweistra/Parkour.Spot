const {
  applyHasImagesFilter,
  deriveHasImages,
  buildHasImagesBackfillUpdate,
} = require("../lib/spot-image-filter");

describe("applyHasImagesFilter", () => {
  it("adds the materialized hasImages constraint when enabled", () => {
    const filteredQuery = {name: "filtered"};
    const query = {
      where: jest.fn().mockReturnValue(filteredQuery),
    };

    const result = applyHasImagesFilter(query, true);

    expect(query.where).toHaveBeenCalledWith("hasImages", "==", true);
    expect(result).toBe(filteredQuery);
  });

  it.each([false, null, undefined, "true"])(
      "leaves the query unchanged for %p",
      (value) => {
        const query = {
          where: jest.fn(),
        };

        const result = applyHasImagesFilter(query, value);

        expect(query.where).not.toHaveBeenCalled();
        expect(result).toBe(query);
      },
  );
});

describe("deriveHasImages", () => {
  it.each([
    [[], null, false],
    [null, null, false],
    [undefined, null, false],
    ["https://example.com/image.jpg", null, false],
    [["https://example.com/image.jpg"], null, true],
    [null, "https://example.com/legacy.jpg", true],
    [[], "   ", false],
  ])("derives %p and legacy %p as %p", (imageUrls, legacyImageUrl, expected) => {
    expect(deriveHasImages(imageUrls, legacyImageUrl)).toBe(expected);
  });
});

describe("buildHasImagesBackfillUpdate", () => {
  it("adds a missing true value", () => {
    expect(buildHasImagesBackfillUpdate({imageUrls: ["image.jpg"]}))
        .toEqual({hasImages: true});
  });

  it("repairs a stale value", () => {
    expect(buildHasImagesBackfillUpdate({
      imageUrls: [],
      hasImages: true,
    })).toEqual({hasImages: false});
  });

  it("supports the legacy singular imageUrl field", () => {
    expect(buildHasImagesBackfillUpdate({
      imageUrl: "legacy.jpg",
    })).toEqual({hasImages: true});
  });

  it("skips a value that is already correct", () => {
    expect(buildHasImagesBackfillUpdate({
      imageUrls: ["image.jpg"],
      hasImages: true,
    })).toBeNull();
  });
});
