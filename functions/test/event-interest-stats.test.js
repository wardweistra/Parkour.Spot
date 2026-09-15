const {
  normalizeInterestStatus,
  normalizeDuplicateOf,
  eventIdFromInterest,
  interestCountDeltas,
  applyInterestCountDeltas,
  idsToRecomputeForDuplicateOfChange,
  aggregateInterestCounts,
  recomputeEventInterestAggregates,
  handleEventInterestWritten,
  handleEventDuplicateOfChanged,
} = require("../lib/event-interest-stats");

function interestDoc({userId, status, eventId}) {
  return {
    data: () => ({userId, status, eventId}),
    ref: {
      parent: {
        parent: {id: userId},
      },
    },
  };
}

function mockDb({
  duplicateIdsByNative = {},
  interestsByEventId = {},
  eventsById = {},
  statsWrites = [],
  statsDeletes = [],
} = {}) {
  const collectionGroupQuery = {
    where: jest.fn((field, op, chunk) => {
      expect(field).toBe("eventId");
      expect(op).toBe("in");
      const docs = [];
      for (const eventId of chunk) {
        const list = interestsByEventId[eventId] || [];
        docs.push(...list);
      }
      return {
        get: jest.fn(async () => ({
          forEach: (fn) => docs.forEach(fn),
          docs,
        })),
      };
    }),
  };

  return {
    collectionGroup: jest.fn((name) => {
      expect(name).toBe("eventInterests");
      return collectionGroupQuery;
    }),
    collection: jest.fn((name) => {
      if (name === "events") {
        return {
          where: jest.fn((field, op, eventId) => {
            expect(field).toBe("duplicateOf");
            expect(op).toBe("==");
            const ids = duplicateIdsByNative[eventId] || [];
            return {
              get: jest.fn(async () => ({
                docs: ids.map((id) => ({id})),
              })),
            };
          }),
          doc: jest.fn((eventId) => ({
            get: jest.fn(async () => {
              const data = eventsById[eventId];
              return {
                exists: data != null,
                data: () => data,
              };
            }),
          })),
        };
      }
      if (name === "eventInterestStats") {
        return {
          doc: jest.fn((eventId) => ({
            set: jest.fn(async (data, options) => {
              statsWrites.push({eventId, data, options});
            }),
            delete: jest.fn(async () => {
              statsDeletes.push(eventId);
            }),
          })),
        };
      }
      throw new Error(`unexpected collection ${name}`);
    }),
  };
}

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

  describe("normalizeDuplicateOf", () => {
    it("trims a native event id", () => {
      expect(normalizeDuplicateOf({duplicateOf: " native-1 "})).toBe("native-1");
    });

    it("returns null when missing or blank", () => {
      expect(normalizeDuplicateOf({})).toBeNull();
      expect(normalizeDuplicateOf({duplicateOf: "  "})).toBeNull();
      expect(normalizeDuplicateOf(null)).toBeNull();
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

  describe("idsToRecomputeForDuplicateOfChange", () => {
    it("returns empty when duplicateOf is unchanged", () => {
      expect(idsToRecomputeForDuplicateOfChange(
          "dup",
          {duplicateOf: "native"},
          {duplicateOf: "native"},
      )).toEqual([]);
    });

    it("includes the event, old native, and new native", () => {
      expect(idsToRecomputeForDuplicateOfChange(
          "dup",
          {duplicateOf: "old-native"},
          {duplicateOf: "new-native"},
      ).sort()).toEqual(["dup", "new-native", "old-native"]);
    });

    it("recomputes the native when a duplicate is deleted", () => {
      expect(idsToRecomputeForDuplicateOfChange(
          "dup",
          {duplicateOf: "native"},
          null,
      )).toEqual(["native"]);
    });
  });

  describe("aggregateInterestCounts", () => {
    it("counts distinct users across native and duplicate listings", () => {
      expect(aggregateInterestCounts([
        interestDoc({userId: "a", status: "going", eventId: "native"}),
        interestDoc({userId: "b", status: "interested", eventId: "dup"}),
        interestDoc({userId: "c", status: "going", eventId: "dup"}),
      ])).toEqual({goingCount: 2, interestedCount: 1});
    });

    it("counts a user once and prefers Going when they marked both", () => {
      expect(aggregateInterestCounts([
        interestDoc({userId: "a", status: "interested", eventId: "native"}),
        interestDoc({userId: "a", status: "going", eventId: "dup"}),
      ])).toEqual({goingCount: 1, interestedCount: 0});
    });
  });

  describe("recomputeEventInterestAggregates", () => {
    it("writes rolled-up totals including duplicate RSVPs", async () => {
      const statsWrites = [];
      const db = mockDb({
        duplicateIdsByNative: {native: ["dup-1"]},
        interestsByEventId: {
          "native": [interestDoc({userId: "a", status: "going", eventId: "native"})],
          "dup-1": [
            interestDoc({userId: "b", status: "interested", eventId: "dup-1"}),
            interestDoc({userId: "a", status: "going", eventId: "dup-1"}),
          ],
        },
        statsWrites,
      });

      const counts = await recomputeEventInterestAggregates(db, "native");
      expect(counts).toEqual({goingCount: 1, interestedCount: 1});
      expect(statsWrites).toEqual([
        {
          eventId: "native",
          data: {goingCount: 1, interestedCount: 1},
          options: {merge: true},
        },
      ]);
    });
  });

  describe("handleEventInterestWritten", () => {
    it("recomputes the duplicate listing and its native event", async () => {
      const statsWrites = [];
      const db = mockDb({
        duplicateIdsByNative: {native: ["dup"], dup: []},
        eventsById: {dup: {duplicateOf: "native"}, native: {}},
        interestsByEventId: {
          dup: [interestDoc({userId: "a", status: "going", eventId: "dup"})],
          native: [],
        },
        statsWrites,
      });

      await handleEventInterestWritten(db, {
        params: {eventId: "dup"},
        data: {
          before: {exists: false, data: () => null},
          after: {
            exists: true,
            data: () => ({eventId: "dup", status: "going", userId: "a"}),
          },
        },
      });

      expect(statsWrites.map((write) => write.eventId)).toEqual(["dup", "native"]);
      expect(statsWrites[0].data).toEqual({goingCount: 1, interestedCount: 0});
      expect(statsWrites[1].data).toEqual({goingCount: 1, interestedCount: 0});
    });
  });

  describe("handleEventDuplicateOfChanged", () => {
    it("recomputes both events and deletes stats when the duplicate is removed", async () => {
      const statsWrites = [];
      const statsDeletes = [];
      const db = mockDb({
        duplicateIdsByNative: {native: []},
        interestsByEventId: {native: []},
        statsWrites,
        statsDeletes,
      });

      await handleEventDuplicateOfChanged(
          db,
          "dup",
          {duplicateOf: "native"},
          null,
      );

      expect(statsWrites.map((write) => write.eventId)).toEqual(["native"]);
      expect(statsDeletes).toEqual(["dup"]);
    });
  });
});
