import {readFile, readdir} from "node:fs/promises";
import path from "node:path";
import {resolveSpotCount} from "./citation";
import type {
  AboutIndex,
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
  };
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
export async function loadAboutIndex(): Promise<AboutIndex> {
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

export async function loadCountry(
  countryCode: string,
): Promise<CountrySnapshot | null> {
  const cc = countryCode.toLowerCase();
  if (useFixtures()) {
    try {
      return await readFixtureJson<CountrySnapshot>(
        `about-countries/${cc}.json`,
      );
    } catch {
      return null;
    }
  }
  const db = await getDb();
  const snap = await db
    .collection("snapshots")
    .doc("about")
    .collection("countries")
    .doc(cc)
    .get();
  if (!snap.exists) return null;
  const data = snap.data() as CountrySnapshot;
  return {
    ...data,
    cities: Array.isArray(data.cities) ? data.cities : [],
    spots: Array.isArray(data.spots) ? data.spots : [],
    events: Array.isArray(data.events) ? data.events : [],
  };
}

export async function loadCity(
  countryCode: string,
  citySlug: string,
): Promise<CitySnapshot | null> {
  const id = `${countryCode.toLowerCase()}_${citySlug}`;
  if (useFixtures()) {
    try {
      return await readFixtureJson<CitySnapshot>(`about-cities/${id}.json`);
    } catch {
      return null;
    }
  }
  const db = await getDb();
  const snap = await db
    .collection("snapshots")
    .doc("about")
    .collection("cities")
    .doc(id)
    .get();
  if (!snap.exists) return null;
  const data = snap.data() as CitySnapshot;
  return {
    ...data,
    spots: Array.isArray(data.spots) ? data.spots : [],
    events: Array.isArray(data.events) ? data.events : [],
  };
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
};

/** Countries and cities in this refresh, with full library totals. */
export async function loadCoverage(): Promise<{
  generatedAt: string;
  countries: CoverageCountry[];
}> {
  const index = await loadAboutIndex();
  const countries: CoverageCountry[] = [];
  for (const entry of index.countries) {
    if (typeof entry?.code !== "string" || entry.code.length !== 2) continue;
    const country = await loadCountry(entry.code);
    if (!country) continue;
    const cities = await loadCityRefs(country);
    if (cities.length === 0) continue;
    const fromCities = cities.reduce(
      (sum, city) => sum + (city.spotCount ?? 0),
      0,
    );
    countries.push({
      code: country.countryCode.toLowerCase(),
      cities,
      spotCount: resolveSpotCount(country.spotCount, fromCities),
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

/** City hubs that were actually written, including events-only cities. */
export async function loadCityRefs(
  country: CountrySnapshot,
): Promise<CityRef[]> {
  const kept: CityRef[] = [];
  for (const city of country.cities ?? []) {
    if (typeof city?.citySlug !== "string" || !city.citySlug) continue;
    const hub = await loadCity(country.countryCode, city.citySlug);
    if (!hub) continue;
    const listed = Array.isArray(hub.spots) ? hub.spots.length : 0;
    kept.push({
      ...city,
      spotCount: resolveSpotCount(hub.spotCount ?? city.spotCount, listed),
    });
  }
  return kept;
}

export async function listCityParams(): Promise<
  Array<{countryCode: string; city: string}>
> {
  const codes = await listCountryCodes();
  const out: Array<{countryCode: string; city: string}> = [];
  for (const code of codes) {
    const country = await loadCountry(code);
    if (!country) continue;
    const cities = await loadCityRefs(country);
    for (const city of cities) {
      out.push({countryCode: code, city: city.citySlug});
    }
  }
  return out;
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
