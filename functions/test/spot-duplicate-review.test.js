const {
  buildDuplicateReviewSnapshot,
  buildDuplicateReviewUpdate,
  diffDuplicateFieldGroups,
  getDuplicateOf,
} = require("../lib/spot-duplicate-review");

const DELETE = {delete: true};

function spotData(overrides = {}) {
  return {
    name: "Central Rails",
    description: "Long rail line",
    imageUrls: ["https://cdn.example.com/a.jpg"],
    youtubeVideoIds: ["abc123xyz"],
    latitude: 50.8,
    longitude: 4.3,
    address: "Brussels",
    city: "Brussels",
    countryCode: "BE",
    spotAccess: "public",
    spotFeatures: ["rails"],
    spotFacilities: {toilet: "yes"},
    goodFor: ["vaults"],
    duplicateOf: "native-1",
    ...overrides,
  };
}

describe("spot-duplicate-review", () => {
  describe("getDuplicateOf", () => {
    it("returns trimmed id", () => {
      expect(getDuplicateOf({duplicateOf: "  orig  "})).toBe("orig");
    });

    it("treats blank as missing", () => {
      expect(getDuplicateOf({duplicateOf: "  "})).toBeNull();
      expect(getDuplicateOf({})).toBeNull();
    });
  });

  describe("diffDuplicateFieldGroups", () => {
    it("returns empty when transferable fields match", () => {
      const snap = buildDuplicateReviewSnapshot(spotData());
      expect(diffDuplicateFieldGroups(snap, spotData())).toEqual([]);
    });

    it("detects each field group", () => {
      const baseline = buildDuplicateReviewSnapshot(spotData());
      expect(diffDuplicateFieldGroups(baseline, spotData({
        name: "New name",
      }))).toEqual(["name"]);
      expect(diffDuplicateFieldGroups(baseline, spotData({
        description: "Updated",
      }))).toEqual(["description"]);
      expect(diffDuplicateFieldGroups(baseline, spotData({
        imageUrls: ["https://cdn.example.com/b.jpg"],
      }))).toEqual(["photos"]);
      expect(diffDuplicateFieldGroups(baseline, spotData({
        youtubeVideoIds: ["otherid123"],
      }))).toEqual(["youtube"]);
      expect(diffDuplicateFieldGroups(baseline, spotData({
        address: "Ghent",
      }))).toEqual(["location"]);
      expect(diffDuplicateFieldGroups(baseline, spotData({
        spotAccess: "private",
      }))).toEqual(["attributes"]);
    });

    it("ignores sync metadata", () => {
      const baseline = buildDuplicateReviewSnapshot(spotData());
      expect(diffDuplicateFieldGroups(baseline, spotData({
        spotSourceName: "Other source",
        folderName: "Folder",
        hidden: true,
        averageRating: 4.2,
        ranking: 0.9,
      }))).toEqual([]);
    });

    it("treats empty description as equal to missing", () => {
      const withEmpty = buildDuplicateReviewSnapshot(spotData({
        description: "",
      }));
      const withNull = buildDuplicateReviewSnapshot(spotData({
        description: null,
      }));
      expect(diffDuplicateFieldGroups(withEmpty, withNull)).toEqual([]);
    });

    it("compares attributes as sets and maps", () => {
      const baseline = buildDuplicateReviewSnapshot(spotData({
        spotFeatures: ["rails", "walls"],
      }));
      expect(diffDuplicateFieldGroups(baseline, spotData({
        spotFeatures: ["walls", "rails"],
      }))).toEqual([]);
    });
  });

  describe("buildDuplicateReviewUpdate", () => {
    it("writes baseline and clears flags when duplicateOf is newly set", () => {
      const before = spotData({duplicateOf: null});
      const after = spotData();
      const update = buildDuplicateReviewUpdate(before, after, DELETE);
      expect(update.duplicateHasPendingChanges).toBe(false);
      expect(update.duplicateChangedFields).toBe(DELETE);
      expect(update.duplicateReviewBaseline.name).toBe("Central Rails");
    });

    it("does not rewrite when newly linked state already matches", () => {
      const after = spotData({
        duplicateReviewBaseline: buildDuplicateReviewSnapshot(spotData()),
        duplicateHasPendingChanges: false,
      });
      const before = spotData({duplicateOf: null});
      expect(buildDuplicateReviewUpdate(before, after, DELETE)).toBeNull();
    });

    it("clears review fields when duplicateOf is removed", () => {
      const reviewFields = {
        duplicateReviewBaseline: buildDuplicateReviewSnapshot(spotData()),
        duplicateHasPendingChanges: true,
        duplicateChangedFields: ["name"],
      };
      const before = spotData(reviewFields);
      const after = spotData({...reviewFields, duplicateOf: null});
      expect(buildDuplicateReviewUpdate(before, after, DELETE)).toEqual({
        duplicateReviewBaseline: DELETE,
        duplicateChangedFields: DELETE,
        duplicateHasPendingChanges: DELETE,
      });
    });

    it("does not write when unlinked spot has no review fields", () => {
      const after = spotData({duplicateOf: null});
      expect(buildDuplicateReviewUpdate(null, after, DELETE)).toBeNull();
    });

    it("flags content changes against an existing baseline", () => {
      const baseline = buildDuplicateReviewSnapshot(spotData());
      const after = spotData({
        name: "Renamed rails",
        duplicateReviewBaseline: baseline,
        duplicateHasPendingChanges: false,
      });
      const update = buildDuplicateReviewUpdate(
          spotData({duplicateReviewBaseline: baseline}),
          after,
          DELETE,
      );
      expect(update).toEqual({
        duplicateChangedFields: ["name"],
        duplicateHasPendingChanges: true,
      });
    });

    it("returns null when pending flags already match the diff", () => {
      const baseline = buildDuplicateReviewSnapshot(spotData());
      const after = spotData({
        name: "Renamed rails",
        duplicateReviewBaseline: baseline,
        duplicateHasPendingChanges: true,
        duplicateChangedFields: ["name"],
      });
      expect(buildDuplicateReviewUpdate(after, after, DELETE)).toBeNull();
    });

    it("ignores metadata-only writes once a baseline exists", () => {
      const baseline = buildDuplicateReviewSnapshot(spotData());
      const after = spotData({
        duplicateReviewBaseline: baseline,
        duplicateHasPendingChanges: false,
        ranking: 0.42,
      });
      expect(buildDuplicateReviewUpdate(
          spotData({duplicateReviewBaseline: baseline}),
          after,
          DELETE,
      )).toBeNull();
    });

    it("uses before snapshot as baseline for existing duplicates without one", () => {
      const before = spotData();
      const after = spotData({name: "Renamed rails"});
      const update = buildDuplicateReviewUpdate(before, after, DELETE);
      expect(update.duplicateHasPendingChanges).toBe(true);
      expect(update.duplicateChangedFields).toEqual(["name"]);
      expect(update.duplicateReviewBaseline.name).toBe("Central Rails");
    });

    it("snapshots current values when an existing duplicate is unchanged", () => {
      const before = spotData({ranking: 0.1});
      const after = spotData({ranking: 0.2});
      const update = buildDuplicateReviewUpdate(before, after, DELETE);
      expect(update.duplicateHasPendingChanges).toBe(false);
      expect(update.duplicateChangedFields).toBe(DELETE);
      expect(update.duplicateReviewBaseline.name).toBe("Central Rails");
    });

    it("clears pending flags when content returns to the baseline", () => {
      const baseline = buildDuplicateReviewSnapshot(spotData());
      const after = spotData({
        duplicateReviewBaseline: baseline,
        duplicateHasPendingChanges: true,
        duplicateChangedFields: ["name"],
      });
      expect(buildDuplicateReviewUpdate(
          spotData({
            name: "Renamed rails",
            duplicateReviewBaseline: baseline,
            duplicateHasPendingChanges: true,
            duplicateChangedFields: ["name"],
          }),
          after,
          DELETE,
      )).toEqual({
        duplicateChangedFields: DELETE,
        duplicateHasPendingChanges: false,
      });
    });
  });
});
