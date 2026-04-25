const {
  markRetroactiveCreateNativeFlags,
} = require("../lib/retroactive-create-native-flag");

describe("markRetroactiveCreateNativeFlags", () => {
  function createSpotDoc(id, data = {}) {
    const updates = [];
    return {
      id,
      data: () => data,
      ref: {
        update: jest.fn(async (payload) => {
          updates.push(payload);
        }),
      },
      updates,
    };
  }

  function createDuplicatesSnapshot(duplicateOfValues) {
    return {
      docs: duplicateOfValues.map((duplicateOf, index) => ({
        id: `dup-${index + 1}`,
        data: () => ({duplicateOf}),
      })),
    };
  }

  function createDb({
    duplicates,
    originalSpotDocsById,
  }) {
    return {
      collection: jest.fn((name) => {
        if (name !== "spots") {
          throw new Error(`Unexpected collection ${name}`);
        }
        return {
          where: jest.fn((field, op, value) => {
            if (field === "duplicateOf" && op === "!=" && value === null) {
              return {
                get: jest.fn(async () => createDuplicatesSnapshot(duplicates)),
              };
            }
            throw new Error(
                `Unexpected where call: ${field} ${op} ${String(value)}`,
            );
          }),
          doc: jest.fn((id) => ({
            get: jest.fn(async () => {
              const doc = originalSpotDocsById[id];
              if (!doc) {
                return {exists: false};
              }
              return {
                exists: true,
                id: doc.id,
                data: doc.data,
                ref: doc.ref,
              };
            }),
          })),
        };
      }),
    };
  }

  it("marks only eligible native original spots", async () => {
    const eligible = createSpotDoc("orig-1", {
      spotSource: null,
      createdFromCreateNative: false,
    });
    const alreadyMarked = createSpotDoc("orig-2", {
      spotSource: null,
      createdFromCreateNative: true,
    });
    const imported = createSpotDoc("orig-3", {
      spotSource: "kml",
      createdFromCreateNative: false,
    });

    const db = createDb({
      duplicates: ["orig-1", "orig-2", "orig-3", "orig-1"],
      originalSpotDocsById: {
        "orig-1": eligible,
        "orig-2": alreadyMarked,
        "orig-3": imported,
      },
    });
    const FieldValue = {serverTimestamp: jest.fn(() => ({_serverTs: true}))};

    const result = await markRetroactiveCreateNativeFlags({
      db,
      FieldValue,
    });

    expect(result).toEqual({
      duplicateTargetsFound: 3,
      processed: 3,
      marked: 1,
      skippedAlreadyMarked: 1,
      skippedImported: 1,
      skippedMissing: 0,
      failed: 0,
      failedSpotIds: [],
    });
    expect(eligible.ref.update).toHaveBeenCalledTimes(1);
    expect(alreadyMarked.ref.update).not.toHaveBeenCalled();
    expect(imported.ref.update).not.toHaveBeenCalled();
  });

  it("tracks missing and failed originals without aborting", async () => {
    const failing = createSpotDoc("orig-fail", {
      spotSource: null,
      createdFromCreateNative: false,
    });
    failing.ref.update = jest.fn(async () => {
      throw new Error("update failed");
    });

    const db = createDb({
      duplicates: ["orig-missing", "orig-fail"],
      originalSpotDocsById: {
        "orig-fail": failing,
      },
    });
    const FieldValue = {serverTimestamp: jest.fn(() => ({_serverTs: true}))};

    const result = await markRetroactiveCreateNativeFlags({
      db,
      FieldValue,
    });

    expect(result.duplicateTargetsFound).toBe(2);
    expect(result.processed).toBe(1);
    expect(result.marked).toBe(0);
    expect(result.skippedMissing).toBe(1);
    expect(result.failed).toBe(1);
    expect(result.failedSpotIds).toEqual(["orig-fail"]);
  });
});
