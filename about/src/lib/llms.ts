import {SITE_NAME} from "./brand";
import {
  APP_DEFINITION,
  MISSION,
  activityFacts,
  cityHubTitle,
  countNoun,
  countryHubTitle,
  countryName,
  curationFacts,
  formatUpdatedAt,
  libraryFacts,
} from "./citation";
import {howItWorksGroups} from "./how-it-works";
import type {CoverageCountry} from "./snapshots";
import type {AboutStats} from "./types";
import {aboutAbsolute, aboutCityPath, aboutCountryPath} from "./urls";

function cityLine(countryCode: string, city: CoverageCountry["cities"][number]): string {
  const path = aboutCityPath(countryCode, city.citySlug);
  const count = Number(city.spotCount);
  const suffix =
    Number.isFinite(count) && count > 0
      ? `: ${countNoun(count, "parkour spot")}`
      : "";
  return `  - [${cityHubTitle(city.city)}](${aboutAbsolute(path)})${suffix}`;
}

function keyFactLines(stats: AboutStats): string[] {
  const days = stats.activityWindowDays ?? 30;
  const facts = [
    ...libraryFacts(stats).map((fact) => `- ${fact.value} ${fact.label}`),
    ...activityFacts(stats).map(
      (fact) => `- ${fact.value} ${fact.label} in the last ${days} days`,
    ),
    ...curationFacts(stats).map((fact) => `- ${fact.value} ${fact.label}`),
  ];
  if (facts.length === 0) return [];
  const asOf = stats.generatedAt ? formatUpdatedAt(stats.generatedAt) : null;
  return [
    asOf ? `## Key facts (as of ${asOf})` : "## Key facts",
    "",
    ...facts,
    "",
    "These figures are recounted every night from the live map.",
    "",
  ];
}

export function buildLlmsTxt(input: {
  countries: CoverageCountry[];
  stats: AboutStats;
}): string {
  const countries = [...input.countries].sort((a, b) =>
    countryName(a.code).localeCompare(countryName(b.code), "en"),
  );
  const lines = [
    `# ${SITE_NAME}`,
    "",
    `> ${APP_DEFINITION}`,
    "",
    "The map is https://parkour.spot. Spots, photos, and ratings come from people who train there and from spot lists kept by local communities. You can explore without an account.",
    "",
    MISSION,
    "",
    ...keyFactLines(input.stats),
    "## Start here",
    "",
    `- [${SITE_NAME}](${aboutAbsolute("/")}): What ${SITE_NAME} is, and which countries have place pages.`,
    `- [How ${SITE_NAME} works](${aboutAbsolute("/how-it-works")}): How to find spots and events, add them, keep lists, and train with the community.`,
    `- [Events](${aboutAbsolute("/events")}): Upcoming public parkour events.`,
    "",
    "## Tasks",
    "",
    ...howItWorksGroups(input.stats).flatMap((group) =>
      group.questions.map(
        (question) =>
          `- [${question.question}](${aboutAbsolute(`/how-it-works#${question.id}`)})`,
      ),
    ),
    "",
    "## Countries and cities",
    "",
  ];

  if (countries.length === 0) {
    lines.push("No country pages yet.");
  } else {
    for (const country of countries) {
      const path = aboutCountryPath(country.code);
      const suffix =
        country.spotCount > 0
          ? `: ${countNoun(country.spotCount, "parkour spot")} in ${countNoun(country.cities.length, "city", "cities")}`
          : `: ${countNoun(country.cities.length, "city", "cities")}`;
      lines.push(
        `- [${countryHubTitle(country.code)}](${aboutAbsolute(path)})${suffix}`,
      );
      for (const city of country.cities) {
        lines.push(cityLine(country.code, city));
      }
    }
  }

  lines.push("");
  return lines.join("\n");
}
