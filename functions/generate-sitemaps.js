/* eslint-disable max-len */
/**
 * Sitemap Generation Cloud Functions
 *
 * Generates XML sitemaps for search engine indexing:
 * - One sitemap per country (e.g., sitemap-nl.xml)
 * - A sitemap index file (sitemap.xml) that references all country sitemaps
 * - Includes URLs for country pages, city pages, and individual spot pages
 */

const admin = require("firebase-admin");

// Import shared utility functions
const {slugify, escapeXml, formatDateToISO} = require("./utils");

const db = admin.firestore();
const bucket = admin.storage().bucket();
const BASE_URL = "https://parkour.spot";
const MAX_URLS_PER_SITEMAP = 50000; // Google's limit
const SITEMAP_STORAGE_PATH = "sitemaps"; // Folder in Storage


/**
 * Generate XML for a single URL entry
 * @param {string} loc - URL location
 * @param {string|null} lastmod - Last modification date (ISO 8601)
 * @return {string} XML URL entry
 */
function generateUrlEntry(loc, lastmod = null) {
  let xml = "  <url>\n";
  xml += `    <loc>${escapeXml(loc)}</loc>\n`;
  if (lastmod) {
    xml += `    <lastmod>${escapeXml(lastmod)}</lastmod>\n`;
  }
  xml += "  </url>\n";
  return xml;
}

/**
 * Generate XML sitemap content
 * @param {Array<Object>} urls - Array of {loc, lastmod} objects
 * @return {string} XML sitemap content
 */
function generateSitemapXml(urls) {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  xml += "<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n";

  for (const url of urls) {
    xml += generateUrlEntry(url.loc, url.lastmod);
  }

  xml += "</urlset>\n";
  return xml;
}

/**
 * Generate XML sitemap index content
 * @param {Array<Object>} sitemaps - Array of {loc, lastmod} objects
 * @return {string} XML sitemap index content
 */
function generateSitemapIndexXml(sitemaps) {
  let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  xml += "<sitemapindex xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n";

  for (const sitemap of sitemaps) {
    xml += "  <sitemap>\n";
    xml += `    <loc>${escapeXml(sitemap.loc)}</loc>\n`;
    if (sitemap.lastmod) {
      xml += `    <lastmod>${escapeXml(sitemap.lastmod)}</lastmod>\n`;
    }
    xml += "  </sitemap>\n";
  }

  xml += "</sitemapindex>\n";
  return xml;
}


/**
 * Generate sitemap URLs for a country
 * @param {string} countryCode - Country code (lowercase)
 * @param {Map<string, Array>} citiesMap - Map of city -> spots[]
 * @return {Array<Object>} Array of {loc, lastmod} objects
 */
function generateCountrySitemapUrls(countryCode, citiesMap) {
  const urls = [];

  // Add country page URL
  urls.push({
    loc: `${BASE_URL}/${countryCode}`,
    lastmod: null,
  });

  // Add city page URLs and spot URLs
  for (const [cityName, spots] of citiesMap.entries()) {
    const citySlug = slugify(cityName);

    // Add city page URL
    urls.push({
      loc: `${BASE_URL}/${countryCode}/${citySlug}`,
      lastmod: null,
    });

    // Add spot URLs with lastmod
    for (const spot of spots) {
      const lastmod = formatDateToISO(spot.updatedAt);
      urls.push({
        loc: `${BASE_URL}/${countryCode}/${citySlug}/${spot.id}`,
        lastmod: lastmod,
      });
    }
  }

  return urls;
}

/**
 * Upload sitemap XML to Firebase Storage
 * @param {string} filename - Sitemap filename (e.g., "sitemap-nl.xml")
 * @param {string} xmlContent - XML content to upload
 * @return {Promise<void>}
 */
async function uploadSitemapToStorage(filename, xmlContent) {
  const filePath = `${SITEMAP_STORAGE_PATH}/${filename}`;
  const file = bucket.file(filePath);

  await file.save(xmlContent, {
    metadata: {
      contentType: "application/xml; charset=utf-8",
      cacheControl: "public, max-age=86400", // Cache for 24 hours
    },
    public: true, // Make publicly accessible
  });

  console.log(`Uploaded ${filename} to Storage`);
}

/**
 * Validate sitemap filename to prevent path traversal attacks
 * @param {string} filename - Filename to validate
 * @return {boolean} True if filename is valid
 */
function isValidSitemapFilename(filename) {
  // Must match pattern: sitemap.xml or sitemap-{country}.xml or sitemap-{country}-{number}.xml
  // Country code is 2 lowercase letters, part number is digits
  if (!/^sitemap(-[a-z]{2}(-\d+)?)?\.xml$/.test(filename)) {
    return false;
  }

  // Additional security: ensure no path traversal sequences
  if (filename.includes("..") || filename.includes("/") || filename.includes("\\")) {
    return false;
  }

  return true;
}

/**
 * Read sitemap XML from Firebase Storage
 * @param {string} filename - Sitemap filename (e.g., "sitemap-nl.xml")
 * @return {Promise<string|null>} XML content or null if not found
 */
async function getSitemapFromStorage(filename) {
  // Validate filename to prevent path traversal attacks
  if (!isValidSitemapFilename(filename)) {
    console.error(`Invalid sitemap filename: ${filename}`);
    return null;
  }

  const filePath = `${SITEMAP_STORAGE_PATH}/${filename}`;
  const file = bucket.file(filePath);

  try {
    const [exists] = await file.exists();
    if (!exists) {
      return null;
    }

    const [contents] = await file.download();
    return contents.toString("utf-8");
  } catch (error) {
    console.error(`Error reading ${filename} from Storage:`, error);
    return null;
  }
}

/**
 * Generate all sitemaps and upload them to Firebase Storage
 * Processes spots in batches to reduce memory usage
 * @return {Promise<void>}
 */
async function generateAllSitemaps() {
  console.log("Starting sitemap generation...");

  // Process spots in batches to reduce memory usage
  const BATCH_SIZE = 1000;
  const grouped = new Map();
  let totalSpots = 0;

  // Fetch spots in batches using cursor-based pagination
  // Note: We can't use orderBy with where clause without an index,
  // so we'll fetch all non-hidden spots and process in memory batches
  const allSpotsSnapshot = await db.collection("spots")
      .where("hidden", "==", false)
      .get();

  const allSpots = allSpotsSnapshot.docs
      .map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }))
      .filter((spot) => spot.duplicateOf == null);

  console.log(`Fetched ${allSpots.length} spots, processing in batches...`);

  // Process spots in batches to reduce peak memory usage
  for (let i = 0; i < allSpots.length; i += BATCH_SIZE) {
    const batch = allSpots.slice(i, i + BATCH_SIZE);

    // Group spots by country and city
    for (const spot of batch) {
      const countryCode = spot.countryCode;
      const city = spot.city;

      if (!countryCode || !city) {
        continue;
      }

      const countryCodeLower = countryCode.toLowerCase();
      if (!grouped.has(countryCodeLower)) {
        grouped.set(countryCodeLower, new Map());
      }

      const countryMap = grouped.get(countryCodeLower);
      const cityKey = city.toLowerCase();

      if (!countryMap.has(cityKey)) {
        countryMap.set(cityKey, []);
      }

      countryMap.get(cityKey).push(spot);
    }

    totalSpots += batch.length;
    if ((i + BATCH_SIZE) % (BATCH_SIZE * 10) === 0 || i + BATCH_SIZE >= allSpots.length) {
      console.log(`Processed ${Math.min(i + BATCH_SIZE, allSpots.length)}/${allSpots.length} spots...`);
    }
  }

  console.log(`Fetched and grouped ${totalSpots} spots into ${grouped.size} countries`);

  const sitemapIndexEntries = [];
  const now = new Date().toISOString();

  for (const [countryCode, citiesMap] of grouped.entries()) {
    try {
      const urls = generateCountrySitemapUrls(countryCode, citiesMap);

      // Split into multiple sitemaps if exceeding limit
      if (urls.length <= MAX_URLS_PER_SITEMAP) {
        const sitemapName = `sitemap-${countryCode}.xml`;
        const xml = generateSitemapXml(urls);

        // Upload to Storage
        await uploadSitemapToStorage(sitemapName, xml);

        sitemapIndexEntries.push({
          loc: `${BASE_URL}/sitemaps/${sitemapName}`,
          lastmod: now,
        });
      } else {
        // Split into multiple sitemaps
        let partNumber = 1;
        for (let i = 0; i < urls.length; i += MAX_URLS_PER_SITEMAP) {
          const chunk = urls.slice(i, i + MAX_URLS_PER_SITEMAP);
          const sitemapName = `sitemap-${countryCode}-${partNumber}.xml`;
          const xml = generateSitemapXml(chunk);

          // Upload to Storage
          await uploadSitemapToStorage(sitemapName, xml);

          sitemapIndexEntries.push({
            loc: `${BASE_URL}/sitemaps/${sitemapName}`,
            lastmod: now,
          });

          partNumber++;
        }
      }

      console.log(`Generated sitemap(s) for ${countryCode} with ${urls.length} URLs`);
    } catch (error) {
      console.error(`Error generating sitemap for ${countryCode}:`, error);
      // Continue with other countries
    }
  }

  // Generate and upload sitemap index
  const sitemapIndexXml = generateSitemapIndexXml(sitemapIndexEntries);
  await uploadSitemapToStorage("sitemap.xml", sitemapIndexXml);

  console.log(`Generated and uploaded ${sitemapIndexEntries.length + 1} sitemap files`);
}

module.exports = {
  generateAllSitemaps,
  getSitemapFromStorage,
};

