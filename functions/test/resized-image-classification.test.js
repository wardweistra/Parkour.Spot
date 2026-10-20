const {
  STATUS_HAS_1200,
  STATUS_ONLY_630,
  STATUS_NONE,
  emptyResizedBasenameSets,
  parseResizedObjectName,
  addResizedObjectToSets,
  classifyImageUrl,
  needsResizeTrigger,
  needs1200ResizeTrigger,
  buildClassificationReport,
} = require("../lib/resized-image-classification");

describe("parseResizedObjectName", () => {
  it("parses spots 1200 and 630", () => {
    expect(parseResizedObjectName("spots/resized/photo_1200x1200.webp")).toEqual({
      prefix: "spots",
      baseName: "photo",
      size: "1200",
    });
    expect(parseResizedObjectName("spots/resized/photo_1200x630.webp")).toEqual({
      prefix: "spots",
      baseName: "photo",
      size: "630",
    });
  });
  it("parses events resized names", () => {
    expect(parseResizedObjectName("events/resized/a_web_image_0_1200x1200.webp")).toEqual({
      prefix: "events",
      baseName: "a_web_image_0",
      size: "1200",
    });
  });
  it("returns null for unrelated paths", () => {
    expect(parseResizedObjectName("spots/photo.jpg")).toBeNull();
    expect(parseResizedObjectName("spots/resized/")).toBeNull();
    expect(parseResizedObjectName("spots/resized/photo.webp")).toBeNull();
  });
});

describe("addResizedObjectToSets", () => {
  it("fills the correct sets", () => {
    const sets = emptyResizedBasenameSets();
    addResizedObjectToSets(sets, "spots/resized/a_1200x1200.webp");
    addResizedObjectToSets(sets, "spots/resized/b_1200x630.webp");
    addResizedObjectToSets(sets, "events/resized/c_1200x1200.webp");
    expect(sets.spots1200.has("a")).toBe(true);
    expect(sets.spots630.has("b")).toBe(true);
    expect(sets.events1200.has("c")).toBe(true);
    expect(sets.spots630.has("a")).toBe(false);
  });
});

describe("classifyImageUrl", () => {
  const sets = emptyResizedBasenameSets();
  sets.spots1200.add("ok");
  sets.spots630.add("legacy");
  sets.events630.add("evt_legacy");

  it("returns null for non-resizable URLs", () => {
    expect(classifyImageUrl("https://example.com/a.jpg", sets)).toBeNull();
  });

  it("classifies has1200 / only630 / none for spots", () => {
    expect(classifyImageUrl(
        "https://storage.googleapis.com/bucket/spots/ok.jpg", sets,
    ).status).toBe(STATUS_HAS_1200);
    expect(classifyImageUrl(
        "https://storage.googleapis.com/bucket/spots/legacy.png", sets,
    ).status).toBe(STATUS_ONLY_630);
    expect(classifyImageUrl(
        "https://storage.googleapis.com/bucket/spots/missing.jpg", sets,
    ).status).toBe(STATUS_NONE);
  });

  it("classifies events", () => {
    expect(classifyImageUrl(
        "https://storage.googleapis.com/bucket/events/evt_legacy.jpg", sets,
    ).status).toBe(STATUS_ONLY_630);
    expect(classifyImageUrl(
        "https://firebasestorage.googleapis.com/v0/b/b/o/events%2Fnew.jpg",
        sets,
    ).status).toBe(STATUS_NONE);
  });

  it("prefers has1200 when both sizes exist", () => {
    sets.spots1200.add("both");
    sets.spots630.add("both");
    expect(classifyImageUrl(
        "https://storage.googleapis.com/bucket/spots/both.jpg", sets,
    ).status).toBe(STATUS_HAS_1200);
  });
});

describe("needsResizeTrigger", () => {
  it("is true only for none", () => {
    const sets = emptyResizedBasenameSets();
    sets.spots630.add("legacy");
    expect(needsResizeTrigger(
        "https://storage.googleapis.com/bucket/spots/legacy.jpg", sets,
    )).toBe(false);
    expect(needsResizeTrigger(
        "https://storage.googleapis.com/bucket/spots/missing.jpg", sets,
    )).toBe(true);
    expect(needsResizeTrigger("https://example.com/x.jpg", sets)).toBe(false);
  });
});

describe("needs1200ResizeTrigger", () => {
  it("is true for none and only630, false for has1200", () => {
    const sets = emptyResizedBasenameSets();
    sets.spots1200.add("ok");
    sets.spots630.add("legacy");
    expect(needs1200ResizeTrigger(
        "https://storage.googleapis.com/bucket/spots/ok.jpg", sets,
    )).toBe(false);
    expect(needs1200ResizeTrigger(
        "https://storage.googleapis.com/bucket/spots/legacy.jpg", sets,
    )).toBe(true);
    expect(needs1200ResizeTrigger(
        "https://storage.googleapis.com/bucket/spots/missing.jpg", sets,
    )).toBe(true);
    expect(needs1200ResizeTrigger("https://example.com/x.jpg", sets)).toBe(false);
  });
});

describe("buildClassificationReport", () => {
  it("builds summary, none detail, and only630 compact rows", () => {
    const sets = emptyResizedBasenameSets();
    sets.spots1200.add("ok");
    sets.spots630.add("legacy");

    const report = buildClassificationReport({
      sets,
      spotDocs: [
        {
          id: "s1",
          name: "Has ok",
          city: "A",
          countryCode: "NL",
          imageUrls: [
            "https://storage.googleapis.com/b/spots/ok.jpg",
            "https://storage.googleapis.com/b/spots/legacy.jpg",
          ],
        },
        {
          id: "s2",
          name: "None only",
          city: "B",
          countryCode: "BE",
          imageUrls: [
            "https://storage.googleapis.com/b/spots/gone.jpg",
          ],
        },
        {
          id: "s3",
          name: "External",
          city: "C",
          countryCode: "DE",
          imageUrls: ["https://example.com/x.jpg"],
        },
      ],
      eventDocs: [
        {
          id: "e1",
          name: "Event none",
          city: "D",
          countryCode: "US",
          imageUrls: [
            "https://storage.googleapis.com/b/events/evt_missing.jpg",
          ],
        },
      ],
    });

    expect(report.summary.spots.has1200.images).toBe(1);
    expect(report.summary.spots.only630.images).toBe(1);
    expect(report.summary.spots.none.images).toBe(1);
    expect(report.summary.events.none.images).toBe(1);
    expect(report.summary.totals.none.images).toBe(2);

    expect(report.none).toEqual(expect.arrayContaining([
      expect.objectContaining({
        kind: "spot",
        id: "s2",
        imageUrls: ["https://storage.googleapis.com/b/spots/gone.jpg"],
      }),
      expect.objectContaining({
        kind: "event",
        id: "e1",
      }),
    ]));

    expect(report.only630).toEqual([
      expect.objectContaining({
        kind: "spot",
        id: "s1",
        count: 1,
      }),
    ]);
    expect(report.only630[0].imageUrls).toBeUndefined();
  });
});
