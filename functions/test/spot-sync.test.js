const {
  buildImportedSpotCoordKey,
  buildImportedSpotLookup,
  hasImportedSpotContentChanges,
  normalizeImportedSpotName,
  normalizeSpotSyncSourceType,
  resolveImportedSpotMatch,
  roundSyncCoordinate,
  spotSyncSourceRequiresUrl,
} = require("../lib/spot-sync");

function mockSpotDoc(id, data) {
  return {id, data: () => data};
}

describe("spot-sync helpers", () => {
  describe("hasImportedSpotContentChanges", () => {
    const incoming = {
      name: "Central Rails",
      description: "Long rail line",
      spotSourceName: "Source 1",
      spotSourceRemoved: false,
      latitude: 50.8,
      longitude: 4.3,
      address: "Brussels",
      city: "Brussels",
      countryCode: "BE",
      averageRating: 4.2,
      ranking: 0.5,
      hidden: false,
    };

    it("returns false when relevant fields are unchanged", () => {
      const existing = {...incoming};
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(false);
    });

    it("returns true when latitude is present and differs", () => {
      const existing = {...incoming, latitude: 1};
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(true);
    });

    it("returns true when longitude is present and differs", () => {
      const existing = {...incoming, longitude: 1};
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(true);
    });

    it("returns true when spotSourceExternalId is present and differs", () => {
      const existing = {...incoming, spotSourceExternalId: "node/1"};
      const withExternalId = {...incoming, spotSourceExternalId: "node/2"};
      expect(hasImportedSpotContentChanges(existing, withExternalId)).toBe(true);
    });

    it("ignores spotSourceExternalId when it is not on the incoming payload", () => {
      const existing = {...incoming, spotSourceExternalId: "node/1"};
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(false);
    });

    it("ignores preserved fields such as address and ratings", () => {
      const existing = {
        ...incoming,
        address: "Old address",
        city: "Old city",
        countryCode: "XX",
        averageRating: 1,
        ranking: 0.1,
        hidden: true,
        duplicateOf: "native-1",
        spotAccess: "public",
      };
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(false);
    });

    it("returns true when name changes", () => {
      const existing = {...incoming, name: "Old name"};
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(true);
    });

    it("returns true when description changes", () => {
      const existing = {...incoming, description: "Old description"};
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(true);
    });

    it("treats empty string and null as equivalent", () => {
      const existing = {...incoming, description: ""};
      const incomingWithoutDescription = {...incoming, description: null};
      expect(
          hasImportedSpotContentChanges(existing, incomingWithoutDescription),
      ).toBe(false);
    });

    it("ignores surrounding whitespace on compared strings", () => {
      const existing = {...incoming, name: "  Central Rails  "};
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(false);
    });

    it("returns true when spotSourceName changes", () => {
      const existing = {...incoming, spotSourceName: "Old source"};
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(true);
    });

    it("returns true when folderName is present and differs", () => {
      const existing = {...incoming, folderName: "Old folder"};
      const withFolder = {...incoming, folderName: "Rails"};
      expect(hasImportedSpotContentChanges(existing, withFolder)).toBe(true);
    });

    it("ignores folderName when it is not on the incoming payload", () => {
      const existing = {...incoming, folderName: "Rails"};
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(false);
    });

    it("returns true when a removed spot reappears", () => {
      const existing = {...incoming, spotSourceRemoved: true};
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(true);
    });

    it("returns false when the spot remains not-removed", () => {
      const existing = {...incoming, spotSourceRemoved: false};
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(false);
    });

    it("returns true when youtubeVideoIds are present and differ", () => {
      const existing = {...incoming, youtubeVideoIds: ["abc123xyz"]};
      const withVideos = {...incoming, youtubeVideoIds: ["newid12345"]};
      expect(hasImportedSpotContentChanges(existing, withVideos)).toBe(true);
    });

    it("ignores youtubeVideoIds when they are not on the incoming payload", () => {
      const existing = {...incoming, youtubeVideoIds: ["abc123xyz"]};
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(false);
    });

    it("returns true when imageUrls are present and differ", () => {
      const existing = {
        ...incoming,
        imageUrls: ["https://cdn.example.com/a.jpg"],
      };
      const withImages = {
        ...incoming,
        imageUrls: ["https://cdn.example.com/b.jpg"],
      };
      expect(hasImportedSpotContentChanges(existing, withImages)).toBe(true);
    });

    it("ignores imageUrls when they are not on the incoming payload", () => {
      const existing = {
        ...incoming,
        imageUrls: ["https://cdn.example.com/a.jpg"],
      };
      expect(hasImportedSpotContentChanges(existing, incoming)).toBe(false);
    });

    it("returns true when imageHashes are present and differ", () => {
      const existing = {...incoming, imageHashes: ["aaa"]};
      const withHashes = {...incoming, imageHashes: ["bbb"]};
      expect(hasImportedSpotContentChanges(existing, withHashes)).toBe(true);
    });

    it("returns true when hasImages is present and differs", () => {
      const existing = {...incoming, hasImages: false};
      const withHasImages = {...incoming, hasImages: true};
      expect(hasImportedSpotContentChanges(existing, withHasImages)).toBe(true);
    });

    it("treats missing hasImages as false", () => {
      const existing = {...incoming};
      const incomingFalse = {...incoming, hasImages: false};
      expect(hasImportedSpotContentChanges(existing, incomingFalse)).toBe(false);
    });
  });

  describe("imported spot matching", () => {
    it("normalizes CJK names with NFC for lookup", () => {
      const nfc = "【宝山】上海大学";
      const nfd = nfc.normalize("NFD");
      expect(normalizeImportedSpotName(nfc)).toBe(nfc);
      expect(normalizeImportedSpotName(nfd)).toBe(nfc);
    });

    it("matches by rounded coordinates when floats differ slightly", () => {
      const lat = 31.316247;
      const lng = 121.392102;
      const lookup = buildImportedSpotLookup([
        mockSpotDoc("a", {
          name: "【宝山】上海大学",
          latitude: lat + 0.0000004,
          longitude: lng - 0.0000003,
          spotSourceRemoved: false,
        }),
      ]);
      const match = resolveImportedSpotMatch(lookup, {
        latitude: lat,
        longitude: lng,
        name: "【宝山】上海大学",
      });
      expect(match?.id).toBe("a");
    });

    it("falls back to name when external id is new but coords match", () => {
      const lookup = buildImportedSpotLookup([
        mockSpotDoc("legacy", {
          name: "【宝山】上海大学",
          latitude: 31.316247,
          longitude: 121.392102,
        }),
      ]);
      const match = resolveImportedSpotMatch(lookup, {
        externalId: "new-google-id",
        latitude: 31.316247,
        longitude: 121.392102,
        name: "【宝山】上海大学",
      });
      expect(match?.id).toBe("legacy");
    });

    it("prefers a spot that is not marked removed from source", () => {
      const lookup = buildImportedSpotLookup([
        mockSpotDoc("removed", {
          name: "Spot A",
          latitude: 1,
          longitude: 2,
          spotSourceRemoved: true,
        }),
        mockSpotDoc("active", {
          name: "Spot A",
          latitude: 1,
          longitude: 2,
          spotSourceRemoved: false,
        }),
      ]);
      const match = resolveImportedSpotMatch(lookup, {
        latitude: 1,
        longitude: 2,
        name: "Spot A",
      });
      expect(match?.id).toBe("active");
    });

    it("rounds coordinates to six decimal places", () => {
      expect(roundSyncCoordinate(31.3162474)).toBe(31.316247);
      expect(buildImportedSpotCoordKey(31.3162474, 121.3921026))
          .toBe("31.316247,121.392103");
    });
  });

  describe("normalizeSpotSyncSourceType", () => {
    it("keeps known types and defaults to file", () => {
      expect(normalizeSpotSyncSourceType("openstreetmap"))
          .toBe("openstreetmap");
      expect(normalizeSpotSyncSourceType("navermap")).toBe("navermap");
      expect(normalizeSpotSyncSourceType("google_earth")).toBe("google_earth");
      expect(normalizeSpotSyncSourceType("file")).toBe("file");
      expect(normalizeSpotSyncSourceType("other")).toBe("file");
    });

    it("requires a URL for file and Naver Map sources", () => {
      expect(spotSyncSourceRequiresUrl("file")).toBe(true);
      expect(spotSyncSourceRequiresUrl("navermap")).toBe(true);
      expect(spotSyncSourceRequiresUrl("openstreetmap")).toBe(false);
      expect(spotSyncSourceRequiresUrl("google_earth")).toBe(false);
    });
  });
});
