const {
  USER_AGENT,
  FALLBACK_USER_AGENT,
  DEFAULT_ACCEPT,
  DEFAULT_MAX_ATTEMPTS,
  downloadTextFromUrl,
  resolveRetryDelayMs,
  isRetryableStatus,
  isConnectionFailure,
} = require("../lib/download-text");

describe("download-text helpers", () => {
  it("uses a browser-compatible User-Agent for calendar hosts", () => {
    expect(USER_AGENT).toContain("Mozilla/5.0");
    expect(USER_AGENT).toContain("ParkourSpotEventSync");
  });

  it("has a non-browser fallback User-Agent", () => {
    expect(FALLBACK_USER_AGENT).not.toContain("Mozilla");
    expect(FALLBACK_USER_AGENT).toContain("ParkourSpotEventSync");
  });

  it("classifies connection failures separately from HTTP errors", () => {
    expect(isConnectionFailure(new Error("socket hang up"))).toBe(true);
    expect(isConnectionFailure(new Error("ICS request timed out"))).toBe(true);
    const reset = new Error("read failed");
    reset.code = "ECONNRESET";
    expect(isConnectionFailure(reset)).toBe(true);
    const http = new Error("Failed fetching ICS (HTTP 503)");
    http.statusCode = 503;
    expect(isConnectionFailure(http)).toBe(false);
  });

  it("switches to the fallback User-Agent after a dropped connection",
      async () => {
        const sleeps = [];
        const userAgents = [];
        const downloadOnceFn = jest.fn(async (url, options) => {
          userAgents.push(options.userAgent);
          if (options.userAgent === USER_AGENT) {
            throw new Error("socket hang up");
          }
          return {body: "BEGIN:VCALENDAR\nEND:VCALENDAR\n", statusCode: 200};
        });

        const body = await downloadTextFromUrl(
            "https://example.com/events/list/?ical=1",
            {
              downloadOnceFn,
              sleepFn: async (ms) => {
                sleeps.push(ms);
              },
            },
        );

        expect(body).toContain("BEGIN:VCALENDAR");
        expect(userAgents).toEqual([USER_AGENT, FALLBACK_USER_AGENT]);
        expect(sleeps).toEqual([]);
      });

  it("keeps the browser User-Agent when retrying HTTP 429", async () => {
    const userAgents = [];
    const downloadOnceFn = jest.fn(async (url, options) => {
      userAgents.push(options.userAgent);
      if (userAgents.length === 1) {
        const error = new Error("Failed fetching ICS (HTTP 429)");
        error.statusCode = 429;
        throw error;
      }
      return {body: "BEGIN:VCALENDAR\nEND:VCALENDAR\n", statusCode: 200};
    });

    await downloadTextFromUrl("https://example.com/feed.ics", {
      baseDelayMs: 1,
      maxDelayMs: 10,
      downloadOnceFn,
      sleepFn: async () => {},
    });

    expect(userAgents).toEqual([USER_AGENT, USER_AGENT]);
  });

  it("prefers calendar content types in Accept", () => {
    expect(DEFAULT_ACCEPT.startsWith("text/calendar")).toBe(true);
  });

  it("retries 429 and common gateway failures", () => {
    expect(isRetryableStatus(429)).toBe(true);
    expect(isRetryableStatus(503)).toBe(true);
    expect(isRetryableStatus(404)).toBe(false);
  });

  it("honors Retry-After seconds when present", () => {
    expect(resolveRetryDelayMs("2", 1, 1500, 20000)).toBe(2000);
  });

  it("falls back to exponential delay without Retry-After", () => {
    const delay = resolveRetryDelayMs(undefined, 2, 1000, 20000);
    expect(delay).toBeGreaterThanOrEqual(2000);
    expect(delay).toBeLessThanOrEqual(2250);
  });

  it("retries HTTP 429 then succeeds", async () => {
    const sleeps = [];
    const calls = [];
    const downloadOnceFn = jest.fn(async () => {
      calls.push(calls.length + 1);
      if (calls.length === 1) {
        const error = new Error("Failed fetching ICS (HTTP 429)");
        error.statusCode = 429;
        error.retryAfter = "1";
        throw error;
      }
      return {body: "BEGIN:VCALENDAR\nEND:VCALENDAR\n", statusCode: 200};
    });

    const body = await downloadTextFromUrl(
        "https://calendar.google.com/calendar/ical/test/public/basic.ics",
        {
          maxAttempts: 3,
          baseDelayMs: 10,
          maxDelayMs: 1000,
          downloadOnceFn,
          sleepFn: async (ms) => {
            sleeps.push(ms);
          },
        },
    );

    expect(body).toContain("BEGIN:VCALENDAR");
    expect(downloadOnceFn).toHaveBeenCalledTimes(2);
    expect(sleeps).toEqual([1000]);
  });

  it("gives up after maxAttempts on persistent 429", async () => {
    const downloadOnceFn = jest.fn(async () => {
      const error = new Error("Failed fetching ICS (HTTP 429)");
      error.statusCode = 429;
      throw error;
    });

    await expect(downloadTextFromUrl("https://example.com/feed.ics", {
      maxAttempts: 3,
      baseDelayMs: 1,
      maxDelayMs: 10,
      downloadOnceFn,
      sleepFn: async () => {},
    })).rejects.toThrow(/HTTP 429/);

    expect(downloadOnceFn).toHaveBeenCalledTimes(3);
  });

  it("does not retry non-retryable HTTP errors", async () => {
    const downloadOnceFn = jest.fn(async () => {
      const error = new Error("Failed fetching ICS (HTTP 404)");
      error.statusCode = 404;
      throw error;
    });

    await expect(downloadTextFromUrl("https://example.com/missing.ics", {
      maxAttempts: DEFAULT_MAX_ATTEMPTS,
      downloadOnceFn,
      sleepFn: async () => {},
    })).rejects.toThrow(/HTTP 404/);

    expect(downloadOnceFn).toHaveBeenCalledTimes(1);
  });
});
