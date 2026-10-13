const {
  hashApiKey,
  generateCalendarToken,
} = require("../lib/api-helpers");
const {
  calendarFeedUrl,
  extractCalendarTokenFromPath,
  escapeIcsText,
  joinDescriptionBody,
  selectFeedEntries,
  buildIcsCalendar,
  INTERESTED_PREFIX,
  CHECK_IN_PREFIX,
  PLANNED_SESSION_PREFIX,
  MY_SESSIONS_URL,
  getOrCreateCalendarFeed,
  regenerateCalendarFeed,
  resolveUserIdFromCalendarToken,
  loadCheckInsForUser,
  loadTrainingPlansForUser,
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

describe("joinDescriptionBody", () => {
  it("joins non-empty parts with blank lines", () => {
    expect(joinDescriptionBody(["Status: Going", "", "Line two", null]))
        .toBe("Status: Going\n\nLine two");
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
        kind: "event",
        entry: {
          eventId: "evt1",
          status: "interested",
          event: {
            id: "evt1",
            title: "City Jam",
            description: "All levels welcome.",
            websiteUrl: "https://example.com/jam",
            startAt: new Date("2026-07-01T12:00:00Z"),
            endAt: new Date("2026-07-01T16:00:00Z"),
            isDateOnly: false,
            address: "Main Street 1",
            updatedAt: new Date("2026-06-01T00:00:00Z"),
          },
        },
      },
      {
        kind: "event",
        entry: {
          eventId: "evt2",
          status: "going",
          event: {
            id: "evt2",
            title: "Roof Session",
            startAt: new Date("2026-08-01T00:00:00Z"),
            isDateOnly: true,
          },
        },
      },
      {
        kind: "checkIn",
        checkIn: {
          id: "ci1",
          spotId: "spot-a",
          spotName: "Riverside Wall",
          checkedInAt: new Date("2026-09-01T08:00:00Z"),
          expectedEndAt: new Date("2026-09-01T10:00:00Z"),
          isPrivate: false,
          comment: "Morning flow",
        },
      },
      {
        kind: "trainingPlan",
        plan: {
          id: "plan1",
          spotId: "spot-b",
          spotName: "Station Park",
          plannedStartAt: new Date("2026-10-01T14:00:00Z"),
          plannedEndAt: new Date("2026-10-01T16:00:00Z"),
          isPrivate: true,
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
    expect(ics).toContain("DESCRIPTION:Status: Interested\\n\\nAll levels welcome.");
    const unfolded = ics.replace(/\r\n /g, "");
    expect(unfolded).toContain("Website: https://example.com/jam");
    expect(ics).toContain(`SUMMARY:${CHECK_IN_PREFIX}Riverside Wall`);
    expect(ics).toContain("URL:https://parkour.spot/spot/spot-a");
    expect(unfolded).toContain(`My sessions: ${MY_SESSIONS_URL}`);
    expect(ics).toContain("UID:checkin-ci1@parkour.spot");
    expect(ics).toContain(`SUMMARY:${PLANNED_SESSION_PREFIX}Station Park`);
    expect(ics).toContain("UID:plan-plan1@parkour.spot");
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

describe("loadCheckInsForUser / loadTrainingPlansForUser", () => {
  /**
   * Minimal query chain mock: records constraints and returns prepared docs.
   * @param {Array<{id: string, data: Object}>} docs
   * @return {{db: Object, lastQuery: Object}}
   */
  function mockQueryDb(docs) {
    const lastQuery = {wheres: [], orderBys: [], limit: null};
    const db = {
      collection() {
        const chain = {
          where(field, op, value) {
            lastQuery.wheres.push({field, op, value});
            return chain;
          },
          orderBy(field, direction) {
            lastQuery.orderBys.push({field, direction});
            return chain;
          },
          limit(n) {
            lastQuery.limit = n;
            return chain;
          },
          async get() {
            return {
              docs: docs.map((d) => ({
                id: d.id,
                data: () => d.data,
              })),
            };
          },
        };
        return chain;
      },
    };
    return {db, lastQuery};
  }

  it("includes historic check-ins (no end-time filter)", async () => {
    const pastEnd = new Date("2020-01-01T12:00:00Z");
    const pastStart = new Date("2020-01-01T10:00:00Z");
    const {db, lastQuery} = mockQueryDb([
      {
        id: "ci-old",
        data: {
          checkedInAt: pastStart,
          expectedEndAt: pastEnd,
          spotId: "s1",
        },
      },
    ]);
    const items = await loadCheckInsForUser(db, "user1");
    expect(lastQuery.wheres).toEqual([
      {field: "userId", op: "==", value: "user1"},
    ]);
    expect(lastQuery.orderBys).toEqual([
      {field: "checkedInAt", direction: "desc"},
    ]);
    expect(items).toHaveLength(1);
    expect(items[0].id).toBe("ci-old");
  });

  it("includes historic plans without plannedEndAt >= now", async () => {
    const pastEnd = new Date("2020-06-01T16:00:00Z");
    const pastStart = new Date("2020-06-01T14:00:00Z");
    const {db, lastQuery} = mockQueryDb([
      {
        id: "plan-old",
        data: {
          plannedStartAt: pastStart,
          plannedEndAt: pastEnd,
          spotId: "s2",
        },
      },
    ]);
    const items = await loadTrainingPlansForUser(db, "user1");
    expect(lastQuery.wheres).toEqual([
      {field: "userId", op: "==", value: "user1"},
    ]);
    expect(lastQuery.orderBys).toEqual([
      {field: "plannedEndAt", direction: "desc"},
    ]);
    expect(items).toHaveLength(1);
    expect(items[0].id).toBe("plan-old");
  });
});
