import {SITE_NAME} from "./brand";
import type {AboutStats} from "./types";

/**
 * Quotable facts for about.parkour.spot.
 * Counts are every public spot. Pages show a short sample in Explore order.
 */
export const APP_DEFINITION =
  `${SITE_NAME} is a free, open source community app for finding the best parkour spots, events, and communities worldwide, whether around the corner or on your next trip. Explore it without an account.`;

export const MISSION =
  `${SITE_NAME} collects, preserves, and shares the world's parkour spots so the community's knowledge stays alive and open to everyone, long after any single app.`;

/** Activity figures below this are left out rather than shown as a weak number. */
export const ACTIVITY_FLOOR = 10;

function present(n: number | undefined): n is number {
  return typeof n === "number" && Number.isFinite(n) && n > 0;
}

function activity(n: number | undefined): n is number {
  return present(n) && n >= ACTIVITY_FLOOR;
}

/** Share of public spots with at least one photo, as a whole percent. */
export function photoSharePercent(stats: AboutStats): number | null {
  if (!present(stats.spotCount) || !present(stats.spotsWithPhotosCount)) {
    return null;
  }
  return Math.round((stats.spotsWithPhotosCount / stats.spotCount) * 100);
}

export interface StatFact {
  id: string;
  value: string;
  label: string;
}

/** Library and reach figures for the stats band and llms.txt. */
export function libraryFacts(stats: AboutStats): StatFact[] {
  const facts: StatFact[] = [];
  if (present(stats.spotCount)) {
    facts.push({id: "spots", value: formatCount(stats.spotCount), label: "parkour spots"});
  }
  if (present(stats.countryCount)) {
    facts.push({id: "countries", value: formatCount(stats.countryCount), label: "countries"});
  }
  if (present(stats.spotSourceCount)) {
    facts.push({
      id: "sources",
      value: formatCount(stats.spotSourceCount),
      label: "community spot sources",
    });
  }
  if (present(stats.upcomingEventCount)) {
    facts.push({
      id: "events",
      value: formatCount(stats.upcomingEventCount),
      label: stats.upcomingEventCount === 1 ? "upcoming event" : "upcoming events",
    });
  }
  if (activity(stats.monthlyActiveUsers)) {
    facts.push({
      id: "mau",
      value: formatCount(stats.monthlyActiveUsers),
      label: "monthly active logged-in users",
    });
  }
  const share = photoSharePercent(stats);
  if (share != null && share > 0) {
    facts.push({id: "photos", value: `${share}%`, label: "of spots with photos"});
  }
  return facts;
}

/** Recent community activity, each figure only when it clears the floor. */
export function activityFacts(stats: AboutStats): StatFact[] {
  const facts: StatFact[] = [];
  if (activity(stats.checkIns30d)) {
    facts.push({id: "check-ins", value: formatCount(stats.checkIns30d), label: "check-ins at spots"});
  }
  if (activity(stats.trainingPlans30d)) {
    facts.push({id: "plans", value: formatCount(stats.trainingPlans30d), label: "training sessions planned"});
  }
  if (activity(stats.spotsAdded30d)) {
    facts.push({id: "new-spots", value: formatCount(stats.spotsAdded30d), label: "spots added"});
  }
  if (activity(stats.ratings30d)) {
    facts.push({id: "ratings", value: formatCount(stats.ratings30d), label: "spot ratings"});
  }
  return facts;
}

/** Curation totals that show the library is looked after. */
export function curationFacts(stats: AboutStats): StatFact[] {
  const facts: StatFact[] = [];
  if (activity(stats.improvementSuggestionCount)) {
    facts.push({
      id: "suggestions",
      value: formatCount(stats.improvementSuggestionCount),
      label: "improvements and reports from the community",
    });
  }
  if (activity(stats.deduplicatedCount)) {
    facts.push({id: "deduplicated", value: formatCount(stats.deduplicatedCount), label: "duplicate spots merged"});
  }
  if (activity(stats.ratingCount)) {
    facts.push({id: "ratings-total", value: formatCount(stats.ratingCount), label: "spot ratings in total"});
  }
  return facts;
}

/** One quotable line: spots, countries, sources, and upcoming events. */
export function statsSentence(stats: AboutStats): string | null {
  if (!present(stats.spotCount)) return null;
  let line = `${SITE_NAME} has ${countNoun(stats.spotCount, "parkour spot")}`;
  if (present(stats.countryCount)) {
    line += ` in ${countNoun(stats.countryCount, "country", "countries")}`;
  }
  if (present(stats.spotSourceCount)) {
    line += `, added by people who train there and from ${countNoun(stats.spotSourceCount, "community spot list")}`;
  }
  if (present(stats.upcomingEventCount)) {
    line += `, and ${countNoun(stats.upcomingEventCount, "upcoming event")}`;
  }
  return `${line}.`;
}

/** Worldwide library size, for context on country and city pages. */
export function worldwideContext(stats: AboutStats): string | null {
  if (!present(stats.spotCount)) return null;
  const where = present(stats.countryCount)
    ? ` in ${countNoun(stats.countryCount, "country", "countries")}`
    : " worldwide";
  return `${SITE_NAME} has ${countNoun(stats.spotCount, "parkour spot")}${where}.`;
}

/** "58 upcoming events in 21 countries" or null. */
export function upcomingEventsPhrase(stats: AboutStats): string | null {
  if (!present(stats.upcomingEventCount)) return null;
  const events = countNoun(stats.upcomingEventCount, "upcoming event");
  if (!present(stats.eventCountryCount)) return events;
  return `${events} in ${countNoun(stats.eventCountryCount, "country", "countries")}`;
}

/** English country names that take "the" ("the Netherlands", "the United States"). */
const REGION_WITH_ARTICLE = new Set([
  "ae",
  "bs",
  "cd",
  "cf",
  "do",
  "gb",
  "gm",
  "km",
  "ky",
  "mh",
  "mv",
  "nl",
  "ph",
  "sb",
  "us",
  "va",
]);

let regionNames: Intl.DisplayNames | null = null;

function regionDisplay(): Intl.DisplayNames {
  regionNames ??= new Intl.DisplayNames(["en"], {type: "region"});
  return regionNames;
}

export function countryName(countryCode: string): string {
  const code = countryCode.trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(code)) return countryCode.trim().toUpperCase();
  try {
    const name = regionDisplay().of(code);
    if (name && name.toUpperCase() !== code) return name;
  } catch {
    // Unknown region code: fall through to the uppercase code.
  }
  return code;
}

/** Phrase after "in": "the Netherlands", "Germany". */
export function countryInPhrase(countryCode: string): string {
  const name = countryName(countryCode);
  const code = countryCode.trim().toLowerCase();
  return REGION_WITH_ARTICLE.has(code) ? `the ${name}` : name;
}

export type HubCounts = {spotCount: number; eventCount: number};

/** "Parkour spots", "Parkour events", or "Parkour spots and events". */
function hubTopic({spotCount, eventCount}: HubCounts): string {
  const spots = present(spotCount);
  const events = present(eventCount);
  if (events && !spots) return "Parkour events";
  if (events && spots) return "Parkour spots and events";
  return "Parkour spots";
}

export function cityHubTitle(city: string, counts: HubCounts): string {
  return `${hubTopic(counts)} in ${city}`;
}

export function countryHubTitle(countryCode: string, counts: HubCounts): string {
  return `${hubTopic(counts)} in ${countryInPhrase(countryCode)}`;
}

/** Calendar date and UTC time for a snapshot `generatedAt` value. */
export function formatUpdatedAt(iso: string): string | null {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return null;
  const day = new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(date);
  const time = new Intl.DateTimeFormat("en-GB", {
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
    timeZone: "UTC",
  }).format(date);
  return `${day}, ${time} UTC`;
}

export function formatCount(n: number): string {
  return new Intl.NumberFormat("en").format(n);
}

export function countNoun(
  n: number,
  singular: string,
  plural = `${singular}s`,
): string {
  return `${formatCount(n)} ${n === 1 ? singular : plural}`;
}

export function joinNames(names: string[]): string {
  const clean = names.map((name) => name.trim()).filter(Boolean);
  if (clean.length === 0) return "";
  if (clean.length === 1) return clean[0];
  if (clean.length === 2) return `${clean[0]} and ${clean[1]}`;
  return `${clean.slice(0, -1).join(", ")}, and ${clean[clean.length - 1]}`;
}

/** Prefer an explicit library total. Otherwise use the spots stored on the page. */
export function resolveSpotCount(
  explicit: number | undefined | null,
  listedLength: number,
): number {
  const count = Number(explicit);
  if (Number.isFinite(count) && count >= listedLength) return count;
  return listedLength;
}

export function moreOnMapLabel(
  spotCount: number,
  listedCount: number,
): string | null {
  const more = spotCount - listedCount;
  if (more < 1) return null;
  return `${formatCount(more)} more on the map`;
}

function sampleSentence(
  spotCount: number,
  listedCount: number,
  topNames: string[],
): string | null {
  if (listedCount < 1) return null;
  const names = joinNames(topNames.slice(0, 3));
  if (names && spotCount <= listedCount) {
    return listedCount === 1
      ? `The highest rated is ${names}.`
      : `The highest rated are ${names}.`;
  }
  return listedCount === 1
    ? "One spot is listed below."
    : `${formatCount(listedCount)} spots are listed below, best rated first.`;
}

/** "3 upcoming events and 12 parkour spots", or just one of the two. */
function holdingsPhrase(spots: string | null, eventCount: number): string | null {
  if (!present(eventCount)) return spots;
  if (!spots) return countNoun(eventCount, "upcoming parkour event");
  return `${countNoun(eventCount, "upcoming event")} and ${spots}`;
}

export function coverageSentence(input: {
  spotCount: number;
  cityCount: number;
  countryCount: number;
}): string | null {
  if (input.countryCount < 1 || input.cityCount < 1) return null;
  const places = `in ${countNoun(input.cityCount, "city", "cities")} across ${countNoun(input.countryCount, "country", "countries")}`;
  if (input.spotCount < 1) {
    return `${SITE_NAME} lists parkour spots ${places}.`;
  }
  return `${SITE_NAME} has ${countNoun(input.spotCount, "parkour spot")} ${places}.`;
}

export function cityHubLede(input: {
  city: string;
  spotCount: number;
  listedCount: number;
  topNames: string[];
  eventCount: number;
}): string | null {
  const total = Math.max(input.spotCount, input.listedCount);
  const holdings = holdingsPhrase(
    total > 0 ? countNoun(total, "parkour spot") : null,
    input.eventCount,
  );
  if (!holdings) return null;
  return [
    `${input.city} has ${holdings} on ${SITE_NAME}.`,
    sampleSentence(total, input.listedCount, input.topNames),
  ]
    .filter(Boolean)
    .join(" ");
}

export function countryHubLede(input: {
  countryCode: string;
  spotCount: number;
  cityNames: string[];
  listedCount: number;
  topNames: string[];
  eventCount: number;
}): string {
  const phrase = countryInPhrase(input.countryCode);
  const place = phrase.charAt(0).toUpperCase() + phrase.slice(1);
  const cities = input.cityNames.map((name) => name.trim()).filter(Boolean);
  const total = Math.max(input.spotCount, input.listedCount);
  let spots: string | null = null;
  if (total > 0) {
    spots = countNoun(total, "parkour spot");
    if (cities.length === 1) spots += ` in ${cities[0]}`;
    if (cities.length > 1) {
      spots += ` across ${countNoun(cities.length, "city", "cities")}`;
    }
  }
  const holdings = holdingsPhrase(spots, input.eventCount);
  if (!holdings) return `${place} on ${SITE_NAME}.`;
  return [
    `${place} has ${holdings} on ${SITE_NAME}.`,
    sampleSentence(total, input.listedCount, input.topNames),
  ]
    .filter(Boolean)
    .join(" ");
}

export function metaDescription(text: string, max = 155): string {
  const flat = text.replace(/\s+/g, " ").trim();
  if (flat.length <= max) return flat;
  const cut = flat.slice(0, max - 1);
  const trimmed = cut.replace(/\s+\S*$/, "").replace(/[.,;:]+$/, "");
  return `${trimmed || cut.trim()}…`;
}
