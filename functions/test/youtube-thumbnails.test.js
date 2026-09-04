const {
  youtubeThumbnailUrl,
  isPlausibleYoutubeVideoId,
  youtubeIdsNeedingThumbnails,
} = require("../lib/youtube-thumbnails");

describe("youtubeThumbnailUrl", () => {
  it("uses maxresdefault by default", () => {
    expect(youtubeThumbnailUrl("abc123xyz")).toBe(
        "https://img.youtube.com/vi/abc123xyz/maxresdefault.jpg",
    );
  });

  it("accepts an alternate quality", () => {
    expect(youtubeThumbnailUrl("abc123xyz", "hqdefault")).toBe(
        "https://img.youtube.com/vi/abc123xyz/hqdefault.jpg",
    );
  });
});

describe("isPlausibleYoutubeVideoId", () => {
  it("accepts typical 11-character IDs", () => {
    expect(isPlausibleYoutubeVideoId("dQw4w9WgXcQ")).toBe(true);
  });

  it("rejects URLs and empty values", () => {
    expect(isPlausibleYoutubeVideoId("")).toBe(false);
    expect(isPlausibleYoutubeVideoId("https://youtu.be/abc")).toBe(false);
    expect(isPlausibleYoutubeVideoId("ab")).toBe(false);
  });
});

describe("youtubeIdsNeedingThumbnails", () => {
  it("returns only newly added IDs", () => {
    expect(youtubeIdsNeedingThumbnails(
        ["aaa"],
        ["aaa", "bbb"],
        [],
    )).toEqual(["bbb"]);
  });

  it("skips IDs that already have a CDN thumbnail in photos", () => {
    expect(youtubeIdsNeedingThumbnails(
        [],
        ["bbb"],
        ["https://img.youtube.com/vi/bbb/maxresdefault.jpg"],
    )).toEqual([]);
  });

  it("preserves first-seen order and drops duplicates", () => {
    expect(youtubeIdsNeedingThumbnails(
        [],
        ["bbb", "ccc", "bbb"],
        [],
    )).toEqual(["bbb", "ccc"]);
  });
});
