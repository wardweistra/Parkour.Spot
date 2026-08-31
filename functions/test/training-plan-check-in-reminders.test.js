const {Timestamp} = require("firebase-admin/firestore");
const {
  planIsInActiveWindow,
  reminderAlreadySentForCurrentStart,
  buildTemplateArgs,
  runTrainingPlanCheckInReminders,
  NOTIFICATION_KIND_TRAINING_PLAN_CHECK_IN_REMINDER,
} = require("../lib/training-plan-check-in-reminders");

function ts(ms) {
  return Timestamp.fromMillis(ms);
}

describe("planIsInActiveWindow", () => {
  const t0 = ts(1700000000000);

  it("is true when now is inside [start, end)", () => {
    const start = ts(1700000000000 - 3600000);
    const end = ts(1700000000000 + 3600000);
    expect(planIsInActiveWindow({plannedStartAt: start, plannedEndAt: end}, t0)).toBe(true);
  });

  it("is false before start", () => {
    const start = ts(1700000000000 + 1000);
    const end = ts(1700000000000 + 3600000);
    expect(planIsInActiveWindow({plannedStartAt: start, plannedEndAt: end}, t0)).toBe(false);
  });

  it("is false at or after end", () => {
    const start = ts(1700000000000 - 3600000);
    const end = ts(1700000000000);
    expect(planIsInActiveWindow({plannedStartAt: start, plannedEndAt: end}, t0)).toBe(false);
  });
});

describe("reminderAlreadySentForCurrentStart", () => {
  it("is false when planReminderSentAt missing", () => {
    expect(reminderAlreadySentForCurrentStart({
      plannedStartAt: ts(100),
    })).toBe(false);
  });

  it("is true when sent marker matches start", () => {
    const s = ts(200);
    expect(reminderAlreadySentForCurrentStart({
      plannedStartAt: s,
      planReminderSentAt: s,
    })).toBe(true);
  });

  it("is false when start changed after send", () => {
    expect(reminderAlreadySentForCurrentStart({
      plannedStartAt: ts(300),
      planReminderSentAt: ts(200),
    })).toBe(false);
  });
});

describe("buildTemplateArgs", () => {
  it("prefers plan spotName over spot doc", () => {
    expect(buildTemplateArgs(
        {spotName: " Plan "},
        {name: " Doc "},
    )).toEqual({spotName: "Plan"});
  });

  it("falls back to spot name", () => {
    expect(buildTemplateArgs(
        {},
        {name: " Wall "},
    )).toEqual({spotName: "Wall"});
  });
});

describe("runTrainingPlanCheckInReminders", () => {
  it("sends one notification and sets planReminderSentAt in a transaction", async () => {
    const now = new Date("2026-04-19T12:00:00.000Z");
    const nowMs = now.getTime();
    const start = ts(nowMs - 60000);
    const end = ts(nowMs + 3600000);

    const planRef = {path: "spotTrainingPlans/p1"};
    const planSnap = {
      ref: planRef,
      id: "p1",
      data: () => ({
        userId: "u1",
        spotId: "s1",
        spotName: "Test spot",
        plannedStartAt: start,
        plannedEndAt: end,
      }),
    };

    const notifRef = {id: "n1", path: "users/u1/notifications/n1"};
    let transactionCalls = 0;

    const db = {
      collection: (name) => {
        if (name === "spotTrainingPlans") {
          return {
            where: () => ({
              where: () => ({
                orderBy: () => ({
                  limit: () => ({
                    get: async () => ({
                      empty: false,
                      size: 1,
                      docs: [planSnap],
                    }),
                  }),
                }),
              }),
            }),
          };
        }
        if (name === "spotCheckIns") {
          return {
            where: () => ({
              where: () => ({
                where: () => ({
                  limit: () => ({
                    get: async () => ({empty: true, docs: []}),
                  }),
                }),
              }),
            }),
          };
        }
        if (name === "spots") {
          return {
            doc: () => ({
              get: async () => ({
                exists: true,
                data: () => ({name: "Doc name", hidden: false}),
              }),
            }),
          };
        }
        if (name === "users") {
          return {
            doc: (uid) => {
              if (uid !== "u1") {
                throw new Error("unexpected uid");
              }
              return {
                collection: () => ({
                  doc: () => notifRef,
                }),
              };
            },
          };
        }
        throw new Error("unexpected collection " + name);
      },
      getAll: async () => [
        {exists: true, data: () => ({notifyTrainingPlanCheckInReminders: true})},
      ],
      runTransaction: async (fn) => {
        transactionCalls++;
        const t = {
          get: async (ref) => {
            expect(ref).toBe(planRef);
            return {exists: true, data: () => planSnap.data()};
          },
          set: (ref, data) => {
            expect(ref).toBe(notifRef);
            expect(data.notificationKind).toBe(
                NOTIFICATION_KIND_TRAINING_PLAN_CHECK_IN_REMINDER,
            );
            expect(data.deeplinkKind).toBe("spot");
            expect(data.deeplinkId).toBe("s1");
            expect(data.templateArgs).toEqual({spotName: "Test spot"});
          },
          update: (ref, data) => {
            expect(ref).toBe(planRef);
            expect(data.planReminderSentAt).toBe(start);
          },
        };
        await fn(t);
      },
    };

    const FieldValue = {serverTimestamp: () => "SERVER_TS"};
    const callOrder = [];
    const sendPush = jest.fn(async () => {
      callOrder.push("push");
    });
    const originalRun = db.runTransaction;
    db.runTransaction = async (fn) => {
      callOrder.push("transaction");
      return originalRun(fn);
    };

    const result = await runTrainingPlanCheckInReminders({
      db, FieldValue, now, sendPush,
    });
    expect(result.notified).toBe(1);
    expect(transactionCalls).toBe(1);
    expect(sendPush).toHaveBeenCalledTimes(1);
    expect(sendPush.mock.calls[0][0].uid).toBe("u1");
    expect(sendPush.mock.calls[0][0].notificationId).toBe("n1");
    expect(sendPush.mock.calls[0][0].payload).toEqual({
      notificationKind: NOTIFICATION_KIND_TRAINING_PLAN_CHECK_IN_REMINDER,
      templateArgs: {spotName: "Test spot"},
      deeplinkKind: "spot",
      deeplinkId: "s1",
    });
    expect(callOrder).toEqual(["transaction", "push"]);
  });

  it("does not send push when the inbox transaction fails", async () => {
    const now = new Date("2026-04-19T12:00:00.000Z");
    const nowMs = now.getTime();
    const start = ts(nowMs - 60000);
    const end = ts(nowMs + 3600000);

    const planRef = {path: "spotTrainingPlans/p1"};
    const planSnap = {
      ref: planRef,
      id: "p1",
      data: () => ({
        userId: "u1",
        spotId: "s1",
        spotName: "Test spot",
        plannedStartAt: start,
        plannedEndAt: end,
      }),
    };

    const db = {
      collection: (name) => {
        if (name === "spotTrainingPlans") {
          return {
            where: () => ({
              where: () => ({
                orderBy: () => ({
                  limit: () => ({
                    get: async () => ({
                      empty: false,
                      size: 1,
                      docs: [planSnap],
                    }),
                  }),
                }),
              }),
            }),
          };
        }
        if (name === "spotCheckIns") {
          return {
            where: () => ({
              where: () => ({
                where: () => ({
                  limit: () => ({
                    get: async () => ({empty: true, docs: []}),
                  }),
                }),
              }),
            }),
          };
        }
        if (name === "spots") {
          return {
            doc: () => ({
              get: async () => ({
                exists: true,
                data: () => ({name: "Doc name", hidden: false}),
              }),
            }),
          };
        }
        if (name === "users") {
          return {
            doc: () => ({
              collection: () => ({
                doc: () => ({path: "users/u1/notifications/n1"}),
              }),
            }),
          };
        }
        throw new Error("unexpected collection " + name);
      },
      getAll: async () => [
        {exists: true, data: () => ({notifyTrainingPlanCheckInReminders: true})},
      ],
      runTransaction: async () => {
        throw new Error("transaction failed");
      },
    };

    const sendPush = jest.fn(async () => {});
    const result = await runTrainingPlanCheckInReminders({
      db,
      FieldValue: {serverTimestamp: () => "SERVER_TS"},
      now,
      sendPush,
    });
    expect(result.notified).toBe(0);
    expect(result.skipped).toBe(1);
    expect(sendPush).not.toHaveBeenCalled();
  });
});
