/* eslint-disable max-len */
/**
 * Shared HTML template for both the regular index.html and the spotPage function
 * This ensures both pages have identical content except for dynamic meta tags
 */

// Import shared utility functions
const {escapeXml} = require("./utils");

const GOOGLE_MAPS_API_KEY = "AIzaSyAAhFK9QYxOlbI3ySWTmoFIJKLAl8CL-qo";

/**
 * Generate the HTML head section with optional dynamic meta tags
 * @param {Object} options - Configuration options
 * @param {string} options.title - Page title (default: "Parkour·Spot")
 * @param {string} options.description - Meta description (default: "Discover and share parkour spots around the world")
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
    description = "Discover and share parkour spots around the world",
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
  });

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
  <link rel="icon" type="image/x-icon" href="favicon.ico"/>

  <title>${escapedTitle}</title>
  <link rel="manifest" href="manifest.json">

  <!-- Google Maps JavaScript API -->
  <script async defer src="https://maps.googleapis.com/maps/api/js?key=${GOOGLE_MAPS_API_KEY}&loading=async"></script>

  <meta name="theme-color" content="#000000" />
  ${escapedUrl ? `<link rel="canonical" href="${escapedUrl}" />` : ""}${breadcrumbJsonLd}${pageTypeJsonLd}`;
}

/**
 * Generate the HTML body section
 * @param {Object} options - Configuration options
 * @param {string} options.siteName - Site name (default: "Parkour·Spot")
 * @param {string} options.url - URL for noscript fallback (optional)
 * @param {string} options.serviceWorkerVersion - Service worker version (default: null)
 * @return {string} HTML body content
 */
function generateHtmlBody(options = {}) {
  const {
    siteName = "Parkour·Spot",
    url = null,
    serviceWorkerVersion = null,
  } = options;

  const escapedUrl = url ? htmlEscape(url) : null;

  return `
  ${url ? `
  <noscript>
    <p>Loading ${siteName}… If you are not redirected, open <a href="${escapedUrl}">${escapedUrl}</a>.</p>
  </noscript>
  ` : ""}
  <script>
    // The value below is injected by flutter build, do not touch.
    const serviceWorkerVersion = ${serviceWorkerVersion !== null ? `'${serviceWorkerVersion}'` : `'{{flutter_service_worker_version}}'`};
  </script>
  <!-- This script adds the flutter initialization JS code -->
  <script src="flutter.js" defer></script>
  <script>
    window.addEventListener('load', function(ev) {
      // Download main.dart.js
      _flutter.loader.loadEntrypoint({
        serviceWorker: {
          serviceWorkerVersion: serviceWorkerVersion,
        },
        onEntrypointLoaded: function(engineInitializer) {
          engineInitializer.initializeEngine().then(function(appRunner) {
            appRunner.runApp();
          });
        }
      });
    });
  </script>`;
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

  return `
  <script type="application/ld+json">
${JSON.stringify(pageData, null, 2)}
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
    htmlEscape,
    GOOGLE_MAPS_API_KEY,
  };
}
