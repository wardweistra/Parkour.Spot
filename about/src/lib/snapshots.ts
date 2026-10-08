import {readFile, readdir} from "node:fs/promises";
import path from "node:path";
import {resolveSpotCount} from "./citation";
import type {
  AboutIndex,
  AboutStats,
  CityRef,
  CitySnapshot,
  CountrySnapshot,
  EventDetail,
  EventsIndex,
} from "./types";

// Astro 7 bundles this module into dist/.prerender/chunks before getStaticPaths
// runs, so import.meta.url points at that chunk rather than src/lib. CI and
// the about package scripts run with the working directory set to about/.
const FIXTURES_ROOT = path.resolve(process.cwd(), "fixtures");

function useFixtures(): boolean {
  return (
    process.env.ABOUT_USE_FIXTURES === "1" ||
    process.env.ABOUT_USE_FIXTURES === "true" ||
    !process.env.GOOGLE_APPLICATION_CREDENTIALS
  );
}

async function readFixtureJson<T>(relativePath: string): Promise<T> {
  const full = path.join(FIXTURES_ROOT, relativePath);
  const raw = await readFile(full, "utf8");
  return JSON.parse(raw) as T;
}

function emptyAboutIndex(): AboutIndex {
  return {
    generatedAt: new Date().toISOString(),
    countries: [],
    eventCount: 0,
    stats: {},
  };
}

/** Keep finite, non-negative numbers and the timestamp; drop everything else. */
function normalizeStats(raw: unknown): AboutStats {
  if (!raw || typeof raw !== "object") return {};
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(raw as Record<string, unknown>)) {
    if (key === "generatedAt") {
      if (typeof value === "string") out.generatedAt = value;
      continue;
    }
    if (typeof value === "number" && Number.isFinite(value) && value >= 0) {
      out[key] = value;
    }
  }
  return out as AboutStats;
}

function emptyEventsIndex(): EventsIndex {
  return {generatedAt: new Date().toISOString(), events: []};
}

function normalizeAboutIndex(data: Partial<AboutIndex> | undefined): AboutIndex {
  if (!data) return emptyAboutIndex();
  return {
    generatedAt:
      typeof data.generatedAt === "string"
        ? data.generatedAt
        : new Date().toISOString(),
    countries: Array.isArray(data.countries) ? data.countries : [],
    eventCount: typeof data.eventCount === "number" ? data.eventCount : 0,
    stats: normalizeStats(data.stats),
  };
}

function normalizeEventsIndex(
  data: Partial<EventsIndex> | undefined,
): EventsIndex {
  if (!data) return emptyEventsIndex();
  return {
    generatedAt:
      typeof data.generatedAt === "string"
        ? data.generatedAt
        : new Date().toISOString(),
    events: Array.isArray(data.events) ? data.events : [],
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let adminDb: any = null;

/**
 * firebase-admin v14 is modular and CommonJS. Under Astro/Vite ESM the
 * module namespace may land on `.default`, so unwrap before use.
 */
function unwrapModule<T>(mod: T): T {
  const withDefault = mod as T & {default?: T};
  return withDefault.default ?? mod;
}

async function getDb() {
  if (adminDb) return adminDb;
  const appMod = unwrapModule(await import("firebase-admin/app"));
  const firestoreMod = unwrapModule(await import("firebase-admin/firestore"));
  if (appMod.getApps().length === 0) {
    appMod.initializeApp({
      credential: appMod.applicationDefault(),
    });
  }
  adminDb = firestoreMod.getFirestore();
  return adminDb;
}

/**
 * Live layout under Firestore:
 * - snapshots/about-index
 * - snapshots/about-events-index
 * - snapshots/about/countries/{cc}
 * - snapshots/about/cities/{cc}_{citySlug}
 * - snapshots/about/events/{slug}
 */
let aboutIndexPromise: Promise<AboutIndex> | null = null;

export function loadAboutIndex(): Promise<AboutIndex> {
  aboutIndexPromise ??= fetchAboutIndex();
  return aboutIndexPromise;
}

async function fetchAboutIndex(): Promise<AboutIndex> {
  if (useFixtures()) {
    return normalizeAboutIndex(
      await readFixtureJson<AboutIndex>("about-index.json"),
    );
  }
  const db = await getDb();
  const snap = await db.collection("snapshots").doc("about-index").get();
  if (!snap.exists) return emptyAboutIndex();
  return normalizeAboutIndex(snap.data() as Partial<AboutIndex>);
}

/**
 * Site-wide totals. Snapshots written before `stats` existed fall back to
 * the per-country index, which only counts spots with a city.
 */
export async function loadStats(): Promise<AboutStats> {
  const index = await loadAboutIndex();
  const stats: AboutStats = {...index.stats};
  if (stats.spotCount == null && index.countries.length > 0) {
    stats.spotCount = index.countries.reduce(
      (sum, country) => sum + (Number(country.spotCount) || 0),
      0,
    );
    stats.countryCount = index.countries.filter(
      (country) => (Number(country.spotCount) || 0) > 0,
    ).length;
  }
  stats.upcomingEventCount ??= index.eventCount;
  stats.generatedAt ??= index.generatedAt;
  return stats;
}

// Firestore caps getAll batches well above this; smaller chunks keep each RPC
// response modest.
const GET_ALL_CHUNK = 300;

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function getAllDocs(refs: any[], fieldMask?: string[]): Promise<any[]> {
  if (refs.length === 0) return [];
  const db = await getDb();
  const chunks = [];
  for (let i = 0; i < refs.length; i += GET_ALL_CHUNK) {
    const slice = refs.slice(i, i + GET_ALL_CHUNK);
    chunks.push(fieldMask ? db.getAll(...slice, {fieldMask}) : db.getAll(...slice));
  }
  return (await Promise.all(chunks)).flat();
}

async function countryRef(cc: string) {
  const db = await getDb();
  return db.collection("snapshots").doc("about").collection("countries").doc(cc);
}

async function cityRef(id: string) {
  const db = await getDb();
  return db.collection("snapshots").doc("about").collection("cities").doc(id);
}

function normalizeCountry(data: CountrySnapshot): CountrySnapshot {
  return {
    ...data,
    cities: Array.isArray(data.cities) ? data.cities : [],
    spots: Array.isArray(data.spots) ? data.spots : [],
    events: Array.isArray(data.events) ? data.events : [],
  };
}

function normalizeCity(data: CitySnapshot): CitySnapshot {
  return {
    ...data,
    spots: Array.isArray(data.spots) ? data.spots : [],
    events: Array.isArray(data.events) ? data.events : [],
  };
}

const countryCache = new Map<string, Promise<CountrySnapshot | null>>();
const cityCache = new Map<string, Promise<CitySnapshot | null>>();

export function loadCountry(
  countryCode: string,
): Promise<CountrySnapshot | null> {
  const cc = countryCode.toLowerCase();
  let pending = countryCache.get(cc);
  if (!pending) {
    pending = fetchCountry(cc);
    countryCache.set(cc, pending);
  }
  return pending;
}

async function fetchCountry(cc: string): Promise<CountrySnapshot | null> {
  if (useFixtures()) {
    try {
      return normalizeCountry(
        await readFixtureJson<CountrySnapshot>(`about-countries/${cc}.json`),
      );
    } catch {
      return null;
    }
  }
  const snap = await (await countryRef(cc)).get();
  return snap.exists ? normalizeCountry(snap.data() as CountrySnapshot) : null;
}

/** Countries in input order, read in batches and cached for later lookups. */
async function loadCountries(
  codes: string[],
): Promise<Array<CountrySnapshot | null>> {
  const wanted = codes.map((code) => code.toLowerCase());
  const missing = [...new Set(wanted)].filter((cc) => !countryCache.has(cc));
  if (missing.length > 0 && !useFixtures()) {
    const batch = getAllDocs(await Promise.all(missing.map(countryRef)));
    missing.forEach((cc, i) => {
      countryCache.set(
        cc,
        batch.then((snaps) =>
          snaps[i].exists
            ? normalizeCountry(snaps[i].data() as CountrySnapshot)
            : null,
        ),
      );
    });
  }
  return Promise.all(wanted.map(loadCountry));
}

export function loadCity(
  countryCode: string,
  citySlug: string,
): Promise<CitySnapshot | null> {
  const id = `${countryCode.toLowerCase()}_${citySlug}`;
  let pending = cityCache.get(id);
  if (!pending) {
    pending = fetchCity(id);
    cityCache.set(id, pending);
  }
  return pending;
}

async function fetchCity(id: string): Promise<CitySnapshot | null> {
  if (useFixtures()) {
    try {
      return normalizeCity(
        await readFixtureJson<CitySnapshot>(`about-cities/${id}.json`),
      );
    } catch {
      return null;
    }
  }
  const snap = await (await cityRef(id)).get();
  return snap.exists ? normalizeCity(snap.data() as CitySnapshot) : null;
}

export async function loadEventsIndex(): Promise<EventsIndex> {
  if (useFixtures()) {
    return normalizeEventsIndex(
      await readFixtureJson<EventsIndex>("about-events-index.json"),
    );
  }
  const db = await getDb();
  const snap = await db.collection("snapshots").doc("about-events-index").get();
  if (!snap.exists) return emptyEventsIndex();
  return normalizeEventsIndex(snap.data() as Partial<EventsIndex>);
}

export async function loadEvent(slug: string): Promise<EventDetail | null> {
  if (useFixtures()) {
    try {
      return await readFixtureJson<EventDetail>(`about-events/${slug}.json`);
    } catch {
      return null;
    }
  }
  const db = await getDb();
  const snap = await db
    .collection("snapshots")
    .doc("about")
    .collection("events")
    .doc(slug)
    .get();
  return snap.exists ? (snap.data() as EventDetail) : null;
}

export type CoverageCountry = {
  code: string;
  cities: CityRef[];
  spotCount: number;
  eventCount: number;
};

type Coverage = {generatedAt: string; countries: CoverageCountry[]};
let coveragePromise: Promise<Coverage> | null = null;

/** Countries and cities in this refresh, with full library totals. */
export function loadCoverage(): Promise<Coverage> {
  coveragePromise ??= fetchCoverage();
  return coveragePromise;
}

async function fetchCoverage(): Promise<Coverage> {
  const index = await loadAboutIndex();
  const codes = index.countries
    .map((entry) => entry?.code)
    .filter((code): code is string => typeof code === "string" && code.length === 2);
  const loaded = await loadCountries(codes);
  const refs = await Promise.all(
    loaded.map((country) => (country ? loadCityRefs(country) : [])),
  );
  const countries: CoverageCountry[] = [];
  for (const [i, country] of loaded.entries()) {
    if (!country) continue;
    const cities = refs[i];
    if (cities.length === 0) continue;
    const fromCities = cities.reduce(
      (sum, city) => sum + (city.spotCount ?? 0),
      0,
    );
    countries.push({
      code: country.countryCode.toLowerCase(),
      cities,
      spotCount: resolveSpotCount(country.spotCount, fromCities),
      eventCount: country.events.length,
    });
  }
  return {generatedAt: index.generatedAt, countries};
}

export async function listCountryCodes(): Promise<string[]> {
  const index = await loadAboutIndex();
  return (index.countries ?? [])
    .filter((c) => typeof c?.code === "string" && c.code.length === 2)
    .map((c) => c.code.toLowerCase());
}

const cityRefsCache = new Map<string, Promise<CityRef[]>>();

/** City hubs that were actually written, including events-only cities. */
export function loadCityRefs(country: CountrySnapshot): Promise<CityRef[]> {
  const cc = country.countryCode.toLowerCase();
  let pending = cityRefsCache.get(cc);
  if (!pending) {
    pending = fetchCityRefs(country);
    cityRefsCache.set(cc, pending);
  }
  return pending;
}

async function fetchCityRefs(country: CountrySnapshot): Promise<CityRef[]> {
  const cc = country.countryCode.toLowerCase();
  const cities = (country.cities ?? []).filter(
    (city) => typeof city?.citySlug === "string" && city.citySlug.length > 0,
  );
  if (useFixtures()) {
    const hubs = await Promise.all(
      cities.map((city) => loadCity(cc, city.citySlug)),
    );
    return cities.flatMap((city, i) => {
      const hub = hubs[i];
      if (!hub) return [];
      return [
        {
          ...city,
          spotCount: resolveSpotCount(
            hub.spotCount ?? city.spotCount,
            hub.spots.length,
          ),
        },
      ];
    });
  }

  // Only existence and the stored total are needed here; full hub documents
  // carry spot lists, so read just `spotCount` and fall back when it is unset.
  const refs = await Promise.all(
    cities.map((city) => cityRef(`${cc}_${city.citySlug}`)),
  );
  const snaps = await getAllDocs(refs, ["spotCount"]);
  const kept = await Promise.all(
    cities.map(async (city, i): Promise<CityRef | null> => {
      if (!snaps[i].exists) return null;
      const stored = Number(snaps[i].get("spotCount"));
      if (Number.isFinite(stored)) {
        return {...city, spotCount: resolveSpotCount(stored, 0)};
      }
      const hub = await loadCity(cc, city.citySlug);
      if (!hub) return null;
      return {
        ...city,
        spotCount: resolveSpotCount(city.spotCount, hub.spots.length),
      };
    }),
  );
  return kept.filter((city): city is CityRef => city !== null);
}

type CityParam = {countryCode: string; city: string};
let cityParamsPromise: Promise<CityParam[]> | null = null;

export function listCityParams(): Promise<CityParam[]> {
  cityParamsPromise ??= fetchCityParams();
  return cityParamsPromise;
}

async function fetchCityParams(): Promise<CityParam[]> {
  const codes = await listCountryCodes();
  const loaded = await loadCountries(codes);
  const refs = await Promise.all(
    loaded.map((country) => (country ? loadCityRefs(country) : [])),
  );
  return codes.flatMap((code, i) =>
    refs[i].map((city) => ({countryCode: code, city: city.citySlug})),
  );
}

export async function listEventSlugs(): Promise<string[]> {
  if (useFixtures()) {
    try {
      const files = await readdir(path.join(FIXTURES_ROOT, "about-events"));
      return files
        .filter((f) => f.endsWith(".json"))
        .map((f) => f.replace(/\.json$/, ""));
    } catch {
      return [];
    }
  }
  const index = await loadEventsIndex();
  return (index.events ?? [])
    .filter((e) => typeof e?.slug === "string" && e.slug.length > 0)
    .map((e) => e.slug);
}
