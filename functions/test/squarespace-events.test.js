const {
  MAX_EVENTS,
  MAX_PAGES,
  fetchSquarespaceCalendarEvents,
  isSquarespaceCalendarPayload,
  normalizeSquarespaceEventsPageUrl,
  squarespaceEventsPublicUrl,
} = require("../lib/squarespace-events");

describe("squarespace-events helpers", () => {
  describe("normalizeSquarespaceEventsPageUrl", () => {
    it("adds format=json and strips the fragment", () => {
      expect(
          normalizeSquarespaceEventsPageUrl(
              "https://www.weave-pk.nl/events#list",
          ),
      ).toBe("https://www.weave-pk.nl/events?format=json");
    });

    it("overwrites an existing format query param", () => {
      expect(
          normalizeSquarespaceEventsPageUrl(
              "https://pkgenboston.com/local-events?format=html&foo=1",
          ),
      ).toBe("https://pkgenboston.com/local-events?format=json&foo=1");
    });

    it("rejects non-http protocols", () => {
      expect(() => normalizeSquarespaceEventsPageUrl("ftp://example.com/x"))
          .toThrow(/http or https/);
    });

    it("rejects empty input", () => {
      expect(() => normalizeSquarespaceEventsPageUrl(""))
          .toThrow(/icsUrl is required/);
    });
  });

  describe("squarespaceEventsPublicUrl", () => {
    it("strips format=json while keeping other query params", () => {
      expect(
          squarespaceEventsPublicUrl(
              "https://example.com/events?format=json&lang=en",
          ),
      ).toBe("https://example.com/events?lang=en");
    });

    it("returns a clean URL when format was the only query param", () => {
      expect(
          squarespaceEventsPublicUrl(
              "https://example.com/events?format=json",
          ),
      ).toBe("https://example.com/events");
    });
  });

  describe("isSquarespaceCalendarPayload", () => {
    it("accepts objects with upcoming or past arrays", () => {
      expect(isSquarespaceCalendarPayload({upcoming: []})).toBe(true);
      expect(isSquarespaceCalendarPayload({past: []})).toBe(true);
    });

    it("rejects non-calendar payloads", () => {
      expect(isSquarespaceCalendarPayload(null)).toBe(false);
      expect(isSquarespaceCalendarPayload([])).toBe(false);
      expect(isSquarespaceCalendarPayload({website: {}})).toBe(false);
    });
  });

  describe("fetchSquarespaceCalendarEvents", () => {
    it("concatenates upcoming and past across paginated pages", async () => {
      const pages = {
        "https://example.com/events?format=json": JSON.stringify({
          website: {timeZone: "America/New_York"},
          upcoming: [{id: "u1", title: "Upcoming"}],
          past: [{id: "p1", title: "Past 1"}],
          pagination: {
            nextPage: true,
            nextPageUrl: "/events?offset=100",
          },
        }),
        "https://example.com/events?offset=100&format=json": JSON.stringify({
          website: {timeZone: "America/New_York"},
          upcoming: [],
          past: [{id: "p2", title: "Past 2"}],
          pagination: {nextPage: false},
        }),
      };

      const fetched = await fetchSquarespaceCalendarEvents(
          "https://example.com/events",
          {
            downloadText: async (url) => {
              if (!pages[url]) throw new Error(`unexpected url ${url}`);
              return pages[url];
            },
          },
      );

      expect(fetched.websiteTimeZone).toBe("America/New_York");
      expect(fetched.siteOrigin).toBe("https://example.com");
      expect(fetched.collectionUrl).toBe("https://example.com/events");
      expect(fetched.items.map((item) => item.id)).toEqual(["u1", "p1", "p2"]);
    });

    it("dedupes items seen on later pages", async () => {
      const fetched = await fetchSquarespaceCalendarEvents(
          "https://example.com/events",
          {
            downloadText: async () => JSON.stringify({
              upcoming: [{id: "same", title: "A"}],
              past: [{id: "same", title: "A again"}],
            }),
          },
      );
      expect(fetched.items).toHaveLength(1);
    });

    it("stops at the event cap", async () => {
      const bulk = Array.from({length: MAX_EVENTS + 50}, (_, i) => ({
        id: `e${i}`,
        title: `Event ${i}`,
      }));
      const fetched = await fetchSquarespaceCalendarEvents(
          "https://example.com/events",
          {
            downloadText: async () => JSON.stringify({
              upcoming: bulk,
              past: [],
            }),
          },
      );
      expect(fetched.items).toHaveLength(MAX_EVENTS);
    });

    it("throws when the response is not calendar JSON", async () => {
      await expect(
          fetchSquarespaceCalendarEvents("https://example.com/about", {
            downloadText: async () => JSON.stringify({website: {}}),
          }),
      ).rejects.toThrow(/Squarespace calendar JSON/);
    });

    it("exposes pagination page and event caps", () => {
      expect(MAX_PAGES).toBe(20);
      expect(MAX_EVENTS).toBe(500);
    });
  });
});
