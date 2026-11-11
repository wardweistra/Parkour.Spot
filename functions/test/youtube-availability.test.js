const https = require("https");
const {
  normalizeYoutubeVideoId,
  checkYoutubeVideoOembedAvailability,
} = require("../lib/youtube-availability");

describe("normalizeYoutubeVideoId", () => {
  it("accepts bare IDs", () => {
    expect(normalizeYoutubeVideoId("dQw4w9WgXcQ")).toBe("dQw4w9WgXcQ");
  });

  it("extracts from watch URLs", () => {
    expect(
        normalizeYoutubeVideoId(
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        ),
    ).toBe("dQw4w9WgXcQ");
  });

  it("extracts from youtu.be URLs", () => {
    expect(normalizeYoutubeVideoId("https://youtu.be/dQw4w9WgXcQ"))
        .toBe("dQw4w9WgXcQ");
  });

  it("returns null for too-short or empty values", () => {
    expect(normalizeYoutubeVideoId("short")).toBeNull();
    expect(normalizeYoutubeVideoId("")).toBeNull();
  });
});

describe("checkYoutubeVideoOembedAvailability", () => {
  let originalGet;

  beforeEach(() => {
    originalGet = https.get;
  });

  afterEach(() => {
    https.get = originalGet;
  });

  it("treats HTTP 200 as available", async () => {
    https.get = jest.fn((url, options, callback) => {
      const response = {
        statusCode: 200,
        resume: jest.fn(),
        on: jest.fn(),
      };
      callback(response);
      return {
        on: jest.fn(),
        setTimeout: jest.fn(),
        destroy: jest.fn(),
      };
    });

    const result = await checkYoutubeVideoOembedAvailability("dQw4w9WgXcQ");
    expect(result.available).toBe(true);
    expect(result.rateLimited).toBe(false);
  });

  it("treats HTTP 404 as unavailable", async () => {
    https.get = jest.fn((url, options, callback) => {
      const response = {
        statusCode: 404,
        resume: jest.fn(),
        on: jest.fn(),
      };
      callback(response);
      return {
        on: jest.fn(),
        setTimeout: jest.fn(),
        destroy: jest.fn(),
      };
    });

    const result = await checkYoutubeVideoOembedAvailability("00000000000");
    expect(result.available).toBe(false);
    expect(result.reason).toBe("not_found_or_private");
  });

  it("treats HTTP 429 as rate limited", async () => {
    https.get = jest.fn((url, options, callback) => {
      const response = {
        statusCode: 429,
        resume: jest.fn(),
        on: jest.fn(),
      };
      callback(response);
      return {
        on: jest.fn(),
        setTimeout: jest.fn(),
        destroy: jest.fn(),
      };
    });

    const result = await checkYoutubeVideoOembedAvailability("abc123xyz01");
    expect(result.available).toBeNull();
    expect(result.rateLimited).toBe(true);
  });
});
