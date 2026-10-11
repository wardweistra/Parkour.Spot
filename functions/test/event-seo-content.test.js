const {
  toSchemaDate,
  formatWhenDisplay,
  effectiveCoords,
  effectiveCityCountry,
  linkedSpotLink,
  buildEventSeoContent,
} = require("../lib/event-seo-content");

describe("toSchemaDate", () => {
  it("formats date-only as YYYY-MM-DD", () => {
    expect(toSchemaDate(new Date("2026-10-11T12:00:00.000Z"), true))
        .toBe("2026-10-11");
  });
  it("formats timed events as ISO", () => {
    expect(toSchemaDate(new Date("2026-10-11T15:30:00.000Z"), false))
        .toBe("2026-10-11T15:30:00.000Z");
  });
});

describe("formatWhenDisplay", () => {
  it("returns a start label for date-only events", () => {
    const label = formatWhenDisplay(
        new Date("2026-10-11T00:00:00.000Z"),
        null,
        true,
        null,
    );
    expect(label).toContain("2026");
    expect(label).toContain("11");
  });
  it("includes end when after start", () => {
    const label = formatWhenDisplay(
        new Date("2026-10-11T00:00:00.000Z"),
        new Date("2026-10-12T00:00:00.000Z"),
        true,
        null,
    );
    expect(label).toContain("–");
  });
});

describe("effectiveCoords / city", () => {
  it("prefers event coordinates", () => {
    expect(effectiveCoords({
      latitude: 1,
      longitude: 2,
      resolvedLocation: {latitude: 9, longitude: 8},
    })).toEqual({latitude: 1, longitude: 2});
  });
  it("falls back to resolvedLocation", () => {
    expect(effectiveCoords({
      resolvedLocation: {latitude: 9, longitude: 8},
    })).toEqual({latitude: 9, longitude: 8});
  });
  it("uses resolved city/country when missing on event", () => {
    expect(effectiveCityCountry({
      resolvedLocation: {city: "Eindhoven", countryCode: "nl"},
    })).toEqual({city: "Eindhoven", countryCode: "NL"});
  });
});

describe("linkedSpotLink", () => {
  it("builds canonical city path when possible", () => {
    expect(linkedSpotLink({
      id: "abc",
      name: "Castle Garden",
      city: "Eindhoven",
      countryCode: "NL",
    })).toEqual({
      title: "Castle Garden",
      url: "/nl/eindhoven/abc",
    });
  });
  it("falls back to /spot/:id", () => {
    expect(linkedSpotLink({id: "abc", name: "Somewhere"}))
        .toEqual({title: "Somewhere", url: "/spot/abc"});
  });
});

describe("buildEventSeoContent", () => {
  it("returns null without a titled event", () => {
    expect(buildEventSeoContent({})).toBeNull();
    expect(buildEventSeoContent({event: {title: "  "}})).toBeNull();
  });

  it("builds a full event view-model", () => {
    const seo = buildEventSeoContent({
      event: {
        id: "ev1",
        title: "Jam at the Castle",
        description: "<p>Bring shoes</p>",
        address: "Kastelenplein 19",
        city: "Eindhoven",
        countryCode: "nl",
        latitude: 51.4,
        longitude: 5.4,
        startAt: new Date("2026-11-01T10:00:00.000Z"),
        endAt: new Date("2026-11-01T14:00:00.000Z"),
        isDateOnly: false,
        timeZone: "Europe/Amsterdam",
        websiteUrl: "https://example.com/jam",
        eventSourceName: "PK Eindhoven",
        imageUrls: ["https://example.com/e.jpg"],
      },
      breadcrumbs: [{name: "Home", url: "/"}, {name: "Jam", url: "/event/ev1"}],
      linkedSpots: [{
        id: "s1",
        name: "Castle Garden",
        city: "Eindhoven",
        countryCode: "NL",
      }],
    });

    expect(seo.kind).toBe("event");
    expect(seo.title).toBe("Jam at the Castle");
    expect(seo.description).toBe("Bring shoes");
    expect(seo.locationLine).toBe("Eindhoven, NL");
    expect(seo.address).toBe("Kastelenplein 19");
    expect(seo.mapUrl).toContain("51.4");
    expect(seo.whenDisplay).toBeTruthy();
    expect(seo.startDateIso).toBe("2026-11-01T10:00:00.000Z");
    expect(seo.websiteUrl).toBe("https://example.com/jam");
    expect(seo.sourceName).toBe("PK Eindhoven");
    expect(seo.linkedSpots).toEqual([{
      title: "Castle Garden",
      url: "/nl/eindhoven/s1",
    }]);
    expect(seo.jumpflixVideos).toEqual([]);
  });

  it("omits empty optional sections", () => {
    const seo = buildEventSeoContent({
      event: {
        title: "Minimal",
        startAt: new Date("2026-01-01T00:00:00.000Z"),
        isDateOnly: true,
      },
    });
    expect(seo.description).toBeNull();
    expect(seo.address).toBeNull();
    expect(seo.websiteUrl).toBeNull();
    expect(seo.linkedSpots).toEqual([]);
    expect(seo.sourceName).toBeNull();
  });
});
