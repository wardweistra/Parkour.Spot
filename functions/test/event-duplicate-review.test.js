const {
  buildDuplicateReviewSnapshot,
  buildDuplicateReviewUpdate,
  diffDuplicateFieldGroups,
  getDuplicateOf,
} = require("../lib/event-duplicate-review");

const DELETE = {delete: true};

function eventData(overrides = {}) {
  return {
    title: "Jam Session",
    description: "Bring water",
    websiteUrl: "https://example.com/jam",
    imageUrls: ["https://cdn.example.com/a.jpg"],
    spotIds: ["spot-1"],
    spotListIds: ["list-1"],
    latitude: 50.8,
    longitude: 4.3,
    address: "Brussels",
    city: "Brussels",
    countryCode: "BE",
    startAt: new Date("2026-05-13T10:00:00.000Z"),
    endAt: new Date("2026-05-13T12:00:00.000Z"),
    isDateOnly: false,
    timeZone: "Europe/Brussels",
    timeZoneSource: "feed",
    duplicateOf: "native-1",
    ...overrides,
  };
}

describe("event-duplicate-review", () => {
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
      const snap = buildDuplicateReviewSnapshot(eventData());
      expect(diffDuplicateFieldGroups(snap, eventData())).toEqual([]);
    });

    it("detects each field group", () => {
      const baseline = buildDuplicateReviewSnapshot(eventData());
      expect(diffDuplicateFieldGroups(baseline, eventData({
        title: "New title",
      }))).toEqual(["title"]);
      expect(diffDuplicateFieldGroups(baseline, eventData({
        description: "Updated",
      }))).toEqual(["description"]);
      expect(diffDuplicateFieldGroups(baseline, eventData({
        websiteUrl: "https://example.com/new",
      }))).toEqual(["website"]);
      expect(diffDuplicateFieldGroups(baseline, eventData({
        imageUrls: ["https://cdn.example.com/b.jpg"],
      }))).toEqual(["photos"]);
      expect(diffDuplicateFieldGroups(baseline, eventData({
        spotIds: ["spot-2"],
      }))).toEqual(["linkedSpots"]);
      expect(diffDuplicateFieldGroups(baseline, eventData({
        address: "Ghent",
      }))).toEqual(["location"]);
      expect(diffDuplicateFieldGroups(baseline, eventData({
        startAt: new Date("2026-05-14T10:00:00.000Z"),
      }))).toEqual(["schedule"]);
    });

    it("ignores sync metadata", () => {
      const baseline = buildDuplicateReviewSnapshot(eventData());
      expect(diffDuplicateFieldGroups(baseline, eventData({
        eventSourceName: "Other source",
        externalEventUid: "uid-9",
        externalSyncLastSeenAt: new Date("2026-08-01T00:00:00.000Z"),
        hidden: true,
      }))).toEqual([]);
    });

    it("treats empty description as equal to missing", () => {
      const withEmpty = buildDuplicateReviewSnapshot(eventData({
        description: "",
      }));
      const withNull = buildDuplicateReviewSnapshot(eventData({
        description: null,
      }));
      expect(diffDuplicateFieldGroups(withEmpty, withNull)).toEqual([]);
    });
  });

  describe("buildDuplicateReviewUpdate", () => {
    it("writes baseline and clears flags when duplicateOf is newly set", () => {
      const before = eventData({duplicateOf: null});
      const after = eventData();
      const update = buildDuplicateReviewUpdate(before, after, DELETE);
      expect(update.duplicateHasPendingChanges).toBe(false);
      expect(update.duplicateChangedFields).toBe(DELETE);
      expect(update.duplicateReviewBaseline.title).toBe("Jam Session");
      expect(update.duplicateReviewBaseline.startAt.toISOString())
          .toBe("2026-05-13T10:00:00.000Z");
    });

    it("does not rewrite when newly linked state already matches", () => {
      const after = eventData({
        duplicateReviewBaseline: buildDuplicateReviewSnapshot(eventData()),
        duplicateHasPendingChanges: false,
      });
      const before = eventData({duplicateOf: null});
      expect(buildDuplicateReviewUpdate(before, after, DELETE)).toBeNull();
    });

    it("clears review fields when duplicateOf is removed", () => {
      const reviewFields = {
        duplicateReviewBaseline: buildDuplicateReviewSnapshot(eventData()),
        duplicateHasPendingChanges: true,
        duplicateChangedFields: ["title"],
      };
      const before = eventData(reviewFields);
      const after = eventData({...reviewFields, duplicateOf: null});
      expect(buildDuplicateReviewUpdate(before, after, DELETE)).toEqual({
        duplicateReviewBaseline: DELETE,
        duplicateChangedFields: DELETE,
        duplicateHasPendingChanges: DELETE,
      });
    });

    it("does not write when unlinked event has no review fields", () => {
      const after = eventData({duplicateOf: null});
      expect(buildDuplicateReviewUpdate(null, after, DELETE)).toBeNull();
    });

    it("flags content changes against an existing baseline", () => {
      const baseline = buildDuplicateReviewSnapshot(eventData());
      const after = eventData({
        title: "Renamed jam",
        duplicateReviewBaseline: baseline,
        duplicateHasPendingChanges: false,
      });
      const update = buildDuplicateReviewUpdate(
          eventData({duplicateReviewBaseline: baseline}),
          after,
          DELETE,
      );
      expect(update).toEqual({
        duplicateChangedFields: ["title"],
        duplicateHasPendingChanges: true,
      });
    });

    it("returns null when pending flags already match the diff", () => {
      const baseline = buildDuplicateReviewSnapshot(eventData());
      const after = eventData({
        title: "Renamed jam",
        duplicateReviewBaseline: baseline,
        duplicateHasPendingChanges: true,
        duplicateChangedFields: ["title"],
      });
      expect(buildDuplicateReviewUpdate(after, after, DELETE)).toBeNull();
    });

    it("ignores last-seen-only writes once a baseline exists", () => {
      const baseline = buildDuplicateReviewSnapshot(eventData());
      const after = eventData({
        duplicateReviewBaseline: baseline,
        duplicateHasPendingChanges: false,
        externalSyncLastSeenAt: new Date("2026-08-22T10:00:00.000Z"),
      });
      expect(buildDuplicateReviewUpdate(
          eventData({duplicateReviewBaseline: baseline}),
          after,
          DELETE,
      )).toBeNull();
    });

    it("uses before snapshot as baseline for existing duplicates without one", () => {
      const before = eventData();
      const after = eventData({title: "Renamed jam"});
      const update = buildDuplicateReviewUpdate(before, after, DELETE);
      expect(update.duplicateHasPendingChanges).toBe(true);
      expect(update.duplicateChangedFields).toEqual(["title"]);
      expect(update.duplicateReviewBaseline.title).toBe("Jam Session");
    });

    it("snapshots current values when an existing duplicate is unchanged", () => {
      const before = eventData({
        externalSyncLastSeenAt: new Date("2026-08-01T00:00:00.000Z"),
      });
      const after = eventData({
        externalSyncLastSeenAt: new Date("2026-08-22T00:00:00.000Z"),
      });
      const update = buildDuplicateReviewUpdate(before, after, DELETE);
      expect(update.duplicateHasPendingChanges).toBe(false);
      expect(update.duplicateChangedFields).toBe(DELETE);
      expect(update.duplicateReviewBaseline.title).toBe("Jam Session");
    });

    it("clears pending flags when content returns to the baseline", () => {
      const baseline = buildDuplicateReviewSnapshot(eventData());
      const after = eventData({
        duplicateReviewBaseline: baseline,
        duplicateHasPendingChanges: true,
        duplicateChangedFields: ["title"],
      });
      expect(buildDuplicateReviewUpdate(
          eventData({
            title: "Renamed jam",
            duplicateReviewBaseline: baseline,
            duplicateHasPendingChanges: true,
            duplicateChangedFields: ["title"],
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
