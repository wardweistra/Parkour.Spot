const {buildAboutStats} = require("../lib/about-stats");

describe("about-stats", () => {
  const now = new Date("2026-10-07T00:00:00.000Z");

  it("counts the public library, sources, photos, and recent spots", () => {
    const spots = [
      {
        id: "a",
        countryCode: "NL",
        city: "Utrecht",
        spotSource: "urbn",
        imageUrls: ["https://x/1.jpg"],
        createdAt: new Date("2026-10-01T00:00:00.000Z"),
      },
      {
        id: "b",
        countryCode: "nl",
        city: "utrecht",
        spotSource: "urbn",
        createdAt: new Date("2025-01-01T00:00:00.000Z"),
      },
      {id: "c", countryCode: "de", spotSource: "apex", imageUrl: "https://x/2.jpg"},
      {id: "d", countryCode: "fr", city: "Paris", duplicateOf: "a"},
      {id: "e", countryCode: "fr", city: "Paris", hidden: true},
    ];
    const upcomingEvents = [
      {countryCode: "nl"},
      {countryCode: "us"},
      {countryCode: "nl"},
      {countryCode: null},
    ];

    const stats = buildAboutStats({spots, upcomingEvents, now});
    expect(stats).toEqual(expect.objectContaining({
      generatedAt: now.toISOString(),
      activityWindowDays: 30,
      spotCount: 3,
      countryCount: 2,
      cityCount: 1,
      spotSourceCount: 2,
      spotsWithPhotosCount: 2,
      spotsAdded30d: 1,
      upcomingEventCount: 4,
      eventCountryCount: 2,
    }));
  });

  it("keeps valid aggregate counts and nulls missing ones", () => {
    const stats = buildAboutStats({
      spots: [],
      upcomingEvents: [],
      now,
      counts: {
        checkIns30d: 42,
        trainingPlans30d: 0,
        monthlyActiveUsers: null,
        ratingCount: "x",
      },
    });
    expect(stats.checkIns30d).toBe(42);
    expect(stats.trainingPlans30d).toBe(0);
    expect(stats.monthlyActiveUsers).toBeNull();
    expect(stats.ratingCount).toBeNull();
    expect(stats.deduplicatedCount).toBeNull();
  });
});
