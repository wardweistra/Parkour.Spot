const https = require("https");
const {
  normalizeHttpUrl,
  checkHttpUrlReachable,
  cacheStatusFromCheckResult,
  eventIsCurrentOrUpcoming,
  collectEventOutgoingLinks,
  collectSpotListOutgoingLinks,
} = require("../lib/http-link-check");

describe("normalizeHttpUrl", () => {
  it("accepts https URLs", () => {
    expect(normalizeHttpUrl("https://example.com/path")).toBe(
        "https://example.com/path",
    );
  });

  it("prepends https when scheme missing", () => {
    expect(normalizeHttpUrl("example.com/page")).toBe(
        "https://example.com/page",
    );
  });

  it("rejects non-http schemes", () => {
    expect(normalizeHttpUrl("mailto:a@b.com")).toBeNull();
  });
});

describe("eventIsCurrentOrUpcoming", () => {
  const now = new Date("2026-06-15T12:00:00.000Z");

  it("is true when end is in the future", () => {
    expect(eventIsCurrentOrUpcoming({
      startAt: {toDate: () => new Date("2026-06-10T10:00:00.000Z")},
      endAt: {toDate: () => new Date("2026-06-20T10:00:00.000Z")},
    }, now)).toBe(true);
  });

  it("is false when end is in the past", () => {
    expect(eventIsCurrentOrUpcoming({
      startAt: {toDate: () => new Date("2026-06-01T10:00:00.000Z")},
      endAt: {toDate: () => new Date("2026-06-10T10:00:00.000Z")},
    }, now)).toBe(false);
  });
});

describe("collect links", () => {
  it("collects event websiteUrl", () => {
    expect(collectEventOutgoingLinks("e1", {
      title: "Jam",
      websiteUrl: "https://example.com",
    })).toEqual([{
      entityType: "event",
      entityId: "e1",
      entityName: "Jam",
      field: "websiteUrl",
      rawUrl: "https://example.com",
    }]);
  });

  it("collects spot list moreInfoUrl", () => {
    expect(collectSpotListOutgoingLinks("l1", {
      name: "My list",
      moreInfoUrl: "https://example.com/list",
    })).toEqual([{
      entityType: "spotList",
      entityId: "l1",
      entityName: "My list",
      field: "moreInfoUrl",
      rawUrl: "https://example.com/list",
    }]);
  });
});

describe("checkHttpUrlReachable", () => {
  let originalHttpsRequest;

  beforeEach(() => {
    originalHttpsRequest = https.request;
  });

  afterEach(() => {
    https.request = originalHttpsRequest;
  });

  it("treats HTTP 200 as reachable", async () => {
    https.request = jest.fn((url, options, callback) => {
      const response = {
        statusCode: 200,
        headers: {},
        resume: jest.fn(),
      };
      callback(response);
      return {
        on: jest.fn(),
        setTimeout: jest.fn(),
        end: jest.fn(),
        destroy: jest.fn(),
      };
    });

    const result = await checkHttpUrlReachable("https://example.com");
    expect(result.reachable).toBe(true);
    expect(cacheStatusFromCheckResult(result)).toBe("ok");
  });

  it("treats HTTP 404 as broken", async () => {
    https.request = jest.fn((url, options, callback) => {
      const response = {
        statusCode: 404,
        headers: {},
        resume: jest.fn(),
      };
      callback(response);
      return {
        on: jest.fn(),
        setTimeout: jest.fn(),
        end: jest.fn(),
        destroy: jest.fn(),
      };
    });

    const result = await checkHttpUrlReachable("https://example.com/missing");
    expect(result.reachable).toBe(false);
    expect(cacheStatusFromCheckResult(result)).toBe("broken");
  });
});
