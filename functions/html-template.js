/* eslint-disable max-len */
/**
 * Shared HTML template for both the regular index.html and the spotPage function
 * This ensures both pages have identical content except for dynamic meta tags
 */

// Import shared utility functions
const {escapeXml} = require("./utils");

const GOOGLE_MAPS_API_KEY = "AIzaSyAAhFK9QYxOlbI3ySWTmoFIJKLAl8CL-qo";
const GOOGLE_ANALYTICS_MEASUREMENT_ID = "G-861J61HFR8";

/**
 * Generate the HTML head section with optional dynamic meta tags
 * @param {Object} options - Configuration options
 * @param {string} options.title - Page title (default: "Parkour·Spot")
 * @param {string} options.description - Meta description (default: "Discover, map, and share the best parkour spots worldwide with community photos, ratings, and local tips for your next training session.")
 * @param {string} options.image - Meta image URL (default: "https://parkour.spot/ParkourSpot-Featured.png")
 * @param {string} options.url - Canonical URL (optional)
 * @param {string} options.siteName - Site name (default: "Parkour·Spot")
 * @param {boolean} options.isDynamic - Whether to include dynamic Open Graph/Twitter tags (default: false)
 * @param {string} options.canonicalHost - Canonical host for breadcrumbs (optional)
 * @param {Array} options.breadcrumbs - Breadcrumb items (optional)
 * @return {string} HTML head content
 */
function generateHtmlHead(options = {}) {
  const {
    title = "Parkour·Spot",
    description = "Discover, map, and share the best parkour spots worldwide with community photos, ratings, and local tips for your next training session.",
    image = "https://parkour.spot/ParkourSpot-Featured.png",
    url = null,
    siteName = "Parkour·Spot",
    isDynamic = false,
    canonicalHost = "parkour.spot",
    breadcrumbs = [],
  } = options;

  const escapedTitle = htmlEscape(title);
  const escapedDesc = htmlEscape(description);
  const escapedImage = htmlEscape(image);
  const escapedUrl = url ? htmlEscape(url) : null;
  const breadcrumbJsonLd = generateBreadcrumbJsonLd({
    canonicalHost: canonicalHost,
    breadcrumbs: breadcrumbs,
  });
  const pageTypeJsonLd = generatePageTypeJsonLd({
    canonicalHost: canonicalHost,
    url: url,
    pageType: options.pageType,
    name: options.pageName,
    description: options.pageDescription,
    address: options.pageAddress,
    geo: options.pageGeo,
    aggregateRating: options.pageAggregateRating,
    image: options.pageImage || (isDynamic ? image : null),
    subjectOf: options.pageSubjectOf,
    startDate: options.pageStartDate,
    endDate: options.pageEndDate,
    eventWebsiteUrl: options.pageEventWebsiteUrl,
    locationName: options.pageLocationName,
  });
  // Only include Organization JSON-LD on home page (non-dynamic pages)
  const organizationJsonLd = !isDynamic ? generateOrganizationJsonLd({
    canonicalHost: canonicalHost,
    siteName: siteName,
    description: description,
  }) : "";

  return `
  <meta charset="UTF-8">
  <meta content="IE=Edge" http-equiv="X-UA-Compatible">
  <meta name="description" content="${escapedDesc}" />
  <base href="/" />

  ${isDynamic ? `
  <!-- Dynamic Open Graph -->
  <meta property="og:type" content="website" />
  <meta property="og:site_name" content="${siteName}" />
  ${escapedUrl ? `<meta property="og:url" content="${escapedUrl}" />` : ""}
  <meta property="og:title" content="${escapedTitle}" />
  <meta property="og:description" content="${escapedDesc}" />
  <meta property="og:image" content="${escapedImage}" />

  <!-- Dynamic Twitter -->
  <meta name="twitter:card" content="summary_large_image" />
  <meta name="twitter:title" content="${escapedTitle}" />
  <meta name="twitter:description" content="${escapedDesc}" />
  <meta name="twitter:image" content="${escapedImage}" />
  ` : `
  <!-- Open Graph default (overridden by dynamic spot page) -->
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="${siteName}">
  <meta property="og:title" content="${escapedTitle}">
  <meta property="og:description" content="${escapedDesc}">
  <meta property="og:image" content="${escapedImage}">

  <!-- Twitter default (overridden by dynamic spot page) -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="${escapedTitle}">
  <meta name="twitter:description" content="${escapedDesc}">
  <meta name="twitter:image" content="${escapedImage}">
  `}

  <!-- iOS meta tags & icons -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="${siteName}">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/svg+xml" href="favicon.svg"/>
  <link rel="icon" type="image/x-icon" href="favicon.ico"/>

  <title>${escapedTitle}</title>
  <link rel="manifest" href="manifest.json">

  <!-- Google Analytics 4 -->
  <script>
    window.GA_MEASUREMENT_ID = "${GOOGLE_ANALYTICS_MEASUREMENT_ID}";
  </script>
  <script async src="https://www.googletagmanager.com/gtag/js?id=${GOOGLE_ANALYTICS_MEASUREMENT_ID}"></script>
  <script>
    window.dataLayer = window.dataLayer || [];
    function gtag(){ dataLayer.push(arguments); }
    gtag('js', new Date());
    gtag('config', window.GA_MEASUREMENT_ID, { send_page_view: false }); // SPA: we'll track manually
  </script>
  <!-- Optional: basic consent defaults -->
  <script>
    gtag('consent', 'default', {
      ad_storage: 'denied',
      analytics_storage: 'granted',
      functionality_storage: 'granted',
      personalization_storage: 'denied',
      security_storage: 'granted'
    });
  </script>

  <!-- Google Maps JavaScript API -->
  <script async defer src="https://maps.googleapis.com/maps/api/js?key=${GOOGLE_MAPS_API_KEY}&loading=async"></script>

  <meta name="theme-color" content="#000000" />
  
  <!-- Identity verification: rel="me" links -->
  <link rel="me" href="https://www.instagram.com/parkourdotspot/" />
  
  ${escapedUrl ? `<link rel="canonical" href="${escapedUrl}" />` : ""}${breadcrumbJsonLd}${pageTypeJsonLd}${organizationJsonLd}`;
}

/**
 * Render a crawlable spot summary for the initial HTML body.
 * @param {Object|null|undefined} seoContent - From buildSpotSeoContent
 * @param {string} [canonicalHost]
 * @return {string}
 */
function renderSeoContentHtml(seoContent, canonicalHost = "parkour.spot") {
  if (!seoContent || typeof seoContent !== "object" || !seoContent.title) {
    return "";
  }

  const parts = [];
  parts.push(`<article id="seo-content">`);

  if (Array.isArray(seoContent.breadcrumbs) && seoContent.breadcrumbs.length > 0) {
    const crumbs = seoContent.breadcrumbs.map((crumb, index) => {
      const name = htmlEscape(crumb.name);
      const href = crumb.url.startsWith("http") ?
        htmlEscape(crumb.url) :
        htmlEscape(`https://${canonicalHost}${crumb.url}`);
      const sep = index > 0 ? " / " : "";
      return `${sep}<a href="${href}">${name}</a>`;
    }).join("");
    parts.push(`<nav aria-label="Breadcrumb">${crumbs}</nav>`);
  }

  parts.push(`<h1>${htmlEscape(seoContent.title)}</h1>`);

  if (seoContent.locationLine) {
    parts.push(`<p>${htmlEscape(seoContent.locationLine)}</p>`);
  }

  if (seoContent.whenDisplay) {
    parts.push(
        `<p><strong>When:</strong> ${htmlEscape(seoContent.whenDisplay)}</p>`,
    );
  }

  if (seoContent.description) {
    parts.push(`<p>${htmlEscape(seoContent.description)}</p>`);
  }

  if (seoContent.address) {
    parts.push(`<p><strong>Address:</strong> ${htmlEscape(seoContent.address)}</p>`);
  }

  if (seoContent.mapUrl && seoContent.latitude != null && seoContent.longitude != null) {
    const coords = `${seoContent.latitude}, ${seoContent.longitude}`;
    parts.push(
        `<p><strong>Location:</strong> ` +
        `<a href="${htmlEscape(seoContent.mapUrl)}">${htmlEscape(coords)}</a></p>`,
    );
  }

  if (seoContent.rating) {
    const ratingText =
      `${seoContent.rating.value.toFixed(1)} from ${seoContent.rating.count} ratings`;
    parts.push(`<p><strong>Rating:</strong> ${htmlEscape(ratingText)}</p>`);
  }

  if (seoContent.access) {
    parts.push(`<p><strong>Access:</strong> ${htmlEscape(seoContent.access)}</p>`);
  }

  if (Array.isArray(seoContent.features) && seoContent.features.length > 0) {
    parts.push("<h2>Features</h2><ul>");
    for (const feature of seoContent.features) {
      parts.push(`<li>${htmlEscape(feature)}</li>`);
    }
    parts.push("</ul>");
  }

  if (Array.isArray(seoContent.goodFor) && seoContent.goodFor.length > 0) {
    parts.push("<h2>Good for</h2><ul>");
    for (const item of seoContent.goodFor) {
      parts.push(`<li>${htmlEscape(item)}</li>`);
    }
    parts.push("</ul>");
  }

  if (Array.isArray(seoContent.facilities) && seoContent.facilities.length > 0) {
    parts.push("<h2>Facilities</h2><ul>");
    for (const facility of seoContent.facilities) {
      parts.push(
          `<li>${htmlEscape(facility.label)}: ${htmlEscape(facility.value)}</li>`,
      );
    }
    parts.push("</ul>");
  }

  if (Array.isArray(seoContent.youtubeVideos) && seoContent.youtubeVideos.length > 0) {
    parts.push("<h2>Videos</h2><ul>");
    for (const video of seoContent.youtubeVideos) {
      parts.push(
          `<li><a href="${htmlEscape(video.url)}">${htmlEscape(video.title)}</a></li>`,
      );
    }
    parts.push("</ul>");
  }

  if (Array.isArray(seoContent.jumpflixVideos) && seoContent.jumpflixVideos.length > 0) {
    parts.push("<h2>As seen in</h2><ul>");
    for (const film of seoContent.jumpflixVideos) {
      const label = `${film.title} — watch on Jumpflix`;
      parts.push(
          `<li><a href="${htmlEscape(film.url)}">${htmlEscape(label)}</a></li>`,
      );
    }
    parts.push("</ul>");
    parts.push(
        `<p>Film locations provided by ` +
        `<a href="https://www.jumpflix.tv/">Jumpflix</a>.</p>`,
    );
  }

  if (seoContent.websiteUrl) {
    parts.push(
        `<p><strong>Website:</strong> ` +
        `<a href="${htmlEscape(seoContent.websiteUrl)}">` +
        `${htmlEscape(seoContent.websiteUrl)}</a></p>`,
    );
  }

  if (Array.isArray(seoContent.linkedSpots) && seoContent.linkedSpots.length > 0) {
    parts.push("<h2>Linked spots</h2><ul>");
    for (const spot of seoContent.linkedSpots) {
      const href = spot.url.startsWith("http") ?
        htmlEscape(spot.url) :
        htmlEscape(`https://${canonicalHost}${spot.url}`);
      parts.push(
          `<li><a href="${href}">${htmlEscape(spot.title)}</a></li>`,
      );
    }
    parts.push("</ul>");
  }

  if (seoContent.sourceName) {
    parts.push(
        `<p><strong>Source:</strong> ${htmlEscape(seoContent.sourceName)}</p>`,
    );
  }

  parts.push("</article>");
  return parts.join("\n  ");
}

/**
 * Loading cover + styles for crawlable SEO HTML.
 * Cover matches Flutter splash primary (#186584 light / #8ECFF2 dark) so humans
 * do not see the plain article while WASM boots. Noscript users see the article.
 * Crawlers that do not run JS still get the full article in the first HTML.
 * @return {string}
 */
function seoContentBootScripts() {
  return `
  <style>
    /* Keep page chrome teal between cover dismiss and first Flutter frame. */
    html, body {
      background: #186584;
      margin: 0;
    }
    #app-loading-cover {
      position: fixed;
      inset: 0;
      z-index: 999999;
      background: #186584;
    }
    @media (prefers-color-scheme: dark) {
      html, body {
        background: #8ECFF2;
      }
      #app-loading-cover {
        background: #8ECFF2;
      }
    }
    #seo-content {
      font-family: system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
      max-width: 40rem;
      margin: 1.5rem auto;
      padding: 0 1rem 2rem;
      line-height: 1.5;
      color: #111;
    }
    #seo-content h1 { font-size: 1.5rem; margin: 0.75rem 0; }
    #seo-content h2 { font-size: 1.125rem; margin: 1.25rem 0 0.5rem; }
    #seo-content nav { font-size: 0.875rem; margin-bottom: 0.75rem; }
    #seo-content ul { padding-left: 1.25rem; }
  </style>
  <noscript>
    <style>#app-loading-cover { display: none !important; }</style>
  </noscript>
  <div id="app-loading-cover" aria-hidden="true"></div>
  <script>
    (function () {
      function dismissSeoShell() {
        var cover = document.getElementById("app-loading-cover");
        if (cover && cover.parentNode) cover.parentNode.removeChild(cover);
        var el = document.getElementById("seo-content");
        if (el) el.setAttribute("hidden", "");
      }
      var observer = new MutationObserver(function () {
        if (document.querySelector("flutter-view, flt-glass-pane, flt-scene-host")) {
          dismissSeoShell();
          observer.disconnect();
        }
      });
      observer.observe(document.documentElement, {childList: true, subtree: true});
    })();
  </script>`;
}

/**
 * Generate the HTML body section
 * @param {Object} options - Configuration options
 * @param {string} options.siteName - Site name (default: "Parkour·Spot")
 * @param {string} options.url - URL for noscript fallback (optional)
 * @param {Object} [options.seoContent] - Crawlable spot or event summary
 * @param {string} [options.canonicalHost]
 * @return {string} HTML body content
 */
function generateHtmlBody(options = {}) {
  const {
    siteName = "Parkour·Spot",
    url = null,
    seoContent = null,
    canonicalHost = "parkour.spot",
  } = options;

  const escapedUrl = url ? htmlEscape(url) : null;
  const seoHtml = renderSeoContentHtml(seoContent, canonicalHost);
  const seoBoot = seoHtml ? seoContentBootScripts() : "";

  // flutter_bootstrap.js is produced by flutter build web: it sets _flutter.buildConfig and calls
  // _flutter.loader.load (do not use flutter.js + manual load — load() requires buildConfig).
  return `
  ${seoBoot}
  ${seoHtml}
  ${url ? `
  <noscript>
    <p>Loading ${siteName}… If you are not redirected, open <a href="${escapedUrl}">${escapedUrl}</a>.</p>
  </noscript>
  ` : ""}
  <script src="flutter_bootstrap.js" async></script>`;
}

/**
 * Generate breadcrumb structured data (JSON-LD)
 * @param {Object} options - Breadcrumb options
 * @param {string} options.canonicalHost - The canonical host (e.g., "parkour.spot")
 * @param {Array} options.breadcrumbs - Array of breadcrumb items with {name, url}
 * @return {string} JSON-LD script tag or empty string
 */
function generateBreadcrumbJsonLd(options = {}) {
  const {canonicalHost = "parkour.spot", breadcrumbs = []} = options;

  if (!breadcrumbs || breadcrumbs.length === 0) {
    return "";
  }

  const items = breadcrumbs.map((crumb, index) => ({
    "@type": "ListItem",
    "position": index + 1,
    "name": htmlEscape(crumb.name),
    "item": `https://${canonicalHost}${crumb.url}`,
  }));

  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    "itemListElement": items,
  };

  return `
  <script type="application/ld+json">
${JSON.stringify(jsonLd, null, 2)}
  </script>`;
}

/**
 * Generate page type structured data (JSON-LD)
 * @param {Object} options - Page type options
 * @param {string} options.canonicalHost - The canonical host (e.g., "parkour.spot")
 * @param {string} options.url - The page URL
 * @param {string} options.pageType - The page type (e.g., "SportsActivityLocation", "CollectionPage")
 * @param {string} options.name - The page name
 * @param {string} options.description - The page description
 * @param {string} options.address - The address (for SportsActivityLocation)
 * @param {Object} [options.geo] - {latitude, longitude}
 * @param {Object} [options.aggregateRating] - {ratingValue, ratingCount}
 * @param {string} [options.image]
 * @param {Array<Object>} [options.subjectOf] - Creative works [{name, url, type}]
 * @param {string} [options.startDate] - Event startDate (ISO or YYYY-MM-DD)
 * @param {string} [options.endDate] - Event endDate
 * @param {string} [options.eventWebsiteUrl] - External event website
 * @param {string} [options.locationName] - Place name for Event location
 * @return {string} JSON-LD script tag or empty string
 */
function generatePageTypeJsonLd(options = {}) {
  const {
    canonicalHost = "parkour.spot",
    url = null,
    pageType = null,
    name = null,
    description = null,
    address = null,
    geo = null,
    aggregateRating = null,
    image = null,
    subjectOf = null,
    startDate = null,
    endDate = null,
    eventWebsiteUrl = null,
    locationName = null,
  } = options;

  if (!pageType || !url) {
    return "";
  }

  // Handle both absolute URLs and relative paths
  const pageId = url.startsWith("http") ? url : `https://${canonicalHost}${url}`;

  const pageData = {
    "@context": "https://schema.org",
    "@type": pageType,
    "@id": pageId,
  };

  if (name) {
    pageData.name = htmlEscape(name);
  }

  if (description) {
    pageData.description = htmlEscape(description);
  }

  // Add address for SportsActivityLocation pages
  if (pageType === "SportsActivityLocation" && address) {
    const addr = String(address).trim();
    if (addr.length > 0) {
      pageData.address = {
        "@type": "PostalAddress",
        "streetAddress": htmlEscape(addr),
      };
    }
  }

  if (pageType === "SportsActivityLocation" && geo &&
      typeof geo.latitude === "number" && typeof geo.longitude === "number" &&
      Number.isFinite(geo.latitude) && Number.isFinite(geo.longitude)) {
    pageData.geo = {
      "@type": "GeoCoordinates",
      "latitude": geo.latitude,
      "longitude": geo.longitude,
    };
  }

  if (pageType === "SportsActivityLocation" && aggregateRating &&
      typeof aggregateRating.ratingValue === "number" &&
      typeof aggregateRating.ratingCount === "number" &&
      aggregateRating.ratingCount > 0) {
    pageData.aggregateRating = {
      "@type": "AggregateRating",
      "ratingValue": aggregateRating.ratingValue,
      "ratingCount": aggregateRating.ratingCount,
      "bestRating": 5,
      "worstRating": 1,
    };
  }

  if (pageType === "Event") {
    pageData.url = pageId;
    if (typeof startDate === "string" && startDate.trim()) {
      pageData.startDate = startDate.trim();
    }
    if (typeof endDate === "string" && endDate.trim()) {
      pageData.endDate = endDate.trim();
    }
    if (typeof eventWebsiteUrl === "string" &&
        eventWebsiteUrl.trim().startsWith("http")) {
      pageData.sameAs = eventWebsiteUrl.trim();
    }

    const place = {"@type": "Place"};
    if (typeof locationName === "string" && locationName.trim()) {
      place.name = htmlEscape(locationName.trim());
    }
    if (address && String(address).trim()) {
      place.address = {
        "@type": "PostalAddress",
        "streetAddress": htmlEscape(String(address).trim()),
      };
    }
    if (geo &&
        typeof geo.latitude === "number" && typeof geo.longitude === "number" &&
        Number.isFinite(geo.latitude) && Number.isFinite(geo.longitude)) {
      place.geo = {
        "@type": "GeoCoordinates",
        "latitude": geo.latitude,
        "longitude": geo.longitude,
      };
    }
    if (place.name || place.address || place.geo) {
      pageData.location = place;
    }
  }

  if (image && typeof image === "string" && image.trim().startsWith("http")) {
    pageData.image = htmlEscape(image.trim());
  }

  if (Array.isArray(subjectOf) && subjectOf.length > 0) {
    const works = [];
    for (const item of subjectOf) {
      if (!item || typeof item.url !== "string" || !item.url.trim()) continue;
      if (typeof item.name !== "string" || !item.name.trim()) continue;
      works.push({
        "@type": item.type || "CreativeWork",
        "name": htmlEscape(item.name.trim()),
        "url": item.url.trim(),
      });
    }
    if (works.length > 0) {
      pageData.subjectOf = works.length === 1 ? works[0] : works;
    }
  }

  return `
  <script type="application/ld+json">
${JSON.stringify(pageData, null, 2)}
  </script>`;
}

/**
 * Generate organization structured data (JSON-LD) with sameAs
 * @param {Object} options - Organization options
 * @param {string} options.canonicalHost - The canonical host (e.g., "parkour.spot")
 * @param {string} options.siteName - The site name
 * @param {string} options.description - The site description
 * @return {string} JSON-LD script tag
 */
function generateOrganizationJsonLd(options = {}) {
  const {
    canonicalHost = "parkour.spot",
    siteName = "Parkour·Spot",
    description = "Discover, map, and share the best parkour spots worldwide with community photos, ratings, and local tips for your next training session.",
  } = options;

  const organizationData = {
    "@context": "https://schema.org",
    "@type": "Organization",
    "name": htmlEscape(siteName),
    "url": `https://${canonicalHost}`,
    "description": htmlEscape(description),
    "sameAs": [
      "https://www.instagram.com/parkourdotspot/",
    ],
  };

  return `
  <script type="application/ld+json">
${JSON.stringify(organizationData, null, 2)}
  </script>`;
}

/**
 * Generate complete HTML page
 * @param {Object} options - Configuration options
 * @return {string} Complete HTML page
 */
function generateHtmlPage(options = {}) {
  const headContent = generateHtmlHead(options);
  const bodyContent = generateHtmlBody(options);

  return `<!DOCTYPE html>
<html>
<head>
${headContent}
</head>
<body>
${bodyContent}
</body>
</html>`;
}

/**
 * HTML escape function
 * @param {any} value - Value to escape
 * @return {string} Escaped HTML string
 */
/**
 * Alias for escapeXml for backward compatibility
 * @param {any} value - Value to escape
 * @return {string} Escaped HTML string
 */
function htmlEscape(value) {
  return escapeXml(value);
}

// Export for use in Node.js (Firebase Functions)
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    generateHtmlHead,
    generateHtmlBody,
    generateHtmlPage,
    generateBreadcrumbJsonLd,
    generatePageTypeJsonLd,
    generateOrganizationJsonLd,
    renderSeoContentHtml,
    htmlEscape,
    GOOGLE_MAPS_API_KEY,
  };
}
