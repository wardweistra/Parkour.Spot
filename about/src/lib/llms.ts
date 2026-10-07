import {SITE_NAME} from "./brand";
import {
  APP_DEFINITION,
  cityHubTitle,
  countNoun,
  countryHubTitle,
  countryName,
} from "./citation";
import {HOW_IT_WORKS_GROUPS} from "./how-it-works";
import type {CoverageCountry} from "./snapshots";
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

export function buildLlmsTxt(input: {
  countries: CoverageCountry[];
}): string {
  const countries = [...input.countries].sort((a, b) =>
    countryName(a.code).localeCompare(countryName(b.code), "en"),
  );
  const lines = [
    `# ${SITE_NAME}`,
    "",
    `> ${APP_DEFINITION}`,
    "",
    "The map is https://parkour.spot. Spots, photos, and ratings come from people who train there. You can explore without an account.",
    "",
    "## Start here",
    "",
    `- [${SITE_NAME}](${aboutAbsolute("/")}): What ${SITE_NAME} is, and which countries have place pages.`,
    `- [How ${SITE_NAME} works](${aboutAbsolute("/how-it-works")}): How to find spots and events, add them, keep lists, and train with the community.`,
    `- [Events](${aboutAbsolute("/events")}): Upcoming public parkour events.`,
    "",
    "## Tasks",
    "",
    ...HOW_IT_WORKS_GROUPS.flatMap((group) =>
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
