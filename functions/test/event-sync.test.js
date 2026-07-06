const {
  buildExternalEventKey,
  dateEndToUtc,
  dateStartToUtc,
  EVENT_TIME_ZONE_SOURCE_FEED,
  EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT,
  extractLastHttpUrlFromDescription,
  hasExternalEventAddressChanged,
  hasExternalEventContentChanges,
  normalizeImportedEventDescription,
  normalizeImportedTimeZone,
  parseExternalEventsFromIcs,
  removeExtractedWebsiteUrlFromDescription,
  shouldGeocodeExternalEventAddress,
} = require("../lib/event-sync");

describe("event-sync helpers", () => {
  describe("buildExternalEventKey", () => {
    it("returns UID when recurrence ID is missing", () => {
      expect(buildExternalEventKey("abc-123", null)).toBe("abc-123");
    });

    it("builds UID+recurrence key when recurrence ID exists", () => {
      const key = buildExternalEventKey(
          "recurring-uid",
          "20260513T120000Z",
      );
      expect(key).toBe("recurring-uid::20260513T120000Z");
    });
  });

  describe("hasExternalEventContentChanges", () => {
    const incoming = {
      title: "Jam Session",
      description: "Bring water",
      websiteUrl: "https://example.com/jam",
      address: "Central Park",
      startAt: new Date("2026-05-13T10:00:00.000Z"),
      endAt: new Date("2026-05-13T12:00:00.000Z"),
      eventSourceId: "source-1",
      eventSourceName: "Source 1",
      externalEventUid: "uid-1",
      externalEventRecurrenceId: null,
      externalEventKey: "uid-1",
    };

    it("returns false when relevant fields are unchanged", () => {
      const existing = {...incoming};
      expect(hasExternalEventContentChanges(existing, incoming)).toBe(false);
    });

    it("returns true when one tracked field changes", () => {
      const existing = {...incoming, title: "Old title"};
      expect(hasExternalEventContentChanges(existing, incoming)).toBe(true);
    });

    it("treats empty string and null as equivalent", () => {
      const existing = {...incoming, description: ""};
      const incomingWithoutDescription = {...incoming, description: null};
      expect(
          hasExternalEventContentChanges(existing, incomingWithoutDescription),
      ).toBe(false);
    });

    it("detects isDateOnly changes", () => {
      const existing = {...incoming, isDateOnly: false};
      const withAllDay = {...incoming, isDateOnly: true};
      expect(hasExternalEventContentChanges(existing, withAllDay)).toBe(true);
    });

    it("detects timeZone changes", () => {
      const existing = {...incoming};
      const withZone = {...incoming, timeZone: "America/New_York"};
      expect(hasExternalEventContentChanges(existing, withZone)).toBe(true);
    });

    it("detects timeZoneSource changes", () => {
      const existing = {...incoming, timeZone: "America/New_York"};
      const withSource = {
        ...existing,
        timeZoneSource: EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT,
      };
      expect(hasExternalEventContentChanges(existing, withSource)).toBe(true);
    });
  });

  describe("schedule timezone helpers", () => {
    it("normalizes imported timezone ids", () => {
      expect(normalizeImportedTimeZone("Europe/Paris")).toBe("Europe/Paris");
      expect(normalizeImportedTimeZone("Etc/UTC")).toBeNull();
      expect(normalizeImportedTimeZone("Invalid/Zone")).toBeNull();
    });

    it("date start/end match same-day boundaries in America/New_York", () => {
      const startUtc = dateStartToUtc(2026, 8, 2, "America/New_York");
      const endUtc = dateEndToUtc(2026, 8, 2, "America/New_York");
      expect(startUtc.toISOString()).toBe("2026-08-02T04:00:00.000Z");
      expect(endUtc.toISOString()).toBe("2026-08-03T03:59:59.999Z");
    });
  });

  describe("address geocoding helpers", () => {
    it("detects address changes after normalization", () => {
      expect(
          hasExternalEventAddressChanged(
              {address: "  Central Park  "},
              {address: "Central Park"},
          ),
      ).toBe(false);
      expect(
          hasExternalEventAddressChanged(
              {address: "Central Park"},
              {address: "Riverside Park"},
          ),
      ).toBe(true);
    });

    it("requests geocoding for create with address", () => {
      expect(
          shouldGeocodeExternalEventAddress(
              null,
              {address: "Rua Augusta, 10"},
          ),
      ).toBe(true);
    });

    it("requests geocoding when update address changed", () => {
      expect(
          shouldGeocodeExternalEventAddress(
              {address: "Rua Augusta, 10", latitude: 1, longitude: 2},
              {address: "Rua Augusta, 10"},
          ),
      ).toBe(false);
      expect(
          shouldGeocodeExternalEventAddress(
              {address: "Rua Augusta, 10"},
              {address: "Avenida Paulista, 1000"},
          ),
      ).toBe(true);
      expect(
          shouldGeocodeExternalEventAddress(
              {address: "Rua Augusta, 10"},
              {address: ""},
          ),
      ).toBe(false);
    });

    it("requests geocoding when address unchanged but coordinates missing", () => {
      expect(
          shouldGeocodeExternalEventAddress(
              {address: "Rua Augusta, 10"},
              {address: "Rua Augusta, 10"},
          ),
      ).toBe(true);
      expect(
          shouldGeocodeExternalEventAddress(
              {address: "Rua Augusta, 10", latitude: null, longitude: null},
              {address: "Rua Augusta, 10"},
          ),
      ).toBe(true);
      expect(
          shouldGeocodeExternalEventAddress(
              {address: "Rua Augusta, 10", latitude: 38.7, longitude: -9.1},
              {address: "Rua Augusta, 10"},
          ),
      ).toBe(false);
    });
  });

  describe("normalizeImportedEventDescription", () => {
    it("turns br into newlines and strips HTML tags", () => {
      const raw =
          "A<br>B<br/>C <strong>x</strong> &amp; <a href=\"https://x.com\">link</a>";
      expect(normalizeImportedEventDescription(raw)).toBe(
          "A\nB\nC x & link",
      );
    });
  });

  describe("extractLastHttpUrlFromDescription", () => {
    it("returns the last URL in document order", () => {
      const html =
          "<a href=\"https://first.example/a\">x</a> text https://second.example/b";
      expect(extractLastHttpUrlFromDescription(html)).toBe(
          "https://second.example/b",
      );
    });
  });

  describe("removeExtractedWebsiteUrlFromDescription", () => {
    it("removes the URL and tidies spaces", () => {
      expect(
          removeExtractedWebsiteUrlFromDescription(
              "Line1\nLine2 old https://newer.example/b",
              "https://newer.example/b",
          ),
      ).toBe("Line1\nLine2 old");
    });

    it("returns text unchanged when url is null", () => {
      expect(
          removeExtractedWebsiteUrlFromDescription("plain text", null),
      ).toBe("plain text");
    });
  });

  describe("parseExternalEventsFromIcs", () => {
    it("parses UID and recurrence ID into unique keys", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//parkour spot test//EN",
        "BEGIN:VEVENT",
        "UID:single-event-uid@example.com",
        "DTSTART:20260512T180000Z",
        "DTEND:20260512T200000Z",
        "SUMMARY:Single event",
        "DESCRIPTION:Bring friends",
        "URL:https://example.com/single",
        "LOCATION:Single place",
        "END:VEVENT",
        "BEGIN:VEVENT",
        "UID:recurring-event-uid@example.com",
        "RECURRENCE-ID:20260513T180000Z",
        "DTSTART:20260513T180000Z",
        "DTEND:20260513T200000Z",
        "SUMMARY:Recurring event instance",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "source-1",
        sourceName: "Source name",
      });

      expect(events).toHaveLength(2);
      expect(events[0].externalEventKey).toBe("single-event-uid@example.com");
      expect(events[1].externalEventKey).toBe(
          "recurring-event-uid@example.com::2026-05-13T18:00:00.000Z",
      );
      expect(events[0].eventSourceId).toBe("source-1");
      expect(events[0].eventSourceName).toBe("Source name");
      expect(events[0].websiteUrl).toBe("https://example.com/single");
    });

    it("uses last URL from HTML description and cleans description text", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//parkour spot test//EN",
        "BEGIN:VEVENT",
        "UID:html-url@example.com",
        "DTSTART:20260512T180000Z",
        "DTEND:20260512T200000Z",
        "SUMMARY:Jam",
        "DESCRIPTION:Line1<br>Line2 <a href=\"https://older.example/a\">old</a> https://newer.example/b",
        "URL:https://ics-fallback.example/",
        "LOCATION:Park",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "s",
        sourceName: "S",
      });

      expect(events).toHaveLength(1);
      expect(events[0].websiteUrl).toBe("https://newer.example/b");
      expect(events[0].description).toBe("Line1\nLine2 old");
    });

    it("parses VALUE=DATE all-day events with calendar timezone", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "X-WR-TIMEZONE:America/New_York",
        "BEGIN:VEVENT",
        "UID:national@example.com",
        "DTSTART;VALUE=DATE:20260626",
        "DTEND;VALUE=DATE:20260629",
        "SUMMARY:2026 USPK National Championship",
        "LOCATION:HUB Parkour Training Center",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "uspk",
        sourceName: "USPK",
      });

      expect(events).toHaveLength(1);
      expect(events[0].isDateOnly).toBe(true);
      expect(events[0].timeZone).toBe("America/New_York");
      expect(events[0].timeZoneSource).toBe(EVENT_TIME_ZONE_SOURCE_FEED);
      expect(events[0].startAt.toISOString()).toBe("2026-06-26T04:00:00.000Z");
      expect(events[0].endAt.toISOString()).toBe("2026-06-29T03:59:59.999Z");
    });

    it("parses timed UTC events without isDateOnly or timeZone", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "X-WR-TIMEZONE:America/New_York",
        "BEGIN:VEVENT",
        "UID:timed@example.com",
        "DTSTART:20260512T180000Z",
        "DTEND:20260512T200000Z",
        "SUMMARY:Timed UTC",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "s",
        sourceName: "S",
      });

      expect(events).toHaveLength(1);
      expect(events[0].isDateOnly).toBe(false);
      expect(events[0].timeZone).toBeUndefined();
      expect(events[0].startAt.toISOString()).toBe("2026-05-12T18:00:00.000Z");
      expect(events[0].endAt.toISOString()).toBe("2026-05-12T20:00:00.000Z");
    });

    it("unfolds folded ICS lines when extracting VALUE=DATE", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "X-WR-TIMEZONE:America/New_York",
        "BEGIN:VEVENT",
        "UID:folded@example.com",
        "DTSTART;VALUE=DATE:20250301",
        "DTEND;VALUE=DATE:20250302",
        "DESCRIPTION:Long line that folds\r\n next line",
        "SUMMARY:Folded event",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "s",
        sourceName: "S",
      });

      expect(events).toHaveLength(1);
      expect(events[0].isDateOnly).toBe(true);
      expect(events[0].startAt.toISOString()).toBe("2025-03-01T05:00:00.000Z");
    });

    it("parses all-day events with UTC when calendar timezone is missing", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "BEGIN:VEVENT",
        "UID:allday@example.com",
        "DTSTART;VALUE=DATE:20260626",
        "DTEND;VALUE=DATE:20260629",
        "SUMMARY:No TZ calendar",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "s",
        sourceName: "S",
      });

      expect(events).toHaveLength(1);
      expect(events[0].isDateOnly).toBe(true);
      expect(events[0].timeZone).toBeUndefined();
      expect(events[0].timeZoneSource).toBeUndefined();
      expect(events[0].startAt.toISOString()).toBe("2026-06-26T00:00:00.000Z");
      expect(events[0].endAt.toISOString()).toBe("2026-06-28T23:59:59.999Z");
    });

    it("uses source default timezone for all-day events without calendar TZ", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "BEGIN:VEVENT",
        "UID:allday@example.com",
        "DTSTART;VALUE=DATE:20260626",
        "DTEND;VALUE=DATE:20260629",
        "SUMMARY:Source default TZ",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "apk",
        sourceName: "American Parkour",
        sourceDefaultTimeZone: "America/New_York",
      });

      expect(events).toHaveLength(1);
      expect(events[0].timeZone).toBe("America/New_York");
      expect(events[0].timeZoneSource).toBe(
          EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT,
      );
      expect(events[0].startAt.toISOString()).toBe("2026-06-26T04:00:00.000Z");
      expect(events[0].endAt.toISOString()).toBe("2026-06-29T03:59:59.999Z");
    });

    it("prefers feed calendar timezone over source default", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "X-WR-TIMEZONE:Europe/London",
        "BEGIN:VEVENT",
        "UID:allday@example.com",
        "DTSTART;VALUE=DATE:20260626",
        "DTEND;VALUE=DATE:20260627",
        "SUMMARY:Feed TZ wins",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "s",
        sourceName: "S",
        sourceDefaultTimeZone: "America/New_York",
      });

      expect(events).toHaveLength(1);
      expect(events[0].timeZone).toBe("Europe/London");
      expect(events[0].timeZoneSource).toBe(EVENT_TIME_ZONE_SOURCE_FEED);
    });

    it("marks timed events with TZID as feed timezone source", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "BEGIN:VEVENT",
        "UID:timed@example.com",
        "DTSTART;TZID=America/New_York:20260724T000000",
        "DTEND;TZID=America/New_York:20260726T235959",
        "SUMMARY:Indy Jam",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "apk",
        sourceName: "American Parkour",
        sourceDefaultTimeZone: "America/Los_Angeles",
      });

      expect(events).toHaveLength(1);
      expect(events[0].timeZone).toBe("America/New_York");
      expect(events[0].timeZoneSource).toBe(EVENT_TIME_ZONE_SOURCE_FEED);
      expect(events[0].isDateOnly).toBe(false);
    });

    it("imports all-day and timed events from feeds without X-WR-TIMEZONE", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "BEGIN:VEVENT",
        "UID:all-day@example.com",
        "DTSTART;VALUE=DATE:20260710",
        "DTEND;VALUE=DATE:20260713",
        "SUMMARY:Summer Jam",
        "END:VEVENT",
        "BEGIN:VEVENT",
        "UID:timed@example.com",
        "DTSTART;TZID=America/New_York:20260724T000000",
        "DTEND;TZID=America/New_York:20260726T235959",
        "SUMMARY:Indy Jam",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "apk",
        sourceName: "American Parkour",
      });

      expect(events).toHaveLength(2);
      expect(events.map((e) => e.title).sort()).toEqual([
        "Indy Jam",
        "Summer Jam",
      ]);
    });
  });
});
