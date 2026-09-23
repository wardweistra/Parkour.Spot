const {
  buildExternalEventKey,
  dateEndToUtc,
  dateStartToUtc,
  EVENT_TIME_ZONE_SOURCE_FEED,
  EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT,
  extractLastHttpUrlFromDescription,
  hasExternalEventAddressChanged,
  hasExternalEventContentChanges,
  hasExternalEventPlaceFields,
  normalizeEventSyncSourceType,
  normalizeImportedEventDescription,
  normalizeImportedTimeZone,
  parseExternalEventsFromIcs,
  parseExternalEventsFromSquarespace,
  parseExternalEventsFromWixPublishedCalendar,
  removeExtractedWebsiteUrlFromDescription,
  shouldGeocodeExternalEventAddress,
  EVENT_SYNC_SOURCE_TYPE_SQUARESPACE_CALENDAR,
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

    it("detects externalImageUrl changes", () => {
      const existing = {
        ...incoming,
        externalImageUrl: "https://cdn.example.com/a.jpg",
      };
      const withImage = {
        ...incoming,
        externalImageUrl: "https://cdn.example.com/b.jpg",
      };
      expect(hasExternalEventContentChanges(existing, withImage)).toBe(true);
      expect(
          hasExternalEventContentChanges(existing, {
            ...incoming,
            externalImageUrl: "https://cdn.example.com/a.jpg",
          }),
      ).toBe(false);
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

    it("skips geocoding when incoming event already has coordinates", () => {
      expect(
          shouldGeocodeExternalEventAddress(
              null,
              {
                address: "Stockholm, Sweden",
                latitude: 59.33,
                longitude: 18.07,
              },
          ),
      ).toBe(false);
    });

    it("detects missing city/country place fields", () => {
      expect(hasExternalEventPlaceFields({city: "Graz", countryCode: "AT"}))
          .toBe(true);
      expect(hasExternalEventPlaceFields({city: "Graz"})).toBe(false);
      expect(hasExternalEventPlaceFields({
        city: "",
        countryCode: "AT",
      })).toBe(false);
      expect(hasExternalEventPlaceFields(null)).toBe(false);
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

    it("uses source default timezone for floating timed events", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "BEGIN:VEVENT",
        "UID:float@example.com",
        "DTSTART:20260702T180000",
        "DTEND:20260702T200000",
        "SUMMARY:Floating timed",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "apk",
        sourceName: "American Parkour",
        sourceDefaultTimeZone: "America/New_York",
      });

      expect(events).toHaveLength(1);
      expect(events[0].isDateOnly).toBe(false);
      expect(events[0].timeZone).toBe("America/New_York");
      expect(events[0].timeZoneSource).toBe(
          EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT,
      );
      expect(events[0].startAt.toISOString()).toBe("2026-07-02T22:00:00.000Z");
      expect(events[0].endAt.toISOString()).toBe("2026-07-03T00:00:00.000Z");
    });

    it("prefers calendar timezone over source default for floating timed", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "X-WR-TIMEZONE:Europe/Berlin",
        "BEGIN:VEVENT",
        "UID:float@example.com",
        "DTSTART:20260702T000000",
        "DTEND:20260703T010000",
        "SUMMARY:Floating with calendar TZ",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "s",
        sourceName: "S",
        sourceDefaultTimeZone: "America/New_York",
      });

      expect(events).toHaveLength(1);
      expect(events[0].timeZone).toBe("Europe/Berlin");
      expect(events[0].timeZoneSource).toBe(EVENT_TIME_ZONE_SOURCE_FEED);
      expect(events[0].startAt.toISOString()).toBe("2026-07-01T22:00:00.000Z");
      expect(events[0].endAt.toISOString()).toBe("2026-07-02T23:00:00.000Z");
    });

    it("does not apply source default to timed UTC events", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "BEGIN:VEVENT",
        "UID:utc@example.com",
        "DTSTART:20260512T180000Z",
        "DTEND:20260512T200000Z",
        "SUMMARY:Timed UTC",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "s",
        sourceName: "S",
        sourceDefaultTimeZone: "America/New_York",
      });

      expect(events).toHaveLength(1);
      expect(events[0].timeZone).toBeUndefined();
      expect(events[0].timeZoneSource).toBeUndefined();
      expect(events[0].startAt.toISOString()).toBe("2026-05-12T18:00:00.000Z");
    });

    it("promotes Google-style UTC midnight spans to all-day using calendar TZ", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "X-WR-TIMEZONE:Europe/Amsterdam",
        "BEGIN:VEVENT",
        "UID:dpl@example.com",
        "DTSTART:20261205T230000Z",
        "DTEND:20261206T230000Z",
        "SUMMARY:DPL Freestyle 1",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "pkfr",
        sourceName: "PKFR Jams NL",
      });

      expect(events).toHaveLength(1);
      expect(events[0].isDateOnly).toBe(true);
      expect(events[0].timeZone).toBe("Europe/Amsterdam");
      expect(events[0].timeZoneSource).toBe(EVENT_TIME_ZONE_SOURCE_FEED);
      expect(events[0].startAt).toEqual(
          dateStartToUtc(2026, 12, 6, "Europe/Amsterdam"),
      );
      expect(events[0].endAt).toEqual(
          dateEndToUtc(2026, 12, 6, "Europe/Amsterdam"),
      );
    });

    it("promotes multi-day local midnight spans to all-day", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "X-WR-TIMEZONE:Europe/Amsterdam",
        "BEGIN:VEVENT",
        "UID:nk@example.com",
        "DTSTART:20270514T220000Z",
        "DTEND:20270516T220000Z",
        "SUMMARY:NK Freestyle",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "pkfr",
        sourceName: "PKFR Jams NL",
      });

      expect(events).toHaveLength(1);
      expect(events[0].isDateOnly).toBe(true);
      expect(events[0].timeZone).toBe("Europe/Amsterdam");
      expect(events[0].startAt).toEqual(
          dateStartToUtc(2027, 5, 15, "Europe/Amsterdam"),
      );
      expect(events[0].endAt).toEqual(
          dateEndToUtc(2027, 5, 16, "Europe/Amsterdam"),
      );
    });

    it("promotes midnight spans using source default when calendar TZ is missing", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "BEGIN:VEVENT",
        "UID:midnight@example.com",
        "DTSTART:20261205T230000Z",
        "DTEND:20261206T230000Z",
        "SUMMARY:Midnight span",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "s",
        sourceName: "S",
        sourceDefaultTimeZone: "Europe/Amsterdam",
      });

      expect(events).toHaveLength(1);
      expect(events[0].isDateOnly).toBe(true);
      expect(events[0].timeZone).toBe("Europe/Amsterdam");
      expect(events[0].timeZoneSource).toBe(
          EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT,
      );
      expect(events[0].startAt).toEqual(
          dateStartToUtc(2026, 12, 6, "Europe/Amsterdam"),
      );
    });

    it("does not promote non-midnight timed UTC events", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "X-WR-TIMEZONE:Europe/Amsterdam",
        "BEGIN:VEVENT",
        "UID:afternoon@example.com",
        "DTSTART:20260512T180000Z",
        "DTEND:20260512T200000Z",
        "SUMMARY:Afternoon",
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
    });

    it("promotes floating local midnight spans to all-day", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "X-WR-TIMEZONE:Europe/Berlin",
        "BEGIN:VEVENT",
        "UID:float-midnight@example.com",
        "DTSTART:20260702T000000",
        "DTEND:20260703T000000",
        "SUMMARY:Floating midnight",
        "END:VEVENT",
        "END:VCALENDAR",
      ].join("\r\n");

      const events = parseExternalEventsFromIcs(icsText, {
        sourceId: "s",
        sourceName: "S",
      });

      expect(events).toHaveLength(1);
      expect(events[0].isDateOnly).toBe(true);
      expect(events[0].timeZone).toBe("Europe/Berlin");
      expect(events[0].timeZoneSource).toBe(EVENT_TIME_ZONE_SOURCE_FEED);
      expect(events[0].startAt).toEqual(
          dateStartToUtc(2026, 7, 2, "Europe/Berlin"),
      );
      expect(events[0].endAt).toEqual(
          dateEndToUtc(2026, 7, 2, "Europe/Berlin"),
      );
    });

    it("does not promote midnight spans when no timezone is available", () => {
      const icsText = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "BEGIN:VEVENT",
        "UID:no-tz@example.com",
        "DTSTART:20261205T230000Z",
        "DTEND:20261206T230000Z",
        "SUMMARY:No TZ midnight",
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
      expect(events[0].startAt.toISOString()).toBe("2026-12-05T23:00:00.000Z");
      expect(events[0].endAt.toISOString()).toBe("2026-12-06T23:00:00.000Z");
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

  describe("parseExternalEventsFromWixPublishedCalendar", () => {
    const basePayload = {
      time_zone: "Europe/Berlin",
      events: [
        {
          id: 1016162,
          title: "KIPA JAM - STOCKHOLM",
          start: "2022-06-17",
          end: "2022-06-19",
          all_day: 1,
          time_zone: "",
          desc: "<p>Jam in Stockholm</p><p>https://kipamagazine.com/jam</p>",
          link: null,
          image: "https://static.wixstatic.com/media/example.jpg",
          venue: {
            name: "Stockholm",
            address: "Stockholm, Sweden",
            lat: "59.32932349999999",
            long: "18.0685808",
          },
        },
        {
          id: 1016145,
          title: "REGENSBURG JAM",
          start: "2022-07-02T00:00",
          end: "2022-07-03T01:00",
          all_day: 0,
          time_zone: "",
          desc: "",
          link: "https://example.com/regensburg",
          image: "[\"https:\\/\\/static.wixstatic.com\\/media\\/array-style.jpg\"]",
          venue: {
            name: "Parkourhalle Regensburg",
            address: "Lilienthalstraße, Regensburg, Germany",
            lat: "49.0114667",
            long: "12.0600309",
          },
        },
        {
          id: 3332204,
          title: "PARKOUR CHALLENGE RACE",
          start: "2025-08-24T12:00",
          end: "2025-08-24T13:00",
          all_day: 0,
          time_zone: "Europe/Paris",
          desc: "Race day",
          venue: {
            address: "Paris, France",
          },
        },
      ],
    };

    it("maps ids, venue address/coords, and website fields", () => {
      const events = parseExternalEventsFromWixPublishedCalendar(basePayload, {
        sourceId: "wix-1",
        sourceName: "Jam Calendar",
      });

      expect(events).toHaveLength(3);
      const stockholm = events.find((e) => e.externalEventUid === "1016162");
      expect(stockholm.externalEventKey).toBe("1016162");
      expect(stockholm.title).toBe("KIPA JAM - STOCKHOLM");
      expect(stockholm.address).toBe("Stockholm, Sweden");
      expect(stockholm.latitude).toBeCloseTo(59.32932349999999);
      expect(stockholm.longitude).toBeCloseTo(18.0685808);
      expect(stockholm.websiteUrl).toBe("https://kipamagazine.com/jam");
      expect(stockholm.description).toBe("Jam in Stockholm");
      expect(stockholm.externalImageUrl).toBe(
          "https://static.wixstatic.com/media/example.jpg",
      );

      const regensburg = events.find((e) => e.externalEventUid === "1016145");
      expect(regensburg.websiteUrl).toBe("https://example.com/regensburg");
      expect(regensburg.externalImageUrl).toBe(
          "https://static.wixstatic.com/media/array-style.jpg",
      );
    });

    it("parses image fields that are JSON-encoded URL arrays", () => {
      const payload = {
        time_zone: "Europe/Berlin",
        events: [
          {
            id: 1,
            title: "Array image",
            start: "2022-06-17",
            end: "2022-06-17",
            all_day: 1,
            image: "[\"https:\\/\\/static.wixstatic.com\\/media\\/foo.jpg\"]",
          },
          {
            id: 2,
            title: "Plain image",
            start: "2022-06-18",
            end: "2022-06-18",
            all_day: 1,
            image: "https://static.wixstatic.com/media/bar.jpg",
          },
          {
            id: 3,
            title: "No image",
            start: "2022-06-19",
            end: "2022-06-19",
            all_day: 1,
            image: "",
          },
        ],
      };
      const events = parseExternalEventsFromWixPublishedCalendar(payload, {
        sourceId: "wix-1",
        sourceName: "Jam Calendar",
      });
      expect(events[0].externalImageUrl).toBe(
          "https://static.wixstatic.com/media/foo.jpg",
      );
      expect(events[1].externalImageUrl).toBe(
          "https://static.wixstatic.com/media/bar.jpg",
      );
      expect(events[2].externalImageUrl).toBeUndefined();
    });

    it("ignores link=event_page and falls back to organizer website", () => {
      const payload = {
        time_zone: "Europe/Berlin",
        events: [
          {
            id: 10,
            title: "Placeholder link",
            start: "2022-06-17",
            end: "2022-06-17",
            all_day: 1,
            link: "event_page",
            organizer: {
              website: "https://organizer.example/jam",
            },
          },
          {
            id: 11,
            title: "Only event_page",
            start: "2022-06-18",
            end: "2022-06-18",
            all_day: 1,
            link: "event_page",
            desc: "<p>See https://from-description.example/x</p>",
          },
        ],
      };
      const events = parseExternalEventsFromWixPublishedCalendar(payload, {
        sourceId: "wix-1",
        sourceName: "Jam Calendar",
      });
      expect(events[0].websiteUrl).toBe("https://organizer.example/jam");
      expect(events[1].websiteUrl).toBe("https://from-description.example/x");
    });

    it("uses calendar time_zone as feed default for all-day and floating timed", () => {
      const events = parseExternalEventsFromWixPublishedCalendar(basePayload, {
        sourceId: "wix-1",
        sourceName: "Jam Calendar",
      });

      const stockholm = events.find((e) => e.externalEventUid === "1016162");
      expect(stockholm.isDateOnly).toBe(true);
      expect(stockholm.timeZone).toBe("Europe/Berlin");
      expect(stockholm.timeZoneSource).toBe(EVENT_TIME_ZONE_SOURCE_FEED);
      expect(stockholm.startAt).toEqual(
          dateStartToUtc(2022, 6, 17, "Europe/Berlin"),
      );
      expect(stockholm.endAt).toEqual(
          dateEndToUtc(2022, 6, 19, "Europe/Berlin"),
      );

      const regensburg = events.find((e) => e.externalEventUid === "1016145");
      expect(regensburg.isDateOnly).toBe(false);
      expect(regensburg.timeZone).toBe("Europe/Berlin");
      expect(regensburg.timeZoneSource).toBe(EVENT_TIME_ZONE_SOURCE_FEED);
      expect(regensburg.startAt.toISOString()).toBe("2022-07-01T22:00:00.000Z");
      expect(regensburg.endAt.toISOString()).toBe("2022-07-02T23:00:00.000Z");
    });

    it("falls back to sourceDefaultTimeZone when calendar TZ is missing", () => {
      const payload = {
        ...basePayload,
        time_zone: "",
        events: [basePayload.events[0]],
      };
      const events = parseExternalEventsFromWixPublishedCalendar(payload, {
        sourceId: "wix-1",
        sourceName: "Jam Calendar",
        sourceDefaultTimeZone: "Europe/Amsterdam",
      });

      expect(events).toHaveLength(1);
      expect(events[0].timeZone).toBe("Europe/Amsterdam");
      expect(events[0].timeZoneSource).toBe(
          EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT,
      );
      expect(events[0].startAt).toEqual(
          dateStartToUtc(2022, 6, 17, "Europe/Amsterdam"),
      );
    });

    it("applies sourceDefaultTimeZone to floating timed Wix events", () => {
      const payload = {
        time_zone: "",
        events: [
          {
            id: 99,
            title: "Timed jam",
            start: "2022-07-02T00:00",
            end: "2022-07-03T01:00",
            all_day: 0,
            time_zone: "",
          },
        ],
      };
      const events = parseExternalEventsFromWixPublishedCalendar(payload, {
        sourceId: "wix-1",
        sourceName: "Jam Calendar",
        sourceDefaultTimeZone: "Europe/Berlin",
      });

      expect(events).toHaveLength(1);
      expect(events[0].isDateOnly).toBe(false);
      expect(events[0].timeZone).toBe("Europe/Berlin");
      expect(events[0].timeZoneSource).toBe(
          EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT,
      );
      expect(events[0].startAt.toISOString()).toBe("2022-07-01T22:00:00.000Z");
      expect(events[0].endAt.toISOString()).toBe("2022-07-02T23:00:00.000Z");
    });

    it("prefers event-level time_zone when set", () => {
      const events = parseExternalEventsFromWixPublishedCalendar(basePayload, {
        sourceId: "wix-1",
        sourceName: "Jam Calendar",
      });
      const race = events.find((e) => e.externalEventUid === "3332204");
      expect(race.timeZone).toBe("Europe/Paris");
      expect(race.timeZoneSource).toBe(EVENT_TIME_ZONE_SOURCE_FEED);
      expect(race.startAt.toISOString()).toBe("2025-08-24T10:00:00.000Z");
      expect(race.endAt.toISOString()).toBe("2025-08-24T11:00:00.000Z");
    });

    it("skips events without id or unparseable start", () => {
      const payload = {
        time_zone: "",
        events: [
          {title: "No id", start: "2022-06-17", all_day: 1},
          {id: 1, title: "Bad start", start: "not-a-date", all_day: 0},
          {
            id: 2,
            title: "Timed without timezone",
            start: "2022-07-02T00:00",
            end: "2022-07-02T01:00",
            all_day: 0,
            time_zone: "",
          },
          {
            id: 3,
            title: "All-day without timezone uses UTC floating",
            start: "2022-06-17",
            end: "2022-06-17",
            all_day: 1,
            time_zone: "",
          },
        ],
      };
      const events = parseExternalEventsFromWixPublishedCalendar(payload, {
        sourceId: "wix-1",
        sourceName: "Jam Calendar",
      });
      expect(events).toHaveLength(1);
      expect(events[0].externalEventUid).toBe("3");
      expect(events[0].timeZone).toBeUndefined();
      expect(events[0].startAt.toISOString()).toBe("2022-06-17T00:00:00.000Z");
    });
  });

  describe("normalizeEventSyncSourceType", () => {
    it("recognizes squarespaceCalendar", () => {
      expect(normalizeEventSyncSourceType("squarespaceCalendar"))
          .toBe(EVENT_SYNC_SOURCE_TYPE_SQUARESPACE_CALENDAR);
    });
  });

  describe("parseExternalEventsFromSquarespace", () => {
    const timedStartMs = Date.UTC(2026, 9, 1, 16, 0, 0); // 12:00 America/New_York
    const timedEndMs = Date.UTC(2026, 9, 1, 18, 0, 0);

    const baseItems = [
      {
        id: "evt-1",
        title: "Somernova Field Day",
        fullUrl: "/local-events/2026/10/1/somernova-field-day",
        startDate: timedStartMs,
        endDate: timedEndMs,
        excerpt:
          "<p>Join us for this fun event!</p>",
        assetUrl:
          "https://images.squarespace-cdn.com/content/v1/abc/photo.png",
        location: {
          mapLat: 42.38161,
          mapLng: -71.1046513,
          addressTitle: "Parkour Generations Boston",
          addressLine1: "12A Tyler Street",
          addressLine2: "Somerville, MA, 02143",
          addressCountry: "United States",
        },
      },
      {
        id: "evt-empty-loc",
        title: "Opening without address",
        fullUrl: "/events/opening",
        startDate: Date.UTC(2026, 5, 6, 14, 0, 0),
        endDate: Date.UTC(2026, 5, 8, 16, 0, 0),
        excerpt: "<p>Opening Strandeiland</p>",
        location: {
          mapLat: 40.7207559,
          mapLng: -74.0007613,
          addressTitle: "",
          addressLine1: "",
          addressLine2: "",
        },
      },
    ];

    it("maps ids, website, address, coords, and images", () => {
      const events = parseExternalEventsFromSquarespace(baseItems, {
        sourceId: "sq-1",
        sourceName: "PkGen Boston",
        websiteTimeZone: "America/New_York",
        siteOrigin: "https://pkgenboston.com",
      });

      expect(events).toHaveLength(2);
      const fieldDay = events.find((e) => e.externalEventUid === "evt-1");
      expect(fieldDay.externalEventKey).toBe("evt-1");
      expect(fieldDay.title).toBe("Somernova Field Day");
      expect(fieldDay.websiteUrl).toBe(
          "https://pkgenboston.com/local-events/2026/10/1/somernova-field-day",
      );
      expect(fieldDay.description).toBe("Join us for this fun event!");
      expect(fieldDay.address).toContain("Parkour Generations Boston");
      expect(fieldDay.address).toContain("12A Tyler Street");
      expect(fieldDay.latitude).toBeCloseTo(42.38161);
      expect(fieldDay.longitude).toBeCloseTo(-71.1046513);
      expect(fieldDay.externalImageUrl).toBe(
          "https://images.squarespace-cdn.com/content/v1/abc/photo.png",
      );
      expect(fieldDay.timeZone).toBe("America/New_York");
      expect(fieldDay.timeZoneSource).toBe(EVENT_TIME_ZONE_SOURCE_FEED);
      expect(fieldDay.startAt.toISOString()).toBe(
          new Date(timedStartMs).toISOString(),
      );
    });

    it("skips placeholder coords when address fields are empty", () => {
      const events = parseExternalEventsFromSquarespace(baseItems, {
        sourceId: "sq-1",
        sourceName: "Weave",
        websiteTimeZone: "Europe/Amsterdam",
        siteOrigin: "https://www.weave-pk.nl",
      });
      const opening = events.find((e) => e.externalEventUid === "evt-empty-loc");
      expect(opening.address).toBeNull();
      expect(opening.latitude).toBeUndefined();
      expect(opening.longitude).toBeUndefined();
      expect(opening.websiteUrl).toBe(
          "https://www.weave-pk.nl/events/opening",
      );
    });

    it("falls back to source default timezone when site has none", () => {
      const events = parseExternalEventsFromSquarespace(
          [baseItems[0]],
          {
            sourceId: "sq-1",
            sourceName: "PkGen Boston",
            siteOrigin: "https://pkgenboston.com",
            sourceDefaultTimeZone: "America/New_York",
          },
      );
      expect(events[0].timeZone).toBe("America/New_York");
      expect(events[0].timeZoneSource)
          .toBe(EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT);
    });

    it("promotes local midnight-to-midnight spans to all-day", () => {
      const startAt = Date.UTC(2026, 5, 6, 4, 0, 0); // midnight EDT
      const endAt = Date.UTC(2026, 5, 8, 4, 0, 0); // midnight EDT two days later
      const events = parseExternalEventsFromSquarespace(
          [{
            id: "all-day",
            title: "Weekend opening",
            fullUrl: "/events/weekend",
            startDate: startAt,
            endDate: endAt,
            excerpt: "",
          }],
          {
            sourceId: "sq-1",
            sourceName: "Weave",
            websiteTimeZone: "America/New_York",
            siteOrigin: "https://www.weave-pk.nl",
          },
      );
      expect(events).toHaveLength(1);
      expect(events[0].isDateOnly).toBe(true);
      expect(events[0].timeZone).toBe("America/New_York");
    });

    it("skips items without id or startDate", () => {
      const events = parseExternalEventsFromSquarespace(
          [
            {title: "No id", startDate: timedStartMs},
            {id: "no-start", title: "Missing start"},
          ],
          {
            sourceId: "sq-1",
            sourceName: "Test",
            siteOrigin: "https://example.com",
          },
      );
      expect(events).toHaveLength(0);
    });
  });
});
