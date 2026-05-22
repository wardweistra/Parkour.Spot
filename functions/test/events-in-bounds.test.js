const {
  isPinShowable,
  normalizePin,
  normalizeImageUrls,
  enrichPinsWithEventCardFields,
  enrichPinsWithEventImages,
  countDistinctEventIds,
  dedupePinsByEventId,
} = require("../lib/events-in-bounds");

describe("events-in-bounds helpers", () => {
  const now = new Date("2026-06-01T12:00:00.000Z");
  const futureStart = new Date("2026-12-01T10:00:00.000Z");
  const futureEnd = new Date("2026-12-01T18:00:00.000Z");
  const pastStart = new Date("2020-01-01T10:00:00.000Z");
  const pastEnd = new Date("2020-01-01T18:00:00.000Z");

  describe("isPinShowable", () => {
    it("allows upcoming pins", () => {
      expect(isPinShowable({startAt: futureStart}, now)).toBe(true);
    });

    it("allows in-progress pins when endAt is in the future", () => {
      expect(isPinShowable({
        startAt: pastStart,
        endAt: futureEnd,
      }, now)).toBe(true);
    });

    it("rejects past pins", () => {
      expect(isPinShowable({
        startAt: pastStart,
        endAt: pastEnd,
      }, now)).toBe(false);
    });
  });

  describe("normalizePin", () => {
    it("normalizes a venue pin", () => {
      const pin = normalizePin("evt1_venue", {
        eventId: "evt1",
        kind: "venue",
        latitude: 50.1,
        longitude: 4.2,
        title: " Jam ",
        startAt: futureStart,
        endAt: futureEnd,
        isDateOnly: true,
        timeZone: "Europe/Paris",
        city: "Utrecht",
        countryCode: "nl",
      });
      expect(pin).toEqual({
        id: "evt1_venue",
        eventId: "evt1",
        kind: "venue",
        latitude: 50.1,
        longitude: 4.2,
        title: "Jam",
        startAt: futureStart.toISOString(),
        endAt: futureEnd.toISOString(),
        isDateOnly: true,
        timeZone: "Europe/Paris",
        city: "Utrecht",
        countryCode: "NL",
      });
    });

    it("normalizes a spot pin with spotId", () => {
      const pin = normalizePin("evt1_spot_abc", {
        eventId: "evt1",
        kind: "spot",
        spotId: "spot-abc",
        latitude: 51,
        longitude: 3,
        title: "Meetup",
        startAt: futureStart,
      });
      expect(pin?.spotId).toBe("spot-abc");
      expect(pin?.kind).toBe("spot");
    });

    it("returns null for invalid pins", () => {
      expect(normalizePin("bad", {kind: "venue"})).toBeNull();
    });

    it("includes description when present on pin data", () => {
      const pin = normalizePin("evt1_venue", {
        eventId: "evt1",
        kind: "venue",
        latitude: 50.1,
        longitude: 4.2,
        title: "Jam",
        startAt: futureStart,
        description: "  Community jam  ",
      });
      expect(pin?.description).toBe("Community jam");
    });

    it("includes resized imageUrls when present on pin data", () => {
      const original =
        "https://storage.googleapis.com/bucket/events/photo.jpg";
      const pin = normalizePin("evt1_venue", {
        eventId: "evt1",
        kind: "venue",
        latitude: 50.1,
        longitude: 4.2,
        title: "Jam",
        startAt: futureStart,
        imageUrls: [original],
      });
      expect(pin?.imageUrls).toEqual([
        "https://storage.googleapis.com/bucket/events/resized/photo_1200x1200.webp",
      ]);
    });
  });

  describe("normalizeImageUrls", () => {
    it("returns empty array for non-array input", () => {
      expect(normalizeImageUrls(null)).toEqual([]);
    });
  });

  describe("enrichPinsWithEventCardFields", () => {
    it("fills missing imageUrls from event documents", async () => {
      const db = {
        collection: (name) => ({
          doc: (id) => ({collection: name, id}),
        }),
        getAll: jest.fn(async (...refs) => refs.map((ref) => ({
          id: ref.id,
          exists: true,
          data: () => ({
            imageUrls: [
              "https://storage.googleapis.com/bucket/events/jam.jpg",
            ],
          }),
        }))),
      };

      const pins = [{
        id: "evt1_venue",
        eventId: "evt1",
        kind: "venue",
        latitude: 1,
        longitude: 2,
        title: "Jam",
        startAt: futureStart.toISOString(),
      }];

      const enriched = await enrichPinsWithEventCardFields(db, pins);
      expect(enriched[0].imageUrls).toEqual([
        "https://storage.googleapis.com/bucket/events/resized/jam_1200x1200.webp",
      ]);
    });

    it("fills missing descriptions from event documents", async () => {
      const db = {
        collection: (name) => ({
          doc: (id) => ({collection: name, id}),
        }),
        getAll: jest.fn(async (...refs) => refs.map((ref) => ({
          id: ref.id,
          exists: true,
          data: () => ({
            description: "Community jam in the park.",
          }),
        }))),
      };

      const pins = [{
        id: "evt1_venue",
        eventId: "evt1",
        kind: "venue",
        latitude: 1,
        longitude: 2,
        title: "Jam",
        startAt: futureStart.toISOString(),
        imageUrls: ["https://example.com/a.jpg"],
      }];

      const enriched = await enrichPinsWithEventCardFields(db, pins);
      expect(enriched[0].description).toBe("Community jam in the park.");
    });

    it("fills missing city and countryCode from event documents", async () => {
      const db = {
        collection: (name) => ({
          doc: (id) => ({collection: name, id}),
        }),
        getAll: jest.fn(async (...refs) => refs.map((ref) => ({
          id: ref.id,
          exists: true,
          data: () => ({
            city: "Ghent",
            countryCode: "be",
          }),
        }))),
      };

      const pins = [{
        id: "evt1_venue",
        eventId: "evt1",
        kind: "venue",
        latitude: 1,
        longitude: 2,
        title: "Jam",
        startAt: futureStart.toISOString(),
      }];

      const enriched = await enrichPinsWithEventCardFields(db, pins);
      expect(enriched[0].city).toBe("Ghent");
      expect(enriched[0].countryCode).toBe("BE");
    });

    it("leaves pins unchanged when they already have card fields", async () => {
      const db = {getAll: jest.fn()};
      const pins = [{
        id: "evt1_venue",
        eventId: "evt1",
        imageUrls: ["https://example.com/a.jpg"],
        description: "Already here",
        city: "Paris",
        countryCode: "FR",
      }];
      const enriched = await enrichPinsWithEventCardFields(db, pins);
      expect(enriched).toEqual(pins);
      expect(db.getAll).not.toHaveBeenCalled();
    });

    it("enrichPinsWithEventImages is an alias for enrichPinsWithEventCardFields", () => {
      expect(enrichPinsWithEventImages).toBe(enrichPinsWithEventCardFields);
    });
  });

  describe("countDistinctEventIds", () => {
    it("counts unique event ids", () => {
      const count = countDistinctEventIds([
        {eventId: "a"},
        {eventId: "b"},
        {eventId: "a"},
      ]);
      expect(count).toBe(2);
    });
  });

  describe("dedupePinsByEventId", () => {
    it("keeps earliest startAt per event", () => {
      const later = {
        eventId: "e1",
        startAt: "2026-12-02T10:00:00.000Z",
        title: "Later",
      };
      const earlier = {
        eventId: "e1",
        startAt: "2026-12-01T10:00:00.000Z",
        title: "Earlier",
      };
      const deduped = dedupePinsByEventId([later, earlier]);
      expect(deduped).toHaveLength(1);
      expect(deduped[0].title).toBe("Earlier");
    });
  });
});
