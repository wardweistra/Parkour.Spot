const {
  localizedNotificationCopy,
  normalizeLocale,
  resolvePushLocale,
} = require("../lib/notification-copy");

describe("normalizeLocale", () => {
  it("accepts supported language codes", () => {
    expect(normalizeLocale("en")).toBe("en");
    expect(normalizeLocale("DE")).toBe("de");
    expect(normalizeLocale("pt-BR")).toBe("pt");
    expect(normalizeLocale("fr_CA")).toBe("fr");
  });

  it("returns null for unsupported or empty values", () => {
    expect(normalizeLocale("xx")).toBeNull();
    expect(normalizeLocale("")).toBeNull();
    expect(normalizeLocale(null)).toBeNull();
  });
});

describe("resolvePushLocale", () => {
  it("prefers the subscription locale", () => {
    expect(resolvePushLocale("nl", "de")).toBe("nl");
  });

  it("falls back to preferredLanguageCode", () => {
    expect(resolvePushLocale("zz", "es")).toBe("es");
    expect(resolvePushLocale(undefined, "fr")).toBe("fr");
  });

  it("falls back to English", () => {
    expect(resolvePushLocale("zz", "yy")).toBe("en");
    expect(resolvePushLocale(undefined, undefined)).toBe("en");
  });
});

describe("localizedNotificationCopy", () => {
  it("renders nearby_new_spot in English", () => {
    expect(localizedNotificationCopy({
      notificationKind: "nearby_new_spot",
      templateArgs: {actorName: "Alex", spotName: "Wall"},
      locale: "en",
    })).toEqual({
      title: "New spot nearby: Wall",
      body: "Alex added a new parkour spot near one of your saved locations.",
    });
  });

  it("renders nearby_check_in in English", () => {
    expect(localizedNotificationCopy({
      notificationKind: "nearby_check_in",
      templateArgs: {actorName: "Alex", spotName: "Wall"},
      locale: "en",
    })).toEqual({
      title: "Alex is training now at Wall",
      body: "They’ve just checked in to this spot.",
    });
  });

  it("renders nearby_training_plan in English", () => {
    expect(localizedNotificationCopy({
      notificationKind: "nearby_training_plan",
      templateArgs: {actorName: "Alex", spotName: "Wall"},
      locale: "en",
    })).toEqual({
      title: "Alex planned training at Wall",
      body: "They shared a public training window near one of your saved locations.",
    });
  });

  it("renders nearby_new_event in English", () => {
    expect(localizedNotificationCopy({
      notificationKind: "nearby_new_event",
      templateArgs: {eventName: "Jam"},
      locale: "en",
    })).toEqual({
      title: "New event nearby: Jam",
      body: "An event was added near one of your saved locations.",
    });
  });

  it("renders training_plan_check_in_reminder in English", () => {
    expect(localizedNotificationCopy({
      notificationKind: "training_plan_check_in_reminder",
      templateArgs: {spotName: "Wall"},
      locale: "en",
    })).toEqual({
      title: "Time to check in at Wall",
      body: "Your planned session has started. Tap to check in.",
    });
  });

  it("uses untitled fallbacks when names are empty", () => {
    expect(localizedNotificationCopy({
      notificationKind: "nearby_new_spot",
      templateArgs: {actorName: "  ", spotName: ""},
      locale: "en",
    })).toEqual({
      title: "New spot nearby: Untitled spot",
      body: "Someone added a new parkour spot near one of your saved locations.",
    });
    expect(localizedNotificationCopy({
      notificationKind: "nearby_new_event",
      templateArgs: {},
      locale: "en",
    }).title).toBe("New event nearby: Untitled event");
  });

  it("uses locale-specific fallbacks", () => {
    const copy = localizedNotificationCopy({
      notificationKind: "nearby_new_spot",
      templateArgs: {},
      locale: "de",
    });
    expect(copy.title).toBe("Neuer Spot in der Nähe: Unbenannter Spot");
    expect(copy.body).toContain("Jemand");
  });

  it("renders Dutch nearby event copy", () => {
    expect(localizedNotificationCopy({
      notificationKind: "nearby_new_event",
      templateArgs: {eventName: "Jam"},
      locale: "nl",
    }).title).toBe("Nieuw evenement in de buurt: Jam");
  });
});
