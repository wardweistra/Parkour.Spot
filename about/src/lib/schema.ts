import {DEFAULT_OG_IMAGE, SITE_NAME} from "./brand";
import {APP_DEFINITION, MISSION, statsSentence} from "./citation";
import {answerPlainText, howItWorksQuestions} from "./how-it-works";
import type {
  AboutStats,
  EventDetail,
  EventSummary,
  SpotSummary,
} from "./types";
import {
  ABOUT_ORIGIN,
  APP_ORIGIN,
  OPEN_SOURCE_URL,
  aboutAbsolute,
  aboutEventPath,
  appSpotUrl,
} from "./urls";

function geoCoordinates(
  latitude: number | null | undefined,
  longitude: number | null | undefined,
): Record<string, unknown> | null {
  if (typeof latitude !== "number" || typeof longitude !== "number") {
    return null;
  }
  return {"@type": "GeoCoordinates", latitude, longitude};
}

function postalAddress(
  street: string | null | undefined,
  city: string | null | undefined,
  countryCode: string | null | undefined,
): Record<string, unknown> | null {
  const data: Record<string, unknown> = {"@type": "PostalAddress"};
  if (street?.trim()) data.streetAddress = street.trim();
  if (city?.trim()) data.addressLocality = city.trim();
  if (countryCode?.trim()) data.addressCountry = countryCode.trim().toUpperCase();
  return Object.keys(data).length > 1 ? data : null;
}

export function buildEventJsonLd(event: EventDetail): Record<string, unknown> {
  const url = `${ABOUT_ORIGIN}${aboutEventPath(event.slug)}`;
  const locationName = [event.city, event.countryCode?.toUpperCase()]
    .filter(Boolean)
    .join(", ");

  const address = event.address?.trim() || "";
  const placeName = !address ? event.placeName?.trim() : "";
  const location: Record<string, unknown> = {
    "@type": "Place",
    name: placeName || address || locationName || "Location TBA",
  };

  const postal = postalAddress(address, event.city, event.countryCode);
  if (postal) location.address = postal;
  const geo = geoCoordinates(event.latitude, event.longitude);
  if (geo) location.geo = geo;
  if (placeName && event.placeSpotId && event.placeSpotCitySlug && event.countryCode) {
    location.url = appSpotUrl(
      event.countryCode,
      event.placeSpotCitySlug,
      event.placeSpotId,
    );
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
  data.image = images.length > 0 ? images : [aboutAbsolute(DEFAULT_OG_IMAGE.path)];

  if (event.websiteUrl) {
    data.offers = {
      "@type": "Offer",
      url: event.websiteUrl,
      availability: "https://schema.org/InStock",
    };
  }

  return data;
}

/** Entity graph for the homepage: the app, the organization, and this site. */
export function buildSiteGraph(stats: AboutStats): Record<string, unknown> {
  const orgId = `${APP_ORIGIN}/#organization`;
  const appId = `${APP_ORIGIN}/#app`;
  const live = statsSentence(stats);
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        "@id": orgId,
        name: SITE_NAME,
        url: APP_ORIGIN,
        description: MISSION,
        sameAs: [`${ABOUT_ORIGIN}/`, OPEN_SOURCE_URL],
      },
      {
        "@type": ["WebApplication", "SoftwareApplication"],
        "@id": appId,
        name: SITE_NAME,
        url: APP_ORIGIN,
        applicationCategory: "SportsApplication",
        operatingSystem: "Web",
        browserRequirements: "Requires a web browser",
        isAccessibleForFree: true,
        description: live ? `${APP_DEFINITION} ${live}` : APP_DEFINITION,
        featureList: [
          "Open map without an account",
          "Community ratings",
          "Spot photos",
          "Add a spot",
          "Parkour events",
          "Spot lists",
          "Want to visit and been to",
          "Training plans",
          "Check-ins",
          "Spot sources from local communities",
          "Install as app (PWA)",
          "Report and suggest improvements",
        ],
        offers: {
          "@type": "Offer",
          price: "0",
          priceCurrency: "USD",
        },
        publisher: {"@id": orgId},
      },
      {
        "@type": "WebSite",
        "@id": `${ABOUT_ORIGIN}/#website`,
        name: SITE_NAME,
        url: `${ABOUT_ORIGIN}/`,
        description: APP_DEFINITION,
        publisher: {"@id": orgId},
      },
    ],
  };
}

/** FAQPage for /how-it-works. Answer text matches the visible page. */
export function buildFaqPageJsonLd(stats: AboutStats): Record<string, unknown> {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: howItWorksQuestions(stats).map((question) => ({
      "@type": "Question",
      name: question.question,
      acceptedAnswer: {
        "@type": "Answer",
        text: answerPlainText(question),
      },
    })),
  };
}

export function buildPlaceJsonLd(input: {
  name: string;
  pageUrl: string;
  spots: SpotSummary[];
  breadcrumbs: Array<{name: string; url: string}>;
}): Record<string, unknown> | null {
  const graph: Record<string, unknown>[] = [];
  if (input.breadcrumbs.length > 0) {
    graph.push({
      "@type": "BreadcrumbList",
      itemListElement: input.breadcrumbs.map((crumb, index) => ({
        "@type": "ListItem",
        position: index + 1,
        name: crumb.name,
        item: crumb.url,
      })),
    });
  }
  if (input.spots.length > 0) {
    graph.push({
      "@type": "ItemList",
      name: input.name,
      url: input.pageUrl,
      numberOfItems: input.spots.length,
      itemListElement: input.spots.map((spot, index) => ({
        "@type": "ListItem",
        position: index + 1,
        item: spotPlace(spot),
      })),
    });
  }
  if (graph.length === 0) return null;
  return {"@context": "https://schema.org", "@graph": graph};
}

function spotPlace(spot: SpotSummary): Record<string, unknown> {
  const place: Record<string, unknown> = {
    "@type": "Place",
    name: spot.name,
    url: appSpotUrl(spot.countryCode, spot.citySlug, spot.id),
  };
  if (spot.imageUrl) place.image = spot.imageUrl;
  const geo = geoCoordinates(spot.latitude, spot.longitude);
  if (geo) place.geo = geo;
  const postal = postalAddress(spot.address, spot.city, spot.countryCode);
  if (postal) place.address = postal;
  return place;
}

/** ItemList for /events, pointing at each About event page. */
export function buildEventsListJsonLd(
  events: EventSummary[],
): Record<string, unknown> | null {
  if (events.length === 0) return null;
  return {
    "@context": "https://schema.org",
    "@type": "ItemList",
    name: "Upcoming parkour events",
    url: aboutAbsolute("/events"),
    numberOfItems: events.length,
    itemListElement: events.map((event, index) => ({
      "@type": "ListItem",
      position: index + 1,
      url: aboutAbsolute(aboutEventPath(event.slug)),
    })),
  };
}
