/* eslint-disable max-len */
const {
  isEmailCategoryEnabled,
  signUnsubscribeToken,
  verifyUnsubscribeParams,
  unsubscribeUrl,
  listUnsubscribeHeaders,
  setEmailCategory,
} = require("../lib/email-preferences");
const {buildYearReviewEmail, unsubscribePageHtml, EMAIL_STRINGS} = require("../lib/year-review-email");
const {sendBrevoEmail, BREVO_SEND_URL} = require("../lib/brevo");
const {
  createYearReviewCampaign,
  cancelCampaign,
  processDueCampaigns,
  isActiveInYear,
} = require("../lib/email-campaigns");

const SECRET = "test-secret";
const d = (iso) => new Date(iso);

describe("email preferences", () => {
  it("defaults newsletter on and honours an explicit choice", () => {
    expect(isEmailCategoryEnabled({}, "newsletter")).toBe(true);
    expect(isEmailCategoryEnabled(null, "newsletter")).toBe(true);
    expect(isEmailCategoryEnabled({emailPrefs: {newsletter: false}}, "newsletter")).toBe(false);
    expect(isEmailCategoryEnabled({emailPrefs: {newsletter: true}}, "newsletter")).toBe(true);
    expect(isEmailCategoryEnabled({}, "unknown")).toBe(false);
  });

  it("verifies its own unsubscribe links and rejects tampered ones", () => {
    const url = new URL(unsubscribeUrl("u1", "newsletter", SECRET));
    expect(url.origin + url.pathname).toBe("https://parkour.spot/email/unsubscribe");
    const params = Object.fromEntries(url.searchParams);
    expect(verifyUnsubscribeParams(params, SECRET)).toEqual({uid: "u1", category: "newsletter"});
    expect(verifyUnsubscribeParams({...params, u: "u2"}, SECRET)).toBeNull();
    expect(verifyUnsubscribeParams({...params, c: "other"}, SECRET)).toBeNull();
    expect(verifyUnsubscribeParams({...params, t: "x"}, SECRET)).toBeNull();
    expect(verifyUnsubscribeParams(params, "other-secret")).toBeNull();
    expect(verifyUnsubscribeParams({}, SECRET)).toBeNull();
    expect(signUnsubscribeToken("u1", "newsletter", SECRET)).toBe(params.t);
  });

  it("builds RFC 8058 one-click headers", () => {
    expect(listUnsubscribeHeaders("https://x/y")).toEqual({
      "List-Unsubscribe": "<https://x/y>",
      "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
    });
  });

  it("stores an opt-out on the user doc", async () => {
    const db = createStore({"users/u1": {email: "a@b.c"}});
    expect(await setEmailCategory(db, fakeFieldValue, "u1", "newsletter", false)).toBe(true);
    expect(db.read("users/u1").emailPrefs.newsletter).toBe(false);
    expect(db.read("users/u1").email).toBe("a@b.c");
    expect(await setEmailCategory(db, fakeFieldValue, "missing", "newsletter", false)).toBe(false);
  });
});

const reviewData = (overrides = {}) => ({
  userId: "u1",
  isPublicProfile: true,
  year: 2026,
  name: "Noor",
  username: "noor",
  counts: [{key: "spotsAdded", count: 4}, {key: "ratings", count: 2}],
  lead: {kind: "spotsAdded", count: 4},
  places: ["Utrecht"],
  frames: [],
  moreCount: 0,
  ...overrides,
});

describe("year review email", () => {
  const unsub = "https://parkour.spot/email/unsubscribe?u=u1&c=newsletter&t=abc";

  it("puts the sentence, counts, card and links in a public profile's email", () => {
    const email = buildYearReviewEmail(reviewData(), {locale: "en", unsubscribeUrl: unsub, now: d("2026-12-02"), cacheKey: "2026-12-02"});
    expect(email.subject).toBe("Your 2026 on Parkour·Spot");
    expect(email.html).toContain("4 spots");
    expect(email.html).toContain("https://parkour.spot/year/2026/@noor/square.jpg?locale=en&amp;v=2026-12-02");
    expect(email.html).toContain("https://parkour.spot/year/2026/@noor\"");
    expect(email.html).toContain(unsub.replace(/&/g, "&amp;"));
    expect(email.text).toContain("4 spots added");
    expect(email.text).toContain(`Unsubscribe from newsletter emails: ${unsub}`);
    expect(email.html).toContain("2026 so far");
  });

  it("gives a private profile its numbers without a card or public link", () => {
    const email = buildYearReviewEmail(reviewData({isPublicProfile: false, username: null}), {locale: "nl", unsubscribeUrl: unsub});
    expect(email.locale).toBe("nl");
    expect(email.html).not.toContain("square.jpg");
    expect(email.html).not.toContain("/year/2026/");
    expect(email.html).toContain(EMAIL_STRINGS.nl.privateNote);
    expect(email.html).toContain("https://parkour.spot/profile/settings");
  });

  it("escapes names and places", () => {
    const email = buildYearReviewEmail(reviewData({name: "<b>x</b>", places: ["A&B"]}), {locale: "en", unsubscribeUrl: unsub});
    expect(email.html).not.toContain("<b>x</b>");
    expect(email.html).toContain("&lt;b&gt;x&lt;/b&gt;");
    expect(email.html).toContain("A&amp;B");
  });

  it("has every string in every locale and falls back to English", () => {
    const keys = Object.keys(EMAIL_STRINGS.en);
    for (const [locale, strings] of Object.entries(EMAIL_STRINGS)) {
      expect(Object.keys(strings).sort()).toEqual([...keys].sort());
      const email = buildYearReviewEmail(reviewData(), {locale, unsubscribeUrl: unsub});
      expect(email.subject).not.toMatch(/\{|\}/);
      expect(email.html).not.toMatch(/\{(year|name|count)\}/);
    }
    expect(buildYearReviewEmail(reviewData(), {locale: "ko", unsubscribeUrl: unsub}).locale).toBe("en");
  });

  it("only unsubscribes from the page's POST form, never on GET", () => {
    const page = unsubscribePageHtml({locale: "de", state: "confirm", actionUrl: "/email/unsubscribe?u=1&t=2"});
    expect(page).toContain("<form method=\"post\" action=\"/email/unsubscribe?u=1&amp;t=2\">");
    expect(page).toContain(EMAIL_STRINGS.de.pageButton);
    expect(unsubscribePageHtml({locale: "en", state: "done"})).toContain(EMAIL_STRINGS.en.pageDone);
    expect(unsubscribePageHtml({locale: "en", state: "invalid"})).toContain(EMAIL_STRINGS.en.pageInvalid);
  });
});

describe("brevo client", () => {
  const message = {to: {email: "a@b.c", name: "A"}, subject: "S", html: "<p>h</p>", text: "h", headers: {"List-Unsubscribe": "<u>"}, tags: ["t"]};

  it("posts the message with the api key and returns the message id", async () => {
    const fetchImpl = jest.fn(async () => ({ok: true, status: 201, text: async () => "{\"messageId\":\"<m1>\"}"}));
    const result = await sendBrevoEmail({apiKey: "k", fetchImpl, isEmulator: false, ...message});
    expect(result).toEqual({messageId: "<m1>"});
    const [url, init] = fetchImpl.mock.calls[0];
    expect(url).toBe(BREVO_SEND_URL);
    expect(init.headers["api-key"]).toBe("k");
    const body = JSON.parse(init.body);
    expect(body).toMatchObject({to: [{email: "a@b.c", name: "A"}], subject: "S", htmlContent: "<p>h</p>", textContent: "h", headers: {"List-Unsubscribe": "<u>"}, tags: ["t"]});
    expect(body.sender).toEqual({name: "Parkour·Spot", email: "noreply@parkour.spot"});
    expect(body.replyTo).toEqual({name: "Parkour·Spot", email: "parkour.spot@wardweistra.nl"});
  });

  it("marks rate limits and server errors retryable, bad requests not", async () => {
    const respond = (status) => async () => ({ok: false, status, statusText: "x", text: async () => "{\"message\":\"nope\"}"});
    await expect(sendBrevoEmail({apiKey: "k", fetchImpl: respond(429), isEmulator: false, ...message})).rejects.toMatchObject({retryable: true, status: 429});
    await expect(sendBrevoEmail({apiKey: "k", fetchImpl: respond(503), isEmulator: false, ...message})).rejects.toMatchObject({retryable: true});
    await expect(sendBrevoEmail({apiKey: "k", fetchImpl: respond(400), isEmulator: false, ...message})).rejects.toMatchObject({retryable: false, message: "Brevo 400: nope"});
  });

  it("dry-runs in the emulator without a key and refuses in production", async () => {
    const log = jest.spyOn(console, "log").mockImplementation(() => {});
    await expect(sendBrevoEmail({apiKey: "", isEmulator: true, ...message})).resolves.toMatchObject({messageId: expect.stringMatching(/^dry-run:/)});
    log.mockRestore();
    await expect(sendBrevoEmail({apiKey: "", isEmulator: false, ...message})).rejects.toThrow("BREVO_API_KEY");
  });
});

describe("email campaigns", () => {
  const now = d("2026-12-01T09:00:00Z");

  /** Three active users (one opted out, one unverified), one inactive. */
  function seed() {
    return createStore({
      "users/a": {preferredLanguageCode: "nl", displayName: "Ann"},
      "users/b": {emailPrefs: {newsletter: false}},
      "users/c": {},
      "users/d": {},
      "publicProfiles/a": {username: "ann", displayName: "Ann", isPublicProfile: true},
      "userStats/a": {years: {"2026": {spotsAdded: 2}}},
      "userStats/b": {years: {"2026": {ratings: 1}}},
      "userStats/c": {years: {"2026": {checkIns: 3}}},
      "userStats/d": {years: {"2025": {spotsAdded: 9}, "2026": {spotsAdded: 0}}},
      "userStats/__anonymous__": {years: {"2026": {spotsAdded: 50}}},
      "spots/s1": {createdBy: "a", createdAt: d("2026-03-01"), name: "Plaza", city: "Utrecht", imageUrls: ["img"]},
    });
  }
  const authUsers = {
    a: {email: "ann@example.com", emailVerified: true, displayName: "Ann"},
    b: {email: "b@example.com", emailVerified: true},
    c: {email: "c@example.com", emailVerified: false},
  };
  const getAuthUser = async (uid) => {
    if (!authUsers[uid]) throw Object.assign(new Error("nope"), {code: "auth/user-not-found"});
    return authUsers[uid];
  };
  const run = (db, send, overrides = {}) => processDueCampaigns({
    db, FieldValue: fakeFieldValue, Timestamp: fakeTimestamp, send, getAuthUser, unsubscribeSecret: SECRET, now, ...overrides,
  });

  it("counts a year as active only with a non-zero count", () => {
    expect(isActiveInYear({years: {"2026": {ratings: 1}}}, 2026)).toBe(true);
    expect(isActiveInYear({years: {"2026": {ratings: 0}}}, 2026)).toBe(false);
    expect(isActiveInYear({}, 2026)).toBe(false);
  });

  it("queues everyone active that year and refuses a second campaign", async () => {
    const db = seed();
    const {campaignId, total} = await createYearReviewCampaign({db, FieldValue: fakeFieldValue, Timestamp: fakeTimestamp, year: 2026, sendAt: "2026-12-01T08:00:00Z", dailyLimit: 2, now});
    expect(total).toBe(3);
    expect(db.ids(`emailCampaigns/${campaignId}/recipients`).sort()).toEqual(["a", "b", "c"]);
    expect(db.read(`emailCampaigns/${campaignId}`)).toMatchObject({status: "queued", dailyLimit: 2, counts: {total: 3, pending: 3}});
    await expect(createYearReviewCampaign({db, FieldValue: fakeFieldValue, Timestamp: fakeTimestamp, year: 2026, now})).rejects.toThrow("already exists");
    await cancelCampaign(db, fakeFieldValue, campaignId);
    await expect(createYearReviewCampaign({db, FieldValue: fakeFieldValue, Timestamp: fakeTimestamp, year: 2026, now})).resolves.toMatchObject({total: 3});
  });

  it("waits for sendAt, then sends to opted-in verified users and skips the rest", async () => {
    const db = seed();
    const {campaignId} = await createYearReviewCampaign({db, FieldValue: fakeFieldValue, Timestamp: fakeTimestamp, year: 2026, sendAt: "2026-12-02T08:00:00Z", now});
    const send = jest.fn(async () => ({messageId: "m"}));

    await run(db, send);
    expect(send).not.toHaveBeenCalled();

    await run(db, send, {now: d("2026-12-02T09:00:00Z")});
    expect(send).toHaveBeenCalledTimes(1);
    const message = send.mock.calls[0][0];
    expect(message.to.email).toBe("ann@example.com");
    expect(message.subject).toBe("Jouw 2026 op Parkour·Spot");
    expect(message.headers["List-Unsubscribe-Post"]).toBe("List-Unsubscribe=One-Click");
    expect(message.tags).toEqual(["year-review-2026"]);

    const r = (uid) => db.read(`emailCampaigns/${campaignId}/recipients/${uid}`);
    expect(r("a")).toMatchObject({status: "sent", messageId: "m", locale: "nl"});
    expect(r("b")).toMatchObject({status: "skipped", reason: "opted-out"});
    expect(r("c")).toMatchObject({status: "skipped", reason: "unverified"});
    expect(db.read(`emailCampaigns/${campaignId}`).counts).toMatchObject({pending: 0, sent: 1, skipped: 2});
    expect(db.read("emailSendCounters/2026-12-02").sent).toBe(1);

    await run(db, send, {now: d("2026-12-02T09:10:00Z")});
    expect(db.read(`emailCampaigns/${campaignId}`).status).toBe("done");
    expect(send).toHaveBeenCalledTimes(1);
  });

  it("re-checks the opt-out at send time", async () => {
    const db = seed();
    await createYearReviewCampaign({db, FieldValue: fakeFieldValue, Timestamp: fakeTimestamp, year: 2026, now});
    db.write("users/a", {emailPrefs: {newsletter: false}});
    const send = jest.fn(async () => ({messageId: "m"}));
    await run(db, send);
    expect(send).not.toHaveBeenCalled();
  });

  it("stops at the daily limit and continues the next day", async () => {
    const db = seed();
    authUsers.c.emailVerified = true;
    try {
      const {campaignId} = await createYearReviewCampaign({db, FieldValue: fakeFieldValue, Timestamp: fakeTimestamp, year: 2026, dailyLimit: 1, now});
      const send = jest.fn(async () => ({messageId: "m"}));
      await run(db, send);
      await run(db, send, {now: d("2026-12-01T09:10:00Z")});
      expect(send).toHaveBeenCalledTimes(1);
      await run(db, send, {now: d("2026-12-02T00:05:00Z")});
      expect(send).toHaveBeenCalledTimes(2);
      expect(db.read(`emailCampaigns/${campaignId}`).counts).toMatchObject({sent: 2, skipped: 1, pending: 0});
    } finally {
      authUsers.c.emailVerified = false;
    }
  });

  it("retries rate-limited sends and gives up on bad requests", async () => {
    const db = seed();
    const {campaignId} = await createYearReviewCampaign({db, FieldValue: fakeFieldValue, Timestamp: fakeTimestamp, year: 2026, now});
    const error = jest.spyOn(console, "error").mockImplementation(() => {});
    await run(db, async () => {
      throw Object.assign(new Error("slow down"), {retryable: true});
    });
    expect(db.read(`emailCampaigns/${campaignId}/recipients/a`)).toMatchObject({status: "pending", attempts: 1});
    await run(db, async () => {
      throw Object.assign(new Error("bad"), {retryable: false});
    });
    expect(db.read(`emailCampaigns/${campaignId}/recipients/a`)).toMatchObject({status: "failed", reason: "bad"});
    error.mockRestore();
  });

  it("sends nothing once cancelled", async () => {
    const db = seed();
    const {campaignId} = await createYearReviewCampaign({db, FieldValue: fakeFieldValue, Timestamp: fakeTimestamp, year: 2026, now});
    await cancelCampaign(db, fakeFieldValue, campaignId);
    const send = jest.fn();
    await run(db, send);
    expect(send).not.toHaveBeenCalled();
    await expect(cancelCampaign(db, fakeFieldValue, campaignId)).rejects.toThrow("already cancelled");
  });
});

// ---------------------------------------------------------------------------
// In-memory Firestore: enough of the Admin SDK for these modules.
// ---------------------------------------------------------------------------

const fakeFieldValue = {
  serverTimestamp: () => ({__op: "ts"}),
  increment: (n) => ({__op: "inc", n}),
  delete: () => ({__op: "del"}),
};
const fakeTimestamp = {fromDate: (date) => date};

/**
 * @param {Object<string, Object>} initial path → data
 * @return {Object}
 */
function createStore(initial = {}) {
  const store = new Map(Object.entries(initial).map(([k, v]) => [k, clone(v)]));
  let autoId = 0;

  const apply = (target, key, value) => {
    if (value && value.__op === "ts") target[key] = new Date();
    else if (value && value.__op === "inc") target[key] = (Number(target[key]) || 0) + value.n;
    else if (value && value.__op === "del") delete target[key];
    else target[key] = value;
  };
  const merge = (target, data) => {
    for (const [key, value] of Object.entries(data)) {
      if (value && typeof value === "object" && !value.__op && !(value instanceof Date) && !Array.isArray(value)) {
        target[key] = target[key] && typeof target[key] === "object" ? target[key] : {};
        merge(target[key], value);
      } else {
        apply(target, key, value);
      }
    }
  };
  const setDoc = (path, data, options = {}) => {
    const target = options.merge && store.has(path) ? store.get(path) : {};
    merge(target, data);
    store.set(path, target);
  };
  const updateDoc = (path, data) => {
    if (!store.has(path)) throw new Error(`No document ${path}`);
    const target = store.get(path);
    for (const [key, value] of Object.entries(data)) {
      const parts = key.split(".");
      let node = target;
      for (const part of parts.slice(0, -1)) {
        node[part] = node[part] && typeof node[part] === "object" ? node[part] : {};
        node = node[part];
      }
      apply(node, parts[parts.length - 1], value);
    }
  };
  const snapshot = (path) => ({
    id: path.split("/").pop(),
    ref: docRef(path),
    exists: store.has(path),
    data: () => (store.has(path) ? clone(store.get(path)) : undefined),
  });
  const docRef = (path) => ({
    id: path.split("/").pop(),
    path,
    _path: path,
    get: async () => snapshot(path),
    set: async (data, options) => setDoc(path, data, options),
    update: async (data) => updateDoc(path, data),
    collection: (name) => collectionRef(`${path}/${name}`),
  });
  const cmp = (v) => (v instanceof Date ? v.getTime() : v);
  const query = (path, filters = [], order = null, limit = null) => ({
    where: (f, op, v) => query(path, [...filters, [f, op, v]], order, limit),
    orderBy: (f) => query(path, filters, f, limit),
    select: () => query(path, filters, order, limit),
    limit: (n) => query(path, filters, order, n),
    async get() {
      const depth = path.split("/").length + 1;
      let rows = [...store.keys()]
          .filter((key) => key.startsWith(`${path}/`) && key.split("/").length === depth)
          .filter((key) => filters.every(([f, op, v]) => {
            const a = cmp(store.get(key)[f]);
            if (op === "==") return a === cmp(v);
            if (op === "in") return v.includes(a);
            if (a === undefined) return false;
            if (op === ">=") return a >= cmp(v);
            if (op === "<=") return a <= cmp(v);
            return a < cmp(v);
          }));
      if (order) rows.sort((x, y) => cmp(store.get(x)[order]) - cmp(store.get(y)[order]));
      if (limit) rows = rows.slice(0, limit);
      return {empty: rows.length === 0, size: rows.length, docs: rows.map(snapshot)};
    },
  });
  const collectionRef = (path) => ({
    ...query(path),
    doc: (id) => docRef(`${path}/${id || `auto${++autoId}`}`),
  });
  const batch = () => {
    const ops = [];
    return {
      set: (ref, data, options) => ops.push(() => setDoc(ref._path, data, options)),
      update: (ref, data) => ops.push(() => updateDoc(ref._path, data)),
      commit: async () => ops.forEach((op) => op()),
    };
  };
  return {
    collection: collectionRef,
    batch,
    runTransaction: async (fn) => {
      const tx = batch();
      const result = await fn({get: (ref) => ref.get(), set: tx.set, update: tx.update});
      await tx.commit();
      return result;
    },
    getAll: async (...refs) => refs.filter((ref) => ref && ref._path).map((ref) => snapshot(ref._path)),
    read: (path) => store.get(path),
    write: (path, data) => setDoc(path, data, {merge: true}),
    ids: (path) => [...store.keys()]
        .filter((key) => key.startsWith(`${path}/`) && key.split("/").length === path.split("/").length + 1)
        .map((key) => key.split("/").pop()),
  };
}

/**
 * @param {unknown} value
 * @return {unknown}
 */
function clone(value) {
  if (value instanceof Date) return new Date(value.getTime());
  if (Array.isArray(value)) return value.map(clone);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, clone(v)]));
  }
  return value;
}
