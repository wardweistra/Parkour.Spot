const {
  EVENT_SYNC_SOURCE_TYPE_STREEM_PARKOUR,
  EVENT_TIME_ZONE_SOURCE_FEED,
  EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT,
  dateEndToUtc,
  dateStartToUtc,
  normalizeEventSyncSourceType,
} = require("../lib/event-sync");
const {
  STREEM_PARKOUR_DEFAULT_TIME_ZONE,
  STREEM_PARKOUR_FALLBACK_EVENT_URL,
  STREEM_PARKOUR_PUBLIC_URL,
  buildStreemExternalEventUid,
  normalizeStreemParkourFeedUrl,
  parseGermanEventDate,
  parseStreemParkourHtml,
  streemParkourPublicUrl,
} = require("../lib/streem-parkour");

const SOURCE = {sourceId: "streem-1", sourceName: "Streem Parkour Basel"};

/**
 * @param {string} eventsInnerHtml
 * @return {string}
 */
function homepageHtml(eventsInnerHtml) {
  return `<!doctype html>
<html lang="de-CH">
<body>
  <div class="stack__event">
    <p class="text--note">11. April 2027</p>
    <p>Teaser should be ignored</p>
  </div>
  <dialog id='events'>
    <div class="modal panel">
      <div class='panel__body'>
        <details class="details__events" name="events" open>
          <summary class="text--strong text--accent">2026</summary>
          <div class="events">
            ${eventsInnerHtml}
          </div>
        </details>
      </div>
    </div>
  </dialog>
</body>
</html>`;
}

describe("streemParkour sync", () => {
  describe("normalizeStreemParkourFeedUrl", () => {
    it("accepts homepage and path variants", () => {
      expect(normalizeStreemParkourFeedUrl("https://www.streemparkour.com/"))
          .toBe(STREEM_PARKOUR_PUBLIC_URL);
      expect(normalizeStreemParkourFeedUrl(
          "https://streemparkour.com/verein?x=1#events",
      )).toBe(STREEM_PARKOUR_PUBLIC_URL);
      expect(normalizeStreemParkourFeedUrl("http://www.streemparkour.com"))
          .toBe(STREEM_PARKOUR_PUBLIC_URL);
    });

    it("rejects other hosts", () => {
      expect(() => normalizeStreemParkourFeedUrl("https://example.com/"))
          .toThrow(/streemparkour\.com/);
    });

    it("rejects empty values", () => {
      expect(() => normalizeStreemParkourFeedUrl(""))
          .toThrow(/icsUrl is required/);
    });
  });

  describe("streemParkourPublicUrl", () => {
    it("returns the homepage", () => {
      expect(streemParkourPublicUrl(STREEM_PARKOUR_PUBLIC_URL))
          .toBe(STREEM_PARKOUR_PUBLIC_URL);
    });
  });

  describe("normalizeEventSyncSourceType", () => {
    it("recognizes streemParkour", () => {
      expect(normalizeEventSyncSourceType("streemParkour"))
          .toBe(EVENT_SYNC_SOURCE_TYPE_STREEM_PARKOUR);
    });
  });

  describe("parseGermanEventDate", () => {
    it("parses a single day with weekday", () => {
      expect(parseGermanEventDate("Samstag, 11. April 2026")).toEqual({
        start: {year: 2026, month: 4, day: 11},
        end: null,
      });
    });

    it("parses a cross-month range", () => {
      expect(parseGermanEventDate("27. Juli - 02. August 2026")).toEqual({
        start: {year: 2026, month: 7, day: 27},
        end: {year: 2026, month: 8, day: 2},
      });
    });

    it("parses und and bis same-month ranges", () => {
      expect(parseGermanEventDate("13. und 14. September 2025")).toEqual({
        start: {year: 2025, month: 9, day: 13},
        end: {year: 2025, month: 9, day: 14},
      });
      expect(parseGermanEventDate("05. bis 11. Juli 2025")).toEqual({
        start: {year: 2025, month: 7, day: 5},
        end: {year: 2025, month: 7, day: 11},
      });
    });

    it("returns null for unparseable text", () => {
      expect(parseGermanEventDate("sometime soon")).toBeNull();
      expect(parseGermanEventDate("")).toBeNull();
    });
  });

  describe("parseStreemParkourHtml", () => {
    it("parses single-day, range, empty href, and participant note", () => {
      const html = homepageHtml(`
        <div class="event">
          <p class="text--note"><span class="text--strong">Samstag, 11. April 2026</span> <i>(StreemTraceurs)</i></p>
          <a href="https://www.swissparkourassociation.ch/events" target="_blank" class="text--link"><i class='bx bx-run'></i>Parkour Expo Skill Competition</a>
          <p class="text--note">Grandstand Park, Luzern</p>
        </div>
        <div class="event">
          <p class="text--note"><span class="text--strong">27. Juli - 02. August 2026</span></p>
          <a href="https://www.streemparkour.com/streemlager" target="_blank" class="text--link"><i class="bx bxs-hot"></i>StreemLager</a>
          <p class="text--note">Aarburg, Aargau, Zürich, Luzern</p>
        </div>
        <div class="event">
          <p class="text--note"><span class="text--strong">Samstag, 23. Mai 2026</span></p>
          <a href="" target="_blank" class="text--link"><i class="bx bxs-chalkboard"></i>Generalversammlung</a>
          <p class="text--note">Brunnmattschulhaus, Basel</p>
        </div>
        <div class="event">
          <p class="text--note"><span class="text--strong">13. und 14. September 2025</span> <i>(StreemTraceurs)</i></p>
          <a href="https://www.swissparkourassociation.ch/events" class="text--link">Swiss Parkour Championship</a>
          <p class="text--note">XTM Park, Payerne</p>
        </div>
      `);

      const events = parseStreemParkourHtml(html, SOURCE);
      expect(events).toHaveLength(4);

      const expo = events[0];
      expect(expo.title).toBe("Parkour Expo Skill Competition");
      expect(expo.description).toContain("StreemTraceurs");
      expect(expo.websiteUrl)
          .toBe("https://www.swissparkourassociation.ch/events");
      expect(expo.address).toBe("Grandstand Park, Luzern");
      expect(expo.isDateOnly).toBe(true);
      expect(expo.timeZone).toBe(STREEM_PARKOUR_DEFAULT_TIME_ZONE);
      expect(expo.timeZoneSource).toBe(EVENT_TIME_ZONE_SOURCE_FEED);
      expect(expo.externalEventUid).toBe(
          buildStreemExternalEventUid(
              "Parkour Expo Skill Competition",
              {year: 2026, month: 4, day: 11},
          ),
      );
      expect(expo.startAt).toEqual(
          dateStartToUtc(2026, 4, 11, STREEM_PARKOUR_DEFAULT_TIME_ZONE),
      );
      expect(expo.endAt).toEqual(
          dateEndToUtc(2026, 4, 11, STREEM_PARKOUR_DEFAULT_TIME_ZONE),
      );

      const lager = events[1];
      expect(lager.title).toBe("StreemLager");
      expect(lager.startAt).toEqual(
          dateStartToUtc(2026, 7, 27, STREEM_PARKOUR_DEFAULT_TIME_ZONE),
      );
      expect(lager.endAt).toEqual(
          dateEndToUtc(2026, 8, 2, STREEM_PARKOUR_DEFAULT_TIME_ZONE),
      );

      const gv = events[2];
      expect(gv.title).toBe("Generalversammlung");
      expect(gv.websiteUrl).toBe(STREEM_PARKOUR_FALLBACK_EVENT_URL);

      const championship = events[3];
      expect(championship.title).toBe("Swiss Parkour Championship");
      expect(championship.startAt).toEqual(
          dateStartToUtc(2025, 9, 13, STREEM_PARKOUR_DEFAULT_TIME_ZONE),
      );
      expect(championship.endAt).toEqual(
          dateEndToUtc(2025, 9, 14, STREEM_PARKOUR_DEFAULT_TIME_ZONE),
      );
    });

    it("honors sourceDefaultTimeZone override", () => {
      const html = homepageHtml(`
        <div class="event">
          <p class="text--note"><span class="text--strong">29. August 2026</span></p>
          <a href="https://www.swissparkourassociation.ch/swiss-jam-2026/" class="text--link">SwissJam</a>
          <p class="text--note">Universität Irchel, Zürich</p>
        </div>
      `);
      const [event] = parseStreemParkourHtml(html, {
        ...SOURCE,
        sourceDefaultTimeZone: "Europe/Berlin",
      });
      expect(event.timeZone).toBe("Europe/Berlin");
      expect(event.timeZoneSource).toBe(EVENT_TIME_ZONE_SOURCE_SOURCE_DEFAULT);
      expect(event.startAt).toEqual(dateStartToUtc(2026, 8, 29, "Europe/Berlin"));
    });

    it("ignores homepage teasers outside the dialog", () => {
      const html = homepageHtml(`
        <div class="event">
          <p class="text--note"><span class="text--strong">24. Oktober 2026</span></p>
          <a href="https://www.parkourluzern.ch/" class="text--link">Josi's Birthday Jam</a>
          <p class="text--note">Grandstandpark, Luzern</p>
        </div>
      `);
      const events = parseStreemParkourHtml(html, SOURCE);
      expect(events).toHaveLength(1);
      expect(events[0].title).toBe("Josi's Birthday Jam");
    });

    it("throws when the events dialog is missing", () => {
      expect(() => parseStreemParkourHtml("<html></html>", SOURCE))
          .toThrow(/events dialog/);
    });

    it("throws when no usable event cards exist", () => {
      expect(() => parseStreemParkourHtml(homepageHtml(`
        <div class="event">
          <p class="text--note"><span class="text--strong">soon</span></p>
          <a href="" class="text--link">Broken</a>
        </div>
      `), SOURCE)).toThrow(/no usable events/);
    });
  });
});
