const {
  buildCommunitySources,
  countSpotsBySourceId,
  countEventsBySourceId,
} = require("../lib/about-community-sources");

/**
 * @param {string} id
 * @param {Object} data
 * @return {{id: string, data: function(): Object}}
 */
function doc(id, data) {
  return {id, data: () => data};
}

/**
 * @param {Array<{id: string, data: function(): Object}>} docs
 * @return {{docs: Array}}
 */
function snap(docs) {
  return {docs};
}

describe("about-community-sources", () => {
  const now = new Date("2026-10-11T12:00:00.000Z");

  it("counts public spots and events by source id", () => {
    expect(countSpotsBySourceId([
      {spotSource: "apex"},
      {spotSource: "apex"},
      {spotSource: "urbn", hidden: true},
      {spotSource: "urbn", duplicateOf: "x"},
      {spotSource: "  cz  "},
      {spotSource: ""},
      {},
    ])).toEqual(new Map([["apex", 2], ["cz", 1]]));

    expect(countEventsBySourceId([
      {eventSourceId: "jam"},
      {eventSourceId: "jam"},
      {eventSourceId: "  ics  "},
      {eventSourceId: ""},
      {},
    ])).toEqual(new Map([["jam", 2], ["ics", 1]]));
  });

  it("publishes only safe fields for active sources, sorted by name", () => {
    const payload = buildCommunitySources({
      now,
      spots: [
        {id: "1", spotSource: "apex"},
        {id: "2", spotSource: "apex"},
        {id: "3", spotSource: "urbn"},
      ],
      events: [
        {id: "e1", eventSourceId: "jump"},
      ],
      spotSourcesSnap: snap([
        doc("urbn", {
          name: "URBN Jumpers",
          publicUrl: "https://example.com/urbn",
          description: "Donated spot data",
          instagramHandle: "@urbn",
          kmzUrl: "https://secret/kmz",
          isActive: true,
        }),
        doc("apex", {
          name: "Apex Speed Run",
          publicUrl: " https://example.com/apex ",
          isActive: true,
        }),
        doc("off", {
          name: "Inactive",
          isActive: false,
        }),
      ]),
      eventSourcesSnap: snap([
        doc("jump", {
          name: "Jump Events",
          publicUrl: "https://example.com/jump",
          icsUrl: "https://secret/ics",
          isActive: true,
        }),
        doc("quiet", {
          name: "Quiet calendar",
          isActive: true,
        }),
      ]),
    });

    expect(payload.generatedAt).toBe(now.toISOString());
    expect(payload.spotSources).toEqual([
      {
        id: "apex",
        name: "Apex Speed Run",
        publicUrl: "https://example.com/apex",
        description: null,
        instagramHandle: null,
        spotCount: 2,
      },
      {
        id: "urbn",
        name: "URBN Jumpers",
        publicUrl: "https://example.com/urbn",
        description: "Donated spot data",
        instagramHandle: "urbn",
        spotCount: 1,
      },
    ]);
    expect(payload.eventSources).toEqual([
      {
        id: "jump",
        name: "Jump Events",
        publicUrl: "https://example.com/jump",
        description: null,
        instagramHandle: null,
        eventCount: 1,
      },
      {
        id: "quiet",
        name: "Quiet calendar",
        publicUrl: null,
        description: null,
        instagramHandle: null,
        eventCount: 0,
      },
    ]);
    expect(JSON.stringify(payload)).not.toMatch(/kmzUrl|icsUrl|secret/);
  });
});
