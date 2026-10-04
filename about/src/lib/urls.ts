export const APP_ORIGIN = "https://parkour.spot";
export const ABOUT_ORIGIN = "https://about.parkour.spot";

export function appHomeUrl(): string {
  return APP_ORIGIN;
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

export function aboutEventPath(slug: string): string {
  return `/events/${slug}`;
}
