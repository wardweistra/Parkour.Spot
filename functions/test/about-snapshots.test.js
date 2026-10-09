const {
  eventSlug,
  isPublicEvent,
  buildPlaceSnapshots,
  attachEventsAndBuildIndexes,
  effectiveEventLocation,
  withResolvedLocationFallback,
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

    it("carries spot coordinates and address into summaries", () => {
      const spots = [
        {
          id: "located",
          name: "Located",
          countryCode: "nl",
          city: "Utrecht",
          latitude: 52.09,
          longitude: 5.12,
          address: " Neude 1, Utrecht ",
          ranking: 2,
        },
        {
          id: "unlocated",
          name: "Unlocated",
          countryCode: "nl",
          city: "Utrecht",
          latitude: "52",
          ranking: 1,
        },
      ];

      const {cityDocs} = buildPlaceSnapshots(spots);
      expect(cityDocs.get("nl_utrecht").spots).toEqual([
        expect.objectContaining({
          id: "located",
          latitude: 52.09,
          longitude: 5.12,
          address: "Neude 1, Utrecht",
        }),
        expect.objectContaining({
          id: "unlocated",
          latitude: null,
          longitude: null,
          address: null,
        }),
      ]);
    });

    it("sorts spots by ranking and caps the sample at 10", () => {
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

    it("lists above-average, then unrated, then below-average spots", () => {
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
      expect(berlin.spots.map((s) => s.id)).toEqual(["good", "bare", "weak"]);
    });

    it("fills the sample with unrated spots before below-average ones", () => {
      const spots = [
        {id: "top", countryCode: "be", city: "Gent", ratingCount: 3, ranking: 13},
        {id: "low", countryCode: "be", city: "Gent", ratingCount: 5, ranking: -8},
      ];
      for (let i = 0; i < 10; i++) {
        spots.push({
          id: `new${i}`,
          countryCode: "be",
          city: "Gent",
          ratingCount: 0,
          ranking: i / 10,
        });
      }

      const {cityDocs, countryDocs} = buildPlaceSnapshots(spots);
      const gent = cityDocs.get("be_gent");
      expect(gent.spotCount).toBe(12);
      expect(gent.spots).toHaveLength(TOP_SPOTS_LIMIT);
      expect(gent.spots[0].id).toBe("top");
      expect(gent.spots.map((s) => s.id)).not.toContain("low");
      expect(countryDocs.get("be").spots.map((s) => s.id))
          .toEqual(gent.spots.map((s) => s.id));
    });

    it("picks the country sample from every spot, not each city cap", () => {
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

    it("places spot-linked events using resolvedLocation", () => {
      const placeState = buildPlaceSnapshots([
        {id: "s1", name: "Kouter", countryCode: "BE", city: "Gent", ranking: 1},
      ], {generatedAt: "2026-10-01T00:00:00.000Z"});
      const now = new Date("2026-10-02T00:00:00.000Z");
      const events = [{
        id: "listonly0xxxx",
        title: "Gent tour",
        startAt: new Date("2026-11-01T10:00:00.000Z"),
        spotListIds: ["list-1"],
        resolvedLocation: {
          source: "list",
          latitude: 51.05,
          longitude: 3.72,
          city: "Gent",
          countryCode: "BE",
          spotId: "s1",
          spotName: "Kouter",
          spotListId: "list-1",
          spotListName: "Gent tour spots",
        },
      }];

      const result = attachEventsAndBuildIndexes(placeState, events, now);
      expect(result.cityDocs.get("be_gent").events).toHaveLength(1);
      expect(result.countryDocs.get("be").events).toHaveLength(1);
      const detail = result.eventDetails.get("gent-tour-listonly");
      expect(detail).toEqual(expect.objectContaining({
        city: "Gent",
        countryCode: "be",
        latitude: 51.05,
        longitude: 3.72,
        placeName: "Gent tour spots",
        locationSource: "list",
      }));
    });
  });

  describe("effectiveEventLocation", () => {
    it("prefers the event's own fields over resolvedLocation", () => {
      expect(effectiveEventLocation({
        city: "Antwerpen",
        countryCode: "BE",
        latitude: 51.2,
        longitude: 4.4,
        resolvedLocation: {source: "venue", latitude: 51.2, longitude: 4.4},
      })).toEqual({
        city: "Antwerpen",
        countryCode: "be",
        latitude: 51.2,
        longitude: 4.4,
        placeName: null,
        placeSpotId: null,
        placeSpotCitySlug: null,
        locationSource: "venue",
      });
    });

    it("uses the spot name and page for a direct spot source", () => {
      expect(effectiveEventLocation({
        resolvedLocation: {
          source: "spot",
          latitude: 52,
          longitude: 4,
          city: "Den Haag",
          countryCode: "NL",
          spotId: "s1",
          spotName: "Markt",
        },
      })).toEqual(expect.objectContaining({
        city: "Den Haag",
        countryCode: "nl",
        placeName: "Markt",
        placeSpotId: "s1",
        placeSpotCitySlug: "den-haag",
        locationSource: "spot",
      }));
    });

    it("links no single spot page for a list source", () => {
      expect(effectiveEventLocation({
        resolvedLocation: {
          source: "list",
          latitude: 52,
          longitude: 4,
          city: "Delft",
          spotId: "s1",
          spotListName: "Delft tour",
        },
      })).toEqual(expect.objectContaining({
        placeName: "Delft tour",
        placeSpotId: null,
        placeSpotCitySlug: null,
      }));
    });
  });

  describe("withResolvedLocationFallback", () => {
    const spotsById = new Map([
      ["s1", {latitude: 52, longitude: 4, city: "Delft", countryCode: "nl", name: "Markt"}],
    ]);

    it("resolves events without a stored location", () => {
      const [event] = withResolvedLocationFallback(
          [{id: "e1", spotIds: ["s1"]}],
          spotsById,
          new Map(),
      );
      expect(event.resolvedLocation).toEqual(expect.objectContaining({
        source: "spot",
        city: "Delft",
        countryCode: "NL",
      }));
    });

    it("keeps stored values and skips venue events", () => {
      const stored = {source: "spot", latitude: 1, longitude: 2};
      const events = [
        {id: "e1", spotIds: ["s1"], resolvedLocation: stored},
        {id: "e2", spotIds: ["s1"], latitude: 51, longitude: 3},
      ];
      const result = withResolvedLocationFallback(events, spotsById, new Map());
      expect(result[0].resolvedLocation).toBe(stored);
      expect(result[1].resolvedLocation).toBeUndefined();
    });
  });
});
