const {
  MAX_EVENTS,
  extractWixEventsCompIdsFromHtml,
  extractWixEventsFromWarmupHtml,
  extractWixEventsInstanceFromHtml,
  fetchWixEventsCalendarEvents,
  normalizeWixEventsPageUrl,
  wixEventsPublicUrl,
  WIX_EVENTS_APP_DEFINITION_ID,
} = require("../lib/wix-events");

/**
 * Minimal unsigned JWT with a JSON payload (signature not verified).
 * @param {Object} payload
 * @return {string}
 */
function fakeJwt(payload) {
  const header = Buffer.from(JSON.stringify({alg: "none"})).toString("base64url");
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  return `${header}.${body}.sig`;
}

describe("wix-events helpers", () => {
  describe("normalizeWixEventsPageUrl", () => {
    it("strips the fragment", () => {
      expect(
          normalizeWixEventsPageUrl(
              "https://www.springstofparkour.com/events#list",
          ),
      ).toBe("https://www.springstofparkour.com/events");
    });

    it("rejects BoomTech published_calendar URLs", () => {
      expect(() => normalizeWixEventsPageUrl(
          "https://example.com/api/published_calendar?instance=x",
      )).toThrow(/not a BoomTech/);
    });

    it("rejects non-http protocols", () => {
      expect(() => normalizeWixEventsPageUrl("ftp://example.com/x"))
          .toThrow(/http or https/);
    });

    it("rejects empty input", () => {
      expect(() => normalizeWixEventsPageUrl(""))
          .toThrow(/icsUrl is required/);
    });
  });

  describe("wixEventsPublicUrl", () => {
    it("returns the cleaned public page URL", () => {
      expect(
          wixEventsPublicUrl("https://www.citilimitsparkour.com/general-6#top"),
      ).toBe("https://www.citilimitsparkour.com/general-6");
    });
  });

  describe("HTML auth extraction", () => {
    const eventsInstance = fakeJwt({
      instanceId: "inst-1",
      appDefId: WIX_EVENTS_APP_DEFINITION_ID,
      metaSiteId: "meta-1",
    });
    const otherInstance = fakeJwt({
      instanceId: "inst-2",
      appDefId: "00000000-0000-0000-0000-000000000000",
    });
    const html = [
      `<html><script>`,
      `"instance":"${otherInstance}",`,
      `"instance":"${eventsInstance}",`,
      `"appsWarmupData":{"${WIX_EVENTS_APP_DEFINITION_ID}":{`,
      `"widgetcomp-mhka1h9a":{"events":{"events":[`,
      `{"id":"evt-1","title":"HAL 5 Skill Competition 2026","status":0},`,
      `{"id":"evt-2","title":"Hawaii Jam 2027","status":0}`,
      `]}}`,
      `}}`,
      `</script></html>`,
    ].join("");

    it("extracts the Events app instance JWT", () => {
      expect(extractWixEventsInstanceFromHtml(html)).toBe(eventsInstance);
    });

    it("extracts widget compIds", () => {
      expect(extractWixEventsCompIdsFromHtml(html)).toEqual([
        "comp-mhka1h9a",
      ]);
    });

    it("extracts warmup event arrays", () => {
      const events = extractWixEventsFromWarmupHtml(html);
      expect(events).toHaveLength(2);
      expect(events[0].id).toBe("evt-1");
      expect(events[1].title).toBe("Hawaii Jam 2027");
    });
  });

  describe("fetchWixEventsCalendarEvents", () => {
    const eventsInstance = fakeJwt({
      instanceId: "inst-1",
      appDefId: WIX_EVENTS_APP_DEFINITION_ID,
    });

    it("paginates the viewer API with Authorization", async () => {
      const pageHtml = [
        `"instance":"${eventsInstance}",`,
        `"widgetcomp-abc123":{"events":{"events":[]}}`,
      ].join("");
      const calls = [];
      const downloadText = async (url, options = {}) => {
        calls.push({url, headers: options.headers || {}});
        if (url.includes("/general-6")) return pageHtml;
        if (url.includes("offset=0")) {
          return JSON.stringify({
            events: [
              {id: "a", title: "A", status: 0},
              {id: "b", title: "B", status: 0},
            ],
            hasMore: true,
            total: 3,
          });
        }
        if (url.includes("offset=2")) {
          return JSON.stringify({
            events: [{id: "c", title: "C", status: 0}],
            hasMore: false,
            total: 3,
          });
        }
        throw new Error(`unexpected url ${url}`);
      };

      const result = await fetchWixEventsCalendarEvents(
          "https://www.citilimitsparkour.com/general-6#x",
          {downloadText},
      );
      expect(result.siteOrigin).toBe("https://www.citilimitsparkour.com");
      expect(result.collectionUrl)
          .toBe("https://www.citilimitsparkour.com/general-6");
      expect(result.items.map((e) => e.id)).toEqual(["a", "b", "c"]);
      expect(calls[0].url)
          .toBe("https://www.citilimitsparkour.com/general-6");
      expect(calls[1].headers.Authorization).toBe(eventsInstance);
      expect(calls[1].url).toContain("compId=comp-abc123");
      expect(calls[1].url).toContain("offset=0");
      expect(calls[2].url).toContain("offset=2");
    });

    it("falls back to warmup events when the viewer API fails", async () => {
      const pageHtml = [
        `"instance":"${eventsInstance}",`,
        `"widgetcomp-mhka1h9a":{"events":{"events":[`,
        `{"id":"warm-1","title":"From warmup","status":0}`,
        `]}}`,
      ].join("");
      const downloadText = async (url) => {
        if (!url.includes("/_api/")) return pageHtml;
        throw new Error("Failed fetching ICS (HTTP 401)");
      };

      const result = await fetchWixEventsCalendarEvents(
          "https://www.springstofparkour.com/events",
          {downloadText},
      );
      expect(result.items).toHaveLength(1);
      expect(result.items[0].id).toBe("warm-1");
    });

    it("throws when no events can be found", async () => {
      await expect(fetchWixEventsCalendarEvents(
          "https://example.com/events",
          {downloadText: async () => "<html>no events</html>"},
      )).rejects.toThrow(/Could not find Wix Events data/);
    });

    it("caps collected events at MAX_EVENTS", async () => {
      const pageHtml = [
        `"instance":"${eventsInstance}",`,
        `"widgetcomp-x":{"events":{"events":[]}}`,
      ].join("");
      const downloadText = async (url) => {
        if (!url.includes("/_api/")) return pageHtml;
        const parsed = new URL(url);
        const offset = Number(parsed.searchParams.get("offset") || "0");
        const events = [];
        for (let i = 0; i < 50; i++) {
          const idNum = offset + i;
          events.push({id: `e${idNum}`, title: `E${idNum}`, status: 0});
        }
        return JSON.stringify({events, hasMore: true, total: 9999});
      };
      const result = await fetchWixEventsCalendarEvents(
          "https://example.com/events",
          {downloadText},
      );
      expect(result.items.length).toBe(MAX_EVENTS);
    });
  });
});
