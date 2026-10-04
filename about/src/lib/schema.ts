import type {EventDetail} from "./types";
import {ABOUT_ORIGIN, aboutEventPath} from "./urls";

export function buildEventJsonLd(event: EventDetail): Record<string, unknown> {
  const url = `${ABOUT_ORIGIN}${aboutEventPath(event.slug)}`;
  const locationName = [event.city, event.countryCode?.toUpperCase()]
    .filter(Boolean)
    .join(", ");

  const location: Record<string, unknown> = {
    "@type": "Place",
    name: locationName || "Location TBA",
  };

  if (event.address) {
    location.address = event.address;
  }
  if (
    typeof event.latitude === "number" &&
    typeof event.longitude === "number"
  ) {
    location.geo = {
      "@type": "GeoCoordinates",
      latitude: event.latitude,
      longitude: event.longitude,
    };
  }

  const data: Record<string, unknown> = {
    "@context": "https://schema.org",
    "@type": "Event",
    name: event.title,
    url,
    eventAttendanceMode: "https://schema.org/OfflineEventAttendanceMode",
    eventStatus: "https://schema.org/EventScheduled",
    location,
  };

  if (event.startAt) data.startDate = event.startAt;
  if (event.endAt) data.endDate = event.endAt;
  if (event.description) data.description = event.description;

  const images =
    event.imageUrls?.length > 0
      ? event.imageUrls
      : event.imageUrl
        ? [event.imageUrl]
        : [];
  if (images.length > 0) data.image = images;

  if (event.websiteUrl) {
    data.offers = {
      "@type": "Offer",
      url: event.websiteUrl,
      availability: "https://schema.org/InStock",
    };
  }

  return data;
}
