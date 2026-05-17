const {
  isPinShowable,
  normalizePin,
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
