import {
  APP_DEFINITION,
  cityHubTitle,
  countNoun,
  countryHubTitle,
  countryName,
  formatAtlasDate,
} from "./citation";
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
  generatedAt: string;
  countries: CoverageCountry[];
}): string {
  const countries = [...input.countries].sort((a, b) =>
    countryName(a.code).localeCompare(countryName(b.code), "en"),
  );
  const lines = [
    "# ParkourSpot",
    "",
    `> ${APP_DEFINITION}`,
    "",
    "The interactive map is https://parkour.spot. This site is the static HTML copy of the same places, refreshed daily. Spot counts are every public spot. Place pages show up to 10 of the highest rated.",
    "",
    `Snapshot date: ${formatAtlasDate(input.generatedAt)}.`,
    "",
    "## Start here",
    "",
    `- [ParkourSpot](${aboutAbsolute("/")}): What ParkourSpot is, and which countries have pages in this refresh.`,
    `- [How ParkourSpot works](${aboutAbsolute("/how-it-works")}): Open map, ratings, photos, adding a spot, events, and how these pages relate to the app.`,
    `- [Events](${aboutAbsolute("/events")}): Upcoming public parkour events.`,
    "",
    "## Countries and cities",
    "",
  ];

  if (countries.length === 0) {
    lines.push("No country pages in this refresh.");
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
