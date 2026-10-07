const {
  eventSlug,
  isPublicEvent,
  buildPlaceSnapshots,
  attachEventsAndBuildIndexes,
  MIN_RATED_SPOTS_PER_CITY,
} = require("../lib/about-snapshots");

describe("about-snapshots", () => {
  describe("eventSlug", () => {
    it("slugifies title and appends id prefix", () => {
      expect(eventSlug("Amsterdam Jam!", "AbCd1234zzzz")).toBe(
          "amsterdam-jam-abcd1234",
      );
    });
  });

  describe("isPublicEvent", () => {
    it("rejects duplicates and hidden events", () => {
      expect(isPublicEvent({duplicateOf: "x"})).toBe(false);
      expect(isPublicEvent({hidden: true})).toBe(false);
      expect(isPublicEvent({visibility: "private"})).toBe(false);
      expect(isPublicEvent({title: "ok"})).toBe(true);
    });
  });

  describe("buildPlaceSnapshots", () => {
    it("only includes cities with enough rated spots", () => {
      const spots = [];
      for (let i = 0; i < MIN_RATED_SPOTS_PER_CITY; i++) {
        spots.push({
          id: `a${i}`,
          name: `Spot A${i}`,
          countryCode: "NL",
          city: "Amsterdam",
          hidden: false,
          duplicateOf: null,
          ratingCount: 2,
          averageRating: 4,
          ranking: 10 + i,
        });
      }
      spots.push({
        id: "lonely",
        name: "Only one",
        countryCode: "NL",
        city: "Utrecht",
        hidden: false,
        ratingCount: 3,
        ranking: 20,
      });

      const {cityDocs, countryDocs, indexCountries} = buildPlaceSnapshots(spots);
      expect(cityDocs.has("nl_amsterdam")).toBe(true);
      expect(cityDocs.has("nl_utrecht")).toBe(false);
      expect(countryDocs.has("nl")).toBe(true);
      expect(indexCountries).toEqual([
        expect.objectContaining({code: "nl", cityCount: 1}),
      ]);
      expect(cityDocs.get("nl_amsterdam").spots).toHaveLength(
          MIN_RATED_SPOTS_PER_CITY,
      );
    });

    it("sorts spots by ranking desc and caps at 20", () => {
      const spots = [];
      for (let i = 0; i < 25; i++) {
        spots.push({
          id: `s${i}`,
          name: `S${i}`,
          countryCode: "fr",
          city: "Paris",
          ratingCount: 1,
          ranking: 10 + i,
        });
      }
      const {cityDocs} = buildPlaceSnapshots(spots);
      const top = cityDocs.get("fr_paris").spots;
      expect(top).toHaveLength(20);
      expect(top[0].id).toBe("s24");
      expect(top[19].id).toBe("s5");
    });

    it("drops spots below the explore Wilson average", () => {
      const spots = [];
      for (let i = 0; i < MIN_RATED_SPOTS_PER_CITY; i++) {
        spots.push({
          id: `good${i}`,
          name: `Good${i}`,
          countryCode: "de",
          city: "Berlin",
          ratingCount: 4,
          ranking: 12 + i,
        });
      }
      spots.push({
        id: "weak",
        name: "Weak",
        countryCode: "de",
        city: "Berlin",
        ratingCount: 8,
        averageRating: 2.1,
        ranking: -4,
      });
      for (let i = 0; i < MIN_RATED_SPOTS_PER_CITY; i++) {
        spots.push({
          id: `bad${i}`,
          name: `Bad${i}`,
          countryCode: "de",
          city: "Hamburg",
          ratingCount: 3,
          ranking: -2 - i,
        });
      }

      const {cityDocs} = buildPlaceSnapshots(spots);
      const berlin = cityDocs.get("de_berlin").spots.map((s) => s.id);
      expect(berlin).not.toContain("weak");
      expect(berlin).toHaveLength(MIN_RATED_SPOTS_PER_CITY);
      expect(cityDocs.has("de_hamburg")).toBe(false);
    });
  });

  describe("attachEventsAndBuildIndexes", () => {
    it("attaches upcoming events to matching hubs", () => {
      const spots = [];
      for (let i = 0; i < 5; i++) {
        spots.push({
          id: `s${i}`,
          name: `S${i}`,
          countryCode: "nl",
          city: "Amsterdam",
          ratingCount: 1,
          ranking: 10 + i,
        });
      }
      const placeState = buildPlaceSnapshots(spots, {
        generatedAt: "2026-10-01T00:00:00.000Z",
      });
      const now = new Date("2026-10-02T00:00:00.000Z");
      const events = [
        {
          id: "abcd1234xxxx",
          title: "Amsterdam jam",
          startAt: new Date("2026-11-01T10:00:00.000Z"),
          countryCode: "NL",
          city: "Amsterdam",
        },
        {
          id: "past0001xxxx",
          title: "Past jam",
          startAt: new Date("2026-09-01T10:00:00.000Z"),
          countryCode: "NL",
          city: "Amsterdam",
        },
      ];

      const result = attachEventsAndBuildIndexes(placeState, events, now);
      expect(result.eventDetails.size).toBe(1);
      expect(result.eventsIndex.events).toHaveLength(1);
      expect(result.eventsIndex.events[0].slug).toBe(
          "amsterdam-jam-abcd1234",
      );
      expect(result.cityDocs.get("nl_amsterdam").events).toHaveLength(1);
      expect(result.countryDocs.get("nl").events).toHaveLength(1);
      expect(result.aboutIndex.eventCount).toBe(1);
    });
  });
});
