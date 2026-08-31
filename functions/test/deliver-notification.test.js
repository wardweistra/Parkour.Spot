const {
  deliverNotifications,
  sendPushForPayload,
  clickUrlForDeeplink,
} = require("../lib/deliver-notification");
const {
  DEFAULT_NOTIFICATION_ICON_URL,
  DEFAULT_NOTIFICATION_BADGE_URL,
} = require("../lib/send-web-push");

const TOKEN = "fcm-token-abcdefghijklmnopqrstuvwxyz";

function createDb({
  written,
  cleanupWrites,
  subscriptionsByUser = {},
  preferredByUser = {},
}) {
  return {
    batch: jest.fn(() => {
      const ops = {
        commit: jest.fn(async () => {}),
        set: jest.fn((ref, data, opts) => {
          if (opts && opts.merge) {
            cleanupWrites.push({ref, data});
          } else {
            written.push({ref, data});
          }
        }),
      };
      return ops;
    }),
    collection: jest.fn((name) => {
      if (name !== "users") {
        throw new Error("unexpected collection " + name);
      }
      return {
        doc: jest.fn((uid) => ({
          get: jest.fn(async () => ({
            exists: true,
            data: () => ({
              preferredLanguageCode: preferredByUser[uid],
            }),
          })),
          collection: jest.fn((sub) => {
            if (sub === "notifications") {
              return {
                doc: jest.fn(() => ({
                  id: "n1",
                  path: `users/${uid}/notifications/n1`,
                })),
              };
            }
            if (sub === "pushSubscriptions") {
              const subs = subscriptionsByUser[uid] || [];
              return {
                get: jest.fn(async () => ({
                  empty: subs.length === 0,
                  docs: subs.map((s) => ({
                    id: s.id,
                    data: () => s,
                  })),
                })),
                doc: jest.fn((id) => ({
                  path: `users/${uid}/pushSubscriptions/${id}`,
                })),
              };
            }
            throw new Error("unexpected subcollection " + sub);
          }),
        })),
      };
    }),
  };
}

const FieldValue = {serverTimestamp: () => ({_ts: true})};

const spotPayload = {
  notificationKind: "nearby_new_spot",
  templateArgs: {actorName: "Alex", spotName: "Wall"},
  deeplinkKind: "spot",
  deeplinkId: "spotA",
};

describe("clickUrlForDeeplink", () => {
  it("builds spot and event URLs", () => {
    expect(clickUrlForDeeplink("spot", "abc")).toBe("https://parkour.spot/spot/abc");
    expect(clickUrlForDeeplink("event", "evt1")).toBe("https://parkour.spot/event/evt1");
  });

  it("appends nid when an inbox id is provided", () => {
    expect(clickUrlForDeeplink("spot", "abc", "n1")).toBe(
        "https://parkour.spot/spot/abc?nid=n1",
    );
    expect(clickUrlForDeeplink("event", "evt1", "n1")).toBe(
        "https://parkour.spot/event/evt1?nid=n1",
    );
  });

  it("ignores blank inbox ids", () => {
    expect(clickUrlForDeeplink("spot", "abc", "  ")).toBe(
        "https://parkour.spot/spot/abc",
    );
  });
});

describe("deliverNotifications", () => {
  it("writes inbox docs without title/body", async () => {
    const written = [];
    const cleanupWrites = [];
    const db = createDb({written, cleanupWrites});
    const messaging = {sendEach: jest.fn()};

    const result = await deliverNotifications({
      db,
      FieldValue,
      userIds: ["u1"],
      payload: spotPayload,
      messaging,
    });

    expect(result.notified).toBe(1);
    expect(written.length).toBe(1);
    expect(written[0].data).toEqual({
      notificationKind: "nearby_new_spot",
      templateArgs: {actorName: "Alex", spotName: "Wall"},
      deeplinkKind: "spot",
      deeplinkId: "spotA",
      createdAt: {_ts: true},
      read: false,
    });
    expect(written[0].data.title).toBeUndefined();
    expect(written[0].data.body).toBeUndefined();
    expect(messaging.sendEach).not.toHaveBeenCalled();
  });

  it("skips push when subscriptions are disabled or missing tokens", async () => {
    const written = [];
    const cleanupWrites = [];
    const db = createDb({
      written,
      cleanupWrites,
      subscriptionsByUser: {
        u1: [
          {id: "s1", enabled: false, token: TOKEN, locale: "en"},
          {id: "s2", enabled: true, token: "short", locale: "en"},
        ],
      },
    });
    const messaging = {sendEach: jest.fn()};

    await deliverNotifications({
      db,
      FieldValue,
      userIds: ["u1"],
      payload: spotPayload,
      messaging,
    });

    expect(written.length).toBe(1);
    expect(messaging.sendEach).not.toHaveBeenCalled();
  });

  it("sends localized title/body and spot click URL", async () => {
    const written = [];
    const cleanupWrites = [];
    const db = createDb({
      written,
      cleanupWrites,
      subscriptionsByUser: {
        u1: [{id: "inst1", enabled: true, token: TOKEN, locale: "nl"}],
      },
    });
    const messaging = {
      sendEach: jest.fn(async (messages) => ({
        successCount: messages.length,
        failureCount: 0,
        responses: messages.map(() => ({success: true})),
      })),
    };

    await deliverNotifications({
      db,
      FieldValue,
      userIds: ["u1"],
      payload: spotPayload,
      messaging,
    });

    expect(messaging.sendEach).toHaveBeenCalledTimes(1);
    const messages = messaging.sendEach.mock.calls[0][0];
    expect(messages.length).toBe(1);
    expect(messages[0].token).toBe(TOKEN);
    expect(messages[0].notification.title).toBe("Nieuwe spot in de buurt: Wall");
    expect(messages[0].data.openUrl).toBe(
        "https://parkour.spot/spot/spotA?nid=n1",
    );
    expect(messages[0].webpush.fcmOptions.link).toBe(
        "https://parkour.spot/spot/spotA?nid=n1",
    );
    expect(messages[0].webpush.notification.icon).toBe(
        DEFAULT_NOTIFICATION_ICON_URL,
    );
    expect(messages[0].webpush.notification.badge).toBe(
        DEFAULT_NOTIFICATION_BADGE_URL,
    );
    expect(messages[0].webpush.notification.actions).toBeUndefined();
  });

  it("sends event click URL for event deeplinks", async () => {
    const written = [];
    const cleanupWrites = [];
    const db = createDb({
      written,
      cleanupWrites,
      subscriptionsByUser: {
        u1: [{id: "inst1", enabled: true, token: TOKEN, locale: "en"}],
      },
    });
    const messaging = {
      sendEach: jest.fn(async (messages) => ({
        successCount: messages.length,
        failureCount: 0,
        responses: messages.map(() => ({success: true})),
      })),
    };

    await deliverNotifications({
      db,
      FieldValue,
      userIds: ["u1"],
      payload: {
        notificationKind: "nearby_new_event",
        templateArgs: {eventName: "Jam"},
        deeplinkKind: "event",
        deeplinkId: "evt1",
      },
      messaging,
    });

    const messages = messaging.sendEach.mock.calls[0][0];
    expect(messages[0].notification.title).toBe("New event nearby: Jam");
    expect(messages[0].data.openUrl).toBe(
        "https://parkour.spot/event/evt1?nid=n1",
    );
    expect(messages[0].webpush.notification.actions).toBeUndefined();
  });

  it("falls back to preferredLanguageCode when subscription locale is unsupported", async () => {
    const written = [];
    const cleanupWrites = [];
    const db = createDb({
      written,
      cleanupWrites,
      subscriptionsByUser: {
        u1: [{id: "inst1", enabled: true, token: TOKEN, locale: "zz"}],
      },
      preferredByUser: {u1: "de"},
    });
    const messaging = {
      sendEach: jest.fn(async (messages) => ({
        successCount: messages.length,
        failureCount: 0,
        responses: messages.map(() => ({success: true})),
      })),
    };

    await deliverNotifications({
      db,
      FieldValue,
      userIds: ["u1"],
      payload: spotPayload,
      messaging,
    });

    const messages = messaging.sendEach.mock.calls[0][0];
    expect(messages[0].notification.title).toBe("Neuer Spot in der Nähe: Wall");
  });

  it("disables invalid registration tokens", async () => {
    const written = [];
    const cleanupWrites = [];
    const db = createDb({
      written,
      cleanupWrites,
      subscriptionsByUser: {
        u1: [{id: "inst1", enabled: true, token: TOKEN, locale: "en"}],
      },
    });
    const messaging = {
      sendEach: jest.fn(async () => ({
        successCount: 0,
        failureCount: 1,
        responses: [{
          success: false,
          error: {
            code: "messaging/registration-token-not-registered",
            message: "not registered",
          },
        }],
      })),
    };

    await deliverNotifications({
      db,
      FieldValue,
      userIds: ["u1"],
      payload: spotPayload,
      messaging,
    });

    expect(cleanupWrites.length).toBe(1);
    expect(cleanupWrites[0].ref.path).toBe("users/u1/pushSubscriptions/inst1");
    expect(cleanupWrites[0].data).toEqual({
      enabled: false,
      token: null,
      updatedAt: {_ts: true},
    });
  });

  it("does not throw when sendEach fails", async () => {
    const written = [];
    const cleanupWrites = [];
    const db = createDb({
      written,
      cleanupWrites,
      subscriptionsByUser: {
        u1: [{id: "inst1", enabled: true, token: TOKEN, locale: "en"}],
      },
    });
    const messaging = {
      sendEach: jest.fn(async () => {
        throw new Error("FCM down");
      }),
    };

    await expect(deliverNotifications({
      db,
      FieldValue,
      userIds: ["u1"],
      payload: spotPayload,
      messaging,
    })).resolves.toEqual({notified: 1});
    expect(written.length).toBe(1);
  });
});

describe("sendPushForPayload", () => {
  it("does not throw when the user has no subscriptions collection get", async () => {
    const db = {
      collection: () => ({
        doc: () => ({
          collection: () => ({
            get: async () => ({empty: true, docs: []}),
          }),
        }),
      }),
    };
    await expect(sendPushForPayload({
      db,
      FieldValue,
      uid: "u1",
      payload: spotPayload,
    })).resolves.toBeUndefined();
  });
});
