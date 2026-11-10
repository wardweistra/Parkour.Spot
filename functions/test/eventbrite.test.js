const {
  EVENT_SYNC_SOURCE_TYPE_EVENTBRITE_COLLECTION,
  normalizeEventSyncSourceType,
} = require("../lib/event-sync");
const {
  normalizeEventbriteCollectionUrl,
  parseEventbriteCollectionHtml,
  resolveEventbriteLocations,
} = require("../lib/eventbrite");

const BOSTON_LAT = "42.3825338";
const BOSTON_LNG = "-71.1054122";

/**
 * @param {Array<Object>} events
 * @return {string}
 */
function collectionHtml(events) {
  const itemList = {
    "@context": "https://schema.org",
    "@type": "ItemList",
    "itemListElement": events.map((event, index) => ({
      "position": index + 1,
      "@type": "ListItem",
      "item": event,
    })),
  };
  return `<!DOCTYPE html><html><head>
<script type="application/ld+json">${JSON.stringify(itemList)}</script>
<script type="application/ld+json">{"@type":"ProfilePage"}</script>
</head><body></body></html>`;
}

/**
 * @param {Object} overrides
 * @return {Object}
 */
function bostonEvent(overrides = {}) {
  return {
    "@type": "Event",
    "name": "2027 ADAPT Level 1 Coach Certification - Boston, MA (USA)",
    "url": "https://www.eventbrite.com/e/2027-adapt-level-1-coach-certification-boston-ma-usa-tickets-2000508722441",
    "startDate": "2027-02-17T09:00:00-0500",
    "endDate": "2027-02-19T17:00:00-0500",
    "description": "3-day ADAPT Level 1 instructor course for parkour coaches.",
    "image": "https://img.evbuc.com/https%3A%2F%2Fcdn.evbuc.com%2Fimages%2F1193196047%2F1%2Foriginal.jpg",
    "location": {
      "@type": "Place",
      "name": "The Dojo at Somernova",
      "address": {
        "@type": "PostalAddress",
        "streetAddress": "15 Properzi Way",
        "addressLocality": "Somerville",
        "addressRegion": "MA",
        "postalCode": "02143",
        "addressCountry": "US",
        "latitude": BOSTON_LAT,
        "longitude": BOSTON_LNG,
      },
    },
    ...overrides,
  };
}

const JUNE_BOSTON = bostonEvent({
  name: "2027 ADAPT Level 2 Coach Certification - Boston, MA (USA)",
  url: "https://www.eventbrite.com/e/2027-adapt-level-2-coach-certification-course-only-boston-ma-usa-tickets-2000508949119",
  startDate: "2027-06-19T09:00:00-0400",
  endDate: "2027-06-23T18:00:00-0400",
});

const MEXICO_CITY = {
  "@type": "Event",
  "name": "2025 ADAPT Level 3 Coach Certification - Mexico City (MEX)",
  "url": "https://www.eventbrite.com/e/2025-adapt-level-3-coach-certification-mexico-city-mex-tickets-1613199586389",
  "startDate": "2025-11-19T09:00:00-0600",
  "endDate": "2025-11-21T17:00:00-0600",
  "description": "Level 3 coach certification in Mexico City.",
  "location": {
    "@type": "Place",
    "name": "",
  },
};

const SOURCE = {sourceId: "eb-1", sourceName: "ADAPT"};

describe("eventbrite collection sync", () => {
  describe("normalizeEventbriteCollectionUrl", () => {
    it("accepts a collection URL and strips the query", () => {
      expect(normalizeEventbriteCollectionUrl(
          "https://www.eventbrite.co.uk/cc/adapt-qualifications-courses-321289/?utm=1",
      )).toBe(
          "https://www.eventbrite.co.uk/cc/adapt-qualifications-courses-321289/",
      );
    });

    it("accepts a locale-prefixed collection path", () => {
      expect(normalizeEventbriteCollectionUrl(
          "https://www.eventbrite.com/fr_CA/cc/adapt-qualifications-courses-321289",
      )).toBe(
          "https://www.eventbrite.com/fr_CA/cc/adapt-qualifications-courses-321289",
      );
    });

    it("rejects a single event URL", () => {
      expect(() => normalizeEventbriteCollectionUrl(
          "https://www.eventbrite.co.uk/e/2027-adapt-level-1-tickets-2000508722441",
      )).toThrow(/not a single event/);
    });

    it("rejects an organizer URL", () => {
      expect(() => normalizeEventbriteCollectionUrl(
          "https://www.eventbrite.com/o/parkour-generations-americas-3481032845",
      )).toThrow(/not an organizer page/);
    });
  });

  describe("normalizeEventSyncSourceType", () => {
    it("recognizes eventbriteCollection", () => {
      expect(normalizeEventSyncSourceType("eventbriteCollection"))
          .toBe(EVENT_SYNC_SOURCE_TYPE_EVENTBRITE_COLLECTION);
    });
  });

  describe("parse and resolve", () => {
    it("stores the UTC instant, coordinates, and America/New_York", async () => {
      const parsed = parseEventbriteCollectionHtml(
          collectionHtml([bostonEvent()]),
          SOURCE,
      );
      const lookups = [];
      const resolved = await resolveEventbriteLocations(parsed, {
        lookupTimeZone: async (latitude, longitude) => {
          lookups.push([latitude, longitude]);
          return "America/New_York";
        },
        geocodeAddress: async () => {
          throw new Error("geocode should not run when coordinates exist");
        },
      });

      expect(resolved).toHaveLength(1);
      const event = resolved[0];
      expect(event.externalEventUid).toBe("2000508722441");
      expect(event.externalEventKey).toBe("2000508722441");
      expect(event.startAt.toISOString()).toBe("2027-02-17T14:00:00.000Z");
      expect(event.endAt.toISOString()).toBe("2027-02-19T22:00:00.000Z");
      expect(event.latitude).toBeCloseTo(42.3825338);
      expect(event.longitude).toBeCloseTo(-71.1054122);
      expect(event.address).toContain("15 Properzi Way");
      expect(event.address).toContain("Somerville");
      expect(event.timeZone).toBe("America/New_York");
      expect(event.timeZoneSource).toBe("feed");
      expect(event.localStart).toBeUndefined();
      expect(event.placeName).toBeUndefined();
      expect(event.description).toContain("parkour coaches");
      expect(event.externalImageUrl).toContain("img.evbuc.com");
      expect(lookups).toHaveLength(1);
    });

    it("looks up a shared venue once and keeps both wall clocks", async () => {
      const parsed = parseEventbriteCollectionHtml(
          collectionHtml([bostonEvent(), JUNE_BOSTON]),
          SOURCE,
      );
      let lookups = 0;
      const resolved = await resolveEventbriteLocations(parsed, {
        lookupTimeZone: async () => {
          lookups += 1;
          return "America/New_York";
        },
      });

      expect(lookups).toBe(1);
      expect(resolved.map((event) => event.timeZone)).toEqual([
        "America/New_York",
        "America/New_York",
      ]);
      expect(resolved[1].startAt.toISOString()).toBe("2027-06-19T13:00:00.000Z");
    });

    it("leaves timeZone unset when the zone does not reproduce 09:00", async () => {
      const parsed = parseEventbriteCollectionHtml(
          collectionHtml([bostonEvent()]),
          SOURCE,
      );
      const warnings = [];
      const resolved = await resolveEventbriteLocations(parsed, {
        lookupTimeZone: async () => "America/Chicago",
        warn: (code) => warnings.push(code),
      });

      expect(resolved[0].timeZone).toBeUndefined();
      expect(resolved[0].timeZoneSource).toBeUndefined();
      expect(resolved[0].startAt.toISOString()).toBe("2027-02-17T14:00:00.000Z");
      expect(resolved[0].latitude).toBeCloseTo(42.3825338);
      expect(warnings).toContain("eventbriteTimeZone.wallClockMismatch");
    });

    it("geocodes a missing venue from the title city", async () => {
      const parsed = parseEventbriteCollectionHtml(
          collectionHtml([MEXICO_CITY]),
          SOURCE,
      );
      const queries = [];
      const resolved = await resolveEventbriteLocations(parsed, {
        geocodeAddress: async (query) => {
          queries.push(query);
          if (query !== "Mexico City") return null;
          return {
            latitude: 19.4326,
            longitude: -99.1332,
            address: "Mexico City, Mexico",
          };
        },
        lookupTimeZone: async () => "America/Mexico_City",
      });

      expect(queries).toEqual(["Mexico City"]);
      expect(resolved[0].latitude).toBeCloseTo(19.4326);
      expect(resolved[0].longitude).toBeCloseTo(-99.1332);
      expect(resolved[0].address).toBe("Mexico City, Mexico");
      expect(resolved[0].timeZone).toBe("America/Mexico_City");
      expect(resolved[0].timeZoneSource).toBe("feed");
      expect(resolved[0].startAt.toISOString()).toBe("2025-11-19T15:00:00.000Z");
    });

    it("imports without a time zone when lookup returns nothing", async () => {
      const parsed = parseEventbriteCollectionHtml(
          collectionHtml([bostonEvent()]),
          SOURCE,
      );
      const warnings = [];
      const resolved = await resolveEventbriteLocations(parsed, {
        lookupTimeZone: async () => null,
        warn: (code) => warnings.push(code),
      });

      expect(resolved[0].timeZone).toBeUndefined();
      expect(resolved[0].startAt.toISOString()).toBe("2027-02-17T14:00:00.000Z");
      expect(warnings).toContain("eventbriteTimeZone.unavailable");
    });

    it("fails the sync when the page has no event list", () => {
      expect(() => parseEventbriteCollectionHtml("<html></html>", SOURCE))
          .toThrow(/did not include an event list/);
    });
  });
});
