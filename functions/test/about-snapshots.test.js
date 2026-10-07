const {
  eventSlug,
  isPublicEvent,
  buildPlaceSnapshots,
  attachEventsAndBuildIndexes,
  TOP_SPOTS_LIMIT,
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
    it("includes a city with a single public spot", () => {
      const spots = [
        {
          id: "lonely",
          name: "Only one",
          countryCode: "NL",
          city: "Utrecht",
          hidden: false,
          ratingCount: 3,
          ranking: 20,
        },
      ];

      const {cityDocs, countryDocs, indexCountries} = buildPlaceSnapshots(spots);
      expect(cityDocs.has("nl_utrecht")).toBe(true);
      expect(cityDocs.get("nl_utrecht").spotCount).toBe(1);
      expect(countryDocs.get("nl").spotCount).toBe(1);
      expect(indexCountries).toEqual([
        expect.objectContaining({code: "nl", cityCount: 1, spotCount: 1}),
      ]);
    });

    it("sorts rated spots by ranking and caps the sample at 10", () => {
      const spots = [];
      for (let i = 0; i < 15; i++) {
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
      const paris = cityDocs.get("fr_paris");
      expect(paris.spotCount).toBe(15);
      expect(paris.spots).toHaveLength(TOP_SPOTS_LIMIT);
      expect(paris.spots[0].id).toBe("s14");
      expect(paris.spots[9].id).toBe("s5");
    });

    it("counts unrated spots and keeps below-average rated spots in the sample", () => {
      const spots = [
        {
          id: "good",
          name: "Good",
          countryCode: "de",
          city: "Berlin",
          ratingCount: 4,
          ranking: 14,
        },
        {
          id: "weak",
          name: "Weak",
          countryCode: "de",
          city: "Berlin",
          ratingCount: 8,
          averageRating: 2.1,
          ranking: -4,
        },
        {
          id: "bare",
          name: "Bare",
          countryCode: "de",
          city: "Berlin",
          ratingCount: 0,
          ranking: 0.4,
        },
      ];

      const {cityDocs} = buildPlaceSnapshots(spots);
      const berlin = cityDocs.get("de_berlin");
      expect(berlin.spotCount).toBe(3);
      expect(berlin.spots.map((s) => s.id)).toEqual(["good", "weak"]);
    });

    it("picks the country sample from every rated spot, not each city cap", () => {
      const spots = [];
      for (let i = 0; i < 12; i++) {
        spots.push({
          id: `a${i}`,
          name: `A${i}`,
          countryCode: "nl",
          city: "Amsterdam",
          ratingCount: 1,
          ranking: i,
        });
      }
      spots.push({
        id: "best",
        name: "Best",
        countryCode: "nl",
        city: "Utrecht",
        ratingCount: 2,
        ranking: 40,
      });

      const {countryDocs} = buildPlaceSnapshots(spots);
      const nl = countryDocs.get("nl");
      expect(nl.spotCount).toBe(13);
      expect(nl.spots[0].id).toBe("best");
      expect(nl.spots).toHaveLength(TOP_SPOTS_LIMIT);
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

    it("creates a city page for an event with no spots", () => {
      const placeState = buildPlaceSnapshots([], {
        generatedAt: "2026-10-01T00:00:00.000Z",
      });
      const now = new Date("2026-10-02T00:00:00.000Z");
      const events = [
        {
          id: "alkmaar01xxxx",
          title: "Alkmaar jam",
          startAt: new Date("2026-11-01T10:00:00.000Z"),
          countryCode: "NL",
          city: "Alkmaar",
        },
        {
          id: "nocountryxxxx",
          title: "Somewhere jam",
          startAt: new Date("2026-11-02T10:00:00.000Z"),
        },
      ];

      const result = attachEventsAndBuildIndexes(placeState, events, now);
      expect(result.eventsIndex.events).toHaveLength(2);
      expect(result.cityDocs.get("nl_alkmaar").spotCount).toBe(0);
      expect(result.cityDocs.get("nl_alkmaar").events).toHaveLength(1);
      expect(result.countryDocs.get("nl").events).toHaveLength(1);
      expect(result.countryDocs.get("nl").cities).toEqual([
        expect.objectContaining({citySlug: "alkmaar", spotCount: 0, eventCount: 1}),
      ]);
      expect(result.aboutIndex.countries).toEqual([
        expect.objectContaining({code: "nl", cityCount: 1, spotCount: 0, eventCount: 1}),
      ]);
    });
  });
});
