import {SITE_NAME} from "./brand";
import {APP_DEFINITION} from "./citation";
import {answerPlainText, howItWorksQuestions} from "./how-it-works";
import type {EventDetail, SpotSummary} from "./types";
import {ABOUT_ORIGIN, APP_ORIGIN, aboutEventPath, appSpotUrl} from "./urls";

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

/** Entity graph for the homepage: the app, the organization, and this site. */
export function buildSiteGraph(): Record<string, unknown> {
  const orgId = `${APP_ORIGIN}/#organization`;
  const appId = `${APP_ORIGIN}/#app`;
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        "@id": orgId,
        name: SITE_NAME,
        url: APP_ORIGIN,
        sameAs: [`${ABOUT_ORIGIN}/`],
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
        description: APP_DEFINITION,
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
export function buildFaqPageJsonLd(): Record<string, unknown> {
  return {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: howItWorksQuestions().map((question) => ({
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
        name: spot.name,
        url: appSpotUrl(spot.countryCode, spot.citySlug, spot.id),
      })),
    });
  }
  if (graph.length === 0) return null;
  return {"@context": "https://schema.org", "@graph": graph};
}
