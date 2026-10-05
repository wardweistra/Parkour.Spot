import {readFile, readdir} from "node:fs/promises";
import path from "node:path";
import {fileURLToPath} from "node:url";
import type {
  AboutIndex,
  CitySnapshot,
  CountrySnapshot,
  EventDetail,
  EventsIndex,
} from "./types";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURES_ROOT = path.resolve(__dirname, "../../fixtures");

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
 * firebase-admin is CommonJS; under Astro/Vite ESM the namespace may land on
 * `.default`. Unwrap that before reading `.apps` / calling `.initializeApp`.
 */
async function getDb() {
  if (adminDb) return adminDb;
  const mod = await import("firebase-admin");
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const admin = ((mod as any).default ?? mod) as typeof import("firebase-admin");
  const apps = admin.apps ?? [];
  if (apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
    });
  }
  adminDb = admin.firestore();
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

export async function listCountryCodes(): Promise<string[]> {
  const index = await loadAboutIndex();
  return (index.countries ?? [])
    .filter((c) => typeof c?.code === "string" && c.code.length === 2)
    .map((c) => c.code.toLowerCase());
}

export async function listCityParams(): Promise<
  Array<{countryCode: string; city: string}>
> {
  const codes = await listCountryCodes();
  const out: Array<{countryCode: string; city: string}> = [];
  for (const code of codes) {
    const country = await loadCountry(code);
    if (!country?.cities?.length) continue;
    for (const city of country.cities) {
      if (typeof city?.citySlug !== "string" || !city.citySlug) continue;
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
