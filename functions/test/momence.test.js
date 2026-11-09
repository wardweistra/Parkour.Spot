const {
  parseExternalEventsFromMomence,
} = require("../lib/event-sync");
const {
  fetchMomenceHostSchedule,
  normalizeMomenceFeedUrl,
  resolveMomenceFeedUrl,
  startOfZonedDayUtc,
} = require("../lib/momence");

const PATH_MOVEMENT_HTML = `
<script
  async
  host_id="190761"
  tag_ids="[368178]"
  src="https://momence.com/plugin/host-schedule/host-schedule.js"
></script>
`;

const MOMENCE_HOST_HTML = `
<html><body>
  <a href="https://momence.com/u/path-movement-IBbky8">Path Movement</a>
  <div host_id="190761"></div>
</body></html>
`;

const PARENTS_NIGHT_OUT = {
  id: 145477227,
  sessionName: "Parents Night Out",
  level: "Enjoy a night off.",
  startsAt: "2026-11-15T00:00:00.000Z",
  endsAt: "2026-11-15T03:00:00.000Z",
  link: "https://momence.com/s/145477227",
  location: "Path Movement",
  fixedTicketPrice: 29,
  currency: "usd",
  isCancelled: false,
  image: "https://images.momence.com/h/190761/event.png",
};

/**
 * @param {Object} options
 * @param {Object} options.metadata
 * @param {function(string, number): Object=} options.sessionsBody
 * @param {string=} options.pageHtml
 * @return {function(string): Promise<string>}
 */
function momenceDownload({metadata, sessionsBody, pageHtml}) {
  return async (url) => {
    if (pageHtml && !url.includes("readonly-api.momence.com")) {
      return pageHtml;
    }
    if (url.includes("/sessions")) {
      const page = Number(new URL(url).searchParams.get("page") || "0");
      return JSON.stringify(
        sessionsBody ? sessionsBody(url, page) : {payload: [], pagination: {}},
      );
    }
    if (url.includes("/host-schedule")) {
      return JSON.stringify(metadata);
    }
    throw new Error(`Unexpected Momence URL ${url}`);
  };
}

describe("momence helpers", () => {
  describe("normalizeMomenceFeedUrl", () => {
    it("canonicalizes a readonly API URL and keeps tag ids", () => {
      expect(normalizeMomenceFeedUrl(
          "https://readonly-api.momence.com/host-plugins/host/190761/" +
          "host-schedule/sessions?tagIds[]=368178&fromDate=2026-11-09",
      )).toBe(
          "https://readonly-api.momence.com/host-plugins/host/190761/" +
          "host-schedule?tagIds%5B%5D=368178",
      );
    });

    it("rejects a page URL that has no host id", () => {
      expect(() => normalizeMomenceFeedUrl("https://pathmovement.com/#schedule"))
          .toThrow(/host\/\{id\}/);
    });
  });

  describe("resolveMomenceFeedUrl", () => {
    it("reads the host id and embed tag from a Path Movement page", async () => {
      const resolved = await resolveMomenceFeedUrl(
          "https://pathmovement.com/#schedule",
          async () => PATH_MOVEMENT_HTML,
      );
      expect(resolved.publicUrl).toBe("https://pathmovement.com/");
      expect(resolved.canonicalUrl).toBe(
          "https://readonly-api.momence.com/host-plugins/host/190761/" +
          "host-schedule?tagIds%5B%5D=368178",
      );
    });

    it("reads the host id from a Momence host page", async () => {
      const resolved = await resolveMomenceFeedUrl(
          "https://momence.com/u/path-movement-IBbky8",
          async () => MOMENCE_HOST_HTML,
      );
      expect(resolved.publicUrl)
          .toBe("https://momence.com/u/path-movement-IBbky8");
      expect(resolved.canonicalUrl).toBe(
          "https://readonly-api.momence.com/host-plugins/host/190761/" +
          "host-schedule",
      );
    });
  });

  describe("startOfZonedDayUtc", () => {
    it("uses Denver midnight rather than the viewer timezone", () => {
      const start = startOfZonedDayUtc(
          "America/Denver",
          new Date("2026-11-09T18:00:00.000Z"),
      );
      expect(start.toISOString()).toBe("2026-11-09T07:00:00.000Z");
    });
  });

  describe("fetchMomenceHostSchedule", () => {
    const eventMetadata = {
      host: {id: 190761, timeZone: "America/Denver"},
      tags: [
        {id: 368178, name: "Event"},
        {id: 9, name: "Class"},
      ],
    };

    it("requests the Event tag and drops a class session", async () => {
      const fetched = await fetchMomenceHostSchedule(
          "https://readonly-api.momence.com/host-plugins/host/190761/host-schedule",
          {
            now: new Date("2026-11-09T18:00:00.000Z"),
            downloadText: momenceDownload({
              metadata: eventMetadata,
              sessionsBody: (url) => {
                const tags = new URL(url).searchParams.getAll("tagIds[]");
                if (!tags.includes("368178") || tags.includes("9")) {
                  return {
                    payload: [{
                      id: 1,
                      sessionName: "Red/White Band Parkour Class",
                      startsAt: "2026-11-09T23:30:00.000Z",
                    }],
                    pagination: {totalCount: 1},
                  };
                }
                return {
                  payload: [PARENTS_NIGHT_OUT],
                  pagination: {totalCount: 1},
                };
              },
            }),
          },
      );

      expect(fetched.hostTimeZone).toBe("America/Denver");
      expect(fetched.items.map((item) => item.sessionName)).toEqual([
        "Parents Night Out",
      ]);
    });

    it("throws when the host has no Event tag and the URL pins none", async () => {
      await expect(fetchMomenceHostSchedule(
          "https://readonly-api.momence.com/host-plugins/host/190761/host-schedule",
          {
            downloadText: momenceDownload({
              metadata: {
                host: {timeZone: "America/Denver"},
                tags: [{id: 9, name: "Class"}],
              },
            }),
          },
      )).rejects.toThrow(/no Event tag/);
    });

    it("skips cancelled sessions", async () => {
      const fetched = await fetchMomenceHostSchedule(
          "https://readonly-api.momence.com/host-plugins/host/190761/" +
          "host-schedule?tagIds[]=368178",
          {
            downloadText: momenceDownload({
              metadata: eventMetadata,
              sessionsBody: () => ({
                payload: [
                  PARENTS_NIGHT_OUT,
                  {
                    ...PARENTS_NIGHT_OUT,
                    id: 99,
                    sessionName: "Cancelled Nerf Night",
                    isCancelled: true,
                  },
                ],
                pagination: {totalCount: 2},
              }),
            }),
          },
      );
      expect(fetched.items.map((item) => item.id)).toEqual([145477227]);
    });

    it("stops at 500 sessions", async () => {
      let maxPage = -1;
      const fetched = await fetchMomenceHostSchedule(
          "https://readonly-api.momence.com/host-plugins/host/190761/" +
          "host-schedule?tagIds[]=368178",
          {
            downloadText: momenceDownload({
              metadata: eventMetadata,
              sessionsBody: (url, page) => {
                maxPage = Math.max(maxPage, page);
                const payload = [];
                for (let i = 0; i < 50; i++) {
                  payload.push({
                    id: page * 50 + i + 1,
                    sessionName: `Session ${page * 50 + i + 1}`,
                    startsAt: "2026-11-15T00:00:00.000Z",
                    isCancelled: false,
                  });
                }
                return {payload, pagination: {totalCount: 600}};
              },
            }),
          },
      );
      expect(fetched.items).toHaveLength(500);
      expect(fetched.items[0].id).toBe(1);
      expect(fetched.items[499].id).toBe(500);
      expect(maxPage).toBe(9);
    });
  });

  describe("parseExternalEventsFromMomence", () => {
    it("keeps the UTC instant and labels it America/Denver", () => {
      const events = parseExternalEventsFromMomence([PARENTS_NIGHT_OUT], {
        sourceId: "src-1",
        sourceName: "Path Movement",
        hostTimeZone: "America/Denver",
      });
      expect(events).toHaveLength(1);
      expect(events[0].startAt.toISOString())
          .toBe("2026-11-15T00:00:00.000Z");
      expect(events[0].endAt.toISOString()).toBe("2026-11-15T03:00:00.000Z");
      expect(events[0].timeZone).toBe("America/Denver");
      expect(events[0].timeZoneSource).toBe("feed");
      expect(events[0].title).toBe("Parents Night Out");
      expect(events[0].description).toBe("Enjoy a night off.\n\n$29");
      expect(events[0].websiteUrl).toBe("https://momence.com/s/145477227");
      expect(events[0].address).toBe("Path Movement");
      expect(events[0].externalEventUid).toBe("145477227");
      expect(events[0].externalEventRecurrenceId).toBeNull();
      expect(events[0].externalImageUrl)
          .toBe("https://images.momence.com/h/190761/event.png");
    });

    it("lets the source default timezone override the host timezone", () => {
      const events = parseExternalEventsFromMomence([PARENTS_NIGHT_OUT], {
        sourceId: "src-1",
        sourceName: "Path Movement",
        hostTimeZone: "America/Denver",
        sourceDefaultTimeZone: "Europe/Amsterdam",
      });
      expect(events[0].startAt.toISOString())
          .toBe("2026-11-15T00:00:00.000Z");
      expect(events[0].timeZone).toBe("Europe/Amsterdam");
      expect(events[0].timeZoneSource).toBe("sourceDefault");
    });

    it("skips cancelled sessions", () => {
      const events = parseExternalEventsFromMomence([
        {...PARENTS_NIGHT_OUT, isCancelled: true},
      ], {
        sourceId: "src-1",
        sourceName: "Path Movement",
        hostTimeZone: "America/Denver",
      });
      expect(events).toEqual([]);
    });
  });
});
