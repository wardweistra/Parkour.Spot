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

// eslint-disable-next-line @typescript-eslint/no-explicit-any
let adminDb: any = null;

async function getDb() {
  if (adminDb) return adminDb;
  const admin = await import("firebase-admin");
  if (!admin.apps.length) {
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
    return readFixtureJson<AboutIndex>("about-index.json");
  }
  const db = await getDb();
  const snap = await db.collection("snapshots").doc("about-index").get();
  if (!snap.exists) {
    return {
      generatedAt: new Date().toISOString(),
      countries: [],
      eventCount: 0,
    };
  }
  return snap.data() as AboutIndex;
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
  return snap.exists ? (snap.data() as CountrySnapshot) : null;
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
  return snap.exists ? (snap.data() as CitySnapshot) : null;
}

export async function loadEventsIndex(): Promise<EventsIndex> {
  if (useFixtures()) {
    return readFixtureJson<EventsIndex>("about-events-index.json");
  }
  const db = await getDb();
  const snap = await db.collection("snapshots").doc("about-events-index").get();
  if (!snap.exists) {
    return {generatedAt: new Date().toISOString(), events: []};
  }
  return snap.data() as EventsIndex;
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
  return index.countries.map((c) => c.code.toLowerCase());
}

export async function listCityParams(): Promise<
  Array<{countryCode: string; city: string}>
> {
  const codes = await listCountryCodes();
  const out: Array<{countryCode: string; city: string}> = [];
  for (const code of codes) {
    const country = await loadCountry(code);
    if (!country) continue;
    for (const city of country.cities) {
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
  return index.events.map((e) => e.slug);
}
