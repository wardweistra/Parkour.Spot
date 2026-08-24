const {hasImportedSpotContentChanges} = require("../lib/spot-sync");

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

    it("ignores preserved fields such as coords, address, and ratings", () => {
      const existing = {
        ...incoming,
        latitude: 1,
        longitude: 2,
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
});
