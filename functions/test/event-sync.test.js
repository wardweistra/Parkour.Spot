const {
  buildExternalEventKey,
  extractLastHttpUrlFromDescription,
  hasExternalEventAddressChanged,
  hasExternalEventContentChanges,
  normalizeImportedEventDescription,
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

    it("requests geocoding only when update address changed", () => {
      expect(
          shouldGeocodeExternalEventAddress(
              {address: "Rua Augusta, 10"},
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
  });
});
