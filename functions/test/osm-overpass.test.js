const {
  DEFAULT_SPOT_NAME,
  pickOsmName,
  buildOsmDescription,
  mapOsmSpotAccess,
  mapOsmSpotFacilities,
  extractOsmImageUrls,
  extractOsmCoordinates,
  mapOverpassElementToPlacemark,
  mapOverpassResponseToPlacemarks,
  fetchOsmParkourPlacemarks,
  placemarkOsmAttributeDefaults,
} = require("../lib/osm-overpass");

describe("osm-overpass helpers", () => {
  describe("pickOsmName", () => {
    it("prefers name then name:en then other name:*", () => {
      expect(pickOsmName({name: "Central Park"})).toBe("Central Park");
      expect(pickOsmName({"name:en": "Rails"})).toBe("Rails");
      expect(pickOsmName({"name:de": "Anlage"})).toBe("Anlage");
      expect(pickOsmName({})).toBe(DEFAULT_SPOT_NAME);
    });
  });

  describe("buildOsmDescription", () => {
    it("joins description, note, and contact fields", () => {
      const text = buildOsmDescription({
        description: "Outdoor park",
        note: "Busy weekends",
        website: "https://example.com",
        opening_hours: "24/7",
        phone: "+1 555",
      });
      expect(text).toContain("Outdoor park");
      expect(text).toContain("Busy weekends");
      expect(text).toContain("Website: https://example.com");
      expect(text).toContain("Opening hours: 24/7");
      expect(text).toContain("Phone: +1 555");
    });
  });

  describe("mapOsmSpotAccess", () => {
    it("maps outdoor pitches to public", () => {
      expect(mapOsmSpotAccess({leisure: "pitch"})).toBe("public");
      expect(mapOsmSpotAccess({leisure: "fitness_station"})).toBe("public");
    });

    it("maps fee and customers to paid", () => {
      expect(mapOsmSpotAccess({fee: "yes"})).toBe("paid");
      expect(mapOsmSpotAccess({access: "customers"})).toBe("paid");
    });

    it("maps private/permit/no to restricted", () => {
      expect(mapOsmSpotAccess({access: "private"})).toBe("restricted");
      expect(mapOsmSpotAccess({access: "permit"})).toBe("restricted");
    });

    it("leaves gym leisure unset without fee/access", () => {
      expect(mapOsmSpotAccess({leisure: "sports_centre"})).toBeNull();
      expect(mapOsmSpotAccess({leisure: "fitness_centre"})).toBeNull();
    });
  });

  describe("mapOsmSpotFacilities", () => {
    it("maps lit and covered/indoor", () => {
      expect(mapOsmSpotFacilities({lit: "yes"})).toEqual({lighting: "yes"});
      expect(mapOsmSpotFacilities({lit: "no"})).toEqual({lighting: "no"});
      expect(mapOsmSpotFacilities({covered: "yes"})).toEqual({covered: "yes"});
      expect(mapOsmSpotFacilities({indoor: "room"})).toEqual({covered: "yes"});
      expect(mapOsmSpotFacilities({indoor: "no"})).toEqual({covered: "no"});
    });
  });

  describe("extractOsmImageUrls", () => {
    it("keeps direct image URLs", () => {
      expect(extractOsmImageUrls({
        image: "https://example.com/spot.jpg",
      })).toEqual(["https://example.com/spot.jpg"]);
    });

    it("resolves wikimedia File: and skips Category:", () => {
      expect(extractOsmImageUrls({
        wikimedia_commons: "File:Parkour_01.jpg",
      })).toEqual([
        "https://commons.wikimedia.org/wiki/Special:FilePath/Parkour_01.jpg",
      ]);
      expect(extractOsmImageUrls({
        wikimedia_commons: "Category:Parkour",
      })).toEqual([]);
    });
  });

  describe("extractOsmCoordinates", () => {
    it("uses node lat/lon and way center", () => {
      expect(extractOsmCoordinates({lat: 1.5, lon: 2.5})).toEqual({
        latitude: 1.5,
        longitude: 2.5,
        altitude: 0,
      });
      expect(extractOsmCoordinates({
        center: {lat: 10, lon: 20},
      })).toEqual({
        latitude: 10,
        longitude: 20,
        altitude: 0,
      });
      expect(extractOsmCoordinates({})).toBeNull();
    });
  });

  describe("mapOverpassElementToPlacemark", () => {
    it("maps a named outdoor node with attributes and images", () => {
      const placemark = mapOverpassElementToPlacemark({
        type: "node",
        id: 42,
        lat: 48.1,
        lon: 11.5,
        tags: {
          sport: "parkour",
          name: "Munich Rails",
          leisure: "pitch",
          lit: "yes",
          image: "https://cdn.example.com/a.jpg",
          website: "https://example.com",
        },
      });
      expect(placemark).toMatchObject({
        name: "Munich Rails",
        externalId: "node/42",
        spotAccess: "public",
        spotFacilities: {lighting: "yes"},
        imageUrls: ["https://cdn.example.com/a.jpg"],
        coordinates: {latitude: 48.1, longitude: 11.5, altitude: 0},
      });
      expect(placemark.description).toContain("Website: https://example.com");
    });

    it("maps a way with center and gym leisure without guessing access", () => {
      const placemark = mapOverpassElementToPlacemark({
        type: "way",
        id: 99,
        center: {lat: 40, lon: -74},
        tags: {
          sport: "parkour",
          leisure: "sports_centre",
          indoor: "yes",
        },
      });
      expect(placemark).toMatchObject({
        name: DEFAULT_SPOT_NAME,
        externalId: "way/99",
        spotFacilities: {covered: "yes"},
        coordinates: {latitude: 40, longitude: -74, altitude: 0},
      });
      expect(placemark.spotAccess).toBeUndefined();
    });

    it("skips elements without parkour sport or coordinates", () => {
      expect(mapOverpassElementToPlacemark({
        type: "node",
        id: 1,
        lat: 1,
        lon: 2,
        tags: {sport: "climbing"},
      })).toBeNull();
      expect(mapOverpassElementToPlacemark({
        type: "way",
        id: 2,
        tags: {sport: "parkour"},
      })).toBeNull();
    });
  });

  describe("mapOverpassResponseToPlacemarks", () => {
    it("filters invalid elements", () => {
      const placemarks = mapOverpassResponseToPlacemarks({
        elements: [
          {
            type: "node",
            id: 1,
            lat: 1,
            lon: 2,
            tags: {sport: "parkour", name: "A"},
          },
          {type: "node", id: 2, tags: {sport: "parkour"}},
        ],
      });
      expect(placemarks).toHaveLength(1);
      expect(placemarks[0].name).toBe("A");
    });
  });

  describe("fetchOsmParkourPlacemarks", () => {
    it("parses Overpass JSON via injectable post", async () => {
      const placemarks = await fetchOsmParkourPlacemarks({
        maxAttempts: 1,
        postTextFn: async () => JSON.stringify({
          elements: [{
            type: "relation",
            id: 7,
            center: {lat: 3, lon: 4},
            tags: {sport: "parkour", name: "Rel"},
          }],
        }),
      });
      expect(placemarks).toHaveLength(1);
      expect(placemarks[0].externalId).toBe("relation/7");
    });

    it("retries retryable failures then succeeds", async () => {
      let attempts = 0;
      const placemarks = await fetchOsmParkourPlacemarks({
        maxAttempts: 3,
        postTextFn: async () => {
          attempts += 1;
          if (attempts < 2) {
            throw new Error("Overpass request failed (HTTP 429)");
          }
          return JSON.stringify({
            elements: [{
              type: "node",
              id: 8,
              lat: 1,
              lon: 1,
              tags: {sport: "parkour", name: "Retry"},
            }],
          });
        },
      });
      expect(attempts).toBe(2);
      expect(placemarks[0].name).toBe("Retry");
    });
  });

  describe("placemarkOsmAttributeDefaults", () => {
    it("returns null when no mapped attributes", () => {
      expect(placemarkOsmAttributeDefaults({name: "x"})).toBeNull();
    });

    it("returns access and facilities", () => {
      expect(placemarkOsmAttributeDefaults({
        spotAccess: "public",
        spotFacilities: {lighting: "yes"},
      })).toEqual({
        spotAccess: "public",
        spotFacilities: {lighting: "yes"},
      });
    });
  });
});
