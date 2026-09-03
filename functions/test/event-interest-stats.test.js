const {
  normalizeInterestStatus,
  eventIdFromInterest,
  interestCountDeltas,
  applyInterestCountDeltas,
} = require("../lib/event-interest-stats");

describe("event-interest-stats", () => {
  describe("normalizeInterestStatus", () => {
    it("accepts going and interested", () => {
      expect(normalizeInterestStatus("going")).toBe("going");
      expect(normalizeInterestStatus(" interested ")).toBe("interested");
    });

    it("rejects unknown values", () => {
      expect(normalizeInterestStatus("maybe")).toBeNull();
      expect(normalizeInterestStatus(1)).toBeNull();
    });
  });

  describe("eventIdFromInterest", () => {
    it("prefers the path param", () => {
      expect(eventIdFromInterest({eventId: "from-doc"}, " from-path ")).toBe("from-path");
    });

    it("falls back to the document field", () => {
      expect(eventIdFromInterest({eventId: " from-doc "}, "")).toBe("from-doc");
    });
  });

  describe("interestCountDeltas", () => {
    it("increments on create", () => {
      expect(interestCountDeltas(null, {status: "going"})).toEqual({
        goingCount: 1,
        interestedCount: 0,
      });
    });

    it("decrements on delete", () => {
      expect(interestCountDeltas({status: "interested"}, null)).toEqual({
        goingCount: 0,
        interestedCount: -1,
      });
    });

    it("moves counts when status changes", () => {
      expect(interestCountDeltas(
          {status: "going"},
          {status: "interested"},
      )).toEqual({
        goingCount: -1,
        interestedCount: 1,
      });
    });

    it("returns null when status is unchanged", () => {
      expect(interestCountDeltas(
          {status: "going"},
          {status: "going"},
      )).toBeNull();
    });
  });

  describe("applyInterestCountDeltas", () => {
    it("clamps at zero", () => {
      expect(applyInterestCountDeltas(
          {goingCount: 0, interestedCount: 1},
          {goingCount: -1, interestedCount: -1},
      )).toEqual({goingCount: 0, interestedCount: 0});
    });

    it("adds to existing totals", () => {
      expect(applyInterestCountDeltas(
          {goingCount: 2, interestedCount: 4},
          {goingCount: 1, interestedCount: -1},
      )).toEqual({goingCount: 3, interestedCount: 3});
    });
  });
});
