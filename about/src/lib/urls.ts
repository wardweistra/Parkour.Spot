export const APP_ORIGIN = "https://parkour.spot";
export const ABOUT_ORIGIN = "https://about.parkour.spot";
export const OPEN_SOURCE_URL = "https://github.com/wardweistra/Parkour.Spot";

export function appHomeUrl(): string {
  return APP_ORIGIN;
}

export function appPath(path: string): string {
  const normalized = path.startsWith("/") ? path : `/${path}`;
  return `${APP_ORIGIN}${normalized}`;
}

export function appCountryUrl(countryCode: string): string {
  return `${APP_ORIGIN}/${countryCode.toLowerCase()}`;
}

export function appCityUrl(countryCode: string, citySlug: string): string {
  return `${APP_ORIGIN}/${countryCode.toLowerCase()}/${citySlug}`;
}

export function appSpotUrl(
  countryCode: string,
  citySlug: string,
  spotId: string,
): string {
  return `${APP_ORIGIN}/${countryCode.toLowerCase()}/${citySlug}/${spotId}`;
}

export function appEventUrl(eventId: string): string {
  return `${APP_ORIGIN}/event/${eventId}`;
}

export function aboutCountryPath(countryCode: string): string {
  return `/${countryCode.toLowerCase()}`;
}

export function aboutCityPath(countryCode: string, citySlug: string): string {
  return `/${countryCode.toLowerCase()}/${citySlug}`;
}

export function cityHubKey(countryCode: string, citySlug: string): string {
  return `${countryCode.toLowerCase()}/${citySlug}`;
}

/**
 * Link an event to a generated area page. City hubs win; a country hub is
 * used only when that country page exists and the city page does not.
 */
export function eventAreaHubLink(
  event: {countryCode: string | null; citySlug: string | null},
  cityHubKeys: ReadonlySet<string>,
  countryHubCodes: ReadonlySet<string>,
): {href: string; label: string} | null {
  const cc = event.countryCode?.trim().toLowerCase() ?? "";
  if (!cc) return null;
  const citySlug = event.citySlug?.trim() ?? "";
  if (citySlug && cityHubKeys.has(cityHubKey(cc, citySlug))) {
    return {href: aboutCityPath(cc, citySlug), label: "Area hub"};
  }
  if (countryHubCodes.has(cc)) {
    return {href: aboutCountryPath(cc), label: "Country hub"};
  }
  return null;
}

export function aboutEventPath(slug: string): string {
  return `/events/${slug}`;
}

export function aboutAbsolute(path: string): string {
  if (path === "/" || path === "") return `${ABOUT_ORIGIN}/`;
  const normalized = path.startsWith("/") ? path : `/${path}`;
  return `${ABOUT_ORIGIN}${normalized}`;
}
