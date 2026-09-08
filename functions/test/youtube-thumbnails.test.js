const https = require("https");
const {
  youtubeThumbnailUrl,
  isPlausibleYoutubeVideoId,
  extractYoutubeVideoIdFromThumbnailUrl,
  isYoutubeCdnThumbnailUrl,
  getYoutubeThumbnailUrlCandidates,
  checkYoutubeThumbnailAvailable,
  resolveYoutubeThumbnailUrl,
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

describe("extractYoutubeVideoIdFromThumbnailUrl", () => {
  it("extracts IDs from img.youtube.com URLs", () => {
    expect(
        extractYoutubeVideoIdFromThumbnailUrl(
            "https://img.youtube.com/vi/pjJ2XwoSmx8/maxresdefault.jpg",
        ),
    ).toBe("pjJ2XwoSmx8");
  });

  it("extracts IDs from i.ytimg.com URLs", () => {
    expect(
        extractYoutubeVideoIdFromThumbnailUrl(
            "https://i3.ytimg.com/vi/pjJ2XwoSmx8/hqdefault.jpg",
        ),
    ).toBe("pjJ2XwoSmx8");
  });

  it("returns null for non-YouTube URLs", () => {
    expect(
        extractYoutubeVideoIdFromThumbnailUrl("https://example.com/photo.jpg"),
    ).toBeNull();
  });
});

describe("getYoutubeThumbnailUrlCandidates", () => {
  it("returns qualities highest-first for YouTube CDN URLs", () => {
    expect(
        getYoutubeThumbnailUrlCandidates(
            "https://img.youtube.com/vi/pjJ2XwoSmx8/maxresdefault.jpg",
        ),
    ).toEqual([
      "https://img.youtube.com/vi/pjJ2XwoSmx8/maxresdefault.jpg",
      "https://img.youtube.com/vi/pjJ2XwoSmx8/sddefault.jpg",
      "https://img.youtube.com/vi/pjJ2XwoSmx8/hqdefault.jpg",
    ]);
  });

  it("returns an empty array for non-YouTube URLs", () => {
    expect(getYoutubeThumbnailUrlCandidates("https://example.com/a.jpg"))
        .toEqual([]);
  });
});

describe("isYoutubeCdnThumbnailUrl", () => {
  it("detects YouTube CDN thumbnail URLs", () => {
    expect(
        isYoutubeCdnThumbnailUrl(
            "https://i3.ytimg.com/vi/pjJ2XwoSmx8/hqdefault.jpg",
        ),
    ).toBe(true);
    expect(isYoutubeCdnThumbnailUrl("https://example.com/a.jpg")).toBe(false);
  });
});

describe("checkYoutubeThumbnailAvailable", () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("returns true for HTTP 200", async () => {
    jest.spyOn(https, "request").mockImplementation((url, options, callback) => {
      callback({statusCode: 200, resume: jest.fn()});
      return {on: jest.fn(), setTimeout: jest.fn(), end: jest.fn()};
    });

    await expect(
        checkYoutubeThumbnailAvailable(
            "https://img.youtube.com/vi/pjJ2XwoSmx8/hqdefault.jpg",
        ),
    ).resolves.toBe(true);
  });

  it("returns false for HTTP 404", async () => {
    jest.spyOn(https, "request").mockImplementation((url, options, callback) => {
      callback({statusCode: 404, resume: jest.fn()});
      return {on: jest.fn(), setTimeout: jest.fn(), end: jest.fn()};
    });

    await expect(
        checkYoutubeThumbnailAvailable(
            "https://img.youtube.com/vi/pjJ2XwoSmx8/maxresdefault.jpg",
        ),
    ).resolves.toBe(false);
  });
});

describe("resolveYoutubeThumbnailUrl", () => {
  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("skips unavailable qualities and returns the first HTTP 200", async () => {
    jest.spyOn(https, "request").mockImplementation((url, options, callback) => {
      const statusCode = String(url).includes("maxresdefault") ? 404 : 200;
      callback({statusCode, resume: jest.fn()});
      return {on: jest.fn(), setTimeout: jest.fn(), end: jest.fn()};
    });

    await expect(resolveYoutubeThumbnailUrl("pjJ2XwoSmx8")).resolves.toBe(
        "https://img.youtube.com/vi/pjJ2XwoSmx8/sddefault.jpg",
    );
  });

  it("returns null when no qualities are available", async () => {
    jest.spyOn(https, "request").mockImplementation((url, options, callback) => {
      callback({statusCode: 404, resume: jest.fn()});
      return {on: jest.fn(), setTimeout: jest.fn(), end: jest.fn()};
    });

    await expect(resolveYoutubeThumbnailUrl("pjJ2XwoSmx8")).resolves.toBeNull();
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
