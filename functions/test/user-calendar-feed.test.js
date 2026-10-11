const {
  hashApiKey,
  generateCalendarToken,
} = require("../lib/api-helpers");
const {
  calendarFeedUrl,
  extractCalendarTokenFromPath,
  escapeIcsText,
  selectFeedEntries,
  buildIcsCalendar,
  INTERESTED_PREFIX,
  getOrCreateCalendarFeed,
  regenerateCalendarFeed,
  resolveUserIdFromCalendarToken,
} = require("../lib/user-calendar-feed");

describe("generateCalendarToken", () => {
  it("uses psc_ prefix and 32 hex chars", () => {
    const token = generateCalendarToken();
    expect(token).toMatch(/^psc_[a-f0-9]{32}$/);
  });
});

describe("extractCalendarTokenFromPath", () => {
  it("parses /calendar/{token}.ics", () => {
    expect(extractCalendarTokenFromPath("/calendar/psc_abc.ics"))
        .toBe("psc_abc");
  });
  it("parses path without .ics suffix", () => {
    expect(extractCalendarTokenFromPath("/calendar/psc_abc"))
        .toBe("psc_abc");
  });
  it("returns null for unrelated paths", () => {
    expect(extractCalendarTokenFromPath("/event/xyz")).toBeNull();
  });
});

describe("calendarFeedUrl", () => {
  it("builds parkour.spot calendar URL", () => {
    expect(calendarFeedUrl("psc_test")).toBe(
        "https://parkour.spot/calendar/psc_test.ics",
    );
  });
});

describe("escapeIcsText", () => {
  it("escapes backslash comma semicolon and newlines", () => {
    expect(escapeIcsText("a;b,c\\d\ne")).toBe("a\\;b\\,c\\\\d\\ne");
  });
});

describe("selectFeedEntries", () => {
  it("remaps duplicates to native and lets going win", () => {
    const eventsById = {
      dup1: {
        id: "dup1",
        title: "Dup",
        duplicateOf: "native1",
        startAt: new Date("2026-06-01T10:00:00Z"),
      },
      native1: {
        id: "native1",
        title: "Native Jam",
        startAt: new Date("2026-06-01T10:00:00Z"),
      },
    };
    const entries = selectFeedEntries(
        [
          {eventId: "dup1", status: "interested"},
          {eventId: "native1", status: "going"},
        ],
        eventsById,
    );
    expect(entries).toHaveLength(1);
    expect(entries[0].eventId).toBe("native1");
    expect(entries[0].status).toBe("going");
    expect(entries[0].event.title).toBe("Native Jam");
  });
});

describe("buildIcsCalendar", () => {
  it("labels interested titles and includes event URL", () => {
    const ics = buildIcsCalendar([
      {
        eventId: "evt1",
        status: "interested",
        event: {
          id: "evt1",
          title: "City Jam",
          startAt: new Date("2026-07-01T12:00:00Z"),
          endAt: new Date("2026-07-01T16:00:00Z"),
          isDateOnly: false,
          address: "Main Street 1",
          updatedAt: new Date("2026-06-01T00:00:00Z"),
        },
      },
      {
        eventId: "evt2",
        status: "going",
        event: {
          id: "evt2",
          title: "Roof Session",
          startAt: new Date("2026-08-01T00:00:00Z"),
          isDateOnly: true,
        },
      },
    ]);

    expect(ics).toContain("BEGIN:VCALENDAR");
    expect(ics).toContain(`SUMMARY:${INTERESTED_PREFIX}City Jam`);
    expect(ics).toContain("SUMMARY:Roof Session");
    expect(ics).not.toContain(`${INTERESTED_PREFIX}Roof Session`);
    expect(ics).toContain("URL:https://parkour.spot/event/evt1");
    expect(ics).toContain("URL:https://parkour.spot/event/evt2");
    expect(ics).toContain("DTSTART:20260701T120000Z");
    expect(ics).toContain("DTSTART;VALUE=DATE:20260801");
    expect(ics).toContain("LOCATION:Main Street 1");
    expect(ics).toContain("UID:evt1@parkour.spot");
  });
});

describe("calendar feed token storage", () => {
  function mockDb() {
    const docs = new Map();
    return {
      docs,
      db: {
        collection(name) {
          return {
            doc(id) {
              const key = `${name}/${id}`;
              return {
                id,
                _collection: name,
                async get() {
                  const data = docs.get(key);
                  return {
                    exists: data !== undefined,
                    data: () => data,
                  };
                },
                async set(data, options) {
                  if (options && options.merge && docs.has(key)) {
                    docs.set(key, {...docs.get(key), ...data});
                  } else {
                    docs.set(key, {...data});
                  }
                },
              };
            },
          };
        },
        batch() {
          const ops = [];
          return {
            set(ref, data, options) {
              ops.push({type: "set", ref, data, options});
            },
            delete(ref) {
              ops.push({type: "delete", ref});
            },
            async commit() {
              for (const op of ops) {
                const key = `${op.ref._collection}/${op.ref.id}`;
                if (op.type === "delete") {
                  docs.delete(key);
                } else if (op.options && op.options.merge && docs.has(key)) {
                  docs.set(key, {...docs.get(key), ...op.data});
                } else {
                  docs.set(key, {...op.data});
                }
              }
            },
          };
        },
      },
    };
  }

  const FieldValue = {
    serverTimestamp: () => "SERVER_TS",
  };

  it("getOrCreate creates then returns existing", async () => {
    const {db, docs} = mockDb();
    const first = await getOrCreateCalendarFeed(db, FieldValue, "user1");
    expect(first.created).toBe(true);
    expect(first.token).toMatch(/^psc_/);
    expect(first.url).toBe(calendarFeedUrl(first.token));
    expect(docs.get(`calendarFeeds/user1`).token).toBe(first.token);
    expect(docs.get(`calendarFeedByToken/${hashApiKey(first.token)}`).userId)
        .toBe("user1");

    const second = await getOrCreateCalendarFeed(db, FieldValue, "user1");
    expect(second.created).toBe(false);
    expect(second.token).toBe(first.token);
  });

  it("regenerate invalidates the previous token", async () => {
    const {db, docs} = mockDb();
    const first = await getOrCreateCalendarFeed(db, FieldValue, "user1");
    const oldHash = hashApiKey(first.token);
    const next = await regenerateCalendarFeed(db, FieldValue, "user1");
    expect(next.token).not.toBe(first.token);
    expect(docs.has(`calendarFeedByToken/${oldHash}`)).toBe(false);
    expect(docs.get(`calendarFeedByToken/${hashApiKey(next.token)}`).userId)
        .toBe("user1");
    expect(await resolveUserIdFromCalendarToken(db, first.token)).toBeNull();
    expect(await resolveUserIdFromCalendarToken(db, next.token)).toBe("user1");
  });
});
