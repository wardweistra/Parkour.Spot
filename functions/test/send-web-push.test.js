/**
 * Unit tests for FCM message shapes by subscription platform.
 */
const {
  buildWebPushMessage,
  normalizePushPlatform,
} = require("../lib/send-web-push");

describe("normalizePushPlatform", () => {
  test("passes through android and ios", () => {
    expect(normalizePushPlatform("android")).toBe("android");
    expect(normalizePushPlatform("ios")).toBe("ios");
  });

  test("defaults unknown to web", () => {
    expect(normalizePushPlatform("web")).toBe("web");
    expect(normalizePushPlatform(null)).toBe("web");
    expect(normalizePushPlatform(undefined)).toBe("web");
    expect(normalizePushPlatform("desktop")).toBe("web");
  });
});

describe("buildWebPushMessage", () => {
  const base = {
    token: "tok-abc",
    title: "Hello",
    body: "World",
    clickLink: "https://parkour.spot/spot/1",
    iconUrl: "https://parkour.spot/icons/Icon-192.png",
    badgeUrl: "https://parkour.spot/icons/ParkourSpot-badge.png",
  };

  test("web includes webpush block", () => {
    const msg = buildWebPushMessage({...base, platform: "web"});
    expect(msg.token).toBe("tok-abc");
    expect(msg.notification).toEqual({title: "Hello", body: "World"});
    expect(msg.data.openUrl).toBe("https://parkour.spot/spot/1");
    expect(msg.webpush).toBeDefined();
    expect(msg.webpush.fcmOptions.link).toBe("https://parkour.spot/spot/1");
    expect(msg.android).toBeUndefined();
    expect(msg.apns).toBeUndefined();
  });

  test("android includes android config, not webpush", () => {
    const msg = buildWebPushMessage({...base, platform: "android"});
    expect(msg.android).toBeDefined();
    expect(msg.android.priority).toBe("high");
    expect(msg.android.notification.clickAction)
        .toBe("FLUTTER_NOTIFICATION_CLICK");
    expect(msg.data.openUrl).toBe("https://parkour.spot/spot/1");
    expect(msg.webpush).toBeUndefined();
    expect(msg.apns).toBeUndefined();
  });

  test("ios includes apns config", () => {
    const msg = buildWebPushMessage({...base, platform: "ios"});
    expect(msg.apns).toBeDefined();
    expect(msg.apns.payload.aps.alert).toEqual({title: "Hello", body: "World"});
    expect(msg.webpush).toBeUndefined();
    expect(msg.android).toBeUndefined();
  });

  test("missing platform defaults to web", () => {
    const msg = buildWebPushMessage(base);
    expect(msg.webpush).toBeDefined();
  });
});
