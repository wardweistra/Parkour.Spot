import {SITE_NAME} from "./brand";

/**
 * Quotable facts for about.parkour.spot.
 * Counts are every public spot. Pages show a short highest-rated sample.
 */
export const APP_DEFINITION =
  `${SITE_NAME} is a free community map for finding, rating, and sharing parkour spots worldwide, open to explore without an account.`;

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

export function cityHubTitle(city: string): string {
  return `Parkour spots in ${city}`;
}

export function countryHubTitle(countryCode: string): string {
  return `Parkour spots in ${countryInPhrase(countryCode)}`;
}

export function formatAtlasDate(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "the latest refresh";
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "long",
    year: "numeric",
    timeZone: "UTC",
  }).format(date);
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

function sampleSentence(listedCount: number, topNames: string[]): string {
  const names = joinNames(topNames.slice(0, 3));
  if (names && listedCount === 1) return ` The highest rated is ${names}.`;
  if (names) return ` The highest rated are ${names}.`;
  if (listedCount === 1) return " This is the highest rated.";
  if (listedCount > 1) {
    return ` These are the ${formatCount(listedCount)} highest rated.`;
  }
  return "";
}

export function coverageSentence(input: {
  spotCount: number;
  cityCount: number;
  countryCount: number;
  generatedAt: string;
}): string | null {
  if (input.countryCount < 1 || input.cityCount < 1) return null;
  const when = formatAtlasDate(input.generatedAt);
  const places = `in ${countNoun(input.cityCount, "city", "cities")} across ${countNoun(input.countryCount, "country", "countries")}`;
  if (input.spotCount < 1) {
    return `As of ${when}, these pages cover ${places}. Pages are refreshed daily.`;
  }
  return `As of ${when}, these pages cover ${countNoun(input.spotCount, "parkour spot")} ${places}. Pages are refreshed daily.`;
}

export function cityHubLede(input: {
  city: string;
  spotCount: number;
  listedCount: number;
  topNames: string[];
}): string | null {
  const total = Math.max(input.spotCount, input.listedCount);
  if (total < 1) return null;
  const lead = `${input.city} has ${countNoun(total, "parkour spot")} on ${SITE_NAME}.`;
  if (input.listedCount < 1) return lead;
  if (total > input.listedCount) {
    const sample =
      input.listedCount === 1
        ? "This is the highest rated."
        : `These are the ${formatCount(input.listedCount)} highest rated.`;
    return `${lead} ${sample}`;
  }
  return `${lead}${sampleSentence(input.listedCount, input.topNames)}`;
}

export function countryHubLede(input: {
  countryCode: string;
  spotCount: number;
  cityNames: string[];
  listedCount: number;
  topNames: string[];
}): string {
  const phrase = countryInPhrase(input.countryCode);
  const place = phrase.charAt(0).toUpperCase() + phrase.slice(1);
  const cities = input.cityNames.map((name) => name.trim()).filter(Boolean);
  if (cities.length === 0 || input.spotCount < 1) {
    return `${place} on ${SITE_NAME}.`;
  }
  const spots = countNoun(input.spotCount, "parkour spot");
  const base =
    cities.length === 1
      ? `${place} has ${spots} in ${cities[0]} on ${SITE_NAME}.`
      : `${place} has ${spots} across ${countNoun(cities.length, "city", "cities")} on ${SITE_NAME}.`;
  if (input.listedCount < 1) return base;
  if (input.spotCount > input.listedCount) {
    const sample =
      input.listedCount === 1
        ? "This is the highest rated."
        : `These are the ${formatCount(input.listedCount)} highest rated.`;
    return `${base} ${sample}`;
  }
  return `${base}${sampleSentence(input.listedCount, input.topNames)}`;
}

export function metaDescription(text: string, max = 155): string {
  const flat = text.replace(/\s+/g, " ").trim();
  if (flat.length <= max) return flat;
  const cut = flat.slice(0, max - 1);
  const trimmed = cut.replace(/\s+\S*$/, "").replace(/[.,;:]+$/, "");
  return `${trimmed || cut.trim()}…`;
}
