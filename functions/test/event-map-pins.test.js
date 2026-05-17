const {
  buildEventMapPinWrites,
  collectLinkedSpotIds,
  effectiveSpotIdsFromList,
  isEventPast,
  isExpandableListVisibility,
  isSpotEligibleForPin,
  MAX_SPOT_PINS_PER_EVENT,
} = require("../lib/event-map-pins");

describe("event-map-pins helpers", () => {
  const futureStart = new Date("2026-12-01T10:00:00.000Z");
  const futureEnd = new Date("2026-12-01T12:00:00.000Z");
  const pastStart = new Date("2020-01-01T10:00:00.000Z");

  describe("isExpandableListVisibility", () => {
    it("allows public and unlisted", () => {
      expect(isExpandableListVisibility("public")).toBe(true);
      expect(isExpandableListVisibility("unlisted")).toBe(true);
    });

    it("rejects private and treats missing as unlisted", () => {
      expect(isExpandableListVisibility("private")).toBe(false);
      expect(isExpandableListVisibility(undefined)).toBe(true);
    });
  });

  describe("effectiveSpotIdsFromList", () => {
    it("uses sections when present", () => {
      const ids = effectiveSpotIdsFromList({
        spotIds: ["legacy-a"],
        sections: [{
          entries: [{spotId: "spot-1"}, {spotId: "spot-2"}],
        }],
      });
      expect(ids).toEqual(["spot-1", "spot-2"]);
    });

    it("falls back to spotIds", () => {
      expect(effectiveSpotIdsFromList({spotIds: ["a", "b"]})).toEqual(["a", "b"]);
    });
  });

  describe("isEventPast", () => {
    it("uses endAt when set", () => {
      const now = new Date("2026-06-01T00:00:00.000Z");
      expect(isEventPast({startAt: futureStart, endAt: pastStart}, now)).toBe(true);
      expect(isEventPast({startAt: pastStart, endAt: futureEnd}, now)).toBe(false);
    });

    it("uses startAt when endAt missing", () => {
      const now = new Date("2026-06-01T00:00:00.000Z");
      expect(isEventPast({startAt: pastStart}, now)).toBe(true);
      expect(isEventPast({startAt: futureStart}, now)).toBe(false);
    });
  });

  describe("isSpotEligibleForPin", () => {
    it("requires coordinates and non-hidden non-duplicate", () => {
      expect(isSpotEligibleForPin({
        latitude: 1,
        longitude: 2,
        hidden: false,
      })).toBe(true);
      expect(isSpotEligibleForPin({
        latitude: 1,
        longitude: 2,
        hidden: true,
      })).toBe(false);
      expect(isSpotEligibleForPin({
        latitude: 1,
        longitude: 2,
        duplicateOf: "orig",
      })).toBe(false);
      expect(isSpotEligibleForPin({latitude: null, longitude: 2})).toBe(false);
    });
  });

  describe("collectLinkedSpotIds", () => {
    it("merges direct spots and expandable lists", () => {
      const listsById = new Map([
        ["list-1", {visibility: "public", spotIds: ["spot-b", "spot-c"]}],
        ["list-private", {visibility: "private", spotIds: ["spot-x"]}],
      ]);
      const ids = collectLinkedSpotIds({
        spotIds: ["spot-a"],
        spotListIds: ["list-1", "list-private"],
      }, listsById);
      expect(ids).toEqual(["spot-a", "spot-b", "spot-c"]);
    });
  });

  describe("buildEventMapPinWrites", () => {
    const now = new Date("2026-06-01T00:00:00.000Z");

    it("returns no pins for duplicate or past events", () => {
      expect(buildEventMapPinWrites("e1", {
        title: "Dup",
        startAt: futureStart,
        duplicateOf: "other",
      }, new Map(), new Map(), {now}).pins).toHaveLength(0);

      expect(buildEventMapPinWrites("e1", {
        title: "Past",
        startAt: pastStart,
      }, new Map(), new Map(), {now}).pins).toHaveLength(0);
    });

    it("writes venue and spot pins", () => {
      const spotsById = new Map([
        ["spot-1", {latitude: 52.0, longitude: 4.0, hidden: false}],
      ]);
      const {pins} = buildEventMapPinWrites("evt-1", {
        title: "Jam",
        startAt: futureStart,
        endAt: futureEnd,
        latitude: 51.0,
        longitude: 3.0,
        spotIds: ["spot-1"],
        spotListIds: [],
      }, spotsById, new Map(), {now});

      expect(pins).toHaveLength(2);
      expect(pins.find((p) => p.id === "evt-1_venue")).toBeTruthy();
      expect(pins.find((p) => p.id === "evt-1_spot_spot-1")).toBeTruthy();
      expect(pins[0].data.eventId).toBe("evt-1");
    });

    it("skips spots without valid coordinates", () => {
      const spotsById = new Map([
        ["spot-bad", {latitude: null, longitude: 4.0}],
      ]);
      const {pins} = buildEventMapPinWrites("evt-2", {
        title: "Jam",
        startAt: futureStart,
        spotIds: ["spot-bad"],
      }, spotsById, new Map(), {now});
      expect(pins).toHaveLength(0);
    });

    it("truncates spot pins at max", () => {
      const spotsById = new Map();
      const spotIds = [];
      for (let i = 0; i < MAX_SPOT_PINS_PER_EVENT + 5; i++) {
        const id = `spot-${i}`;
        spotIds.push(id);
        spotsById.set(id, {latitude: 50 + i * 0.001, longitude: 4, hidden: false});
      }
      const {pins, truncated} = buildEventMapPinWrites("evt-big", {
        title: "Big",
        startAt: futureStart,
        spotIds,
      }, spotsById, new Map(), {now});
      expect(truncated).toBe(true);
      expect(pins.filter((p) => p.data.kind === "spot")).toHaveLength(
          MAX_SPOT_PINS_PER_EVENT,
      );
    });
  });
});
