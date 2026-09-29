const {
  JUMP_EVENTS_API_URL,
  JUMP_EVENTS_DEFAULT_TIME_ZONE,
  JUMP_EVENTS_PUBLIC_URL,
  fetchJumpEventsCalendarEvents,
  isJumpEventsPayload,
  jumpEventsEventUrl,
  jumpEventsImageUrl,
  jumpEventsPublicUrl,
  normalizeJumpEventsFeedUrl,
} = require("../lib/jump-events");

describe("jump-events helpers", () => {
  describe("normalizeJumpEventsFeedUrl", () => {
    it("normalizes the homepage to the API URL", () => {
      expect(normalizeJumpEventsFeedUrl("https://jumpevents.nl/"))
          .toBe(JUMP_EVENTS_API_URL);
    });

    it("accepts www and the API path", () => {
      expect(normalizeJumpEventsFeedUrl(
          "https://www.jumpevents.nl/api/events?x=1",
      )).toBe(JUMP_EVENTS_API_URL);
    });

    it("rejects unrelated hosts", () => {
      expect(() => normalizeJumpEventsFeedUrl("https://example.com/api/events"))
          .toThrow(/jumpevents\.nl/);
    });

    it("rejects empty input", () => {
      expect(() => normalizeJumpEventsFeedUrl(""))
          .toThrow(/icsUrl is required/);
    });
  });

  describe("jumpEventsPublicUrl", () => {
    it("returns the public agenda homepage", () => {
      expect(jumpEventsPublicUrl(JUMP_EVENTS_API_URL))
          .toBe(JUMP_EVENTS_PUBLIC_URL);
    });
  });

  describe("jumpEventsImageUrl", () => {
    it("builds an uploads URL", () => {
      expect(jumpEventsImageUrl("a4483444564d7094.jpeg"))
          .toBe("https://jumpevents.nl/uploads/a4483444564d7094.jpeg");
    });

    it("returns null for empty photo", () => {
      expect(jumpEventsImageUrl("")).toBeNull();
    });
  });

  describe("jumpEventsEventUrl", () => {
    it("builds the public event detail page URL", () => {
      expect(jumpEventsEventUrl("19062312-50e6-4408-b796-ff1da741c1b0"))
          .toBe(
              "https://jumpevents.nl/evenement/" +
              "19062312-50e6-4408-b796-ff1da741c1b0",
          );
    });

    it("returns null without an id", () => {
      expect(jumpEventsEventUrl("")).toBeNull();
    });
  });

  describe("isJumpEventsPayload", () => {
    it("accepts arrays", () => {
      expect(isJumpEventsPayload([])).toBe(true);
      expect(isJumpEventsPayload([{id: "1"}])).toBe(true);
    });

    it("rejects non-arrays", () => {
      expect(isJumpEventsPayload(null)).toBe(false);
      expect(isJumpEventsPayload({events: []})).toBe(false);
    });
  });

  describe("fetchJumpEventsCalendarEvents", () => {
    it("parses the API array and dedupes by id", async () => {
      const fetched = await fetchJumpEventsCalendarEvents(
          "https://jumpevents.nl/",
          {
            downloadText: async (url) => {
              expect(url).toBe(JUMP_EVENTS_API_URL);
              return JSON.stringify([
                {id: "a", title: "One"},
                {id: "a", title: "Duplicate"},
                {id: "b", title: "Two"},
                {title: "No id kept"},
              ]);
            },
          },
      );

      expect(fetched.defaultTimeZone).toBe(JUMP_EVENTS_DEFAULT_TIME_ZONE);
      expect(fetched.collectionUrl).toBe(JUMP_EVENTS_PUBLIC_URL);
      expect(fetched.items).toHaveLength(3);
      expect(fetched.items.map((item) => item.title)).toEqual([
        "One",
        "Two",
        "No id kept",
      ]);
    });

    it("rejects non-array JSON", async () => {
      await expect(fetchJumpEventsCalendarEvents(
          "https://jumpevents.nl/api/events",
          {
            downloadText: async () => JSON.stringify({events: []}),
          },
      )).rejects.toThrow(/Jump Events JSON array/);
    });
  });
});
