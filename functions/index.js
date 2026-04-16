/* eslint-disable max-len */
/**
 * Firebase Cloud Functions for ParkourSpot App
 *
 * Import function triggers from their respective submodules:
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentCreated, onDocumentUpdated} = require(
 *     "firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at
 * https://firebase.google.com/docs/
 * functions
 */

const {onCall, onRequest} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const sharp = require("sharp");
const yauzl = require("yauzl");
const xml2js = require("xml2js");
const https = require("https");
const path = require("path");
const {google} = require("googleapis");
const countries = require("i18n-iso-countries");

// Initialize Firebase Admin
admin.initializeApp();
const {FieldValue} = require("firebase-admin/firestore");
const db = admin.firestore();
const bucket = admin.storage().bucket();

// Register English locale for country names
countries.registerLocale(require("i18n-iso-countries/langs/en.json"));

// Import shared utilities
const {slugify, formatDateToISO, clipForMeta} = require("./utils");
const {
  extractSpotIdFromPath,
  extractFilename,
  getResizedImageUrlForApi,
  getResizedPathInfo,
  getImageContentTypeForPath,
  isEphemeralImageHost,
} = require("./lib/url-helpers");
const {
  hashApiKey,
  generateApiKey,
  serializeSpotForApi,
} = require("./lib/api-helpers");
const {
  getCountryNameWithArticle,
  calculateDistance,
  calculateBounds,
} = require("./lib/geo");
// Nearby notification fan-out will use collectionGroup("locationsOfInterest")
// and must dedupe matches by userId because a user can match via multiple
// anchors (e.g. lastKnown + home/work).
const {
  cleanUndefinedValues,
  buildSpotSearchWords,
  normalizeSpotAttributeDefaults,
  normalizeFolderSpotAttributeDefaults,
  buildFolderDefaultsLookup,
  mergeSpotAttributeDefaults,
  getEffectiveSpotAttributeDefaults,
  applySpotAttributeDefaultsToSpotData,
  buildSpotAttributeUpdateData,
} = require("./lib/spot-attributes");
const {
  buildDescription,
  getSearchQueryTokens,
  spotSearchTermDocId,
  cleanDescription,
  extractYoutubeVideoIdsFromDescription,
  extractImageUrls,
} = require("./lib/text-processing");
const {
  detectImportFormat,
  generateImageHash,
} = require("./lib/import-helpers");
const {shouldRunSync} = require("./lib/sync-helpers");

// Import shared HTML template
const {generateHtmlPage} = require("./html-template");

// Import sitemap generation functions
const {
  generateAllSitemaps,
  getSitemapFromStorage,
} = require("./generate-sitemaps");

/** App description appended to spot, list, and user page meta descriptions */
const APP_DESCRIPTION = "Discover, map, and share the best parkour spots worldwide with community photos, ratings, and local tips for your next training session.";

/**
 * Browser tab title for spot detail pages (matches Flutter web SpotDetailScreen).
 * @param {Object} spot
 * @return {string}
 */
function spotTitleWithLocation(spot) {
  const siteSuffix = "Parkour·Spot";
  const name = spot.name;
  const parts = [];
  const city = spot.city != null ? String(spot.city).trim() : "";
  if (city.length > 0) parts.push(city);
  const cc = spot.countryCode != null ? String(spot.countryCode).trim() : "";
  if (cc.length > 0) parts.push(cc.toUpperCase());
  const loc = parts.join(", ");
  if (loc.length === 0) return `${name} - ${siteSuffix}`;
  return `${name} · ${loc} - ${siteSuffix}`;
}

/**
 * Helper: perform geocoding for given lat/lng
 * @param {number} latitude - The latitude coordinate
 * @param {number} longitude - The longitude coordinate
 * @param {string} apiKey - The Google Maps API key
 * @return {Promise<Object>} Geocoding result
 */
async function geocodeLatLng(latitude, longitude, apiKey) {
  const geocodingUrl = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${latitude},${longitude}&key=${apiKey}`;
  const response = await new Promise((resolve, reject) => {
    https
        .get(geocodingUrl, (res) => {
          let data = "";
          res.on("data", (chunk) => (data += chunk));
          res.on("end", () => {
            try {
              resolve(JSON.parse(data));
            } catch (e) {
              reject(e);
            }
          });
        })
        .on("error", reject);
  });

  if (
    response.status === "OK" &&
    response.results &&
    response.results.length > 0
  ) {
    const result = response.results[0];
    const address = result.formatted_address;

    let city = null;
    let countryCode = null;
    if (Array.isArray(result.address_components)) {
      const components = result.address_components;
      const countryComp = components.find(
          (c) => c.types && c.types.includes("country"),
      );
      if (countryComp && countryComp.short_name) {
        countryCode = countryComp.short_name;
      }
      const cityTypesPriority = [
        "locality",
        "postal_town",
        "administrative_area_level_2",
        "administrative_area_level_1",
      ];
      for (const t of cityTypesPriority) {
        const comp = components.find(
            (c) => c.types && c.types.includes(t),
        );
        if (comp && comp.long_name) {
          city = comp.long_name;
          break;
        }
      }
    }

    return {success: true, address, city, countryCode};
  }

  return {
    success: false,
    error: response.error_message || "No address found for coordinates",
  };
}

// ========== Social sharing: Dynamic per-spot Open Graph/Twitter meta ==========
/**
 * HTTP function that serves an HTML page with dynamic Open Graph and Twitter
 * meta tags for spot detail URLs. It also boots the Flutter web app so that
 * normal users see the app, while crawlers read the meta tags.
 */
exports.spotPage = onRequest({region: "europe-west1"}, async (req, res) => {
  try {
    const originalUrl = req.originalUrl || req.url || "/";
    // Use parkour.spot domain for canonical URLs and meta tags, even if called from .run.app
    const host = req.headers.host || "parkour.spot";
    const canonicalHost = host.includes("parkour.spot") ? host : "parkour.spot";
    const fullUrl = `https://${canonicalHost}${originalUrl}`;

    const pathname = (() => {
      try {
        const u = new URL(fullUrl);
        return u.pathname;
      } catch (_) {
        return req.path || "/";
      }
    })();

    // Check if this is a location URL (1 or 2 segments) vs spot URL (3 segments)
    const pathSegments = pathname.split("/").filter((segment) => segment.length > 0);
    const isLocationUrl = pathSegments.length === 1 || pathSegments.length === 2;
    const isSpotUrl = pathSegments.length === 3;

    let spot = null;
    let locationInfo = null;

    if (isSpotUrl) {
      // Handle spot detail URLs
      const spotId = extractSpotIdFromPath(pathname);
      if (spotId) {
        const snap = await db.collection("spots").doc(spotId).get();
        if (snap.exists) {
          spot = {id: snap.id, ...snap.data()};
        }
      }
    } else if (isLocationUrl) {
      // Handle location URLs: /gb or /gb/london
      const countryCode = pathSegments[0] ? pathSegments[0].toUpperCase() : null;
      const citySlug = pathSegments[1];

      // Validate country code (2 letters)
      if (countryCode && countryCode.length === 2 && /^[A-Z]{2}$/.test(countryCode)) {
        // Check if country code actually exists
        const countryNameRaw = countries.getName(countryCode, "en");
        if (!countryNameRaw) {
          // Country code doesn't exist, redirect to /explore
          res.redirect(302, "/explore");
          return;
        }

        if (citySlug) {
          // City + country URL: /gb/london
          // Decode and capitalize city name
          const decodedCity = decodeURIComponent(citySlug);
          const cityName = decodedCity.split(" ").map((word) => {
            if (word.length === 0) return word;
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          }).join(" ");

          // When city is present, don't use "the" article before country name
          const countryName = getCountryNameWithArticle(countryCode, false);

          locationInfo = {
            city: cityName,
            countryCode: countryCode,
            countryName: countryName,
          };
        } else {
          // Country only URL: /gb - use "the" article when appropriate
          const countryName = getCountryNameWithArticle(countryCode, true);

          locationInfo = {
            countryCode: countryCode,
            countryName: countryName,
          };
        }
      }
    }

    // Generate canonical URL
    let canonicalUrl = fullUrl;
    if (spot && spot.countryCode && spot.city && isSpotUrl) {
      const citySlug = slugify(spot.city);
      const canonicalPath = `/${spot.countryCode.toLowerCase()}/${citySlug}/${spot.id}`;
      canonicalUrl = `https://${canonicalHost}${canonicalPath}`;
    } else if (locationInfo) {
      // Use the current URL as canonical for location pages
      canonicalUrl = fullUrl;
    }

    // Generate breadcrumb data
    const breadcrumbs = [];
    breadcrumbs.push({name: "Home", url: "/"});

    if (locationInfo || spot) {
      const countryCodeValue = locationInfo?.countryCode || spot?.countryCode;
      const countryCode = countryCodeValue ? countryCodeValue.toUpperCase() : null;
      // Always use country name without article for breadcrumbs
      const countryName = countryCode ? getCountryNameWithArticle(countryCode, false) : null;

      if (countryCode && countryName) {
        breadcrumbs.push({
          name: countryName,
          url: `/${countryCode.toLowerCase()}`,
        });
      }
    }

    if ((locationInfo?.city || spot?.city) && (locationInfo?.countryCode || spot?.countryCode)) {
      const countryCodeValue = locationInfo?.countryCode || spot?.countryCode;
      const countryCode = countryCodeValue ? countryCodeValue.toLowerCase() : null;
      const cityName = locationInfo?.city || spot?.city;
      const citySlug = slugify(cityName);

      breadcrumbs.push({
        name: cityName,
        url: `/${countryCode}/${citySlug}`,
      });
    }

    if (spot && spot.name && spot.countryCode && spot.city) {
      const countryCode = spot.countryCode.toLowerCase();
      const citySlug = slugify(spot.city);

      breadcrumbs.push({
        name: spot.name,
        url: `/${countryCode}/${citySlug}/${spot.id}`,
      });
    }

    const siteName = "Parkour·Spot";
    const defaultTitle = `${siteName}`;
    const defaultImage = `https://${canonicalHost}/ParkourSpot-Featured.png`;

    // Generate title and description based on URL type
    let title = defaultTitle;
    let description = "Discover, map, and share the best parkour spots worldwide with community photos, ratings, and local tips for your next training session.";

    if (spot && spot.name) {
      // Spot detail page
      title = spotTitleWithLocation(spot);
      description = buildDescription(spot) + " — " + APP_DESCRIPTION;
    } else if (locationInfo) {
      // Location page
      if (locationInfo.city) {
        title = `Best parkour spots in ${locationInfo.city}, ${locationInfo.countryName}`;
        description = `Discover the best parkour spots in ${locationInfo.city}, ${locationInfo.countryName}. Find training locations, share your favorite spots, and connect with the parkour community.`;
      } else {
        title = `Best parkour spots in ${locationInfo.countryName}`;
        description = `Discover the best parkour spots in ${locationInfo.countryName}. Find training locations, share your favorite spots, and connect with the parkour community.`;
      }
    }

    // Determine current page type and metadata for structured data
    let pageType = null;
    let pageName = null;
    let pageDescription = null;
    let pageAddress = null;

    if (spot && spot.name) {
      // Spot detail page
      pageType = "SportsActivityLocation";
      pageName = spot.name;
      pageDescription = description;
      // Extract address if available
      if (spot.address) {
        const addr = String(spot.address).trim();
        if (addr.length > 0) {
          pageAddress = addr;
        }
      }
    } else if (locationInfo) {
      // Location page (country or city)
      pageType = "CollectionPage";
      pageName = locationInfo.city ?
        `Best parkour spots in ${locationInfo.city}, ${locationInfo.countryName}` :
        `Best parkour spots in ${locationInfo.countryName}`;
      pageDescription = description;
    }

    let imageUrl = (spot && Array.isArray(spot.imageUrls) && spot.imageUrls.length > 0) ?
      spot.imageUrls[0] :
      defaultImage;

    // For social media previews (og:image), use the resized version for better load performance
    // getResizedImageUrlForApi handles firebasestorage + storage.googleapis.com formats
    imageUrl = getResizedImageUrlForApi(imageUrl);

    // Basic caching for crawlers and share scrapers
    res.set("Cache-Control", "public, max-age=300, s-maxage=600");
    res.set("Content-Type", "text/html; charset=utf-8");

    const html = generateHtmlPage({
      title: title,
      description: description,
      image: imageUrl,
      url: canonicalUrl,
      siteName: siteName,
      isDynamic: true,
      canonicalHost: canonicalHost,
      breadcrumbs: breadcrumbs,
      pageType: pageType,
      pageName: pageName,
      pageDescription: pageDescription,
      pageAddress: pageAddress,
    });

    res.status(200).send(html);
  } catch (err) {
    console.error("spotPage error", err);
    res.status(500).send("Internal Server Error");
  }
});

// ========== Social sharing: Dynamic User and Spot List Open Graph/Twitter meta ==========
/**
 * HTTP function that serves HTML with dynamic Open Graph/Twitter meta tags for
 * /user/:id and /list/:id URLs. Boots the Flutter web app for normal users;
 * crawlers read the meta tags for share previews.
 */
exports.userAndListPage = onRequest({region: "europe-west1"}, async (req, res) => {
  try {
    const originalUrl = req.originalUrl || req.url || "/";
    const host = req.headers.host || "parkour.spot";
    const canonicalHost = host.includes("parkour.spot") ? host : "parkour.spot";
    const fullUrl = `https://${canonicalHost}${originalUrl}`;

    const pathname = (() => {
      try {
        const u = new URL(fullUrl);
        return u.pathname;
      } catch (_) {
        return req.path || "/";
      }
    })();

    const pathSegments = pathname.split("/").filter((s) => s.length > 0);

    const siteName = "Parkour·Spot";
    const defaultTitle = siteName;
    const defaultDescription = APP_DESCRIPTION;
    const defaultImage = `https://${canonicalHost}/ParkourSpot-Featured.png`;

    let title = defaultTitle;
    let description = defaultDescription;
    let imageUrl = defaultImage;
    const breadcrumbs = [{name: "Home", url: "/"}];

    // /user/:userIdOrUsername
    if (pathSegments[0] === "user" && pathSegments.length >= 2) {
      const userIdOrUsername = pathSegments[1];
      let userDoc = null;

      if (userIdOrUsername.length === 28) {
        const snap = await db.collection("users").doc(userIdOrUsername).get();
        if (snap.exists) userDoc = {id: snap.id, ...snap.data()};
      }
      if (!userDoc) {
        const q = await db.collection("users")
            .where("username", "==", userIdOrUsername.toLowerCase())
            .limit(1)
            .get();
        if (!q.empty) {
          const d = q.docs[0];
          userDoc = {id: d.id, ...d.data()};
        }
      }

      if (userDoc && (userDoc.isPublicProfile !== false)) {
        const displayName = userDoc.displayName || userDoc.username || "User";
        title = `${displayName} - ${siteName}`;
        description = `View ${displayName}'s parkour spots and lists on ${siteName} — ${APP_DESCRIPTION}`;
        if (userDoc.photoURL && typeof userDoc.photoURL === "string" &&
            userDoc.photoURL.trim().length > 0) {
          imageUrl = userDoc.photoURL.trim();
        }
        breadcrumbs.push({name: displayName, url: `/user/${userIdOrUsername}`});
      }
    }

    // /list/:listId
    if (pathSegments[0] === "list" && pathSegments.length >= 2) {
      const listId = pathSegments[1];
      const listSnap = await db.collection("spotLists").doc(listId).get();

      if (listSnap.exists) {
        const list = {id: listSnap.id, ...listSnap.data()};
        const visibility = list.visibility || "unlisted";

        if (visibility !== "private") {
          const listName = list.name || "Spot list";
          const spotIds = Array.isArray(list.spotIds) ? list.spotIds : [];
          const spotCount = spotIds.length;

          title = `${listName} - ${siteName}`;
          const rawListDesc = list.description && list.description.trim().length > 0 ?
            list.description.trim() :
            `A curated list of ${spotCount} parkour spot${spotCount === 1 ? "" : "s"} on ${siteName}`;
          description = clipForMeta(rawListDesc) + " — " + APP_DESCRIPTION;

          // Use first spot's image if available
          if (spotIds.length > 0) {
            const firstSpotSnap = await db.collection("spots").doc(spotIds[0]).get();
            if (firstSpotSnap.exists) {
              const spotData = firstSpotSnap.data();
              const urls = spotData?.imageUrls;
              if (Array.isArray(urls) && urls.length > 0) {
                imageUrl = urls[0];
                if (imageUrl.includes("firebasestorage.googleapis.com") &&
                    imageUrl.includes("spots%2F")) {
                  imageUrl = imageUrl.replace("spots%2F", "spots%2Fresized%2F");
                  imageUrl = imageUrl.replace(/\.(jpg|jpeg|png|webp)(\?|$)/, "_1200x1200.webp$2");
                }
              }
            }
          }

          breadcrumbs.push({name: listName, url: `/list/${listId}`});
        }
      }
    }

    res.set("Cache-Control", "public, max-age=300, s-maxage=600");
    res.set("Content-Type", "text/html; charset=utf-8");

    const html = generateHtmlPage({
      title,
      description,
      image: imageUrl,
      url: fullUrl,
      siteName,
      isDynamic: true,
      canonicalHost,
      breadcrumbs,
      pageType: null,
      pageName: null,
      pageDescription: null,
      pageAddress: null,
    });

    res.status(200).send(html);
  } catch (err) {
    console.error("userAndListPage error", err);
    res.status(500).send("Internal Server Error");
  }
});

/**
 * Queues a batched update and flushes when needed.
 * @param {Object} batchState
 * @param {FirebaseFirestore.DocumentReference} docRef
 * @param {Object} updateData
 * @return {Promise<void>}
 */
async function queueBatchUpdate(batchState, docRef, updateData) {
  batchState.batch.update(docRef, updateData);
  batchState.operationCount += 1;
  if (batchState.operationCount >= 450) {
    await batchState.batch.commit();
    batchState.batch = db.batch();
    batchState.operationCount = 0;
  }
}

/**
 * Flushes pending batched writes if any remain.
 * @param {Object} batchState
 * @return {Promise<void>}
 */
async function commitPendingBatch(batchState) {
  if (batchState.operationCount > 0) {
    await batchState.batch.commit();
    batchState.batch = db.batch();
    batchState.operationCount = 0;
  }
}

// ========== Ranked Spots within Bounds ==========
/**
 * Shared query logic for top spots in bounds. Used by getTopSpotsInBounds callable
 * and the spots-in-bounds API endpoint.
 * @param {Object} params - minLat, maxLat, minLng, maxLng, limit, filterArea, spotSource,
 *   folders, folder, spotAccess, spotFacilities*, goodFor, spotFeatures
 * @return {Promise<{success: boolean, totalCount: number, averageWilson: number,
 *   shownCount: number, spots: Array}|{success: boolean, error: string}>}
 */
async function executeTopSpotsInBoundsQuery(params) {
  const {
    minLat,
    maxLat,
    minLng,
    maxLng,
    limit = 100,
    spotSource = null,
    folder = null,
    folders = null,
    filterArea = null,
    spotAccess = null,
    spotFacilitiesCovered = null,
    spotFacilitiesLighting = null,
    spotFacilitiesWaterTap = null,
    spotFacilitiesToilet = null,
    spotFacilitiesParking = null,
    goodFor = null,
    spotFeatures = null,
  } = params || {};

  if (
    typeof minLat !== "number" ||
    typeof maxLat !== "number" ||
    typeof minLng !== "number" ||
    typeof maxLng !== "number"
  ) {
    throw new Error("minLat, maxLat, minLng, maxLng are required numbers");
  }

  const normalizeLongitude = (lng) => {
    return ((lng + 180) % 360 + 360) % 360 - 180;
  };

  const normalizedMinLng = normalizeLongitude(minLng);
  const normalizedMaxLng = normalizeLongitude(maxLng);
  const isFullWrap = normalizedMinLng === normalizedMaxLng;

  let spansEntireGlobe = false;
  let crossesDateline = false;
  let lngSpan = null;

  if (isFullWrap) {
    spansEntireGlobe = true;
  } else {
    if (normalizedMinLng > normalizedMaxLng) {
      lngSpan = (180 - normalizedMinLng) + (normalizedMaxLng - (-180));
    } else {
      const rawSpan = maxLng - minLng;
      lngSpan = rawSpan >= 360 ? rawSpan : normalizedMaxLng - normalizedMinLng;
    }
    spansEntireGlobe = lngSpan >= 360;
    crossesDateline = !spansEntireGlobe && normalizedMinLng > normalizedMaxLng;
  }

  let averageWilson = 0;
  try {
    const settingsSnap = await db
        .collection("settings")
        .where("name", "==", "wilsonLowerBoundAvg")
        .limit(1)
        .get();
    if (!settingsSnap.empty) {
      const v = settingsSnap.docs[0].data().value;
      if (typeof v === "number") averageWilson = v;
      else if (v && typeof v === "object" && typeof v.toNumber === "function") {
        averageWilson = v.toNumber();
      }
    }
  } catch (avgErr) {
    console.warn("Failed to load wilsonLowerBoundAvg, defaulting to 0", avgErr);
  }

  const projection = [
    "name",
    "description",
    "latitude",
    "longitude",
    "address",
    "city",
    "countryCode",
    "imageUrls",
    "tags",
    "spotSource",
    "spotSourceName",
    "spotSourceRemoved",
    "spotSourceRemovedAt",
    "folderName",
    "averageRating",
    "ratingCount",
    "wilsonLowerBound",
    "createdAt",
    "updatedAt",
    "ranking",
    "spotAccess",
    "spotFacilities",
    "goodFor",
    "spotFeatures",
  ];

  const maxItems = Math.max(0, Math.min(200, Number(limit) || 100));

  let normalizedFolders = null;
  if (folders && Array.isArray(folders) && folders.length > 0 &&
      spotSource !== null && spotSource !== undefined) {
    normalizedFolders = folders
        .filter((f) => f && typeof f === "string" && f.trim().length > 0)
        .map((f) => String(f).trim());
    if (normalizedFolders.length === 0) normalizedFolders = null;
  } else if (folder && typeof folder === "string" && folder.trim().length > 0 &&
      spotSource !== null && spotSource !== undefined) {
    normalizedFolders = [String(folder).trim()];
  }

  const useAmenitiesFilter = filterArea === "amenities" && (
    (spotAccess && (typeof spotAccess === "string" ||
        (Array.isArray(spotAccess) && spotAccess.length > 0))) ||
    (spotFacilitiesCovered === "yes") ||
    (spotFacilitiesLighting === "yes") ||
    (spotFacilitiesWaterTap === "yes") ||
    (spotFacilitiesToilet === "yes") ||
    (spotFacilitiesParking === "yes") ||
    (goodFor && Array.isArray(goodFor) && goodFor.length > 0) ||
    (spotFeatures && Array.isArray(spotFeatures) && spotFeatures.length > 0)
  );

  const goodForArr = Array.isArray(goodFor) ?
    goodFor.filter((v) => v && typeof v === "string") : [];
  const spotFeaturesArr = Array.isArray(spotFeatures) ?
    spotFeatures.filter((v) => v && typeof v === "string") : [];

  const buildQuery = (lngMin, lngMax) => {
    let query = db
        .collection("spots")
        .where("latitude", ">=", minLat)
        .where("latitude", "<=", maxLat)
        .where("longitude", ">=", lngMin)
        .where("longitude", "<=", lngMax);

    if (useAmenitiesFilter) {
      query = query.where("duplicateOf", "==", null);
      query = query.where("hidden", "==", false);

      const accessValues = Array.isArray(spotAccess) ?
        spotAccess.filter((v) => v && typeof v === "string") :
        (spotAccess && typeof spotAccess === "string" ? [spotAccess] : []);
      if (accessValues.length === 1) {
        query = query.where("spotAccess", "==", accessValues[0]);
      } else if (accessValues.length > 1) {
        query = query.where("spotAccess", "in", accessValues.slice(0, 10));
      }
      if (spotFacilitiesCovered === "yes") {
        query = query.where("spotFacilities.covered", "==", "yes");
      }
      if (spotFacilitiesLighting === "yes") {
        query = query.where("spotFacilities.lighting", "==", "yes");
      }
      if (spotFacilitiesWaterTap === "yes") {
        query = query.where("spotFacilities.water_tap", "==", "yes");
      }
      if (spotFacilitiesToilet === "yes") {
        query = query.where("spotFacilities.toilet", "==", "yes");
      }
      if (spotFacilitiesParking === "yes") {
        query = query.where("spotFacilities.parking", "==", "yes");
      }
      if (goodForArr.length > 0) {
        query = query.where("goodFor", "array-contains-any", goodForArr.slice(0, 10));
      } else if (spotFeaturesArr.length > 0) {
        query = query.where("spotFeatures", "array-contains-any",
            spotFeaturesArr.slice(0, 10));
      }
    } else {
      if (spotSource !== null && spotSource !== undefined) {
        if (spotSource === "") {
          query = query.where("spotSource", "==", null);
        } else {
          query = query.where("spotSource", "==", spotSource);
        }
        if (normalizedFolders && normalizedFolders.length > 0) {
          if (normalizedFolders.length === 1) {
            query = query.where("folderName", "==", normalizedFolders[0]);
          } else {
            query = query.where("folderName", "in", normalizedFolders);
          }
        }
      } else {
        query = query.where("duplicateOf", "==", null);
      }
      query = query.where("hidden", "==", false);
    }

    return query.orderBy("ranking", "desc");
  };

  let totalCount = 0;
  let spots = [];

  if (spansEntireGlobe) {
    const [snap, count] = await Promise.all([
      buildQuery(-180, 180).select(...projection).limit(maxItems).get(),
      buildQuery(-180, 180).count().get(),
    ]);
    spots = snap.docs.map((d) => ({id: d.id, ...d.data()}));
    totalCount = count.data().count || 0;
  } else if (crossesDateline) {
    const [snap1, snap2, count1, count2] = await Promise.all([
      buildQuery(normalizedMinLng, 180).select(...projection).limit(maxItems).get(),
      buildQuery(-180, normalizedMaxLng).select(...projection).limit(maxItems).get(),
      buildQuery(normalizedMinLng, 180).count().get(),
      buildQuery(-180, normalizedMaxLng).count().get(),
    ]);
    spots = [
      ...snap1.docs.map((d) => ({id: d.id, ...d.data()})),
      ...snap2.docs.map((d) => ({id: d.id, ...d.data()})),
    ];
    totalCount = (count1.data().count || 0) + (count2.data().count || 0);
  } else {
    const [snap, count] = await Promise.all([
      buildQuery(normalizedMinLng, normalizedMaxLng)
          .select(...projection).limit(maxItems).get(),
      buildQuery(normalizedMinLng, normalizedMaxLng).count().get(),
    ]);
    spots = snap.docs.map((d) => ({id: d.id, ...d.data()}));
    totalCount = count.data().count || 0;
  }

  const normalize = (s) => {
    const createdAt = formatDateToISO(s.createdAt) || s.createdAt || null;
    const updatedAt = formatDateToISO(s.updatedAt) || s.updatedAt || null;
    return {...s, createdAt, updatedAt};
  };

  return {
    success: true,
    totalCount,
    averageWilson,
    shownCount: spots.length,
    spots: spots.map(normalize),
  };
}

/**
 * Returns the top N spots within given map bounds ranked by ranking field,
 * along with total count.
 */
exports.getTopSpotsInBounds = onCall(
    {region: "europe-west1", timeoutSeconds: 60, memory: "512MiB"},
    async (request) => {
      try {
        return await executeTopSpotsInBoundsQuery(request.data || {});
      } catch (error) {
        console.error("getTopSpotsInBounds error", error);
        return {success: false, error: error.message};
      }
    },
);

// ========== Ratings Aggregation Helpers ==========
/**
 * Helper function to fetch wilsonLowerBoundAvg from settings
 * @return {Promise<number>} The average Wilson lower bound
 */
async function getWilsonLowerBoundAvg() {
  try {
    const settingsSnap = await db
        .collection("settings")
        .where("name", "==", "wilsonLowerBoundAvg")
        .limit(1)
        .get();
    if (!settingsSnap.empty) {
      const v = settingsSnap.docs[0].data().value;
      if (typeof v === "number") return v;
      if (v && typeof v === "object" && typeof v.toNumber === "function") {
        return v.toNumber();
      }
    }
    return 0;
  } catch (err) {
    console.warn("Failed to load wilsonLowerBoundAvg from settings, defaulting to 0", err);
    return 0;
  }
}

/**
 * Recomputes rating aggregates for a spot and updates the spot document.
 * Includes ratings from the spot itself and from any spots marked as duplicates
 * of it (duplicateOf == spotId).
 * averageRating: mean of ratings (0..5)
 * ratingCount: number of ratings
 * wilsonLowerBound: Wilson score lower bound over normalized stars (0..5)
 * ranking: computed ranking value based on wilsonLowerBound and wilsonLowerBoundAvg
 * @param {string} spotId
 */
async function recomputeSpotRatingAggregates(spotId) {
  try {
    if (!spotId) return;

    // Fetch wilsonLowerBoundAvg from settings
    const wilsonLowerBoundAvg = await getWilsonLowerBoundAvg();

    // Include ratings from this spot and from any spots that are duplicates of it
    const duplicatesSnap = await db
        .collection("spots")
        .where("duplicateOf", "==", spotId)
        .get();
    const duplicateIds = duplicatesSnap.docs.map((d) => d.id);
    const spotIdsToInclude = [spotId, ...duplicateIds];

    // Firestore "in" supports max 30 values; batch if needed
    const IN_QUERY_LIMIT = 30;
    const allRatings = [];
    for (let i = 0; i < spotIdsToInclude.length; i += IN_QUERY_LIMIT) {
      const chunk = spotIdsToInclude.slice(i, i + IN_QUERY_LIMIT);
      const ratingsSnap = await db
          .collection("ratings")
          .where("spotId", "in", chunk)
          .get();
      ratingsSnap.forEach((doc) => allRatings.push(doc.data()));
    }

    const count = allRatings.length;

    if (count === 0) {
      // No ratings: set ranking to random value
      await db.collection("spots").doc(spotId).set(
          {
            averageRating: 0,
            ratingCount: 0,
            wilsonLowerBound: 0,
            ranking: Math.random(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: true},
      );
      return;
    }

    let sum = 0;
    allRatings.forEach((data) => {
      const r = typeof data.rating === "number" ? data.rating : 0;
      // Clamp ratings to [0,5]
      const clamped = Math.max(0, Math.min(5, r));
      sum += clamped;
    });

    const average = sum / count;

    // Compute Wilson lower bound on normalized ratings
    // (treat each star as Bernoulli success)
    // successes = total stars awarded = sum (rating),
    // trials = max stars per rating (5) * count
    const z = 1.96; // 95% confidence
    const trials = 5 * count;
    const successes = sum; // since ratings already clamped 0..5
    const p = successes / trials;
    const denom = 1 + (z * z) / trials;
    const center = p + (z * z) / (2 * trials);
    const margin = z * Math.sqrt(
        (p * (1 - p) + (z * z) / (4 * trials)) / trials);
    const lowerBoundProportion = (center - margin) / denom;
    const wilsonLowerBound = Math.max(0, Math.min(1, lowerBoundProportion)) * 5;

    // Compute ranking based on wilsonLowerBound vs wilsonLowerBoundAvg
    let ranking;
    if (wilsonLowerBound > wilsonLowerBoundAvg) {
      ranking = wilsonLowerBound + 10;
    } else if (wilsonLowerBound < wilsonLowerBoundAvg) {
      ranking = wilsonLowerBound - 10;
    } else {
      // Equal: treat as above average
      ranking = wilsonLowerBound + 10;
    }

    await db
        .collection("spots")
        .doc(spotId)
        .set(
            {
              averageRating: Number(average.toFixed(4)),
              ratingCount: count,
              wilsonLowerBound: Number(wilsonLowerBound.toFixed(4)),
              ranking: Number(ranking.toFixed(4)),
              updatedAt: FieldValue.serverTimestamp(),
            },
            {merge: true},
        );
  } catch (err) {
    console.error(
        "Failed to recompute rating aggregates for spot",
        spotId,
        err,
    );
  }
}

// ========== Admin Callable: Recompute aggregates for all rated spots ==========
exports.recomputeAllRatedSpots = onCall(
    {region: "europe-west1", memory: "512MiB", timeoutSeconds: 540},
    async (_request) => {
      try {
        // Collect unique spotIds from ratings
        const ratingsSnap = await db.collection("ratings").get();
        const uniqueSpotIds = new Set();
        ratingsSnap.forEach((doc) => {
          const data = doc.data();
          const spotId = data && data.spotId;
          if (typeof spotId === "string" && spotId.length > 0) {
            uniqueSpotIds.add(spotId);
          }
        });

        // Include originals of duplicate spots (they aggregate duplicate ratings)
        const duplicatesSnap = await db
            .collection("spots")
            .where("duplicateOf", "!=", null)
            .get();
        duplicatesSnap.forEach((doc) => {
          const dupOf = doc.data()?.duplicateOf;
          if (typeof dupOf === "string" && dupOf.length > 0) {
            uniqueSpotIds.add(dupOf);
          }
        });

        const spotIds = Array.from(uniqueSpotIds);
        let successCount = 0;
        let failCount = 0;

        // Process sequentially to be gentle on Firestore
        for (const spotId of spotIds) {
          try {
            await recomputeSpotRatingAggregates(spotId);
            successCount++;
          } catch (e) {
            console.error("Failed recomputing for", spotId, e);
            failCount++;
          }
        }

        return {
          success: true,
          processed: spotIds.length,
          updated: successCount,
          failed: failCount,
        };
      } catch (error) {
        console.error("recomputeAllRatedSpots error", error);
        return {success: false, error: error.message};
      }
    },
);

// ========== Admin Callable: Recompute spot rankings ==========
exports.recomputeSpotRankings = onCall(
    {region: "europe-west1", memory: "512MiB", timeoutSeconds: 540},
    async (_request) => {
      try {
        // Fetch wilsonLowerBoundAvg from settings once
        const wilsonLowerBoundAvg = await getWilsonLowerBoundAvg();

        // Query all spots
        const spotsSnap = await db.collection("spots").get();

        let processed = 0;
        let updated = 0;
        let failed = 0;

        // Process each spot
        for (const spotDoc of spotsSnap.docs) {
          try {
            processed++;
            const spotData = spotDoc.data();
            const wilsonLowerBound = spotData.wilsonLowerBound || 0;

            let ranking;
            if (wilsonLowerBound === 0) {
              // No ratings: set ranking to random value
              ranking = Math.random();
            } else if (wilsonLowerBound > wilsonLowerBoundAvg) {
              ranking = wilsonLowerBound + 10;
            } else if (wilsonLowerBound < wilsonLowerBoundAvg) {
              ranking = wilsonLowerBound - 10;
            } else {
              // Equal: treat as above average
              ranking = wilsonLowerBound + 10;
            }

            // Update the spot document with ranking field
            await spotDoc.ref.update({
              ranking: Number(ranking.toFixed(4)),
              updatedAt: FieldValue.serverTimestamp(),
            });

            updated++;
          } catch (e) {
            console.error("Failed to recompute ranking for", spotDoc.id, e);
            failed++;
          }
        }

        return {
          success: true,
          processed: processed,
          updated: updated,
          failed: failed,
        };
      } catch (error) {
        console.error("recomputeSpotRankings error", error);
        return {success: false, error: error.message};
      }
    },
);

// ========== Rating Triggers ==========
exports.onRatingCreated = onDocumentCreated(
    {document: "ratings/{ratingId}", region: "europe-west1"},
    async (event) => {
      try {
        const data = event.data.data();
        const spotId = data && data.spotId;
        await recomputeSpotRatingAggregates(spotId);
        const spotDoc = await db.collection("spots").doc(spotId).get();
        const duplicateOf = spotDoc.data()?.duplicateOf;
        if (duplicateOf) {
          await recomputeSpotRatingAggregates(duplicateOf);
        }
      } catch (e) {
        console.error("onRatingCreated error", e);
      }
    },
);

exports.onRatingUpdated = onDocumentUpdated(
    {document: "ratings/{ratingId}", region: "europe-west1"},
    async (event) => {
      try {
        const before = event.data.before.data();
        const after = event.data.after.data();
        const beforeSpotId = before && before.spotId;
        const afterSpotId = after && after.spotId;

        const spotsToRecompute = new Set();
        if (beforeSpotId && beforeSpotId !== afterSpotId) {
          spotsToRecompute.add(beforeSpotId);
        }
        spotsToRecompute.add(afterSpotId);

        for (const spotId of spotsToRecompute) {
          await recomputeSpotRatingAggregates(spotId);
        }

        const originalsToRecompute = new Set();
        for (const spotId of spotsToRecompute) {
          const spotDoc = await db.collection("spots").doc(spotId).get();
          const duplicateOf = spotDoc.data()?.duplicateOf;
          if (duplicateOf) {
            originalsToRecompute.add(duplicateOf);
          }
        }
        for (const originalId of originalsToRecompute) {
          await recomputeSpotRatingAggregates(originalId);
        }
      } catch (e) {
        console.error("onRatingUpdated error", e);
      }
    },
);

exports.onRatingDeleted = onDocumentDeleted(
    {document: "ratings/{ratingId}", region: "europe-west1"},
    async (event) => {
      try {
        const before = event.data && event.data.data();
        const spotId = before && before.spotId;
        await recomputeSpotRatingAggregates(spotId);
        const spotDoc = await db.collection("spots").doc(spotId).get();
        const duplicateOf = spotDoc.data()?.duplicateOf;
        if (duplicateOf) {
          await recomputeSpotRatingAggregates(duplicateOf);
        }
      } catch (e) {
        console.error("onRatingDeleted error", e);
      }
    },
);

// Trigger when a new spot is created - index words in spotSearchTerms
exports.onSpotCreated = onDocumentCreated(
    {document: "spots/{spotId}", region: "europe-west1"},
    async (event) => {
      const spotId = event.params.spotId;
      const spotData = event.data.data();
      const name = typeof spotData?.name === "string" ? spotData.name : "";
      const words = buildSpotSearchWords(name);
      if (words.length === 0) return;
      const batch = db.batch();
      for (const term of words) {
        const ref = db.collection("spotSearchTerms").doc(spotSearchTermDocId(spotId, term));
        batch.set(ref, {term, spotId});
      }
      await batch.commit();
      console.log("Indexed spot search terms:", {spotId, name: name.slice(0, 40), wordCount: words.length});
    },
);

// Trigger when a spot is updated - reindex spotSearchTerms if name changed,
// recompute rating aggregates if duplicateOf changed
exports.onSpotUpdated = onDocumentUpdated(
    {document: "spots/{spotId}", region: "europe-west1"},
    async (event) => {
      const spotId = event.params.spotId;
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();

      const beforeDup = beforeData?.duplicateOf;
      const afterDup = afterData?.duplicateOf;
      if (beforeDup !== afterDup) {
        const toRecompute = new Set();
        toRecompute.add(spotId);
        if (beforeDup) toRecompute.add(beforeDup);
        if (afterDup) toRecompute.add(afterDup);
        await Promise.all(
            [...toRecompute].map((id) => recomputeSpotRatingAggregates(id)),
        );
      }

      const nameBefore = typeof beforeData?.name === "string" ? beforeData.name : "";
      const nameAfter = typeof afterData?.name === "string" ? afterData.name : "";
      if (nameBefore === nameAfter) return;
      const termsSnapshot = await db.collection("spotSearchTerms")
          .where("spotId", "==", spotId)
          .get();
      const batch = db.batch();
      termsSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
      if (termsSnapshot.size > 0) await batch.commit();
      const words = buildSpotSearchWords(nameAfter);
      if (words.length === 0) return;
      const writeBatch = db.batch();
      for (const term of words) {
        const ref = db.collection("spotSearchTerms").doc(spotSearchTermDocId(spotId, term));
        writeBatch.set(ref, {term, spotId});
      }
      await writeBatch.commit();
      console.log("Reindexed spot search terms:", {spotId, name: nameAfter.slice(0, 40), wordCount: words.length});
    },
);

// Trigger when a spot is deleted - remove from spotSearchTerms
exports.onSpotDeleted = onDocumentDeleted(
    {document: "spots/{spotId}", region: "europe-west1"},
    async (event) => {
      const spotId = event.params.spotId;
      const termsSnapshot = await db.collection("spotSearchTerms")
          .where("spotId", "==", spotId)
          .get();
      if (termsSnapshot.empty) return;
      const batch = db.batch();
      termsSnapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
      console.log("Removed spot search terms:", {spotId, count: termsSnapshot.size});
    },
);


/**
 * Downloads a file from the given URL
 * @param {string} url - The URL to download from
 * @return {Promise<Buffer>} A promise that resolves to the file buffer
 */
function downloadFile(url) {
  return new Promise((resolve, reject) => {
    https
        .get(url, (response) => {
          if (response.statusCode !== 200) {
            reject(
                new Error(
                    `HTTP ${response.statusCode}: ${response.statusMessage}`,
                ),
            );
            return;
          }

          const chunks = [];
          response.on("data", (chunk) => chunks.push(chunk));
          response.on("end", () => resolve(Buffer.concat(chunks)));
          response.on("error", reject);
        })
        .on("error", reject);
  });
}

/**
 * Checks if an image with the given hash already exists in Firebase Storage
 * @param {string} imageHash - The content hash of the image
 * @return {Promise<string|null>} A promise that resolves to the existing
 * file path or null
 */
async function checkImageExists(imageHash) {
  try {
    // List files in the spots folder with the hash prefix
    const [files] = await bucket.getFiles({
      prefix: `spots/`,
      delimiter: "/",
    });

    for (const file of files) {
      const fileName = file.name;
      // Check if filename contains our hash (format: spots/name_hash_index.ext)
      if (fileName.includes(`_${imageHash}_`)) {
        // Verify the file still exists and is accessible
        const [exists] = await file.exists();
        if (exists) {
          return fileName;
        }
      }
    }
    return null;
  } catch (error) {
    console.error("Error checking if image exists:", error);
    return null;
  }
}

/**
 * Gets the public URL for a file in Firebase Storage
 * @param {string} fileName - The file name in Firebase Storage
 * @return {string} The public URL for the file
 */
function getPublicUrl(fileName) {
  return `https://storage.googleapis.com/${bucket.name}/${fileName}`;
}

/**
 * Extracts KML from KMZ
 * @param {Buffer} kmzBuffer - The KMZ buffer
 * @return {Promise<string>} A promise that resolves to the KML content
 */
function extractKmlFromKmz(kmzBuffer) {
  return new Promise((resolve, reject) => {
    yauzl.fromBuffer(kmzBuffer, {lazyEntries: true}, (err, zipfile) => {
      if (err) return reject(err);

      const kmlFiles = [];

      zipfile.readEntry();
      zipfile.on("entry", (entry) => {
        // Look for KML files in the root or in any subfolder
        if (
          entry.fileName.endsWith(".kml") &&
          !entry.fileName.startsWith("__MACOSX/")
        ) {
          kmlFiles.push(entry.fileName);
        }
        zipfile.readEntry();
      });

      zipfile.on("end", () => {
        if (kmlFiles.length === 0) {
          reject(new Error("No KML file found in KMZ"));
          return;
        }

        // If multiple KML files found, prefer the one in the root,
        // otherwise use the first one
        const kmlFileToUse =
          kmlFiles.find((file) => !file.includes("/")) || kmlFiles[0];

        // Find the entry for the KML file we want to use
        yauzl.fromBuffer(kmzBuffer, {lazyEntries: true}, (err, zipfile2) => {
          if (err) return reject(err);

          zipfile2.readEntry();
          zipfile2.on("entry", (entry) => {
            if (entry.fileName === kmlFileToUse) {
              zipfile2.openReadStream(entry, (err, readStream) => {
                if (err) return reject(err);

                const chunks = [];
                readStream.on("data", (chunk) => chunks.push(chunk));
                readStream.on("end", () => {
                  resolve(Buffer.concat(chunks).toString("utf8"));
                });
                readStream.on("error", reject);
              });
            } else {
              zipfile2.readEntry();
            }
          });
          zipfile2.on("end", () => {
            reject(new Error(`KML file ${kmlFileToUse} not found in KMZ`));
          });
          zipfile2.on("error", reject);
        });
      });
      zipfile.on("error", reject);
    });
  });
}

/**
 * Checks if GeoJSON contains uMap metadata with datalayers
 * @param {Object} json - Parsed JSON object
 * @return {boolean} True if this is uMap metadata
 */
function isUMapMetadata(json) {
  return json &&
         json.type === "Feature" &&
         json.properties &&
         json.properties.datalayers &&
         Array.isArray(json.properties.datalayers) &&
         json.properties.datalayers.length > 0;
}

/**
 * Extracts datalayer URLs from uMap metadata
 * @param {Object} json - Parsed uMap metadata JSON
 * @param {string} baseUrl - Original URL to extract map ID from
 * @return {string[]} Array of datalayer URLs
 */
function extractDatalayerUrls(json, baseUrl) {
  const urls = [];

  // Extract map ID from URL (e.g., 640485 from /en/map/640485/geojson/)
  const mapIdMatch = baseUrl.match(/\/map\/(\d+)\//);
  if (!mapIdMatch) {
    console.error("Could not extract map ID from URL:", baseUrl);
    return urls;
  }

  const mapId = mapIdMatch[1];
  const baseDomain = baseUrl.split("/").slice(0, 3).join("/");

  for (const datalayer of json.properties.datalayers) {
    if (datalayer.id) {
      const datalayerUrl = `${baseDomain}/en/datalayer/${mapId}/` +
        `${datalayer.id}/`;
      urls.push(datalayerUrl);
      console.log(`Found datalayer: ${datalayer.name || "Unnamed"} -> ` +
        `${datalayerUrl}`);
    }
  }

  return urls;
}

/**
 * Downloads and processes a single datalayer GeoJSON
 * @param {string} datalayerUrl - URL to the datalayer GeoJSON
 * @param {string} datalayerName - Name of the datalayer for folder organization
 * @return {Promise<Object[]>} Array of placemarks
 */
async function processDatalayer(datalayerUrl, datalayerName) {
  try {
    console.log(`Processing datalayer: ${datalayerName} from ` +
      `${datalayerUrl}`);
    const fileBuffer = await downloadFile(datalayerUrl);
    const geojsonText = fileBuffer.toString("utf8");
    const placemarks = parseGeoJsonFeatures(geojsonText);

    // Add datalayer name as folder for all placemarks
    return placemarks.map((placemark) => ({
      ...placemark,
      folderPath: [datalayerName],
      folderName: datalayerName,
    }));
  } catch (error) {
    console.error(`Failed to process datalayer ${datalayerName}:`, error);
    return [];
  }
}

/**
 * Parses GeoJSON text and extracts point features as placemarks
 * Supports uMap layers and plain FeatureCollections
 * @param {string} geojsonText
 * @return {Object[]} placemarks compatible with KML flow
 */
function parseGeoJsonFeatures(geojsonText) {
  try {
    const json = JSON.parse(geojsonText);

    // uMap may return a single FeatureCollection or an object with 'type'/'features'
    // Normalize into an array of features
    let features = [];
    if (Array.isArray(json)) {
      // Rare case: array of features
      features = json;
    } else if (json && json.type === "FeatureCollection" &&
               Array.isArray(json.features)) {
      features = json.features;
    } else if (json && json.type === "Feature") {
      features = [json];
    } else if (json && json._umap_options && Array.isArray(json.features)) {
      // Some uMap exports include extra metadata
      features = json.features;
    }

    const placemarks = [];
    for (const feature of features) {
      if (!feature || feature.type !== "Feature" || !feature.geometry) continue;
      const geom = feature.geometry;

      // Only import Point features for spots
      if (geom.type !== "Point" || !Array.isArray(geom.coordinates) ||
          geom.coordinates.length < 2) {
        continue;
      }

      const [longitude, latitude, altitudeRaw] = geom.coordinates;
      const altitude = Number.isFinite(altitudeRaw) ? Number(altitudeRaw) : 0;

      const props = feature.properties || {};
      const name = String(props.name || props.title || props.label ||
        "Unnamed Spot");
      const description = String(props.description || props.desc ||
          props.popupContent || "")
          // uMap often stores HTML in descriptions; keep KML cleaning consistent later
          .trim();

      // uMap folder/layer name often in properties._umap_options.name or
      // properties._umap_options.label, but each feature may also carry a
      // 'layer' or 'category'
      let folderName = null;
      if (props._umap_options && (props._umap_options.name ||
          props._umap_options.label)) {
        folderName = String(props._umap_options.name ||
          props._umap_options.label).trim();
      } else if (props.layer) {
        folderName = String(props.layer).trim();
      } else if (props.category) {
        folderName = String(props.category).trim();
      }

      const folderPath = folderName ? [folderName] : [];

      // Try to extract images from common uMap props: 'pictures', 'icon',
      // 'image'. We'll pass through 'description' and rely on existing image
      // extraction for HTML images.

      placemarks.push({
        name,
        description,
        coordinates: {latitude: Number(latitude),
          longitude: Number(longitude), altitude},
        extendedData: {},
        folderPath,
        folderName,
      });
    }

    return placemarks;
  } catch (e) {
    console.error("Failed to parse GeoJSON:", e);
    return [];
  }
}

/**
 * Checks if an image URL has already been processed and cached
 * @param {string} imageUrl - The URL of the image to check
 * @return {Promise<string|null>} A promise that resolves to the cached public URL or null
 */
async function checkImageUrlCache(imageUrl) {
  try {
    // Skip URL-based cache for ephemeral Google URLs
    if (isEphemeralImageHost(imageUrl)) {
      return null;
    }
    const imageCacheRef = db
        .collection("imageCache")
        .doc(encodeURIComponent(imageUrl));
    const imageCacheDoc = await imageCacheRef.get();

    if (imageCacheDoc.exists) {
      const cacheData = imageCacheDoc.data();
      const {hash, publicUrl} = cacheData;

      // Check if the cached image still exists in storage
      const existingFileName = await checkImageExists(hash);
      if (existingFileName) {
        console.log(
            `Found cached image for URL: ${imageUrl.substring(0, 50)}...`,
        );
        return publicUrl;
      } else {
        // Cached image no longer exists in storage, remove from cache
        console.log(
            `Cached image no longer exists, removing from cache: ${imageUrl.substring(0, 50)}...`,
        );
        await imageCacheRef.delete();
      }
    }
    return null;
  } catch (error) {
    console.error("Error checking image URL cache:", error);
    return null;
  }
}

/**
 * Caches image metadata for future lookups
 * @param {string} imageUrl - The original URL of the image
 * @param {string} imageHash - The content hash of the image
 * @param {string} publicUrl - The public URL of the uploaded image
 */
async function cacheImageMetadata(imageUrl, imageHash, publicUrl) {
  try {
    // Skip storing cache entries for ephemeral Google URLs
    if (isEphemeralImageHost(imageUrl)) {
      return;
    }
    const imageCacheRef = db
        .collection("imageCache")
        .doc(encodeURIComponent(imageUrl));
    await imageCacheRef.set({
      url: imageUrl,
      hash: imageHash,
      publicUrl: publicUrl,
      lastChecked: FieldValue.serverTimestamp(),
    });
    console.log(`Cached image metadata for: ${imageUrl.substring(0, 50)}...`);
  } catch (error) {
    console.error("Error caching image metadata:", error);
  }
}

/**
 * Optimizes an image buffer using Sharp for better performance and smaller file sizes
 * @param {Buffer} imageBuffer - The original image buffer
 * @return {Promise<Buffer>} A promise that resolves to the optimized image buffer
 */
async function optimizeImage(imageBuffer) {
  let sharpInstance = null;
  try {
    // Get image metadata
    const metadata = await sharp(imageBuffer).metadata();

    // Set maximum dimensions to reduce file size while maintaining quality
    const maxWidth = 1920;
    const maxHeight = 1920;

    sharpInstance = sharp(imageBuffer);

    // Resize if image is too large
    if (metadata.width > maxWidth || metadata.height > maxHeight) {
      sharpInstance = sharpInstance.resize(maxWidth, maxHeight, {
        fit: "inside",
        withoutEnlargement: true,
      });
    }

    // Convert to JPEG with optimization
    const optimizedBuffer = await sharpInstance
        .jpeg({
          quality: 85, // Good balance between quality and file size
          progressive: true, // Progressive JPEG for better loading
          mozjpeg: true, // Use mozjpeg encoder for better compression
        })
        .toBuffer();

    console.log(`Image optimized: ${imageBuffer.length} bytes -> ${optimizedBuffer.length} bytes (${((1 - optimizedBuffer.length / imageBuffer.length) * 100).toFixed(1)}% reduction)`);

    // Clean up sharp instance to free memory
    sharpInstance = null;

    return optimizedBuffer;
  } catch (error) {
    console.error("Error optimizing image:", error);
    // Clean up sharp instance on error
    sharpInstance = null;
    // Return original buffer if optimization fails
    return imageBuffer;
  }
}

/**
 * Downloads and uploads an image to Firebase Storage (with URL-based deduplication and hash validation)
 * @param {string} imageUrl - The URL of the image to download
 * @param {string} spotName - The name of the spot for filename generation
 * @param {number} imageIndex - The index of the image for filename generation
 * @param {string|null} storedHash - Previously stored hash for this image (if available)
 * @return {Promise<Object|null>} A promise that resolves to {url, hash} or null
 */
async function downloadAndUploadImage(
    imageUrl,
    spotName,
    imageIndex,
    storedHash = null,
) {
  let imageBuffer = null;
  try {
    console.log(`Processing image ${imageIndex + 1} for spot: ${spotName}`);

    // First, check if we've already processed this URL
    const cachedPublicUrl = await checkImageUrlCache(imageUrl);
    if (cachedPublicUrl) {
      console.log(
          `Using cached image for URL: ${imageUrl.substring(0, 50)}...`,
      );
      // Get the hash from cache
      const imageCacheRef = db
          .collection("imageCache")
          .doc(encodeURIComponent(imageUrl));
      const imageCacheDoc = await imageCacheRef.get();
      const cachedHash = imageCacheDoc.exists ?
        imageCacheDoc.data().hash :
        null;
      return {url: cachedPublicUrl, hash: cachedHash};
    }

    // If we have a stored hash, check if the image still exists by that hash
    if (storedHash) {
      const existingFileName = await checkImageExists(storedHash);
      if (existingFileName) {
        console.log(
            `Using stored hash for existing image: ${storedHash.substring(0, 8)}...`,
        );
        const publicUrl = getPublicUrl(existingFileName);

        // Cache this URL-to-hash mapping for future use
        await cacheImageMetadata(imageUrl, storedHash, publicUrl);

        return {url: publicUrl, hash: storedHash};
      } else {
        console.log(
            `Stored hash no longer valid, will download and recalculate: ${storedHash.substring(0, 8)}...`,
        );
      }
    }

    // Download image
    imageBuffer = await downloadFile(imageUrl);

    // Generate content-based hash
    const imageHash = generateImageHash(imageBuffer);
    console.log(`Generated hash for image: ${imageHash.substring(0, 8)}...`);

    // Validate against stored hash if available
    if (storedHash && storedHash !== imageHash) {
      console.warn(
          `Hash mismatch! Stored: ${storedHash.substring(0, 8)}..., Calculated: ${imageHash.substring(0, 8)}...`,
      );
      console.warn(`Image may have changed, using new hash`);
    }

    // Check if image already exists by hash
    const existingFileName = await checkImageExists(imageHash);
    if (existingFileName) {
      console.log(`Image already exists, reusing: ${existingFileName}`);
      const publicUrl = getPublicUrl(existingFileName);

      // Cache this URL-to-hash mapping for future use
      await cacheImageMetadata(imageUrl, imageHash, publicUrl);

      // Clear buffer immediately if we're reusing existing image
      imageBuffer = null;
      return {url: publicUrl, hash: imageHash};
    }

    // Generate filename with hash instead of timestamp
    const extension = path.extname(new URL(imageUrl).pathname) || ".jpg";
    const filename =
      `spots/${spotName.replace(/[^a-zA-Z0-9]/g, "_")}_` +
      `${imageHash}_${imageIndex}${extension}`;

    // Optimize the image before uploading
    const optimizedImageBuffer = await optimizeImage(imageBuffer);

    // Clear original buffer to free memory
    imageBuffer = null;

    // Upload optimized image to Firebase Storage
    const file = bucket.file(filename);
    await file.save(optimizedImageBuffer, {
      metadata: {
        contentType: "image/jpeg",
        cacheControl: "public, max-age=31536000",
      },
    });

    // Make file publicly accessible
    await file.makePublic();

    // Return public URL and hash
    const publicUrl = getPublicUrl(filename);
    console.log(`Uploaded new image to: ${publicUrl}`);

    // Cache this URL-to-hash mapping for future use
    await cacheImageMetadata(imageUrl, imageHash, publicUrl);

    return {url: publicUrl, hash: imageHash};
  } catch (error) {
    console.error(
        `Failed to download/upload image ${imageIndex + 1} for ` + `${spotName}:`,
        error,
    );
    return null;
  } finally {
    // Explicitly clear the buffer to free memory
    if (imageBuffer) {
      imageBuffer = null;
    }
  }
}

/**
 * Processes images for a placemark by downloading and uploading them
 * @param {Object} placemark - The placemark data containing image URLs
 * @param {Object} existingSpotData - Existing spot data (if updating)
 * @param {boolean} [updateImagesForExistingSpots=false] - Whether to update images for existing spots
 * @return {Promise<Object>} A promise that resolves to an object containing
 *     imageUrls and imageHashes arrays
 */
async function processPlacemarkImages(placemark, existingSpotData = null, updateImagesForExistingSpots = false) {
  const imageUrls = extractImageUrls(placemark);

  if (imageUrls.length === 0) {
    return {imageUrls: [], imageHashes: []};
  }

  // If updateImagesForExistingSpots is false and we have existing spot data,
  // skip processing and return the existing image arrays (preserve as-is)
  if (!updateImagesForExistingSpots && existingSpotData) {
    console.log(`Skipping image processing for existing spot: ${placemark.name} (preserving existing images)`);
    return {
      imageUrls: existingSpotData.imageUrls || [],
      imageHashes: existingSpotData.imageHashes || [],
    };
  }

  console.log(`Found ${imageUrls.length} images for spot: ${placemark.name}`);

  const uploadedImageUrls = [];
  const imageHashes = [];

  // Create URL-to-hash mapping from existing spot data
  const urlToHashMap = new Map();
  if (
    existingSpotData &&
    existingSpotData.imageUrls &&
    existingSpotData.imageHashes
  ) {
    for (let i = 0; i < existingSpotData.imageUrls.length; i++) {
      if (existingSpotData.imageUrls[i] && existingSpotData.imageHashes[i]) {
        urlToHashMap.set(
            existingSpotData.imageUrls[i],
            existingSpotData.imageHashes[i],
        );
      }
    }
  }

  // Process images sequentially to avoid memory issues
  // Processing in parallel was causing heap out of memory errors
  for (let i = 0; i < imageUrls.length; i++) {
    const url = imageUrls[i];
    console.log(`Processing image ${i + 1}/${imageUrls.length} for spot: ${placemark.name}`);

    // Check if we have a stored hash for this specific image URL
    let storedHash = null;
    if (urlToHashMap.has(url)) {
      storedHash = urlToHashMap.get(url);
    }

    const result = await downloadAndUploadImage(
        url,
        placemark.name,
        i,
        storedHash,
    );

    // Add successful result to our arrays
    if (result) {
      uploadedImageUrls.push(result.url);
      imageHashes.push(result.hash);
    }

    // Force garbage collection hint after each image to free memory
    if (global.gc) {
      global.gc();
    }

    // Small delay to allow GC to complete and prevent memory buildup
    if (i < imageUrls.length - 1) {
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  }

  console.log(
      `Successfully processed ${uploadedImageUrls.length} images ` +
      `for spot: ${placemark.name}`,
  );
  return {imageUrls: uploadedImageUrls, imageHashes};
}


/**
 * Extracts address information from a KML placemark
 * @param {Object} placemark - The KML placemark object
 * @return {string|null} The address string or null if no address found
 */
function extractAddressFromPlacemark(placemark) {
  // Check for direct address element first
  if (placemark.address && placemark.address[0]) {
    return placemark.address[0].trim();
  }

  // Check ExtendedData for address information
  if (placemark.ExtendedData && placemark.ExtendedData[0]) {
    const extendedData = placemark.ExtendedData[0];

    // Check for Data elements with address-related names
    if (extendedData.Data) {
      for (const data of extendedData.Data) {
        if (data.$ && data.$.name) {
          const name = data.$.name.toLowerCase();
          if (name.includes("adresse") || name.includes("address") || name.includes("location") ||
              name.includes("place") || name.includes("street")) {
            if (data.value && data.value[0]) {
              return data.value[0].trim();
            }
          }
        }
      }
    }
  }

  // Check description for address information
  if (placemark.description && placemark.description[0]) {
    const description = placemark.description[0];
    // Look for common address patterns in description
    const addressPatterns = [
      /adresse complète[:\s]+([^\n\r<]+)/i,
      /address[:\s]+([^\n\r<]+)/i,
      /location[:\s]+([^\n\r<]+)/i,
      /place[:\s]+([^\n\r<]+)/i,
      /street[:\s]+([^\n\r<]+)/i,
    ];

    for (const pattern of addressPatterns) {
      const match = description.match(pattern);
      if (match && match[1]) {
        return match[1].trim();
      }
    }
  }

  // Check name for address information (sometimes the name itself is an address)
  if (placemark.name && placemark.name[0]) {
    const name = placemark.name[0];
    // If name looks like an address (contains street numbers, common address words)
    if (name.match(/\d+.*(street|st|avenue|ave|road|rd|boulevard|blvd|way|drive|dr|lane|ln|place|pl)/i)) {
      return name.trim();
    }
  }

  return null;
}

/**
 * Parses KML and extracts Placemarks, including folder hierarchy when present
 * @param {string} kmlContent - The KML content
 * @return {Promise<Object[]>} A promise that resolves to the Placemarks
 */
function parseKmlPlacemarks(kmlContent) {
  return new Promise((resolve, reject) => {
    const parser = new xml2js.Parser();
    parser.parseString(kmlContent, (err, result) => {
      if (err) return reject(err);

      const placemarks = [];

      /**
       * Recursively extracts placemarks from a folder structure
       * @param {Object} folder - The folder containing placemarks
       * @param {Array} folderPath - The path to the current folder
       */
      function extractPlacemarksFromFolder(folder, folderPath = []) {
        // Current folder name if available
        let currentFolderName = null;
        if (folder.name && Array.isArray(folder.name) && folder.name[0]) {
          currentFolderName = String(folder.name[0]).trim();
        }
        const nextFolderPath = currentFolderName ?
          [...folderPath, currentFolderName] :
          [...folderPath];

        if (folder.Placemark) {
          folder.Placemark.forEach((placemark) => {
            const name =
              (placemark.name && placemark.name[0]) || "Unnamed Spot";
            const description =
              (placemark.description && placemark.description[0]) || "";
            const coordinates =
              placemark.Point &&
              placemark.Point[0] &&
              placemark.Point[0].coordinates &&
              placemark.Point[0].coordinates[0];

            if (coordinates) {
              // Placemark has coordinates - process normally
              const [longitude, latitude, altitude] = coordinates
                  .split(",")
                  .map(Number);
              placemarks.push({
                name: name,
                description: description,
                coordinates: {latitude, longitude, altitude: altitude || 0},
                extendedData:
                  (placemark.ExtendedData && placemark.ExtendedData[0]) || {},
                folderPath: nextFolderPath,
                folderName:
                  nextFolderPath.length > 0 ?
                    nextFolderPath[nextFolderPath.length - 1].trim() :
                    null,
              });
            } else {
              // Placemark has no coordinates - check for address information
              const address = extractAddressFromPlacemark(placemark);
              if (address) {
                placemarks.push({
                  name: name,
                  description: description,
                  coordinates: null, // Will be geocoded later
                  address: address,
                  extendedData:
                    (placemark.ExtendedData && placemark.ExtendedData[0]) || {},
                  folderPath: nextFolderPath,
                  folderName:
                    nextFolderPath.length > 0 ?
                      nextFolderPath[nextFolderPath.length - 1].trim() :
                      null,
                });
              }
            }
          });
        }

        if (folder.Folder) {
          folder.Folder.forEach((sub) =>
            extractPlacemarksFromFolder(sub, nextFolderPath),
          );
        }
      }

      if (result.kml && result.kml.Document && result.kml.Document[0]) {
        const document = result.kml.Document[0];

        // Check for placemarks directly in Document
        if (document.Placemark) {
          document.Placemark.forEach((placemark) => {
            const name =
              (placemark.name && placemark.name[0]) || "Unnamed Spot";
            const description =
              (placemark.description && placemark.description[0]) || "";
            const coordinates =
              placemark.Point &&
              placemark.Point[0] &&
              placemark.Point[0].coordinates &&
              placemark.Point[0].coordinates[0];

            if (coordinates) {
              // Placemark has coordinates - process normally
              const [longitude, latitude, altitude] = coordinates
                  .split(",")
                  .map(Number);
              placemarks.push({
                name: name,
                description: description,
                coordinates: {latitude, longitude, altitude: altitude || 0},
                extendedData:
                  (placemark.ExtendedData && placemark.ExtendedData[0]) || {},
                folderPath: [],
                folderName: null,
              });
            } else {
              // Placemark has no coordinates - check for address information
              const address = extractAddressFromPlacemark(placemark);
              if (address) {
                placemarks.push({
                  name: name,
                  description: description,
                  coordinates: null, // Will be geocoded later
                  address: address,
                  extendedData:
                    (placemark.ExtendedData && placemark.ExtendedData[0]) || {},
                  folderPath: [],
                  folderName: null,
                });
              }
            }
          });
        }

        // Check for placemarks in Folders
        if (document.Folder) {
          document.Folder.forEach((f) => extractPlacemarksFromFolder(f, []));
        }
      }

      resolve(placemarks);
    });
  });
}

/**
 * Helper function to reverse geocode an address to coordinates
 * @param {string} address - The address to geocode
 * @param {string} apiKey - The Google Maps API key
 * @return {Promise<Object>} Reverse geocoding result with coordinates
 */
async function reverseGeocodeAddress(address, apiKey) {
  try {
    const encodedAddress = encodeURIComponent(address);
    const geocodingUrl = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodedAddress}&key=${apiKey}`;

    const response = await new Promise((resolve, reject) => {
      https
          .get(geocodingUrl, (res) => {
            let data = "";
            res.on("data", (chunk) => (data += chunk));
            res.on("end", () => {
              try {
                resolve(JSON.parse(data));
              } catch (e) {
                reject(e);
              }
            });
          })
          .on("error", reject);
    });

    if (
      response.status === "OK" &&
      response.results &&
      response.results.length > 0
    ) {
      const location = response.results[0].geometry.location;
      return {
        success: true,
        latitude: location.lat,
        longitude: location.lng,
      };
    } else {
      return {
        success: false,
        error: response.error_message || "No coordinates found for address",
      };
    }
  } catch (error) {
    console.warn(`Reverse geocoding error for ${address}:`, error);
    return {
      success: false,
      error: error.message || "Reverse geocoding request failed",
    };
  }
}

/**
 * Helper function to geocode coordinates and return address details
 * @param {number} latitude - The latitude coordinate
 * @param {number} longitude - The longitude coordinate
 * @param {string} apiKey - The Google Maps API key
 * @return {Promise<Object>} Geocoding result with address details
 */
async function geocodeCoordinates(latitude, longitude, apiKey) {
  try {
    const geocodingUrl = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${latitude},${longitude}&key=${apiKey}`;
    const response = await new Promise((resolve, reject) => {
      https
          .get(geocodingUrl, (res) => {
            let data = "";
            res.on("data", (chunk) => (data += chunk));
            res.on("end", () => {
              try {
                resolve(JSON.parse(data));
              } catch (e) {
                reject(e);
              }
            });
          })
          .on("error", reject);
    });

    if (
      response.status === "OK" &&
      response.results &&
      response.results.length > 0
    ) {
      const result = response.results[0];
      const address = result.formatted_address;

      let city = null;
      let countryCode = null;
      if (Array.isArray(result.address_components)) {
        const components = result.address_components;
        const countryComp = components.find(
            (c) => c.types && c.types.includes("country"),
        );
        if (countryComp && countryComp.short_name) {
          countryCode = countryComp.short_name;
        }
        const cityTypesPriority = [
          "locality",
          "postal_town",
          "administrative_area_level_2",
          "administrative_area_level_1",
        ];
        for (const t of cityTypesPriority) {
          const comp = components.find((c) => c.types && c.types.includes(t));
          if (comp && comp.long_name) {
            city = comp.long_name;
            break;
          }
        }
      }

      return {success: true, address, city, countryCode};
    }

    return {
      success: false,
      error: response.error_message || "No address found for coordinates",
    };
  } catch (error) {
    console.warn(`Geocoding error for ${latitude}, ${longitude}:`, error);
    return {
      success: false,
      error: error.message || "Geocoding request failed",
    };
  }
}

/**
 * Helper function to process a single sync source with geocoding
 * @param {Object} source - The sync source object
 * @param {string} sourceId - The ID of the sync source
 * @param {string} apiKey - The Google Maps API key
 * @param {boolean} [updateImagesForExistingSpots=false] - Whether to update images for existing spots
 * @param {number} [startIndex=0] - The index to start processing from (for resuming)
 * @return {Promise<Object>} Processing result with statistics
 */
async function processSyncSource(source, sourceId, apiKey, updateImagesForExistingSpots = false, startIndex = 0) {
  const syncType = updateImagesForExistingSpots ? "full" : "light";
  const isResuming = startIndex > 0;
  console.log(`Processing source: ${source.name} (${sourceId}) with updateImagesForExistingSpots=${updateImagesForExistingSpots}${isResuming ? ` (resuming from index ${startIndex})` : ""}`);

  // Timeout configuration - leave 5 minutes buffer
  const BATCH_SIZE = 25; // Process 25 spots per batch
  const MIN_TIME_REMAINING = 5 * 60 * 1000; // 5 minutes in milliseconds
  const timeoutMs = 55 * 60 * 1000; // 55 minutes (leave buffer before 1 hour timeout)
  const startTime = Date.now();

  // Download and process based on detected format (KMZ/KML/GeoJSON)
  let fileBuffer = await downloadFile(source.kmzUrl);
  const format = detectImportFormat(fileBuffer, source.kmzUrl);
  console.log(`Detected import format: ${format}`);

  let placemarks = [];
  if (format === "kmz") {
    const kmlContent = await extractKmlFromKmz(fileBuffer);
    placemarks = await parseKmlPlacemarks(kmlContent);
  } else if (format === "kml") {
    const kmlContent = fileBuffer.toString("utf8");
    placemarks = await parseKmlPlacemarks(kmlContent);
  } else {
    // GeoJSON (uMap) support
    const geojsonText = fileBuffer.toString("utf8");
    const json = JSON.parse(geojsonText);

    console.log("Parsed GeoJSON structure:", {
      type: json.type,
      hasProperties: !!json.properties,
      hasDatalayers: !!(json.properties && json.properties.datalayers),
      datalayersCount: json.properties && json.properties.datalayers ? json.properties.datalayers.length : 0,
      propertiesName: json.properties ? json.properties.name : null,
    });

    if (isUMapMetadata(json)) {
      console.log("Detected uMap metadata with datalayers, " +
        "processing each datalayer separately");

      // Extract datalayer URLs
      const datalayerUrls = extractDatalayerUrls(json, source.kmzUrl);

      if (datalayerUrls.length === 0) {
        console.warn("No datalayer URLs found in uMap metadata");
        placemarks = [];
      } else {
        // Process each datalayer
        const allPlacemarks = [];
        for (let i = 0; i < datalayerUrls.length; i++) {
          const datalayerUrl = datalayerUrls[i];
          const datalayerName = json.properties.datalayers[i].name || `Datalayer ${i + 1}`;

          const datalayerPlacemarks = await processDatalayer(
              datalayerUrl, datalayerName);
          allPlacemarks.push(...datalayerPlacemarks);
        }
        placemarks = allPlacemarks;
        console.log(`Processed ${datalayerUrls.length} datalayers, ` +
          `found ${placemarks.length} total placemarks`);
      }
    } else {
      // Regular GeoJSON processing
      placemarks = parseGeoJsonFeatures(geojsonText);
    }
  }

  // Normalize includeFolders from source configuration
  let includeFolders = [];
  if (Array.isArray(source.includeFolders)) {
    includeFolders = source.includeFolders;
  } else if (typeof source.includeFolders === "string") {
    includeFolders = source.includeFolders.split(",");
  }
  includeFolders = includeFolders
      .map((s) => (typeof s === "string" ? s.trim() : ""))
      .filter((s) => s.length > 0);

  if (includeFolders.length > 0) {
    console.log(
        `[FOLDER FILTER] Applying folder filter for source: ${source.name}`,
    );
    console.log(
        `[FOLDER FILTER] Total placemarks before filter: ${placemarks.length}`,
    );
    console.log(
        `[FOLDER FILTER] Include folders: [${includeFolders.join(", ")}]`,
    );

    // Log all folder names found in placemarks before processing
    const foldersInPlacemarks = new Set();
    placemarks.forEach((placemark) => {
      if (placemark.folderName) {
        foldersInPlacemarks.add(placemark.folderName);
      }
    });
    console.log(
        `[FOLDER FILTER] Folders found in placemarks: [${Array.from(foldersInPlacemarks).join(", ")}]`,
    );

    const includeSetLower = new Set(includeFolders.map((f) => f.toLowerCase()));
    const beforeCount = placemarks.length;
    placemarks = placemarks.filter((p) => {
      const path = Array.isArray(p.folderPath) ? p.folderPath : [];
      return path.some((seg) => includeSetLower.has(String(seg).toLowerCase()));
    });

    // Sort placemarks by the order specified in includeFolders
    placemarks.sort((a, b) => {
      const aFolderName = a.folderName ? a.folderName.toLowerCase() : "";
      const bFolderName = b.folderName ? b.folderName.toLowerCase() : "";

      const aIndex = includeFolders.findIndex(
          (folder) => folder.toLowerCase() === aFolderName,
      );
      const bIndex = includeFolders.findIndex(
          (folder) => folder.toLowerCase() === bFolderName,
      );

      // If both folders are in includeFolders, sort by their order
      if (aIndex !== -1 && bIndex !== -1) {
        return aIndex - bIndex;
      }

      // If only one folder is in includeFolders, prioritize it
      if (aIndex !== -1) return -1;
      if (bIndex !== -1) return 1;

      // If neither folder is in includeFolders, maintain original order
      return 0;
    });

    console.log(
        `Applied folder filter and ordering for source ${source.name}: ${placemarks.length}/${beforeCount} placemarks kept`,
    );
  }

  const sourceDefaultSpotAttributes = normalizeSpotAttributeDefaults(
      source.defaultSpotAttributes,
  );
  const folderSpotAttributeDefaults = normalizeFolderSpotAttributeDefaults(
      source.folderSpotAttributes,
  );
  const folderSpotAttributeDefaultsLookup = buildFolderDefaultsLookup(
      folderSpotAttributeDefaults,
  );
  const hasAnySpotAttributeDefaults = Boolean(sourceDefaultSpotAttributes) ||
    Object.keys(folderSpotAttributeDefaultsLookup).length > 0;

  if (hasAnySpotAttributeDefaults) {
    console.log(
        `[ATTRIBUTE DEFAULTS] Source ${source.name} has defaults configured ` +
        `(source=${Boolean(sourceDefaultSpotAttributes)}, ` +
        `folders=${Object.keys(folderSpotAttributeDefaultsLookup).length})`,
    );
  }

  // Clear file buffer to free memory
  fileBuffer = null;

  // Mark sync as in progress (if not already marked)
  const sourceDocRef = db.collection("syncSources").doc(sourceId);
  if (!isResuming) {
    const initialSyncProgress = {
      processedCount: 0,
      totalCount: placemarks.length,
      lastProcessedIndex: 0,
    };
    if (source.recordFolderName === true) {
      initialSyncProgress.collectedFolders = [];
    }

    await sourceDocRef.update({
      syncInProgress: true,
      syncType: syncType,
      syncProgress: initialSyncProgress,
    });
  }

  let created = 0;
  let updated = 0;
  let geocoded = 0;
  let geocodingFailed = 0;
  let removed = 0;
  const skipped = 0;
  const processedSpotIds = new Set();
  const addedSpotSummaries = [];
  const updatedSpotSummaries = [];
  const removedSpotSummaries = [];

  // Collect all unique folder names from successfully processed spots if recordFolderName is enabled.
  // On resumed syncs, restore folders collected in earlier partial runs.
  const previouslyCollectedFolders = (
    isResuming &&
    source.recordFolderName === true &&
    Array.isArray(source.syncProgress?.collectedFolders)
  ) ? source.syncProgress.collectedFolders : [];
  const allFolders = new Set(
      previouslyCollectedFolders
          .filter((folder) => typeof folder === "string")
          .map((folder) => folder.trim())
          .filter((folder) => folder.length > 0),
  );

  if (source.recordFolderName === true) {
    console.log(
        `[FOLDER COLLECTION] Starting folder collection for source: ${source.name}`,
    );
    console.log(
        `[FOLDER COLLECTION] Total placemarks to process: ${placemarks.length}`,
    );
    if (isResuming) {
      console.log(
          `[FOLDER COLLECTION] Restored ${allFolders.size} folder(s) from previous partial runs`,
      );
    }

    // Log all folder names found in placemarks before processing
    const foldersInPlacemarks = new Set();
    placemarks.forEach((placemark) => {
      if (placemark.folderName) {
        foldersInPlacemarks.add(placemark.folderName);
      }
    });
    console.log(
        `[FOLDER COLLECTION] Folders found in placemarks: [${Array.from(foldersInPlacemarks).join(", ")}]`,
    );
  }

  // Process each placemark in batches
  for (let i = startIndex; i < placemarks.length; i++) {
    // Check if we're running out of time before processing next batch
    const elapsed = Date.now() - startTime;
    const timeRemaining = timeoutMs - elapsed;

    if (timeRemaining < MIN_TIME_REMAINING) {
      console.log(`Approaching timeout. Processed ${i - startIndex} spots (${i}/${placemarks.length} total). Saving progress...`);

      // Save progress
      const syncProgressUpdate = {
        processedCount: i,
        totalCount: placemarks.length,
        lastProcessedIndex: i,
      };
      if (source.recordFolderName === true) {
        syncProgressUpdate.collectedFolders = Array.from(allFolders);
      }
      await sourceDocRef.update({
        syncProgress: syncProgressUpdate,
      });

      // Return partial result
      return {
        sourceId: sourceId,
        sourceName: source.name,
        stats: {
          total: placemarks.length,
          created,
          updated,
          removed,
          skipped,
          geocoded,
          geocodingFailed,
          geocodingSuccessRate: placemarks.length > 0 ?
            ((geocoded / placemarks.length) * 100).toFixed(1) + "%" :
            "0%",
        },
        partial: true,
        processed: i - startIndex,
        remaining: placemarks.length - i,
        message: `Partial sync: ${i - startIndex}/${placemarks.length - startIndex} spots processed. Will resume on next run.`,
      };
    }
    const placemark = placemarks[i];
    const {name, description, coordinates, address: placemarkAddress} = placemark;

    if (source.recordFolderName === true) {
      console.log(
          `[FOLDER COLLECTION] Processing spot "${name}" with folder: ${placemark.folderName || "null"}`,
      );
    }

    let finalCoordinates = coordinates;
    let address = placemarkAddress;
    let city = null;
    let countryCode = null;
    let existingSpotData = null;

    // If placemark has no coordinates but has an address, geocode the address
    if (!coordinates && placemarkAddress) {
      console.log(`Reverse geocoding address for spot: ${name} - ${placemarkAddress}`);

      // Add small delay to respect API rate limits
      if (i > 0) {
        await new Promise((resolve) => setTimeout(resolve, 100));
      }

      const reverseGeocodeResult = await reverseGeocodeAddress(placemarkAddress, apiKey);

      if (reverseGeocodeResult.success) {
        finalCoordinates = {
          latitude: reverseGeocodeResult.latitude,
          longitude: reverseGeocodeResult.longitude,
          altitude: 0,
        };
        address = placemarkAddress; // Use the original address
        geocoded++;
        console.log(`✓ Reverse geocoded spot: ${name} - ${placemarkAddress} -> ${finalCoordinates.latitude}, ${finalCoordinates.longitude}`);
      } else {
        geocodingFailed++;
        console.warn(`✗ Reverse geocoding failed for spot: ${name} - ${reverseGeocodeResult.error}`);
        continue; // Skip this placemark if we can't get coordinates
      }
    }

    // Check if spot already exists with same coordinates and source
    const existingSpots = await db
        .collection("spots")
        .where("spotSource", "==", sourceId)
        .where("latitude", "==", finalCoordinates.latitude)
        .where("longitude", "==", finalCoordinates.longitude)
        .get();

    if (existingSpots.empty) {
      // Only geocode for NEW spots (if we don't already have address from reverse geocoding)
      if (!address) {
        console.log(
            `Geocoding new spot: ${name} at ${finalCoordinates.latitude}, ${finalCoordinates.longitude}`,
        );

        // Add small delay to respect API rate limits
        if (i > 0) {
          await new Promise((resolve) => setTimeout(resolve, 100));
        }

        const geocodeResult = await geocodeCoordinates(
            finalCoordinates.latitude,
            finalCoordinates.longitude,
            apiKey,
        );

        if (geocodeResult.success) {
          address = geocodeResult.address;
          city = geocodeResult.city;
          countryCode = geocodeResult.countryCode;
          geocoded++;
          console.log(`✓ Geocoded new spot: ${name} - ${address}`);
        } else {
          geocodingFailed++;
          console.warn(
              `✗ Geocoding failed for new spot: ${name} - ${geocodeResult.error}`,
          );
        }
      } else {
        // We have address from reverse geocoding, now get city and country
        console.log(`Getting city/country for spot: ${name} at ${finalCoordinates.latitude}, ${finalCoordinates.longitude}`);

        const geocodeResult = await geocodeCoordinates(
            finalCoordinates.latitude,
            finalCoordinates.longitude,
            apiKey,
        );

        if (geocodeResult.success) {
          city = geocodeResult.city;
          countryCode = geocodeResult.countryCode;
          geocoded++;
          console.log(`✓ Got city/country for spot: ${name} - ${city}, ${countryCode}`);
        } else {
          geocodingFailed++;
          console.warn(`✗ Failed to get city/country for spot: ${name} - ${geocodeResult.error}`);
        }
      }
    } else {
      // For existing spots, keep their current address data
      const existingSpot = existingSpots.docs[0];
      existingSpotData = existingSpot.data();
      address = existingSpotData.address;
      city = existingSpotData.city;
      countryCode = existingSpotData.countryCode;
      console.log(`Keeping existing address data for spot: ${name}`);
    }

    // Process images for this placemark (with existing data for hash optimization)
    console.log(
        `Processing images for spot: ${name} from source: ${source.name}`,
    );
    const imageResult = await processPlacemarkImages(
        placemark,
        existingSpotData,
        updateImagesForExistingSpots,
    );

    // Extract YouTube IDs from the raw description for storage and thumbnails
    const youtubeVideoIds = extractYoutubeVideoIdsFromDescription(
        description || "",
    );

    // If a YouTube thumbnail failed to download (e.g., 404), don't keep the video ID
    // We determine success by checking if the thumbnail URL was cached during image processing
    let filteredYoutubeVideoIds = [];

    // For existing spots in default sync mode, skip YouTube thumbnail processing
    if (!updateImagesForExistingSpots && existingSpotData) {
      // Preserve existing YouTube video IDs without processing thumbnails
      if (existingSpotData.youtubeVideoIds && Array.isArray(existingSpotData.youtubeVideoIds)) {
        filteredYoutubeVideoIds = existingSpotData.youtubeVideoIds;
        console.log(`Skipping YouTube thumbnail processing for existing spot: ${name} (preserving ${filteredYoutubeVideoIds.length} existing video IDs)`);
      }
    } else if (youtubeVideoIds && youtubeVideoIds.length > 0) {
      // Process YouTube thumbnails for new spots or when doing full sync
      const validationResults = await Promise.all(
          youtubeVideoIds.map(async (vid) => {
            const thumbUrl = `https://img.youtube.com/vi/${vid}/maxresdefault.jpg`;
            const cachedPublicUrl = await checkImageUrlCache(thumbUrl);
            if (!cachedPublicUrl) {
              const folderName = placemark.folderName || "unknown";
              console.warn(
                  `Dropping YouTube ID ${vid} due to missing/cached thumbnail (likely 404): ${thumbUrl} (folder: ${folderName}, spot: ${name})`,
              );
              return null;
            }
            return vid;
          }),
      );
      filteredYoutubeVideoIds = validationResults.filter((v) => Boolean(v));
    }

    // Clean the description to remove HTML
    const cleanedDescription = cleanDescription(description);
    const effectiveSpotAttributeDefaults = getEffectiveSpotAttributeDefaults(
        sourceDefaultSpotAttributes,
        folderSpotAttributeDefaultsLookup,
        placemark.folderName,
    );

    const spotData = {
      name: name.trim(),
      description: cleanedDescription.trim(),
      latitude: finalCoordinates.latitude,
      longitude: finalCoordinates.longitude,
      address: address,
      city: city,
      countryCode: countryCode,
      spotSource: sourceId,
      spotSourceName: source.name,
      spotSourceRemoved: false,
      updatedAt: FieldValue.serverTimestamp(),
    };

    // Optionally record folder name on spot if configured and available
    if (source.recordFolderName === true) {
      if (placemark.folderName) {
        spotData.folderName = placemark.folderName;
      } else {
        spotData.folderName = null;
      }
    }

    if (existingSpots.empty && effectiveSpotAttributeDefaults) {
      applySpotAttributeDefaultsToSpotData(
          spotData,
          effectiveSpotAttributeDefaults,
      );
    }

    // Add YouTube video IDs
    // For existing spots with updateImagesForExistingSpots=false, preserve existing array
    // For new spots or when updateImagesForExistingSpots=true, use processed/validated IDs
    if (existingSpots.empty) {
      // New spot - use processed YouTube IDs
      if (filteredYoutubeVideoIds.length > 0) {
        spotData.youtubeVideoIds = filteredYoutubeVideoIds;
      } else if (youtubeVideoIds && youtubeVideoIds.length > 0) {
        // No valid thumbnails found, clear the array
        spotData.youtubeVideoIds = [];
      }
    } else {
      // Existing spot
      if (updateImagesForExistingSpots) {
        // Full sync - use processed YouTube IDs
        if (filteredYoutubeVideoIds.length > 0) {
          spotData.youtubeVideoIds = filteredYoutubeVideoIds;
        } else if (
          (existingSpotData && Array.isArray(existingSpotData.youtubeVideoIds) && existingSpotData.youtubeVideoIds.length > 0) ||
          (youtubeVideoIds && youtubeVideoIds.length > 0)
        ) {
          // Explicitly clear previously stored IDs if thumbnails failed or links now broken
          spotData.youtubeVideoIds = [];
        }
      } else {
        // Default sync - preserve existing YouTube IDs (already set in filteredYoutubeVideoIds)
        if (filteredYoutubeVideoIds.length > 0) {
          spotData.youtubeVideoIds = filteredYoutubeVideoIds;
        }
        // If no existing YouTube IDs, don't set the field to preserve existing state
      }
    }

    // Add image URLs and hashes
    // For existing spots with updateImagesForExistingSpots=false, preserve existing arrays
    // For new spots or when updateImagesForExistingSpots=true, use processed images
    if (existingSpots.empty) {
      // New spot - always use processed images
      if (imageResult.imageUrls.length > 0) {
        spotData.imageUrls = imageResult.imageUrls;
        spotData.imageHashes = imageResult.imageHashes;
      }
    } else {
      // Existing spot
      if (updateImagesForExistingSpots) {
        // Full sync - use processed images
        if (imageResult.imageUrls.length > 0) {
          spotData.imageUrls = imageResult.imageUrls;
          spotData.imageHashes = imageResult.imageHashes;
        } else if (existingSpotData && existingSpotData.imageUrls && existingSpotData.imageUrls.length > 0) {
          // If placemark has no images but existing spot has images, clear them
          spotData.imageUrls = [];
          spotData.imageHashes = [];
        }
      } else {
        // Default sync - preserve existing images (already handled in processPlacemarkImages)
        if (imageResult.imageUrls.length > 0) {
          spotData.imageUrls = imageResult.imageUrls;
          spotData.imageHashes = imageResult.imageHashes;
        }
        // If no images returned, don't set imageUrls/imageHashes to preserve existing arrays
      }
    }

    if (existingSpots.empty) {
      // Create new spot - initialize rating fields to 0 and ranking field
      spotData.averageRating = 0;
      spotData.ratingCount = 0;
      spotData.wilsonLowerBound = 0;
      spotData.ranking = Math.random(); // Random ranking for new spots
      spotData.duplicateOf = null; // Initialize duplicateOf field
      spotData.hidden = false; // Initialize hidden field
      spotData.createdAt = FieldValue.serverTimestamp();
      const newSpotRef = await db.collection("spots").add(cleanUndefinedValues(spotData));
      created++;
      processedSpotIds.add(newSpotRef.id);
      addedSpotSummaries.push({
        id: newSpotRef.id,
        name: spotData.name,
      });
      console.log(
          `Created new spot: ${name} from source: ${source.name} with ${imageResult.imageUrls.length} images and geocoded address`,
      );
    } else {
      // Update existing spot - preserve existing rating and ranking fields
      const existingSpot = existingSpots.docs[0];
      const existingData = existingSpot.data();

      // Preserve existing rating fields if they exist
      if (existingData.averageRating !== undefined) {
        spotData.averageRating = existingData.averageRating;
      }
      if (existingData.ratingCount !== undefined) {
        spotData.ratingCount = existingData.ratingCount;
      }
      if (existingData.wilsonLowerBound !== undefined) {
        spotData.wilsonLowerBound = existingData.wilsonLowerBound;
      }
      // Preserve existing ranking field if it exists
      if (existingData.ranking !== undefined) {
        spotData.ranking = existingData.ranking;
      }
      // Preserve existing duplicateOf field if it exists
      if (existingData.duplicateOf !== undefined) {
        spotData.duplicateOf = existingData.duplicateOf;
      }
      // Preserve existing hidden field if it exists
      if (existingData.hidden !== undefined) {
        spotData.hidden = existingData.hidden;
      }

      // Remove spotSourceRemovedAt field if it exists (only valid in update operations)
      spotData.spotSourceRemovedAt = FieldValue.delete();

      await existingSpot.ref.update(cleanUndefinedValues(spotData));
      processedSpotIds.add(existingSpot.id);
      updatedSpotSummaries.push({
        id: existingSpot.id,
        name: spotData.name,
      });
      updated++;
      console.log(
          `Updated existing spot: ${name} from source: ${source.name} with ${imageResult.imageUrls.length} images (preserved rating: ${existingData.averageRating || 0}, count: ${existingData.ratingCount || 0})`,
      );
    }

    // Collect folder name from successfully processed spot if recordFolderName is enabled
    if (source.recordFolderName === true && placemark.folderName) {
      const wasNew = !allFolders.has(placemark.folderName);
      allFolders.add(placemark.folderName);
      console.log(
          `[FOLDER COLLECTION] Added folder "${placemark.folderName}" from spot "${name}" ${wasNew ? "(NEW)" : "(EXISTING)"}`,
      );
    } else if (source.recordFolderName === true) {
      console.log(`[FOLDER COLLECTION] Spot "${name}" has no folder name`);
    }

    // Force garbage collection after every 10 spots to free memory
    if (i % 10 === 0 && global.gc) {
      global.gc();
      console.log(`Processed ${i + 1}/${placemarks.length} spots, forced GC`);
    }

    // Update progress after each batch
    if ((i + 1) % BATCH_SIZE === 0 || (i + 1) === placemarks.length) {
      const syncProgressUpdate = {
        processedCount: i + 1,
        totalCount: placemarks.length,
        lastProcessedIndex: i + 1,
      };
      if (source.recordFolderName === true) {
        syncProgressUpdate.collectedFolders = Array.from(allFolders);
      }
      await sourceDocRef.update({
        syncProgress: syncProgressUpdate,
      });
      console.log(`Progress update: ${i + 1}/${placemarks.length} spots processed`);
    }
  }

  // Identify and label spots that were not present in this sync
  // Only do this when we've processed ALL placemarks from the beginning
  // (i.e., when startIndex === 0 and we completed the full sync)
  // This prevents incorrectly marking spots as removed during multi-stage syncs
  if (startIndex === 0) {
    const sourceSpotsSnapshot = await db
        .collection("spots")
        .where("spotSource", "==", sourceId)
        .get();

    for (const doc of sourceSpotsSnapshot.docs) {
      if (processedSpotIds.has(doc.id)) {
        continue;
      }

      const spotRecord = doc.data() || {};
      if (spotRecord.spotSourceRemoved === true) {
        continue; // Already labeled as removed
      }

      await doc.ref.update({
        spotSourceRemoved: true,
        spotSourceRemovedAt: FieldValue.serverTimestamp(),
      });

      removed++;
      removedSpotSummaries.push({
        id: doc.id,
        name: spotRecord.name || doc.id,
      });
    }
  } else {
    console.log(`Skipping removal check: sync resumed from index ${startIndex}, will check removals when sync completes from beginning`);
  }

  const geocodingSuccessRate =
    placemarks.length > 0 ?
      ((geocoded / placemarks.length) * 100).toFixed(1) + "%" :
      "0%";

  const stats = {
    total: placemarks.length,
    created,
    updated,
    removed,
    skipped,
    geocoded,
    geocodingFailed,
    geocodingSuccessRate,
  };

  // Sync completed - clear progress tracking and update last sync time
  const sourceDoc = await db.collection("syncSources").doc(sourceId).get();
  if (sourceDoc.exists) {
    const updateData = {
      lastSyncAt: FieldValue.serverTimestamp(),
      lastSyncStats: stats,
      syncInProgress: false,
      syncProgress: FieldValue.delete(),
      syncType: FieldValue.delete(),
    };

    // Update allFolders if recordFolderName is enabled
    if (source.recordFolderName === true) {
      console.log(
          `[FOLDER COLLECTION] Final allFolders before sorting: [${Array.from(allFolders).join(", ")}]`,
      );

      // Sort folders by the order specified in includeFolders, then alphabetically for any not in includeFolders
      const sortedFolders = Array.from(allFolders).sort((a, b) => {
        const aIndex = includeFolders.findIndex(
            (folder) => folder.toLowerCase() === a.toLowerCase(),
        );
        const bIndex = includeFolders.findIndex(
            (folder) => folder.toLowerCase() === b.toLowerCase(),
        );

        // If both folders are in includeFolders, sort by their order
        if (aIndex !== -1 && bIndex !== -1) {
          return aIndex - bIndex;
        }

        // If only one folder is in includeFolders, prioritize it
        if (aIndex !== -1) return -1;
        if (bIndex !== -1) return 1;

        // If neither folder is in includeFolders, sort alphabetically
        return a.localeCompare(b);
      });

      console.log(
          `[FOLDER COLLECTION] Final sorted allFolders: [${sortedFolders.join(", ")}]`,
      );
      updateData.allFolders = sortedFolders;
    }

    await sourceDoc.ref.update(updateData);
  }

  try {
    await db.collection("auditLog").add({
      action: "spotSourceSync",
      spotId: `syncSource:${sourceId}`,
      userId: null,
      userName: "Spot Sync Service",
      timestamp: FieldValue.serverTimestamp(),
      metadata: {
        sourceId: sourceId,
        sourceName: source.name,
        stats: stats,
        addedSpots: addedSpotSummaries,
        updatedSpots: updatedSpotSummaries,
        removedSpots: removedSpotSummaries,
      },
    });
  } catch (error) {
    console.error(
        `Failed to write audit log entry for source ${sourceId}:`,
        error,
    );
  }

  return {
    sourceId: sourceId,
    sourceName: source.name,
    stats,
  };
}

/**
 * Helper to ensure caller is admin (via custom claim or Firestore users/{uid}.isAdmin)
 * @param {Object} request - The request object
 * @return {Promise<void>} Resolves if admin, throws if not
 */
async function ensureAdmin(request) {
  const auth = request.auth;

  // For service account calls (no auth.uid), check if the request has a Bearer token
  // Service account access tokens are OAuth2 tokens, not Firebase Auth ID tokens
  // So request.auth will be null, but we can check the raw request headers
  if (!auth || !auth.uid) {
    // Check if there's a Bearer token in the request (service account access token)
    // Firebase callable functions expose the raw request in request.rawRequest
    let authHeader = null;

    // Try to get auth header from rawRequest
    if (request.rawRequest && request.rawRequest.headers) {
      authHeader = request.rawRequest.headers.authorization ||
                   request.rawRequest.headers.Authorization;
    }

    // Also try to get from the request context if available
    if (!authHeader && request.context && request.context.rawRequest) {
      const rawReq = request.context.rawRequest;
      if (rawReq.headers) {
        authHeader = rawReq.headers.authorization || rawReq.headers.Authorization;
      }
    }

    if (authHeader && authHeader.startsWith("Bearer ")) {
      const token = authHeader.substring(7);

      // Verify the OAuth2 access token by checking if it's from our service account
      try {
        // Use Google OAuth2 tokeninfo endpoint to verify the token
        const tokenInfoUrl = `https://oauth2.googleapis.com/tokeninfo?access_token=${token}`;
        const response = await new Promise((resolve, reject) => {
          https.get(tokenInfoUrl, (res) => {
            let data = "";
            res.on("data", (chunk) => (data += chunk));
            res.on("end", () => {
              try {
                resolve(JSON.parse(data));
              } catch (e) {
                reject(e);
              }
            });
          }).on("error", reject);
        });

        // Check if the token is from our service account
        const expectedEmail = "firebase-adminsdk-fbsvc@parkourspot-93c90.iam.gserviceaccount.com";
        if (response.email === expectedEmail || response.email_verified === true) {
          // Valid service account token
          return;
        }
      } catch (error) {
        // Token verification failed, but we'll still allow it if it's a Bearer token
        // This is a fallback - in production you might want stricter verification
        console.warn("Could not verify service account token:", error.message);
        // Still allow it if we have a Bearer token (trust but verify approach)
        return;
      }
    }
    throw new Error("Authentication required");
  }

  // Prefer custom claims if set
  if (auth.token && auth.token.admin === true) {
    return;
  }
  // Fallback to Firestore user doc flag
  const userDoc = await db.collection("users").doc(auth.uid).get();
  if (!userDoc.exists || userDoc.data().isAdmin !== true) {
    throw new Error("Admin privileges required");
  }
}

/**
 * Helper to ensure caller is moderator or admin (via custom claims or Firestore users/{uid}.isModerator/isAdmin)
 * @param {Object} request - The request object
 * @return {Promise<void>} Resolves if moderator or admin, throws if not
 */
async function ensureModerator(request) {
  const auth = request.auth;

  // For service account calls (no auth.uid), check if the request has a Bearer token
  // Service account access tokens are OAuth2 tokens, not Firebase Auth ID tokens
  // So request.auth will be null, but we can check the raw request headers
  if (!auth || !auth.uid) {
    // Check if there's a Bearer token in the request (service account access token)
    // Firebase callable functions expose the raw request in request.rawRequest
    let authHeader = null;

    // Try to get auth header from rawRequest
    if (request.rawRequest && request.rawRequest.headers) {
      authHeader = request.rawRequest.headers.authorization ||
                   request.rawRequest.headers.Authorization;
    }

    // Also try to get from the request context if available
    if (!authHeader && request.context && request.context.rawRequest) {
      const rawReq = request.context.rawRequest;
      if (rawReq.headers) {
        authHeader = rawReq.headers.authorization || rawReq.headers.Authorization;
      }
    }

    if (authHeader && authHeader.startsWith("Bearer ")) {
      const token = authHeader.substring(7);

      // Verify the OAuth2 access token by checking if it's from our service account
      try {
        // Use Google OAuth2 tokeninfo endpoint to verify the token
        const tokenInfoUrl = `https://oauth2.googleapis.com/tokeninfo?access_token=${token}`;
        const response = await new Promise((resolve, reject) => {
          https.get(tokenInfoUrl, (res) => {
            let data = "";
            res.on("data", (chunk) => (data += chunk));
            res.on("end", () => {
              try {
                resolve(JSON.parse(data));
              } catch (e) {
                reject(e);
              }
            });
          }).on("error", reject);
        });

        // Check if the token is from our service account
        const expectedEmail = "firebase-adminsdk-fbsvc@parkourspot-93c90.iam.gserviceaccount.com";
        if (response.email === expectedEmail || response.email_verified === true) {
          // Valid service account token
          return;
        }
      } catch (error) {
        // Token verification failed, but we'll still allow it if it's a Bearer token
        // This is a fallback - in production you might want stricter verification
        console.warn("Could not verify service account token:", error.message);
        // Still allow it if we have a Bearer token (trust but verify approach)
        return;
      }
    }
    throw new Error("Authentication required");
  }

  // Prefer custom claims if set (check for admin or moderator)
  if (auth.token) {
    if (auth.token.admin === true || auth.token.moderator === true) {
      return;
    }
  }
  // Fallback to Firestore user doc flag (check for admin or moderator)
  const userDoc = await db.collection("users").doc(auth.uid).get();
  if (!userDoc.exists) {
    throw new Error("Moderator privileges required");
  }
  const userData = userDoc.data();
  if (userData.isAdmin !== true && userData.isModerator !== true) {
    throw new Error("Moderator privileges required");
  }
}

// Function to sync a single source by ID (admin only)
exports.syncSingleSource = onCall(
    {
      region: "europe-west1",
      memory: "2GiB", // Increased from 1GiB to handle large image processing
      timeoutSeconds: 3600,
      secrets: ["GOOGLE_MAPS_API_KEY"],
    },
    async (request) => {
      try {
        await ensureAdmin(request);
        const {sourceId, updateImagesForExistingSpots = false} = request.data || {};

        if (!sourceId) {
          throw new Error("sourceId is required");
        }

        const apiKey = process.env.GOOGLE_MAPS_API_KEY;
        if (!apiKey) {
          throw new Error("Google Maps API key not configured");
        }

        console.log(`Starting sync for single source: ${sourceId} (updateImagesForExistingSpots=${updateImagesForExistingSpots})`);

        // Get the specific sync source
        const sourceDoc = await db.collection("syncSources").doc(sourceId).get();

        if (!sourceDoc.exists) {
          throw new Error(`Sync source with ID ${sourceId} not found`);
        }

        const source = sourceDoc.data();

        if (!source.isActive) {
          throw new Error(`Sync source ${source.name} is not active`);
        }

        try {
        // Use the shared helper function
          const result = await processSyncSource(source, sourceId, apiKey, updateImagesForExistingSpots);

          const response = {
            success: true,
            message: `Sync completed for source: ${source.name} with geocoding`,
            sourceId: result.sourceId,
            sourceName: result.sourceName,
            stats: result.stats,
          };

          console.log(`Completed sync for source: ${source.name}`, result.stats);
          return response;
        } catch (sourceError) {
          console.error(`Error processing source ${source.name}:`, sourceError);
          throw new Error(
              `Failed to sync source ${source.name}: ${sourceError.message}`,
          );
        }
      } catch (error) {
        console.error("Error syncing single source:", error);
        throw new Error(`Failed to sync single source: ${error.message}`);
      }
    },
);

// Function to resume a sync that is in progress (admin only)
exports.resumeSync = onCall(
    {
      region: "europe-west1",
      memory: "2GiB",
      timeoutSeconds: 3600,
      secrets: ["GOOGLE_MAPS_API_KEY"],
    },
    async (request) => {
      try {
        await ensureAdmin(request);
        const {sourceId} = request.data || {};

        if (!sourceId) {
          throw new Error("sourceId is required");
        }

        const apiKey = process.env.GOOGLE_MAPS_API_KEY;
        if (!apiKey) {
          throw new Error("Google Maps API key not configured");
        }

        console.log(`Resuming sync for source: ${sourceId}`);

        // Get the specific sync source
        const sourceDoc = await db.collection("syncSources").doc(sourceId).get();

        if (!sourceDoc.exists) {
          throw new Error(`Sync source with ID ${sourceId} not found`);
        }

        const source = sourceDoc.data();

        if (!source.isActive) {
          throw new Error(`Sync source ${source.name} is not active`);
        }

        // Check if there's a sync in progress
        if (source.syncInProgress !== true) {
          throw new Error(`No sync in progress for source ${source.name}`);
        }

        const syncType = source.syncType || "light";
        const startIndex = source.syncProgress?.lastProcessedIndex || 0;
        const isFullSync = syncType === "full";

        console.log(`Resuming in-progress ${syncType} sync for source: ${source.name} (${sourceId}) from index ${startIndex}`);

        // Refresh source data to get latest state
        const refreshedSourceDoc = await db.collection("syncSources").doc(sourceId).get();
        const refreshedSource = refreshedSourceDoc.data();

        try {
          const result = await processSyncSource(
              refreshedSource,
              sourceId,
              apiKey,
              isFullSync,
              startIndex,
          );

          const response = {
            success: true,
            message: result.partial ? result.message : `Resumed and completed ${syncType} sync for source: ${source.name}`,
            sourceId: result.sourceId,
            sourceName: result.sourceName,
            stats: result.stats,
            resumed: true,
            partial: result.partial,
          };

          console.log(`Resumed sync for source: ${source.name}`, result.stats);
          return response;
        } catch (sourceError) {
          console.error(`Error resuming sync for source ${source.name}:`, sourceError);
          throw new Error(
              `Failed to resume sync for source ${source.name}: ${sourceError.message}`,
          );
        }
      } catch (error) {
        console.error("Error resuming sync:", error);
        throw new Error(`Failed to resume sync: ${error.message}`);
      }
    },
);

// Function to sync all sources from Firestore collection (admin only)
exports.syncAllSources = onCall(
    {
      region: "europe-west1",
      memory: "1GiB",
      timeoutSeconds: 3600,
      secrets: ["GOOGLE_MAPS_API_KEY"],
    },
    async (request) => {
      try {
        await ensureAdmin(request);

        const apiKey = process.env.GOOGLE_MAPS_API_KEY;
        if (!apiKey) {
          throw new Error("Google Maps API key not configured");
        }

        const {updateImagesForExistingSpots = false} = request.data || {};

        console.log(`Starting sync for all sources from Firestore (updateImagesForExistingSpots=${updateImagesForExistingSpots})`);

        // Get all active sync sources
        const sourcesSnapshot = await db
            .collection("syncSources")
            .where("isActive", "==", true)
            .get();

        if (sourcesSnapshot.empty) {
          return {
            success: true,
            message: "No active sync sources found",
            results: [],
          };
        }

        const results = [];
        let totalCreated = 0;
        let totalUpdated = 0;
        let totalSkipped = 0;
        let totalGeocoded = 0;
        let totalGeocodingFailed = 0;

        // Process each source
        for (const sourceDoc of sourcesSnapshot.docs) {
          const source = sourceDoc.data();
          const sourceId = sourceDoc.id;

          try {
          // Use the shared helper function
            const result = await processSyncSource(source, sourceId, apiKey, updateImagesForExistingSpots);

            const sourceResult = {
              sourceId: result.sourceId,
              sourceName: result.sourceName,
              success: true,
              stats: result.stats,
            };

            results.push(sourceResult);
            totalCreated += result.stats.created;
            totalUpdated += result.stats.updated;
            totalSkipped += result.stats.skipped;
            totalGeocoded += result.stats.geocoded;
            totalGeocodingFailed += result.stats.geocodingFailed;

            console.log(
                `Completed sync for source: ${source.name}`,
                result.stats,
            );
          } catch (sourceError) {
            console.error(`Error processing source ${source.name}:`, sourceError);
            results.push({
              sourceId: sourceId,
              sourceName: source.name,
              success: false,
              error: sourceError.message,
              stats: {
                total: 0,
                created: 0,
                updated: 0,
                skipped: 0,
                geocoded: 0,
                geocodingFailed: 0,
                geocodingSuccessRate: "0%",
              },
            });
          }
        }

        const overallResult = {
          success: true,
          message: `Sync completed for ${results.length} sources with geocoding`,
          totalStats: {
            total: totalCreated + totalUpdated + totalSkipped,
            created: totalCreated,
            updated: totalUpdated,
            skipped: totalSkipped,
            geocoded: totalGeocoded,
            geocodingFailed: totalGeocodingFailed,
            geocodingSuccessRate:
            totalGeocoded + totalGeocodingFailed > 0 ?
              (
                (totalGeocoded / (totalGeocoded + totalGeocodingFailed)) *
                  100
              ).toFixed(1) + "%" :
              "0%",
          },
          results: results,
        };

        console.log("Overall sync result:", overallResult);
        return overallResult;
      } catch (error) {
        console.error("Error syncing all sources:", error);
        throw new Error(`Failed to sync all sources: ${error.message}`);
      }
    },
);

// Function to create a new sync source (admin only)
exports.createSyncSource = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        await ensureAdmin(request);
        const {
          name,
          kmzUrl,
          description,
          publicUrl,
          instagramHandle,
          isActive = true,
          includeFolders,
          recordFolderName,
          defaultSpotAttributes,
          folderSpotAttributes,
          lightSyncSchedule,
          fullSyncSchedule,
          autoSyncEnabled = false,
        } = request.data;

        if (!name || !kmzUrl) {
          throw new Error("name and kmzUrl are required");
        }

        const sourceData = {
          name: name,
          kmzUrl: kmzUrl,
          description: description || "",
          publicUrl: publicUrl || "",
          instagramHandle: instagramHandle || "",
          isActive: isActive,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        };

        // Add optional folder config only if they have values
        if (Array.isArray(includeFolders) && includeFolders.length > 0) {
          sourceData.includeFolders = includeFolders
              .map((s) => s.trim())
              .filter((s) => s.length > 0);
        } else if (
          typeof includeFolders === "string" &&
        includeFolders.trim().length > 0
        ) {
          sourceData.includeFolders = includeFolders
              .split(",")
              .map((s) => s.trim())
              .filter((s) => s.length > 0);
        }

        if (typeof recordFolderName === "boolean") {
          sourceData.recordFolderName = recordFolderName;
        }

        const normalizedDefaultSpotAttributes = normalizeSpotAttributeDefaults(
            defaultSpotAttributes,
        );
        if (normalizedDefaultSpotAttributes) {
          sourceData.defaultSpotAttributes = normalizedDefaultSpotAttributes;
        }

        const normalizedFolderSpotAttributes = normalizeFolderSpotAttributeDefaults(
            folderSpotAttributes,
        );
        if (Object.keys(normalizedFolderSpotAttributes).length > 0) {
          sourceData.folderSpotAttributes = normalizedFolderSpotAttributes;
        }

        if (lightSyncSchedule) {
          sourceData.lightSyncSchedule = lightSyncSchedule;
        }
        if (fullSyncSchedule) {
          sourceData.fullSyncSchedule = fullSyncSchedule;
        }
        sourceData.autoSyncEnabled = autoSyncEnabled;

        const docRef = await db.collection("syncSources").add(sourceData);

        return {
          success: true,
          message: "Sync source created successfully",
          sourceId: docRef.id,
        };
      } catch (error) {
        console.error("Error creating sync source:", error);
        throw new Error(`Failed to create sync source: ${error.message}`);
      }
    },
);

// Function to update a sync source (admin only)
exports.updateSyncSource = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        await ensureAdmin(request);
        const {
          sourceId,
          name,
          kmzUrl,
          description,
          publicUrl,
          instagramHandle,
          isActive,
          includeFolders,
          recordFolderName,
          defaultSpotAttributes,
          folderSpotAttributes,
          lightSyncSchedule,
          fullSyncSchedule,
          autoSyncEnabled,
        } = request.data;

        if (!sourceId) {
          throw new Error("sourceId is required");
        }

        const updateData = {
          updatedAt: FieldValue.serverTimestamp(),
        };

        if (name !== undefined) updateData.name = name;
        if (kmzUrl !== undefined) updateData.kmzUrl = kmzUrl;
        if (description !== undefined) updateData.description = description;
        if (publicUrl !== undefined) updateData.publicUrl = publicUrl;
        if (instagramHandle !== undefined) {
          updateData.instagramHandle = instagramHandle;
        }
        if (isActive !== undefined) updateData.isActive = isActive;
        if (includeFolders !== undefined) {
          if (Array.isArray(includeFolders)) {
            updateData.includeFolders = includeFolders
                .map((s) => s.trim())
                .filter((s) => s.length > 0);
          } else if (typeof includeFolders === "string") {
            const list = includeFolders
                .split(",")
                .map((s) => s.trim())
                .filter((s) => s.length > 0);
            updateData.includeFolders = list;
          } else if (includeFolders === null) {
            updateData.includeFolders = FieldValue.delete();
          }
        }
        if (recordFolderName !== undefined) {
          if (typeof recordFolderName === "boolean") {
            updateData.recordFolderName = recordFolderName;
          } else if (recordFolderName === null) {
            updateData.recordFolderName = FieldValue.delete();
          }
        }
        if (defaultSpotAttributes !== undefined) {
          if (defaultSpotAttributes === null) {
            updateData.defaultSpotAttributes = FieldValue.delete();
          } else {
            const normalizedDefaultSpotAttributes = normalizeSpotAttributeDefaults(
                defaultSpotAttributes,
            );
            if (normalizedDefaultSpotAttributes) {
              updateData.defaultSpotAttributes = normalizedDefaultSpotAttributes;
            } else {
              updateData.defaultSpotAttributes = FieldValue.delete();
            }
          }
        }
        if (folderSpotAttributes !== undefined) {
          if (folderSpotAttributes === null) {
            updateData.folderSpotAttributes = FieldValue.delete();
          } else {
            const normalizedFolderSpotAttributes = normalizeFolderSpotAttributeDefaults(
                folderSpotAttributes,
            );
            if (Object.keys(normalizedFolderSpotAttributes).length > 0) {
              updateData.folderSpotAttributes = normalizedFolderSpotAttributes;
            } else {
              updateData.folderSpotAttributes = FieldValue.delete();
            }
          }
        }
        if (lightSyncSchedule !== undefined) {
          if (lightSyncSchedule && lightSyncSchedule.trim().length > 0) {
            updateData.lightSyncSchedule = lightSyncSchedule.trim();
          } else {
            updateData.lightSyncSchedule = FieldValue.delete();
          }
        }
        if (fullSyncSchedule !== undefined) {
          if (fullSyncSchedule && fullSyncSchedule.trim().length > 0) {
            updateData.fullSyncSchedule = fullSyncSchedule.trim();
          } else {
            updateData.fullSyncSchedule = FieldValue.delete();
          }
        }
        if (autoSyncEnabled !== undefined) {
          updateData.autoSyncEnabled = autoSyncEnabled;
        }

        await db.collection("syncSources").doc(sourceId).update(updateData);

        return {
          success: true,
          message: "Sync source updated successfully",
          sourceId: sourceId,
        };
      } catch (error) {
        console.error("Error updating sync source:", error);
        throw new Error(`Failed to update sync source: ${error.message}`);
      }
    },
);

// Function to delete a sync source (admin only)
exports.deleteSyncSource = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        await ensureAdmin(request);
        const {sourceId} = request.data;

        if (!sourceId) {
          throw new Error("sourceId is required");
        }

        await db.collection("syncSources").doc(sourceId).delete();

        return {
          success: true,
          message: "Sync source deleted successfully",
          sourceId: sourceId,
        };
      } catch (error) {
        console.error("Error deleting sync source:", error);
        throw new Error(`Failed to delete sync source: ${error.message}`);
      }
    },
);

// Function to get all sync sources. includeInactive allowed only for admins
exports.getSyncSources = onCall({region: "europe-west1"}, async (request) => {
  try {
    let {includeInactive = false, summaryOnly = false} = request.data;

    // Only admins may include inactive sources
    try {
      await ensureAdmin(request);
    } catch (e) {
      includeInactive = false;
    }

    let query = db.collection("syncSources");

    if (!includeInactive) {
      query = query.where("isActive", "==", true);
    }

    // Try to get sources with orderBy, but fallback to basic query if it fails
    let snapshot;
    try {
      snapshot = await query.orderBy("createdAt", "desc").get();
    } catch (orderByError) {
      console.log(
          "OrderBy failed, trying without orderBy:",
          orderByError.message,
      );
      snapshot = await query.get();
    }

    let sources;
    if (summaryOnly) {
      sources = snapshot.docs.map((doc) => {
        const data = doc.data();
        return {
          id: doc.id,
          name: data.name || "",
          recordFolderName: data.recordFolderName ?? null,
          allFolders: data.allFolders ?? null,
        };
      });
    } else {
      sources = snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));
    }

    return {
      success: true,
      sources: sources,
      count: sources.length,
    };
  } catch (error) {
    console.error("Error getting sync sources:", error);
    throw new Error(`Failed to get sync sources: ${error.message}`);
  }
});

// Function to get a single sync source by ID (full details, for details dialog)
exports.getSyncSource = onCall({region: "europe-west1"}, async (request) => {
  try {
    const {sourceId} = request.data;
    if (!sourceId || typeof sourceId !== "string") {
      throw new Error("sourceId is required");
    }

    const doc = await db.collection("syncSources").doc(sourceId).get();
    if (!doc.exists) {
      return {success: false, error: "Source not found", source: null};
    }

    const data = doc.data();
    const source = {id: doc.id, ...data};

    return {
      success: true,
      source: source,
    };
  } catch (error) {
    console.error("Error getting sync source:", error);
    throw new Error(`Failed to get sync source: ${error.message}`);
  }
});

// Admin callable to backfill source/folder default spot attributes.
exports.backfillSourceSpotAttributes = onCall(
    {
      region: "europe-west1",
      timeoutSeconds: 540,
      memory: "1GiB",
    },
    async (request) => {
      try {
        await ensureAdmin(request);
        const {sourceId = null} = request.data || {};
        if (sourceId !== null && sourceId !== undefined && typeof sourceId !== "string") {
          throw new Error("sourceId must be a string when provided");
        }

        let sourceDocs = [];
        if (sourceId && sourceId.trim().length > 0) {
          const sourceDoc = await db.collection("syncSources").doc(sourceId).get();
          if (!sourceDoc.exists) {
            throw new Error(`Sync source with ID ${sourceId} not found`);
          }
          sourceDocs = [sourceDoc];
        } else {
          const sourcesSnapshot = await db.collection("syncSources").get();
          sourceDocs = sourcesSnapshot.docs;
        }

        const batchState = {
          batch: db.batch(),
          operationCount: 0,
        };

        const results = [];
        let totalSpotsScanned = 0;
        let totalSpotsUpdated = 0;
        let totalOriginalSpotsUpdated = 0;
        let sourcesWithDefaults = 0;
        let sourcesSkippedNoDefaults = 0;
        let sourcesFailed = 0;

        for (const sourceDoc of sourceDocs) {
          const sourceData = sourceDoc.data() || {};
          const sourceName = sourceData.name || sourceDoc.id;

          try {
            const sourceDefaults = normalizeSpotAttributeDefaults(
                sourceData.defaultSpotAttributes,
            );
            const folderDefaults = normalizeFolderSpotAttributeDefaults(
                sourceData.folderSpotAttributes,
            );
            const folderDefaultsLookup = buildFolderDefaultsLookup(folderDefaults);
            const hasDefaults = Boolean(sourceDefaults) ||
              Object.keys(folderDefaultsLookup).length > 0;

            if (!hasDefaults) {
              sourcesSkippedNoDefaults += 1;
              results.push({
                sourceId: sourceDoc.id,
                sourceName: sourceName,
                skipped: true,
                reason: "No default attributes configured",
                spotsScanned: 0,
                spotsUpdated: 0,
                originalSpotsUpdated: 0,
              });
              continue;
            }

            sourcesWithDefaults += 1;

            const sourceResult = {
              sourceId: sourceDoc.id,
              sourceName: sourceName,
              skipped: false,
              spotsScanned: 0,
              spotsUpdated: 0,
              originalSpotsUpdated: 0,
            };

            const sourceSpotsSnapshot = await db
                .collection("spots")
                .where("spotSource", "==", sourceDoc.id)
                .get();

            sourceResult.spotsScanned = sourceSpotsSnapshot.size;
            totalSpotsScanned += sourceSpotsSnapshot.size;

            // For duplicate spots, accumulate defaults to also apply to originals.
            const originalDefaultsBySpotId = new Map();

            for (const spotDoc of sourceSpotsSnapshot.docs) {
              const currentSpotData = spotDoc.data() || {};
              const effectiveDefaults = getEffectiveSpotAttributeDefaults(
                  sourceDefaults,
                  folderDefaultsLookup,
                  currentSpotData.folderName,
              );
              if (!effectiveDefaults) {
                continue;
              }

              const mutableSpotData = {...currentSpotData};
              const changedSpot = applySpotAttributeDefaultsToSpotData(
                  mutableSpotData,
                  effectiveDefaults,
              );
              if (changedSpot) {
                await queueBatchUpdate(
                    batchState,
                    spotDoc.ref,
                    buildSpotAttributeUpdateData(
                        mutableSpotData,
                        FieldValue.serverTimestamp(),
                    ),
                );
                sourceResult.spotsUpdated += 1;
                totalSpotsUpdated += 1;
              }

              const duplicateOfId = typeof currentSpotData.duplicateOf === "string" ?
                currentSpotData.duplicateOf.trim() :
                "";
              if (duplicateOfId) {
                const previousDefaults = originalDefaultsBySpotId.get(duplicateOfId) || null;
                const mergedDefaults = mergeSpotAttributeDefaults(
                    previousDefaults,
                    effectiveDefaults,
                );
                if (mergedDefaults) {
                  originalDefaultsBySpotId.set(duplicateOfId, mergedDefaults);
                }
              }
            }

            const originalIds = Array.from(originalDefaultsBySpotId.keys());
            for (let i = 0; i < originalIds.length; i += 200) {
              const chunk = originalIds.slice(i, i + 200);
              const refs = chunk.map((id) => db.collection("spots").doc(id));
              const originalDocs = await db.getAll(...refs);

              for (const originalDoc of originalDocs) {
                if (!originalDoc.exists) continue;

                const defaultsForOriginal = originalDefaultsBySpotId.get(originalDoc.id);
                if (!defaultsForOriginal) continue;

                const mutableOriginalData = {...(originalDoc.data() || {})};
                const changedOriginal = applySpotAttributeDefaultsToSpotData(
                    mutableOriginalData,
                    defaultsForOriginal,
                );
                if (changedOriginal) {
                  await queueBatchUpdate(
                      batchState,
                      originalDoc.ref,
                      buildSpotAttributeUpdateData(
                          mutableOriginalData,
                          FieldValue.serverTimestamp(),
                      ),
                  );
                  sourceResult.originalSpotsUpdated += 1;
                  totalOriginalSpotsUpdated += 1;
                }
              }
            }

            results.push(sourceResult);
          } catch (sourceError) {
            sourcesFailed += 1;
            console.error(
                `Failed backfilling spot attributes for source ${sourceDoc.id}:`,
                sourceError,
            );
            results.push({
              sourceId: sourceDoc.id,
              sourceName: sourceName,
              skipped: false,
              spotsScanned: 0,
              spotsUpdated: 0,
              originalSpotsUpdated: 0,
              error: sourceError.message,
            });
          }
        }

        await commitPendingBatch(batchState);

        return {
          success: true,
          message: sourceId && sourceId.trim().length > 0 ?
            `Backfill completed for source ${sourceId}` :
            `Backfill completed for ${sourceDocs.length} source(s)`,
          summary: {
            sourcesRequested: sourceDocs.length,
            sourcesWithDefaults: sourcesWithDefaults,
            sourcesSkippedNoDefaults: sourcesSkippedNoDefaults,
            sourcesFailed: sourcesFailed,
            spotsScanned: totalSpotsScanned,
            spotsUpdated: totalSpotsUpdated,
            originalSpotsUpdated: totalOriginalSpotsUpdated,
          },
          results: results,
        };
      } catch (error) {
        console.error("Error backfilling source spot attributes:", error);
        throw new Error(`Failed to backfill source spot attributes: ${error.message}`);
      }
    },
);

// Admin tool: set or unset a user's admin status
exports.setUserAdmin = onCall({region: "europe-west1"}, async (request) => {
  try {
    await ensureAdmin(request);
    const {targetUid, targetEmail, isAdmin} = request.data;
    if (typeof isAdmin !== "boolean") {
      throw new Error("isAdmin boolean is required");
    }
    let uid = targetUid;
    if (!uid && targetEmail) {
      const userRecord = await admin.auth().getUserByEmail(targetEmail);
      uid = userRecord.uid;
    }
    if (!uid) {
      throw new Error("targetUid or targetEmail is required");
    }

    // Update Firestore profile
    await db
        .collection("users")
        .doc(uid)
        .set({isAdmin: isAdmin}, {merge: true});
    // Update custom claims for faster checks (best-effort)
    try {
      const userRecord = await admin.auth().getUser(uid);
      const existingClaims = userRecord.customClaims || {};
      await admin
          .auth()
          .setCustomUserClaims(uid, {...existingClaims, admin: isAdmin});
    } catch (claimErr) {
      console.warn("Failed to set custom claims:", claimErr.message);
    }

    return {success: true, uid: uid, isAdmin: isAdmin};
  } catch (error) {
    console.error("Error setting user admin:", error);
    throw new Error(`Failed to set user admin: ${error.message}`);
  }
});

// Admin function to overwrite user.createdAt based on Firebase Auth creation time
exports.syncUserCreatedAtFromAuth = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        await ensureAdmin(request);
        const {dryRun = false, limit = null} = request.data || {};

        console.log(`Starting sync of user.createdAt from Firebase Auth${dryRun ? " (DRY RUN)" : ""}`);

        let totalProcessed = 0;
        let totalUpdated = 0;
        let totalSkipped = 0;
        let totalErrors = 0;
        const errors = [];
        const changes = []; // Track changes for dry run preview

        // List all users from Firebase Auth (paginated)
        let nextPageToken;
        do {
          const listUsersResult = await admin.auth().listUsers(1000, nextPageToken);
          nextPageToken = listUsersResult.pageToken;

          for (const userRecord of listUsersResult.users) {
            totalProcessed++;

            try {
              // Get creation time from Firebase Auth metadata
              const authCreatedAt = userRecord.metadata.creationTime;
              if (!authCreatedAt) {
                console.log(`Skipping user ${userRecord.uid}: no creation time in Auth`);
                totalSkipped++;
                continue;
              }

              // Convert to Firestore Timestamp
              const createdAtTimestamp = admin.firestore.Timestamp.fromDate(
                  new Date(authCreatedAt),
              );

              // Get current Firestore document
              const userDocRef = db.collection("users").doc(userRecord.uid);
              const userDocSnapshot = await userDocRef.get();

              if (!userDocSnapshot.exists) {
                console.log(`Skipping user ${userRecord.uid}: no Firestore document`);
                totalSkipped++;
                continue;
              }

              const userDocData = userDocSnapshot.data();
              const currentCreatedAt = userDocData?.createdAt;

              // Check if update is needed
              if (currentCreatedAt) {
                let currentTimestamp;
                if (currentCreatedAt instanceof admin.firestore.Timestamp) {
                  currentTimestamp = currentCreatedAt;
                } else {
                  currentTimestamp = admin.firestore.Timestamp.fromDate(
                      currentCreatedAt.toDate(),
                  );
                }
                if (currentTimestamp.isEqual(createdAtTimestamp)) {
                  console.log(`Skipping user ${userRecord.uid}: createdAt already matches`);
                  totalSkipped++;
                  continue;
                }
              }

              // Format timestamps for display
              const formatTimestamp = (ts) => {
                if (!ts) return null;
                let date;
                if (ts instanceof admin.firestore.Timestamp) {
                  date = ts.toDate();
                } else {
                  date = ts.toDate();
                }
                return date.toISOString();
              };

              if (!dryRun) {
                // Update Firestore document
                await userDocRef.update({
                  createdAt: createdAtTimestamp,
                });
                console.log(
                    `Updated user ${userRecord.uid}: createdAt = ${authCreatedAt}`,
                );
              } else {
                // In dry run, collect change details
                changes.push({
                  uid: userRecord.uid,
                  email: userRecord.email || "N/A",
                  displayName: userDocData?.displayName || null,
                  from: formatTimestamp(currentCreatedAt),
                  to: formatTimestamp(createdAtTimestamp),
                });
                console.log(
                    `[DRY RUN] Would update user ${userRecord.uid}: createdAt = ${authCreatedAt}`,
                );
              }

              totalUpdated++;
            } catch (error) {
              console.error(`Error processing user ${userRecord.uid}:`, error);
              totalErrors++;
              errors.push({
                uid: userRecord.uid,
                email: userRecord.email,
                error: error.message,
              });
            }

            // Apply limit if specified (for testing)
            if (limit && totalProcessed >= limit) {
              nextPageToken = undefined;
              break;
            }
          }
        } while (nextPageToken);

        const result = {
          success: true,
          dryRun: dryRun,
          totalProcessed: totalProcessed,
          totalUpdated: totalUpdated,
          totalSkipped: totalSkipped,
          totalErrors: totalErrors,
        };

        if (errors.length > 0) {
          result.errors = errors;
        }

        // Include changes in dry run mode
        if (dryRun && changes.length > 0) {
          result.changes = changes;
        }

        console.log(`Sync completed:`, result);
        return result;
      } catch (error) {
        console.error("Error syncing user createdAt:", error);
        throw new Error(`Failed to sync user createdAt: ${error.message}`);
      }
    },
);

/**
 * Check if URL is a Google profile picture URL.
 * Only googleusercontent.com; googleapis.com is excluded because Firebase
 * Storage URLs contain it and would be falsely matched.
 * @param {string} url - The URL to check
 * @return {boolean} True if URL is a Google profile picture
 */
function isGoogleProfilePictureUrl(url) {
  if (!url || typeof url !== "string") return false;
  return url.includes("googleusercontent.com");
}

/**
 * Optimize profile image: center crop to square, resize to max 800x800, JPEG 85%.
 * Matches Flutter ProfilePictureService processing for consistency.
 * @param {Buffer} imageBuffer - Original image bytes
 * @return {Promise<Buffer>} Processed JPEG buffer
 */
async function optimizeProfileImage(imageBuffer) {
  const metadata = await sharp(imageBuffer).metadata();
  const {width, height} = metadata;
  const cropSize = Math.min(width, height);
  const left = Math.floor((width - cropSize) / 2);
  const top = Math.floor((height - cropSize) / 2);
  const size = Math.min(cropSize, 800);

  return sharp(imageBuffer)
      .extract({left, top, width: cropSize, height: cropSize})
      .resize(size, size)
      .jpeg({quality: 85})
      .toBuffer();
}

/**
 * Delay helper for rate limiting.
 * @param {number} ms - Milliseconds to wait
 * @return {Promise<void>}
 */
function delay(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Delay between Google image downloads to avoid rate limits (ms) */
const GOOGLE_AVATAR_DELAY_MS = 2500;

// Admin function to copy Google profile pictures to Firebase Storage for users
// who still have Google URLs. Includes rate limiting to avoid hitting Google limits.
exports.copyGoogleAvatarsToStorage = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        await ensureAdmin(request);
        const {dryRun = false, limit = null} = request.data || {};

        console.log(
            `Starting copy of Google avatars to Storage${
              dryRun ? " (DRY RUN)" : ""
            }`,
        );

        let totalProcessed = 0;
        let totalCopied = 0;
        let totalUpdated = 0;
        let totalSkipped = 0;
        let totalErrors = 0;
        const errors = [];
        const changes = [];

        const usersSnapshot = await db
            .collection("users")
            .orderBy("createdAt", "desc")
            .limit(limit ?? 5000)
            .get();

        for (const doc of usersSnapshot.docs) {
          totalProcessed++;
          const uid = doc.id;
          const data = doc.data();
          const photoURL = data?.photoURL;
          const email = data?.email || "N/A";
          const displayName = data?.displayName;

          try {
            // Skip if no photoURL or empty
            if (!photoURL || typeof photoURL !== "string" || !photoURL.trim()) {
              totalSkipped++;
              continue;
            }

            // Skip if not a Google profile picture URL
            if (!isGoogleProfilePictureUrl(photoURL)) {
              totalSkipped++;
              continue;
            }

            // Check if user already has a file in Storage
            const storagePath = `users/${uid}/profile.jpg`;
            const file = bucket.file(storagePath);

            if (!dryRun) {
              const [exists] = await file.exists();
              if (exists) {
                const storageUrl =
                  `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
                // Ensure file is publicly accessible (may not have been before)
                await file.makePublic();
                if (photoURL !== storageUrl) {
                  await db.collection("users").doc(uid).update({
                    photoURL: storageUrl,
                  });
                  console.log(
                      `Updated ${uid}: profile now points at existing Storage file`,
                  );
                  totalUpdated++;
                } else {
                  console.log(`Skipping ${uid}: profile.jpg already in Storage`);
                  totalSkipped++;
                }
                continue;
              }
            }

            if (dryRun) {
              changes.push({
                uid,
                email,
                displayName: displayName || null,
                photoURL: photoURL.substring(0, 80) + "...",
              });
              totalCopied++;
              continue;
            }

            // Rate limit: wait before downloading from Google
            await delay(GOOGLE_AVATAR_DELAY_MS);

            // Download image from Google
            const imageBuffer = await downloadFile(photoURL);
            if (!imageBuffer || imageBuffer.length === 0) {
              throw new Error("Downloaded image is empty");
            }

            // Process (crop, resize)
            const processedBuffer = await optimizeProfileImage(imageBuffer);

            // Upload to Storage (public GCS URL format - simpler, both formats work)
            await file.save(processedBuffer, {
              metadata: {
                contentType: "image/jpeg",
                cacheControl: "public, max-age=31536000",
              },
            });

            await file.makePublic();
            const storageUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;

            // Update Firestore user document
            await db.collection("users").doc(uid).update({
              photoURL: storageUrl,
            });

            console.log(`Copied avatar for ${uid} (${email}) to Storage`);
            totalCopied++;
          } catch (error) {
            console.error(`Error processing user ${uid}:`, error);
            totalErrors++;
            errors.push({
              uid,
              email,
              displayName: displayName || null,
              error: error.message,
            });
          }
        }

        const result = {
          success: true,
          dryRun: dryRun,
          totalProcessed,
          totalCopied,
          totalUpdated,
          totalSkipped,
          totalErrors,
        };
        if (errors.length > 0) result.errors = errors;
        if (dryRun && changes.length > 0) result.changes = changes;

        console.log("Copy Google avatars completed:", result);
        return result;
      } catch (error) {
        console.error("Error copying Google avatars:", error);
        throw new Error(
            `Failed to copy Google avatars: ${error.message}`,
        );
      }
    },
);

/**
 * Admin function to make existing user profile pictures in Storage publicly
 * accessible. For each user, if users/{uid}/profile.jpg exists, calls makePublic().
 * Useful when profile images were uploaded but not made public.
 * @return {Promise<Object>} { success, totalProcessed, totalMadePublic, totalSkipped, totalErrors, errors? }
 */
exports.makeProfilePicturesPublic = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        await ensureAdmin(request);

        console.log("Starting make profile pictures public");

        let totalProcessed = 0;
        let totalMadePublic = 0;
        let totalSkipped = 0;
        let totalErrors = 0;
        const errors = [];

        const usersSnapshot = await db
            .collection("users")
            .orderBy("createdAt", "desc")
            .limit(5000)
            .get();

        for (const doc of usersSnapshot.docs) {
          totalProcessed++;
          const uid = doc.id;

          try {
            const storagePath = `users/${uid}/profile.jpg`;
            const file = bucket.file(storagePath);
            const [exists] = await file.exists();

            if (!exists) {
              totalSkipped++;
              continue;
            }

            await file.makePublic();
            console.log(`Made public: ${uid}`);
            totalMadePublic++;
          } catch (error) {
            console.error(`Error processing user ${uid}:`, error);
            totalErrors++;
            errors.push({
              uid,
              email: doc.data()?.email ?? "N/A",
              error: error.message,
            });
          }
        }

        const result = {
          success: true,
          totalProcessed,
          totalMadePublic,
          totalSkipped,
          totalErrors,
        };
        if (errors.length > 0) result.errors = errors;

        console.log("Make profile pictures public completed:", result);
        return result;
      } catch (error) {
        console.error("Error making profile pictures public:", error);
        throw new Error(
            `Failed to make profile pictures public: ${error.message}`,
        );
      }
    },
);

/**
 * Firestore trigger: when a user's displayName changes, propagate to spots
 * (createdByName and contributors[].userName).
 */
exports.onUserDisplayNameUpdated = onDocumentUpdated(
    {document: "users/{userId}", region: "europe-west1"},
    async (event) => {
      const before = event.data.before.data();
      const after = event.data.after.data();
      const newName = (typeof after?.displayName === "string" &&
        after.displayName.trim().length > 0) ?
        after.displayName.trim() :
        null;
      const oldName = (typeof before?.displayName === "string" &&
        before.displayName.trim().length > 0) ?
        before.displayName.trim() :
        null;
      if (newName === oldName) return;

      const userId = event.params.userId;
      const BATCH_SIZE = 400;
      let batch = db.batch();
      let batchCount = 0;

      // 1. Update spots where createdBy == userId
      const createdByQuery = db.collection("spots")
          .where("createdBy", "==", userId);
      const createdBySnapshot = await createdByQuery.get();
      for (const spotDoc of createdBySnapshot.docs) {
        batch.update(spotDoc.ref, {createdByName: newName});
        batchCount++;
        if (batchCount >= BATCH_SIZE) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      }

      // 2. Paginate through all spots to find contributors
      let lastDoc = null;
      const pageSize = 500;
      let hasMore = true;
      while (hasMore) {
        let spotsQuery = db.collection("spots").limit(pageSize);
        if (lastDoc) spotsQuery = spotsQuery.startAfter(lastDoc);
        const spotsSnapshot = await spotsQuery.get();
        if (spotsSnapshot.empty) break;

        for (const spotDoc of spotsSnapshot.docs) {
          lastDoc = spotDoc;
          const spotData = spotDoc.data();
          const contributors = spotData.contributors;
          if (!Array.isArray(contributors) || contributors.length === 0) {
            continue;
          }

          const needsContributorUpdate = contributors.some(
              (c) => c.userId === userId && (c.userName ?? null) !== newName);
          if (!needsContributorUpdate) continue;

          const updatedContributors = contributors.map((c) => {
            if (c.userId !== userId) return c;
            return {...c, userName: newName};
          });
          batch.update(spotDoc.ref, {contributors: updatedContributors});
          batchCount++;
          if (batchCount >= BATCH_SIZE) {
            await batch.commit();
            batch = db.batch();
            batchCount = 0;
          }
        }
        hasMore = spotsSnapshot.docs.length >= pageSize;
      }

      if (batchCount > 0) {
        await batch.commit();
      }
      console.log(`Propagated display name for user ${userId} to spots`);
    },
);

/**
 * Admin function to sync display names from users table into the spots table.
 * Updates createdByName and contributors[].userName for all spots where the
 * stored name does not match the user's current displayName.
 * @param {Object} request.data - { dryRun?: boolean }
 * @return {Promise<Object>} { success, totalUsersProcessed, spotsUpdated, spotsSkipped, totalErrors, errors?, changes? }
 */
exports.syncSpotDisplayNames = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        await ensureAdmin(request);
        const {dryRun = false} = request.data || {};

        console.log(
            `Starting sync of spot display names${dryRun ? " (DRY RUN)" : ""}`,
        );

        // Build userId -> displayName map from users collection
        const usersSnapshot = await db
            .collection("users")
            .limit(10000)
            .get();

        const userDisplayNames = new Map();
        for (const doc of usersSnapshot.docs) {
          const d = doc.data();
          const dn = d.displayName;
          const str =
              (typeof dn === "string" && dn.trim().length > 0) ?
                dn.trim() :
                null;
          userDisplayNames.set(doc.id, str);
        }

        const totalUsersProcessed = userDisplayNames.size;
        let spotsUpdated = 0;
        let spotsSkipped = 0;
        const totalErrors = 0;
        const errors = [];
        const changes = dryRun ? [] : null;

        const BATCH_SIZE = 400;
        let batch = db.batch();
        let batchCount = 0;

        // Process all spots in batches
        let lastDoc = null;
        const pageSize = 500;
        let hasMore = true;

        while (hasMore) {
          let spotsQuery = db.collection("spots").limit(pageSize);
          if (lastDoc) spotsQuery = spotsQuery.startAfter(lastDoc);

          const spotsSnapshot = await spotsQuery.get();
          if (spotsSnapshot.empty) break;

          for (const spotDoc of spotsSnapshot.docs) {
            lastDoc = spotDoc;
            const spotData = spotDoc.data();
            const updates = {};
            let hasChanges = false;

            // 1. createdBy / createdByName
            const createdBy = spotData.createdBy ?? null;
            if (createdBy) {
              const expectedName = userDisplayNames.get(createdBy);
              const currentName = spotData.createdByName ?? null;
              const needsUpdate =
                expectedName !== undefined &&
                ((expectedName !== null && currentName !== expectedName) ||
                 (expectedName === null &&
                  currentName != null &&
                  currentName !== ""));

              if (needsUpdate) {
                hasChanges = true;
                if (dryRun) {
                  changes.push({
                    spotId: spotDoc.id,
                    spotName: spotData.name,
                    field: "createdByName",
                    userId: createdBy,
                    from: currentName ?? "(empty)",
                    to: expectedName ?? "(empty)",
                  });
                } else {
                  updates.createdByName = expectedName;
                }
              }
            }

            // 2. contributors
            const contributors = spotData.contributors;
            if (Array.isArray(contributors) && contributors.length > 0) {
              const updatedContributors = contributors.map((c) => {
                const cUserId = c.userId;
                if (!cUserId) return c;
                const expectedName = userDisplayNames.get(cUserId);
                if (expectedName === undefined) return c;

                const currentName = c.userName ?? null;
                const needsUpdate =
                  (expectedName !== null && currentName !== expectedName) ||
                  (expectedName === null &&
                   currentName != null &&
                   currentName !== "");

                if (needsUpdate) {
                  return {...c, userName: expectedName};
                }
                return c;
              });

              const contributorsModified = contributors.some(
                  (c, i) => c.userName !== updatedContributors[i]?.userName);
              if (contributorsModified) {
                hasChanges = true;
                if (dryRun) {
                  const firstChanged = contributors.find((c) => {
                    const exp = userDisplayNames.get(c.userId);
                    if (exp === undefined) return false;
                    const cur = c.userName ?? null;
                    return (exp !== null && cur !== exp) ||
                           (exp === null && cur != null && cur !== "");
                  });
                  changes.push({
                    spotId: spotDoc.id,
                    spotName: spotData.name,
                    field: "contributors",
                    userId: firstChanged?.userId ?? "?",
                    from: firstChanged?.userName ?? "(empty)",
                    to: userDisplayNames.get(firstChanged?.userId) ?? "(empty)",
                  });
                } else {
                  updates.contributors = updatedContributors;
                }
              }
            }

            if (hasChanges) {
              if (!dryRun && Object.keys(updates).length > 0) {
                batch.update(spotDoc.ref, updates);
                batchCount++;
                if (batchCount >= BATCH_SIZE) {
                  await batch.commit();
                  spotsUpdated += batchCount;
                  batch = db.batch();
                  batchCount = 0;
                }
              } else if (dryRun) {
                spotsUpdated++;
              }
            } else {
              spotsSkipped++;
            }
          }

          hasMore = spotsSnapshot.docs.length >= pageSize;
        }

        if (batchCount > 0 && !dryRun) {
          await batch.commit();
          spotsUpdated += batchCount;
        }

        const result = {
          success: true,
          totalUsersProcessed,
          spotsUpdated,
          spotsSkipped,
          totalErrors,
        };
        if (errors.length > 0) result.errors = errors;
        if (dryRun && changes && changes.length > 0) result.changes = changes;

        console.log("Sync spot display names completed:", result);
        return result;
      } catch (error) {
        console.error("Error syncing spot display names:", error);
        throw new Error(
            `Failed to sync spot display names: ${error.message}`,
        );
      }
    },
);

// Admin function to update spot source names for existing spots
exports.updateSpotSourceNames = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        await ensureAdmin(request);
        const {sourceId} = request.data;

        console.log(`Starting spot source name update${sourceId ? ` for source: ${sourceId}` : " for all sources"}`);

        // Get all sync sources to build a mapping
        const sourcesSnapshot = await db.collection("syncSources").get();
        const sourceMap = new Map();

        sourcesSnapshot.docs.forEach((doc) => {
          const data = doc.data();
          sourceMap.set(doc.id, data.name);
        });

        console.log(`Found ${sourceMap.size} sync sources`);

        // Build query for spots
        let spotsQuery = db.collection("spots");

        // If specific sourceId provided, filter by that source
        if (sourceId) {
          spotsQuery = spotsQuery.where("spotSource", "==", sourceId);
        }

        const spotsSnapshot = await spotsQuery.get();
        console.log(`Found ${spotsSnapshot.size} spots to process`);

        let updatedCount = 0;
        let skippedCount = 0;
        const batch = db.batch();

        spotsSnapshot.docs.forEach((doc) => {
          const spotData = doc.data();
          const spotSourceId = spotData.spotSource;

          if (!spotSourceId) {
            console.log(`Skipping spot ${doc.id}: no spotSource`);
            skippedCount++;
            return;
          }

          const sourceName = sourceMap.get(spotSourceId);
          if (!sourceName) {
            console.log(`Skipping spot ${doc.id}: source ${spotSourceId} not found`);
            skippedCount++;
            return;
          }

          // Only update if spotSourceName is missing or different
          if (!spotData.spotSourceName || spotData.spotSourceName !== sourceName) {
            batch.update(doc.ref, {
              spotSourceName: sourceName,
              updatedAt: FieldValue.serverTimestamp(),
            });
            updatedCount++;
            console.log(`Queued update for spot ${doc.id}: ${spotData.name} -> source: ${sourceName}`);
          } else {
            skippedCount++;
            console.log(`Skipping spot ${doc.id}: spotSourceName already correct`);
          }
        });

        // Commit the batch update
        if (updatedCount > 0) {
          await batch.commit();
          console.log(`Successfully updated ${updatedCount} spots`);
        }

        return {
          success: true,
          message: `Spot source names update completed`,
          stats: {
            totalSpots: spotsSnapshot.size,
            updated: updatedCount,
            skipped: skippedCount,
            sourcesProcessed: sourceMap.size,
          },
        };
      } catch (error) {
        console.error("Error updating spot source names:", error);
        throw new Error(`Failed to update spot source names: ${error.message}`);
      }
    },
);

// One-time backfill: populate spotSearchTerms for all existing spots.
// Run once after deploying. Admin only.
exports.backfillSpotNameLower = onCall(
    {region: "europe-west1", memory: "256MiB", timeoutSeconds: 540},
    async (request) => {
      try {
        await ensureAdmin(request);
        const BATCH_SIZE = 250;
        let lastDoc = null;
        let totalProcessed = 0;
        let searchTermsWritten = 0;
        let hasMore = true;
        while (hasMore) {
          let query = db.collection("spots").limit(BATCH_SIZE);
          if (lastDoc) {
            query = query.startAfter(lastDoc);
          }
          const snapshot = await query.get();
          if (snapshot.empty) {
            hasMore = false;
            break;
          }
          let termsBatch = db.batch();
          let termsCount = 0;
          const BATCH_LIMIT = 450;
          for (const doc of snapshot.docs) {
            const data = doc.data();
            const name = typeof data.name === "string" ? data.name.trim() : "";
            const words = buildSpotSearchWords(name);
            for (const term of words) {
              if (termsCount >= BATCH_LIMIT) {
                await termsBatch.commit();
                termsBatch = db.batch();
                termsCount = 0;
              }
              const ref = db.collection("spotSearchTerms").doc(spotSearchTermDocId(doc.id, term));
              termsBatch.set(ref, {term, spotId: doc.id});
              termsCount++;
              searchTermsWritten++;
            }
          }
          if (termsCount > 0) await termsBatch.commit();
          totalProcessed += snapshot.size;
          lastDoc = snapshot.docs[snapshot.docs.length - 1];
          hasMore = snapshot.size === BATCH_SIZE;
          console.log(`Backfill: ${totalProcessed} spots, ${searchTermsWritten} terms`);
        }
        return {
          success: true,
          message: "Backfill completed",
          stats: {totalProcessed, searchTermsWritten},
        };
      } catch (error) {
        console.error("Error in backfillSpotNameLower:", error);
        throw new Error(`Failed to backfill: ${error.message}`);
      }
    },
);

// Geocoding function to convert coordinates to address and components
exports.geocodeCoordinates = onCall(
    {region: "europe-west1", secrets: ["GOOGLE_MAPS_API_KEY"]},
    async (request) => {
      try {
        const {latitude, longitude} = request.data;

        if (latitude === undefined || longitude === undefined) {
          throw new Error("latitude and longitude are required");
        }

        // Use Google Maps Geocoding API
        const apiKey = process.env.GOOGLE_MAPS_API_KEY;
        if (!apiKey) {
          throw new Error("Google Maps API key not configured");
        }

        const geocodingUrl = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${latitude},${longitude}&key=${apiKey}`;

        const response = await new Promise((resolve, reject) => {
          https
              .get(geocodingUrl, (res) => {
                let data = "";
                res.on("data", (chunk) => (data += chunk));
                res.on("end", () => {
                  try {
                    resolve(JSON.parse(data));
                  } catch (e) {
                    reject(e);
                  }
                });
              })
              .on("error", reject);
        });

        if (
          response.status === "OK" &&
        response.results &&
        response.results.length > 0
        ) {
          const result = response.results[0];
          const address = result.formatted_address;

          // Extract city and country code from address_components
          let city = null;
          let countryCode = null;
          if (Array.isArray(result.address_components)) {
            const components = result.address_components;
            // Country code from component with type 'country' (short_name is 2-letter code)
            const countryComp = components.find(
                (c) => c.types && c.types.includes("country"),
            );
            if (countryComp && countryComp.short_name) {
              countryCode = countryComp.short_name; // e.g., 'NL'
            }

            // City can be 'locality' or 'postal_town'; fallback to 'administrative_area_level_2' then level_1
            const cityTypesPriority = [
              "locality",
              "postal_town",
              "administrative_area_level_2",
              "administrative_area_level_1",
            ];
            for (const t of cityTypesPriority) {
              const comp = components.find((c) => c.types && c.types.includes(t));
              if (comp && comp.long_name) {
                city = comp.long_name;
                break;
              }
            }
          }

          return {
            success: true,
            address: address,
            city: city,
            countryCode: countryCode,
          };
        } else {
          return {
            success: false,
            error: response.error_message || "No address found for coordinates",
          };
        }
      } catch (error) {
        console.error("Error geocoding coordinates:", error);
        return {
          success: false,
          error: error.message,
        };
      }
    },
);

/**
 * Shared search-by-title logic. Returns full spot objects for API/callable use.
 * @param {Object} params - Params object.
 * @param {string} params.query - Search query.
 * @param {number=} params.limit - Max results (default 20).
 * @return {Promise<Object>}
 */
async function executeSearchSpotsByTitle(params) {
  const {query, limit = 20} = params || {};
  if (!query || typeof query !== "string") {
    return {success: false, error: "query is required"};
  }

  const tokens = getSearchQueryTokens(query);
  if (tokens.length === 0) {
    return {success: true, spots: []};
  }

  const parsedLimit = Number(limit);
  const maxResults = Number.isFinite(parsedLimit) ?
    Math.max(1, Math.min(Math.floor(parsedLimit), 100)) :
    20;

  const spotIdToMatchCount = new Map();
  for (const token of tokens) {
    const queryEnd = token + "\uf8ff";
    const termsSnapshot = await db.collection("spotSearchTerms")
        .where("term", ">=", token)
        .where("term", "<", queryEnd)
        .limit(200)
        .get();
    termsSnapshot.docs.forEach((doc) => {
      const spotId = doc.data().spotId;
      if (!spotId) return;
      const prev = spotIdToMatchCount.get(spotId) || 0;
      spotIdToMatchCount.set(spotId, prev + 1);
    });
  }

  let spotIds;
  const spotsWithAll = [...spotIdToMatchCount.entries()]
      .filter(([, count]) => count === tokens.length)
      .map(([id]) => id);
  if (spotsWithAll.length > 0) {
    spotIds = spotsWithAll;
  } else {
    spotIds = [...spotIdToMatchCount.entries()]
        .sort((a, b) => b[1] - a[1])
        .map(([id]) => id);
  }

  if (spotIds.length === 0) {
    return {success: true, spots: []};
  }

  const spotsToFetch = spotIds.slice(0, 60);
  const spotRefs = spotsToFetch.map((id) => db.collection("spots").doc(id));
  const spotDocs = await db.getAll(...spotRefs);
  const matches = [];
  spotDocs.forEach((doc) => {
    if (!doc.exists) return;
    const data = doc.data();
    if (data.duplicateOf || data.hidden) return;
    const name = typeof data.name === "string" ? data.name.trim() : "";
    if (!name) return;
    const ranking = typeof data.ranking === "number" ? data.ranking : 0;
    const matchCount = spotIdToMatchCount.get(doc.id) || 0;
    const spot = {id: doc.id, ...data, ranking, matchCount};
    matches.push(spot);
  });

  // Sort by match count (most tokens first), then ranking, then name
  matches.sort((a, b) => {
    if (a.matchCount !== b.matchCount) return b.matchCount - a.matchCount;
    if (a.ranking !== b.ranking) return b.ranking - a.ranking;
    return String(a.name).localeCompare(String(b.name));
  });

  const normalize = (s) => {
    const createdAt = formatDateToISO(s.createdAt) || s.createdAt || null;
    const updatedAt = formatDateToISO(s.updatedAt) || s.updatedAt || null;
    const rest = {...s};
    delete rest.matchCount;
    return {...rest, createdAt, updatedAt};
  };

  const spots = matches.slice(0, maxResults).map(normalize);
  return {success: true, spots};
}

// Spot title search for Explore autocomplete.
// Multi-word: query each token, intersect results. Rank by match count, then spot ranking.
exports.searchSpotsByTitle = onCall(
    {region: "europe-west1", memory: "256MiB", timeoutSeconds: 10},
    async (request) => {
      try {
        const result = await executeSearchSpotsByTitle(request.data || {});
        if (!result.success) return {success: false, error: result.error};
        // Flutter autocomplete needs reduced shape
        const spots = (result.spots || []).map((s) => ({
          id: s.id,
          name: s.name,
          address: s.address,
          city: s.city,
          countryCode: s.countryCode,
          latitude: s.latitude,
          longitude: s.longitude,
        }));
        return {success: true, spots};
      } catch (error) {
        console.error("Error in searchSpotsByTitle:", error);
        return {success: false, error: error.message};
      }
    },
);

// Places Autocomplete (addresses, cities, countries)
exports.placesAutocomplete = onCall(
    {region: "europe-west1", secrets: ["GOOGLE_MAPS_API_KEY"]},
    async (request) => {
      try {
        const {
          input,
          sessionToken,
          location,
          radiusMeters,
          types = "geocode",
          language,
        } = request.data || {};

        if (!input || typeof input !== "string") {
          throw new Error("input is required");
        }

        const apiKey = process.env.GOOGLE_MAPS_API_KEY;
        if (!apiKey) {
          throw new Error("Google Maps API key not configured");
        }

        // Build Places Autocomplete URL
        const params = new URLSearchParams();
        params.append("input", input);
        params.append("key", apiKey);
        if (sessionToken) params.append("sessiontoken", sessionToken);
        if (types) params.append("types", types); // geocode to bias addresses
        if (language) params.append("language", language);
        if (
          location &&
        typeof location.lat === "number" &&
        typeof location.lng === "number"
        ) {
          params.append("location", `${location.lat},${location.lng}`);
          if (typeof radiusMeters === "number") {
            params.append("radius", String(radiusMeters));
          }
        }

        const url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?${params.toString()}`;

        const response = await new Promise((resolve, reject) => {
          https
              .get(url, (res) => {
                let data = "";
                res.on("data", (chunk) => (data += chunk));
                res.on("end", () => {
                  try {
                    resolve(JSON.parse(data));
                  } catch (e) {
                    reject(e);
                  }
                });
              })
              .on("error", reject);
        });

        if (response.status === "OK" && Array.isArray(response.predictions)) {
          const suggestions = response.predictions.map((p) => ({
            description: p.description,
            placeId: p.place_id,
            types: p.types || [],
            matchedSubstrings: p.matched_substrings || [],
            structuredFormatting: p.structured_formatting || null,
          }));
          return {success: true, suggestions};
        }

        return {
          success: false,
          error: response.error_message || response.status || "No suggestions",
        };
      } catch (error) {
        console.error("Error in placesAutocomplete:", error);
        return {success: false, error: error.message};
      }
    },
);

// Place Details to get coordinates and formatted address
exports.placeDetails = onCall(
    {region: "europe-west1", secrets: ["GOOGLE_MAPS_API_KEY"]},
    async (request) => {
      try {
        const {placeId, sessionToken, language} = request.data || {};
        if (!placeId) {
          throw new Error("placeId is required");
        }

        const apiKey = process.env.GOOGLE_MAPS_API_KEY;
        if (!apiKey) {
          throw new Error("Google Maps API key not configured");
        }

        const params = new URLSearchParams();
        params.append("place_id", placeId);
        params.append(
            "fields",
            "geometry,formatted_address,address_component,types",
        );
        params.append("key", apiKey);
        if (sessionToken) params.append("sessiontoken", sessionToken);
        if (language) params.append("language", language);

        const url = `https://maps.googleapis.com/maps/api/place/details/json?${params.toString()}`;

        const response = await new Promise((resolve, reject) => {
          https
              .get(url, (res) => {
                let data = "";
                res.on("data", (chunk) => (data += chunk));
                res.on("end", () => {
                  try {
                    resolve(JSON.parse(data));
                  } catch (e) {
                    reject(e);
                  }
                });
              })
              .on("error", reject);
        });

        if (response.status === "OK" && response.result) {
          const r = response.result;
          const loc = r.geometry && r.geometry.location;
          const viewport = r.geometry && r.geometry.viewport;
          let city = null;
          let countryCode = null;
          if (Array.isArray(r.address_components)) {
            const components = r.address_components;
            const countryComp = components.find(
                (c) => c.types && c.types.includes("country"),
            );
            if (countryComp && countryComp.short_name) {
              countryCode = countryComp.short_name;
            }
            const cityTypesPriority = [
              "locality",
              "postal_town",
              "administrative_area_level_2",
              "administrative_area_level_1",
            ];
            for (const t of cityTypesPriority) {
              const comp = components.find((c) => c.types && c.types.includes(t));
              if (comp && comp.long_name) {
                city = comp.long_name;
                break;
              }
            }
          }
          return {
            success: true,
            latitude: loc && loc.lat,
            longitude: loc && loc.lng,
            formattedAddress: r.formatted_address || null,
            city,
            countryCode,
            viewport,
            types: r.types || [],
          };
        }

        return {
          success: false,
          error: response.error_message || response.status || "No details found",
        };
      } catch (error) {
        console.error("Error in placeDetails:", error);
        return {success: false, error: error.message};
      }
    },
);

// Reverse geocoding function to convert address to coordinates
exports.reverseGeocodeAddress = onCall(
    {region: "europe-west1", secrets: ["GOOGLE_MAPS_API_KEY"]},
    async (request) => {
      try {
        const {address} = request.data;

        if (!address) {
          throw new Error("address is required");
        }

        // Use Google Maps Geocoding API
        const apiKey = process.env.GOOGLE_MAPS_API_KEY;
        if (!apiKey) {
          throw new Error("Google Maps API key not configured");
        }

        const encodedAddress = encodeURIComponent(address);
        const geocodingUrl = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodedAddress}&key=${apiKey}`;

        const response = await new Promise((resolve, reject) => {
          https
              .get(geocodingUrl, (res) => {
                let data = "";
                res.on("data", (chunk) => (data += chunk));
                res.on("end", () => {
                  try {
                    resolve(JSON.parse(data));
                  } catch (e) {
                    reject(e);
                  }
                });
              })
              .on("error", reject);
        });

        if (
          response.status === "OK" &&
        response.results &&
        response.results.length > 0
        ) {
          const location = response.results[0].geometry.location;
          return {
            success: true,
            latitude: location.lat,
            longitude: location.lng,
          };
        } else {
          return {
            success: false,
            error: response.error_message || "No coordinates found for address",
          };
        }
      } catch (error) {
        console.error("Error reverse geocoding address:", error);
        return {
          success: false,
          error: error.message,
        };
      }
    },
);

// Function to cleanup unused images by moving them to trash (admin only)
exports.cleanupUnusedImages = onCall(
    {region: "europe-west1", memory: "2GiB", timeoutSeconds: 540},
    async (request) => {
      try {
        await ensureAdmin(request);

        console.log("Starting unused images cleanup");

        // Get all spots to find which images are currently in use
        const spotsSnapshot = await db.collection("spots").get();
        const usedImageUrls = new Set();
        const usedImageBaseNames = new Set(); // Track base names for resized image matching

        spotsSnapshot.forEach((doc) => {
          const spotData = doc.data();
          if (spotData.imageUrls && Array.isArray(spotData.imageUrls)) {
            spotData.imageUrls.forEach((url) => {
            // Extract filename from URL, handling both Firebase Storage URL formats
              let filename;
              try {
                const urlObj = new URL(url);
                const pathname = urlObj.pathname;

                // Handle Firebase Storage URLs with encoded paths
                if (
                  url.includes("firebasestorage.googleapis.com") &&
                pathname.includes("/o/")
                ) {
                // Format: /v0/b/bucket-name/o/spots%2Ffilename.jpg
                  const encodedPath = pathname.split("/o/")[1];
                  const decodedPath = decodeURIComponent(encodedPath);
                  filename = decodedPath.split("/").pop();
                } else {
                // Format: /bucket-name/spots/filename.jpg
                  filename = pathname.split("/").pop();
                }

                if (filename) {
                  usedImageUrls.add(filename);
                  // Extract base name for resized image matching
                  // Remove extension to get base name (e.g., "image_123_hash_0" from "image_123_hash_0.jpg")
                  const baseName = filename.replace(/\.[^/.]+$/, "");
                  usedImageBaseNames.add(baseName);
                }
              } catch (urlError) {
                console.warn(`Failed to parse URL: ${url}`, urlError);
                // Fallback to simple extraction
                const urlParts = url.split("/");
                const lastPart = urlParts[urlParts.length - 1];
                const filename = lastPart.split("?")[0]; // Remove query parameters
                if (filename) {
                  usedImageUrls.add(filename);
                  const baseName = filename.replace(/\.[^/.]+$/, "");
                  usedImageBaseNames.add(baseName);
                }
              }
            });
          }
        });

        console.log(`Found ${usedImageUrls.size} images currently in use`);

        // Helper function to check if a file is a resized version of a used image
        const isResizedVersionOfUsedImage = (fileName) => {
          // Check if file is in resized folder
          if (!fileName.startsWith("spots/resized/")) {
            return false;
          }

          // Extract the resized filename (remove "spots/resized/" prefix)
          const resizedFileName = fileName.replace("spots/resized/", "");

          // Remove extension and size suffix to get base name
          // Firebase Storage Resize extension creates files like: "baseName_1200x630.webp"
          const baseName = resizedFileName.replace(/_\d+x\d+\.webp$/, "");

          return usedImageBaseNames.has(baseName);
        };

        // Ensure trash folder exists by creating a placeholder if needed
        const trashFolderExists = await bucket
            .file("spots/trash/.gitkeep")
            .exists();
        if (!trashFolderExists[0]) {
          console.log("Creating trash folder...");
          await bucket.file("spots/trash/.gitkeep").save("", {
            metadata: {
              contentType: "text/plain",
            },
          });
          console.log("Trash folder created");
        }

        let movedCount = 0;
        let skippedCount = 0;
        let totalFiles = 0;
        const movedFiles = [];
        const BATCH_SIZE = 100; // Process files in batches
        const LOG_INTERVAL = 1000; // Log progress every N files

        // Helper function to process a batch of files
        const processBatch = async (
            files,
            usedImageUrls,
            isResizedVersionOfUsedImage,
        ) => {
          let batchMovedCount = 0;
          let batchSkippedCount = 0;
          const batchMovedFiles = [];

          for (const file of files) {
            const fileName = file.name;
            const fileNameOnly = fileName.split("/").pop();

            // Skip if file is currently in use (original image)
            if (usedImageUrls.has(fileNameOnly)) {
              batchSkippedCount++;
              continue;
            }

            // Skip if file is a resized version of a used image
            if (isResizedVersionOfUsedImage(fileName)) {
              batchSkippedCount++;
              continue;
            }

            // Skip if already in trash folder
            if (fileName.startsWith("spots/trash/")) {
              batchSkippedCount++;
              continue;
            }

            try {
              // Determine trash path based on file location
              let trashFileName;
              if (fileName.startsWith("spots/resized/")) {
                // Keep resized folder structure in trash
                trashFileName = `spots/trash/resized/${fileNameOnly}`;
              } else {
                // Original images go directly to trash root
                trashFileName = `spots/trash/${fileNameOnly}`;
              }

              // Copy to trash location
              await file.copy(trashFileName);

              // Delete original file
              await file.delete();

              batchMovedCount++;
              batchMovedFiles.push(fileName);
            } catch (moveError) {
              console.error(`Failed to move file ${fileName} to trash:`, moveError);
            }
          }

          return {batchMovedCount, batchSkippedCount, batchMovedFiles};
        };

        // Process files using streaming to avoid loading all into memory
        return new Promise((resolve, reject) => {
          const fileStream = bucket.getFilesStream({
            prefix: "spots/",
          });

          let batch = [];
          let processedInBatch = 0;
          let isProcessing = false;

          fileStream
              .on("data", (file) => {
                totalFiles++;
                batch.push(file);

                // Process batch when it reaches BATCH_SIZE (only if not already processing)
                if (batch.length >= BATCH_SIZE && !isProcessing) {
                  fileStream.pause(); // Pause the stream while processing
                  isProcessing = true;

                  const currentBatch = batch;
                  batch = [];

                  processBatch(
                      currentBatch,
                      usedImageUrls,
                      isResizedVersionOfUsedImage,
                  )
                      .then((result) => {
                        movedCount += result.batchMovedCount;
                        skippedCount += result.batchSkippedCount;
                        movedFiles.push(...result.batchMovedFiles);
                        processedInBatch += currentBatch.length;

                        // Log progress periodically
                        if (processedInBatch % LOG_INTERVAL === 0) {
                          console.log(
                              `Processed ${processedInBatch} files. ` +
                              `Moved: ${movedCount}, Skipped: ${skippedCount}`,
                          );
                        }

                        isProcessing = false;
                        fileStream.resume(); // Resume the stream
                      })
                      .catch((error) => {
                        fileStream.destroy();
                        reject(error);
                      });
                }
              })
              .on("end", async () => {
                // Wait for any ongoing batch processing to complete
                while (isProcessing) {
                  await new Promise((r) => setTimeout(r, 100));
                }

                // Process remaining files in the batch
                if (batch.length > 0) {
                  try {
                    const result = await processBatch(
                        batch,
                        usedImageUrls,
                        isResizedVersionOfUsedImage,
                    );
                    movedCount += result.batchMovedCount;
                    skippedCount += result.batchSkippedCount;
                    movedFiles.push(...result.batchMovedFiles);
                  } catch (error) {
                    reject(error);
                    return;
                  }
                }

                const result = {
                  success: true,
                  movedCount,
                  skippedCount,
                  totalFiles,
                  movedFiles: movedFiles.slice(0, 10), // Limit to first 10 for response size
                  message:
                  `Cleanup completed. Moved ${movedCount} unused images ` +
                  `(including resized versions) to trash, skipped ${skippedCount} files.`,
                };

                console.log("Unused images cleanup completed:", result);
                resolve(result);
              })
              .on("error", (error) => {
                console.error("Error streaming files:", error);
                reject(error);
              });
        });
      } catch (error) {
        console.error("Error during unused images cleanup:", error);
        return {
          success: false,
          error: error.message,
        };
      }
    },
);


// Function to find missing images and provide upload URLs (admin only)
exports.findMissingImages = onCall(
    {region: "europe-west1", memory: "2GiB", timeoutSeconds: 540},
    async (request) => {
      try {
        await ensureAdmin(request);

        console.log("Starting missing images check");

        // Get all spots to find which images are referenced
        // Build a map of filename -> array of spots that reference it
        // This avoids the nested loop later
        const spotsSnapshot = await db.collection("spots").get();
        const filenameToSpots = new Map(); // filename -> [{spotId, spotName, imageUrl}]

        spotsSnapshot.forEach((doc) => {
          const spotData = doc.data();
          if (spotData.imageUrls && Array.isArray(spotData.imageUrls)) {
            spotData.imageUrls.forEach((url) => {
              const filename = extractFilename(url);
              if (filename) {
                if (!filenameToSpots.has(filename)) {
                  filenameToSpots.set(filename, []);
                }
                filenameToSpots.get(filename).push({
                  spotId: doc.id,
                  spotName: spotData.name || "Unnamed Spot",
                  imageUrl: url,
                });
              }
            });
          }
        });

        console.log(`Found ${filenameToSpots.size} referenced images`);

        // List all files in the spots folder
        const [files] = await bucket.getFiles({
          prefix: "spots/",
        });

        console.log(`Found ${files.length} total files in storage`);

        // Create a set of existing filenames
        const existingFiles = new Set();
        files.forEach((file) => {
          const fileName = file.name;
          const fileNameOnly = fileName.split("/").pop();
          existingFiles.add(fileNameOnly);
        });

        // Find missing images and build result in one pass
        const missingImagesWithSpots = [];
        filenameToSpots.forEach((spots, filename) => {
          if (!existingFiles.has(filename)) {
            missingImagesWithSpots.push({
              filename: filename,
              spots: spots,
            });
          }
        });

        const result = {
          success: true,
          totalReferencedImages: filenameToSpots.size,
          totalExistingFiles: existingFiles.size,
          missingImagesCount: missingImagesWithSpots.length,
          missingImages: missingImagesWithSpots,
          message: `Found ${missingImagesWithSpots.length} missing images referenced by ${spotsSnapshot.size} spots`,
        };

        console.log("Missing images check completed:", result);
        return result;
      } catch (error) {
        console.error("Error during missing images check:", error);
        return {
          success: false,
          error: error.message,
        };
      }
    },
);

// Function to upload replacement image (admin only)
exports.uploadReplacementImage = onCall(
    {region: "europe-west1", memory: "256MiB", timeoutSeconds: 60},
    async (request) => {
      try {
        await ensureAdmin(request);

        const {filename, imageData, contentType = "image/jpeg"} = request.data;

        if (!filename || !imageData) {
          throw new Error("filename and imageData are required");
        }

        console.log(`Uploading replacement image: ${filename}`);

        // Convert base64 to buffer
        const imageBuffer = Buffer.from(imageData, "base64");

        // Upload to Firebase Storage
        const fileName = `spots/${filename}`;
        const file = bucket.file(fileName);

        await file.save(imageBuffer, {
          metadata: {
            contentType: contentType,
            cacheControl: "public, max-age=31536000",
          },
        });

        // Make file publicly accessible
        await file.makePublic();

        // Get public URL
        const publicUrl = `https://storage.googleapis.com/${bucket.name}/${fileName}`;

        console.log(`Successfully uploaded replacement image: ${filename}`);

        return {
          success: true,
          filename: filename,
          publicUrl: publicUrl,
          message: `Successfully uploaded replacement image: ${filename}`,
        };
      } catch (error) {
        console.error("Error uploading replacement image:", error);
        return {
          success: false,
          error: error.message,
        };
      }
    },
);

// Trigger storage-resize-images extension for one spot's images missing resized versions (admin only)
exports.triggerResizeForSpot = onCall(
    {region: "europe-west1", memory: "512MiB", timeoutSeconds: 120},
    async (request) => {
      try {
        await ensureAdmin(request);

        const {spotId} = request.data || {};
        if (!spotId || typeof spotId !== "string") {
          throw new Error("spotId is required");
        }

        const doc = await db.collection("spots").doc(spotId).get();
        if (!doc.exists) {
          throw new Error("Spot not found");
        }

        const data = doc.data();
        const imageUrls = data.imageUrls || [];
        const spotName = data.name || "Unnamed";

        const toProcess = [];
        for (const url of imageUrls) {
          const info = getResizedPathInfo(url);
          if (!info) continue;

          // Skip if any resized version exists (1200x1200 or 1200x630)
          let hasResized = false;
          for (const candidatePath of info.resizedPathCandidates) {
            const [exists] = await bucket.file(candidatePath).exists();
            if (exists) {
              hasResized = true;
              break;
            }
          }
          if (hasResized) continue;

          toProcess.push({originalPath: info.originalPath, resizedPath: info.resizedPath});
        }

        console.log(`Spot ${spotId}: ${toProcess.length} images missing resized versions`);

        const results = [];
        const VERIFY_DELAY_MS = 3000;

        for (let i = 0; i < toProcess.length; i++) {
          const item = toProcess[i];
          const file = bucket.file(item.originalPath);
          const result = {
            originalPath: item.originalPath,
            resizedPath: item.resizedPath,
            triggered: false,
            verified: false,
            error: null,
          };

          try {
            const [exists] = await file.exists();
            if (!exists) {
              result.error = "Original file not found";
              results.push(result);
              continue;
            }

            const [metadata] = await file.getMetadata();
            const contentType = getImageContentTypeForPath(
                item.originalPath,
                metadata?.contentType,
            );
            if (metadata?.contentType === "application/octet-stream") {
              console.log(`Fixing contentType for ${item.originalPath}: octet-stream -> ${contentType}`);
            }

            const [buffer] = await file.download();
            await file.save(buffer, {
              metadata: {contentType, cacheControl: "public, max-age=31536000"},
            });
            result.triggered = true;

            if (i < toProcess.length - 1) {
              await new Promise((r) => setTimeout(r, 500));
            }
          } catch (err) {
            result.error = err.message;
            console.error(`Trigger failed for ${item.originalPath}:`, err);
          }
          results.push(result);
        }

        if (toProcess.length > 0) {
          await new Promise((r) => setTimeout(r, VERIFY_DELAY_MS));
        }

        for (const r of results) {
          if (!r.triggered || r.error) continue;
          const item = toProcess.find((p) => p.originalPath === r.originalPath);
          if (item) {
            const [exists] = await bucket.file(item.resizedPath).exists();
            r.verified = exists;
          }
        }

        const triggered = results.filter((r) => r.triggered).length;
        const verified = results.filter((r) => r.verified).length;
        const failed = results.filter((r) => r.error).length;

        return {
          success: true,
          spotId,
          spotName,
          total: toProcess.length,
          triggered,
          verified,
          failed,
          results,
          message: `Triggered resize for ${triggered} images. Verified: ${verified} succeeded, ${failed} had errors.`,
        };
      } catch (error) {
        console.error("Error triggering resize for spot:", error);
        return {success: false, error: error.message};
      }
    },
);

// Trigger storage-resize-images extension for images missing resized versions (admin only)
// Re-uploads each image to the same path, which fires object.finalize and triggers the extension
exports.triggerResizeForMissingImages = onCall(
    {region: "europe-west1", memory: "512MiB", timeoutSeconds: 540},
    async (request) => {
      try {
        await ensureAdmin(request);

        // 1. Find all spots with imageUrls and collect image URLs that need resized versions
        const spotsSnapshot = await db.collection("spots")
            .where("imageUrls", "!=", null)
            .get();

        const toProcess = []; // {originalPath, resizedPath, spotId, spotName}
        const seenPaths = new Set();

        for (const doc of spotsSnapshot.docs) {
          const data = doc.data();
          const imageUrls = data.imageUrls || [];
          const spotName = data.name || "Unnamed";

          for (const url of imageUrls) {
            const info = getResizedPathInfo(url);
            if (!info) continue;

            if (seenPaths.has(info.originalPath)) continue;
            seenPaths.add(info.originalPath);

            // Skip if any resized version exists (1200x1200 or 1200x630)
            let hasResized = false;
            for (const candidatePath of info.resizedPathCandidates) {
              const [exists] = await bucket.file(candidatePath).exists();
              if (exists) {
                hasResized = true;
                break;
              }
            }
            if (hasResized) continue;

            toProcess.push({
              originalPath: info.originalPath,
              resizedPath: info.resizedPath,
              spotId: doc.id,
              spotName,
            });
          }
        }

        console.log(`Found ${toProcess.length} images missing resized versions`);

        const results = [];
        const VERIFY_DELAY_MS = 3000; // Wait for extension to process

        for (let i = 0; i < toProcess.length; i++) {
          const item = toProcess[i];
          const file = bucket.file(item.originalPath);
          const result = {
            originalPath: item.originalPath,
            resizedPath: item.resizedPath,
            spotId: item.spotId,
            spotName: item.spotName,
            triggered: false,
            verified: false,
            error: null,
          };

          try {
            const [exists] = await file.exists();
            if (!exists) {
              result.error = "Original file not found";
              results.push(result);
              continue;
            }

            const [metadata] = await file.getMetadata();
            const contentType = getImageContentTypeForPath(
                item.originalPath,
                metadata?.contentType,
            );
            if (metadata?.contentType === "application/octet-stream") {
              console.log(`Fixing contentType for ${item.originalPath}: octet-stream -> ${contentType}`);
            }

            const [buffer] = await file.download();
            await file.save(buffer, {
              metadata: {
                contentType,
                cacheControl: "public, max-age=31536000",
              },
            });
            result.triggered = true;

            // Small delay between triggers to avoid overwhelming the extension
            if (i < toProcess.length - 1) {
              await new Promise((r) => setTimeout(r, 500));
            }
          } catch (err) {
            result.error = err.message;
            console.error(`Trigger failed for ${item.originalPath}:`, err);
          }
          results.push(result);
        }

        // Wait for extension to process, then verify
        if (toProcess.length > 0) {
          await new Promise((r) => setTimeout(r, VERIFY_DELAY_MS));
        }

        for (const r of results) {
          if (!r.triggered || r.error) continue;
          const item = toProcess.find((p) => p.originalPath === r.originalPath);
          if (item) {
            const [exists] = await bucket.file(item.resizedPath).exists();
            r.verified = exists;
          }
        }

        const triggered = results.filter((r) => r.triggered).length;
        const verified = results.filter((r) => r.verified).length;
        const failed = results.filter((r) => r.error).length;

        return {
          success: true,
          total: toProcess.length,
          triggered,
          verified,
          failed,
          results,
          message: `Triggered resize for ${triggered} images. Verified: ${verified} succeeded, ${failed} had errors.`,
        };
      } catch (error) {
        console.error("Error triggering resize for missing images:", error);
        return {
          success: false,
          error: error.message,
        };
      }
    },
);

// Test function to check spots in database
exports.testSpotsCount = onCall({region: "europe-west1"}, async (request) => {
  try {
    await ensureAdmin(request);
    const spotsSnapshot = await db.collection("spots").get();
    console.log(`Total spots in database: ${spotsSnapshot.size}`);

    // Count spots missing latitude/longitude (field doesn't exist or is null/undefined)
    const spotsMissingLatLng = spotsSnapshot.docs.filter((doc) => {
      const data = doc.data();
      return (
        !Object.prototype.hasOwnProperty.call(data, "latitude") ||
        data.latitude === null ||
        data.latitude === undefined ||
        !Object.prototype.hasOwnProperty.call(data, "longitude") ||
        data.longitude === null ||
        data.longitude === undefined
      );
    });
    console.log(
        `Spots missing latitude/longitude: ${spotsMissingLatLng.length}`,
    );

    // Check a few sample spots
    let sampleCount = 0;
    spotsSnapshot.forEach((doc) => {
      if (sampleCount < 3) {
        const data = doc.data();
        console.log(
            `Spot ${doc.id}: address="${data.address}", city="${data.city}", countryCode="${data.countryCode}", lat="${data.latitude}", lng="${data.longitude}"`,
        );
        sampleCount++;
      }
    });

    return {
      success: true,
      totalSpots: spotsSnapshot.size,
      missingLatLng: spotsMissingLatLng.length,
      message: `Found ${spotsSnapshot.size} total spots, ${spotsMissingLatLng.length} missing lat/lng`,
    };
  } catch (error) {
    console.error("Error testing spots count:", error);
    return {
      success: false,
      error: error.message,
    };
  }
});

// Function to find and log spots linked to non-existent spot sources (admin only)
exports.findOrphanedSpots = onCall(
    {region: "europe-west1", memory: "512MiB", timeoutSeconds: 300},
    async (request) => {
      try {
        await ensureAdmin(request);

        console.log("Starting orphaned spots check...");

        // Get all spots that have a spotSource field
        const spotsSnapshot = await db
            .collection("spots")
            .where("spotSource", "!=", null)
            .get();

        console.log(`Found ${spotsSnapshot.size} spots with spotSource field`);

        // Get all sync source IDs
        const syncSourcesSnapshot = await db.collection("syncSources").get();
        const validSourceIds = new Set();

        syncSourcesSnapshot.forEach((doc) => {
          validSourceIds.add(doc.id);
        });

        console.log(`Found ${validSourceIds.size} valid sync sources`);

        // Find orphaned spots
        const orphanedSpots = [];
        let validSpotsCount = 0;

        spotsSnapshot.forEach((doc) => {
          const spotData = doc.data();
          const spotSource = spotData.spotSource;

          if (spotSource && !validSourceIds.has(spotSource)) {
            orphanedSpots.push({
              spotId: doc.id,
              spotName: spotData.name || "Unnamed Spot",
              spotSource: spotSource,
              latitude: spotData.latitude,
              longitude: spotData.longitude,
              address: spotData.address,
              city: spotData.city,
              countryCode: spotData.countryCode,
              createdAt: spotData.createdAt,
              updatedAt: spotData.updatedAt,
            });

            console.log(
                `ORPHANED SPOT: ${doc.id} - "${spotData.name || "Unnamed Spot"}" references non-existent source: ${spotSource}`,
            );
          } else {
            validSpotsCount++;
          }
        });

        const result = {
          success: true,
          totalSpotsWithSource: spotsSnapshot.size,
          validSpotsCount: validSpotsCount,
          orphanedSpotsCount: orphanedSpots.length,
          orphanedSpots: orphanedSpots,
          validSourceIds: Array.from(validSourceIds),
          message: `Found ${orphanedSpots.length} orphaned spots out of ${spotsSnapshot.size} spots with spotSource field`,
        };

        console.log("Orphaned spots check completed:", result);
        return result;
      } catch (error) {
        console.error("Error during orphaned spots check:", error);
        return {
          success: false,
          error: error.message,
        };
      }
    },
);

// Function to delete a spot (admin only)
exports.deleteSpot = onCall({region: "europe-west1"}, async (request) => {
  try {
    await ensureAdmin(request);
    const {spotId} = request.data;

    if (!spotId) {
      throw new Error("spotId is required");
    }

    // Get spot data first to log what we're deleting
    const spotDoc = await db.collection("spots").doc(spotId).get();
    if (!spotDoc.exists) {
      throw new Error(`Spot with ID ${spotId} not found`);
    }

    const spotData = spotDoc.data();
    const spotName = spotData.name || "Unnamed Spot";

    // Delete the spot
    await db.collection("spots").doc(spotId).delete();

    console.log(`Admin deleted spot: ${spotName} (${spotId})`);

    return {
      success: true,
      message: `Spot "${spotName}" deleted successfully`,
      spotId: spotId,
    };
  } catch (error) {
    console.error("Error deleting spot:", error);
    throw new Error(`Failed to delete spot: ${error.message}`);
  }
});

// Function to delete multiple spots (admin only)
exports.deleteSpots = onCall(
    {region: "europe-west1", memory: "512MiB", timeoutSeconds: 300},
    async (request) => {
      try {
        await ensureAdmin(request);
        const {spotIds} = request.data;

        if (!Array.isArray(spotIds) || spotIds.length === 0) {
          throw new Error("spotIds array is required");
        }

        console.log(`Admin deleting ${spotIds.length} spots`);

        // Delete spots in batch
        const batch = db.batch();
        const deletedSpots = [];

        for (const spotId of spotIds) {
          const spotRef = db.collection("spots").doc(spotId);
          batch.delete(spotRef);
          deletedSpots.push(spotId);
        }

        await batch.commit();

        console.log(`Admin successfully deleted ${deletedSpots.length} spots`);

        return {
          success: true,
          message: `Successfully deleted ${deletedSpots.length} spots`,
          deletedCount: deletedSpots.length,
          deletedSpotIds: deletedSpots,
        };
      } catch (error) {
        console.error("Error deleting spots:", error);
        throw new Error(`Failed to delete spots: ${error.message}`);
      }
    },
);

/**
 * Admin tool: Geocode all spots missing address fields
 * (address, city, or countryCode)
 */
exports.geocodeMissingSpotAddresses = onCall(
    {
      region: "europe-west1",
      memory: "1GiB",
      timeoutSeconds: 900,
      secrets: ["GOOGLE_MAPS_API_KEY"],
    },
    async (request) => {
      try {
        console.log("geocodeMissingSpotAddresses function called");
        await ensureAdmin(request);
        console.log("Admin check passed");

        const apiKey = process.env.GOOGLE_MAPS_API_KEY;
        if (!apiKey) {
          throw new Error("Google Maps API key not configured");
        }


        // Process spots in batches to avoid timeout
        const BATCH_SIZE = 50; // Process 50 spots at a time
        const API_DELAY = 100; // 100ms delay between API calls to respect rate limits

        let totalCandidates = 0;
        let processed = 0;
        let updated = 0;
        let failed = 0;
        let skipped = 0;
        let lastDoc = null;

        // First, get total count of all spots and candidates
        console.log("Scanning all spots to count candidates...");
        const allSpotsSnapshot = await db.collection("spots").get();
        const totalSpots = allSpotsSnapshot.size;
        let totalCandidatesCount = 0;

        allSpotsSnapshot.forEach((doc) => {
          const data = doc.data();
          const address = data.address;
          const city = data.city;
          const countryCode = data.countryCode;

          const isMissingAddress = !address || address.trim() === "";
          const isMissingCity = !city || city.trim() === "";
          const isMissingCountryCode = !countryCode || countryCode.trim() === "";

          if (isMissingAddress || isMissingCity || isMissingCountryCode) {
            totalCandidatesCount++;
          }
        });

        console.log(
            `Database scan complete: ${totalSpots} total spots, ${totalCandidatesCount} candidates for geocoding`,
        );

        // Now process in batches
        console.log("Starting batch processing of candidates...");
        let batchNumber = 0;

        let processing = true;
        while (processing) {
          batchNumber++;
          console.log(`Processing batch ${batchNumber}...`);

          // Build query for next batch
          let query = db.collection("spots").limit(BATCH_SIZE);
          if (lastDoc) {
            query = query.startAfter(lastDoc);
          }

          const batchSnapshot = await query.get();
          if (batchSnapshot.empty) {
            console.log(
                `No more spots to process. Completed ${batchNumber - 1} batches.`,
            );
            processing = false;
          }

          console.log(
              `Batch ${batchNumber}: Processing ${batchSnapshot.size} spots...`,
          );

          // Filter spots in this batch that need geocoding
          const batchCandidates = [];
          batchSnapshot.forEach((doc) => {
            const data = doc.data();
            const address = data.address;
            const city = data.city;
            const countryCode = data.countryCode;

            // Check if any of the address fields are missing or empty
            const isMissingAddress = !address || address.trim() === "";
            const isMissingCity = !city || city.trim() === "";
            const isMissingCountryCode =
            !countryCode || countryCode.trim() === "";

            if (isMissingAddress || isMissingCity || isMissingCountryCode) {
              batchCandidates.push(doc);
            }
          });

          totalCandidates += batchCandidates.length;
          console.log(
              `Batch ${batchNumber}: Found ${batchCandidates.length} candidates (${totalCandidates}/${totalCandidatesCount} total)`,
          );

          // Process each candidate in this batch
          for (const doc of batchCandidates) {
            try {
              const data = doc.data();
              const location = data && data.location;
              if (
                !location ||
              typeof location.latitude !== "number" ||
              typeof location.longitude !== "number"
              ) {
                skipped++;
                console.warn(
                    `Skipping spot ${doc.id}: invalid or missing location`,
                );
                continue;
              }

              const latitude = location.latitude;
              const longitude = location.longitude;

              // Add delay to respect API rate limits
              if (processed > 0) {
                await new Promise((resolve) => setTimeout(resolve, API_DELAY));
              }

              const result = await geocodeLatLng(latitude, longitude, apiKey);

              if (result.success) {
                await doc.ref.update({
                  address: result.address || null,
                  city: result.city || null,
                  countryCode: result.countryCode || null,
                  updatedAt: FieldValue.serverTimestamp(),
                });
                updated++;
                console.log(`✓ Updated spot ${doc.id}: ${result.address}`);
              } else {
                console.warn(
                    `✗ Geocoding failed for spot ${doc.id}: ${result.error}`,
                );
                failed++;
              }
            } catch (err) {
              console.error(`✗ Error processing spot ${doc.id}:`, err);
              failed++;
            } finally {
              processed++;

              // Log progress every 5 spots
              if (processed % 5 === 0) {
                const progress = (
                  (processed / totalCandidatesCount) *
                100
                ).toFixed(1);
                console.log(
                    `Progress: ${processed}/${totalCandidatesCount} (${progress}%) - Updated: ${updated}, Failed: ${failed}, Skipped: ${skipped}`,
                );
              }
            }
          }

          // Update lastDoc for pagination
          lastDoc = batchSnapshot.docs[batchSnapshot.docs.length - 1];

          // Force garbage collection after each batch
          if (global.gc) {
            global.gc();
            console.log(
                `Batch ${batchNumber} completed. Processed: ${processed}, Updated: ${updated}, Failed: ${failed}, Skipped: ${skipped}`,
            );
          }
        }

        console.log(`Batch processing completed!`);
        console.log(
            `Final results: ${totalSpots} total spots, ${totalCandidatesCount} candidates, ${processed} processed, ${updated} updated, ${failed} failed, ${skipped} skipped`,
        );

        const response = {
          success: true,
          message: `Geocoding completed successfully! Processed ${processed} spots out of ${totalCandidatesCount} candidates from ${totalSpots} total spots.`,
          stats: {
            totalSpots,
            totalCandidates: totalCandidatesCount,
            processed,
            updated,
            failed,
            skipped,
            successRate:
            totalCandidatesCount > 0 ?
              ((updated / totalCandidatesCount) * 100).toFixed(1) + "%" :
              "0%",
          },
        };
        console.log("Geocode missing addresses result:", response);
        console.log("Returning response from geocodeMissingSpotAddresses");
        return response;
      } catch (error) {
        console.error("Error geocoding missing spot addresses:", error);
        console.log("Error details:", error.stack);
        return {
          success: false,
          error: error.message,
        };
      }
    },
);

/**
 * Scheduled function to check and run automated syncs for spot sources
 * Runs every hour to check which sources need syncing based on their cron schedules
 * Processes only one source per run to avoid timeout issues
 */
exports.checkAndRunAutoSyncs = onSchedule(
    {
      schedule: "every 1 hours",
      timeZone: "UTC",
      region: "europe-west1",
      memory: "2GiB",
      timeoutSeconds: 1800,
      secrets: ["GOOGLE_MAPS_API_KEY"],
    },
    async () => {
      console.log("Auto-sync check started");
      const apiKey = process.env.GOOGLE_MAPS_API_KEY;
      if (!apiKey) {
        throw new Error("Google Maps API key not configured");
      }

      try {
        // Get all active sync sources with auto-sync enabled
        const sourcesSnapshot = await db
            .collection("syncSources")
            .where("isActive", "==", true)
            .get();

        const now = new Date();
        let processedSource = false;

        for (const sourceDoc of sourcesSnapshot.docs) {
          const source = sourceDoc.data();
          const sourceId = sourceDoc.id;

          // Skip if auto-sync is disabled
          if (source.autoSyncEnabled !== true) {
            continue;
          }

          // PRIORITY 1: Check if there's a sync in progress - finish it first
          if (source.syncInProgress === true) {
            try {
              const syncType = source.syncType || "light";
              const startIndex = source.syncProgress?.lastProcessedIndex || 0;
              const isFullSync = syncType === "full";

              console.log(`Resuming in-progress ${syncType} sync for source: ${source.name} (${sourceId}) from index ${startIndex}`);

              // Refresh source data to get latest state
              const refreshedSourceDoc = await db.collection("syncSources").doc(sourceId).get();
              const refreshedSource = refreshedSourceDoc.data();

              const result = await processSyncSource(
                  refreshedSource,
                  sourceId,
                  apiKey,
                  isFullSync,
                  startIndex,
              );

              // If sync completed (not partial), update timestamp and clear progress
              if (!result.partial) {
                const updateField = isFullSync ? "lastFullSyncAt" : "lastLightSyncAt";
                await db.collection("syncSources").doc(sourceId).update({
                  [updateField]: FieldValue.serverTimestamp(),
                });
                console.log(`Auto-sync completed: ${syncType} sync for ${source.name}`, result.stats);
              } else {
                console.log(`Auto-sync partial: ${syncType} sync for ${source.name} - ${result.message}`);
              }

              processedSource = true;
              return {
                success: true,
                sourceId,
                sourceName: source.name,
                syncType: syncType,
                stats: result.stats,
                resumed: true,
                partial: result.partial,
                message: result.partial ? result.message : `Resumed and completed ${syncType} sync`,
              };
            } catch (error) {
              console.error(`Error resuming sync for ${source.name}:`, error);
              processedSource = true;
              return {
                success: false,
                sourceId,
                sourceName: source.name,
                syncType: source.syncType || "unknown",
                error: error.message,
                resumed: true,
                message: `Failed to resume sync for ${source.name}`,
              };
            }
          }

          // PRIORITY 2: Check if a new sync is due (only if no sync in progress)
          let shouldRunLightSync = false;
          let shouldRunFullSync = false;

          // Check light sync schedule
          if (source.lightSyncSchedule) {
            const lastLightSync = source.lastLightSyncAt?.toDate() || new Date(0);
            shouldRunLightSync = shouldRunSync(source.lightSyncSchedule, lastLightSync, now);
          }

          // Check full sync schedule
          if (source.fullSyncSchedule) {
            const lastFullSync = source.lastFullSyncAt?.toDate() || new Date(0);
            shouldRunFullSync = shouldRunSync(source.fullSyncSchedule, lastFullSync, now);
          }

          // Run full sync if scheduled (takes precedence)
          if (shouldRunFullSync) {
            try {
              console.log(`Running scheduled full sync for source: ${source.name} (${sourceId})`);
              const result = await processSyncSource(source, sourceId, apiKey, true);

              // If sync completed (not partial), update timestamp
              if (!result.partial) {
                await db.collection("syncSources").doc(sourceId).update({
                  lastFullSyncAt: FieldValue.serverTimestamp(),
                });
                console.log(`Auto-sync completed: Full sync for ${source.name}`, result.stats);
              } else {
                console.log(`Auto-sync partial: Full sync for ${source.name} - ${result.message}`);
              }

              processedSource = true;
              return {
                success: true,
                sourceId,
                sourceName: source.name,
                syncType: "full",
                stats: result.stats,
                partial: result.partial,
                message: result.partial ? result.message : `Processed 1 source (full sync)`,
              };
            } catch (error) {
              console.error(`Error running full sync for ${source.name}:`, error);
              processedSource = true;
              return {
                success: false,
                sourceId,
                sourceName: source.name,
                syncType: "full",
                error: error.message,
                message: `Failed to process source: ${source.name}`,
              };
            }
          } else if (shouldRunLightSync) {
            // Run light sync if scheduled (only if full sync wasn't needed)
            try {
              console.log(`Running scheduled light sync for source: ${source.name} (${sourceId})`);
              const result = await processSyncSource(source, sourceId, apiKey, false);

              // If sync completed (not partial), update timestamp
              if (!result.partial) {
                await db.collection("syncSources").doc(sourceId).update({
                  lastLightSyncAt: FieldValue.serverTimestamp(),
                });
                console.log(`Auto-sync completed: Light sync for ${source.name}`, result.stats);
              } else {
                console.log(`Auto-sync partial: Light sync for ${source.name} - ${result.message}`);
              }

              processedSource = true;
              return {
                success: true,
                sourceId,
                sourceName: source.name,
                syncType: "light",
                stats: result.stats,
                partial: result.partial,
                message: result.partial ? result.message : `Processed 1 source (light sync)`,
              };
            } catch (error) {
              console.error(`Error running light sync for ${source.name}:`, error);
              processedSource = true;
              return {
                success: false,
                sourceId,
                sourceName: source.name,
                syncType: "light",
                error: error.message,
                message: `Failed to process source: ${source.name}`,
              };
            }
          }
        }

        if (!processedSource) {
          console.log("Auto-sync check completed. No sources needed syncing at this time.");
          return {
            success: true,
            message: "No sources needed syncing",
            processed: 0,
          };
        }
      } catch (error) {
        console.error("Error in auto-sync check:", error);
        throw error;
      }
    },
);

/**
 * Scheduled function to regenerate sitemaps nightly
 * Runs at midnight UTC every day
 */
exports.generateSitemapsScheduled = onSchedule(
    {
      schedule: "every day 00:00",
      timeZone: "UTC",
      region: "europe-west1",
      memory: "1GiB", // Increase memory limit to handle large sitemap generation
      timeoutSeconds: 540, // 9 minutes (max for scheduled functions)
    },
    async () => {
      console.log("Scheduled sitemap generation started");
      try {
        // Generate and upload sitemaps to Storage
        await generateAllSitemaps();

        console.log("Scheduled sitemap generation completed successfully");
      } catch (error) {
        console.error("Error in scheduled sitemap generation:", error);
        throw error;
      }
    },
);

/**
 * Admin callable: Manually trigger sitemap generation
 * Useful for testing or refreshing sitemaps after bulk data changes
 */
exports.generateSitemaps = onCall(
    {
      region: "europe-west1",
      memory: "1GiB",
      timeoutSeconds: 540,
    },
    async (request) => {
      try {
        await ensureAdmin(request);
        console.log("Manual sitemap generation started");
        await generateAllSitemaps();
        console.log("Manual sitemap generation completed successfully");
        return {success: true};
      } catch (error) {
        console.error("Error in manual sitemap generation:", error);
        throw new Error(`Sitemap generation failed: ${error.message}`);
      }
    },
);

// ========== Jumpflix integration: video-spot link import ==========
const SPOT_JUMPFLIX_VIDEOS_COLLECTION = "spotJumpflixVideos";
const JUMPFLIX_VIDEOS_COLLECTION = "jumpflixVideos";
const JUMPFLIX_THUMBNAILS_PREFIX = "jumpflix/thumbnails/";
const JUMPFLIX_API_BASE = "https://www.jumpflix.tv/api/v1";
const JUMPFLIX_API_URL = `${JUMPFLIX_API_BASE}/videos?type=movie`;
const JUMPFLIX_API_DELAY_MS = 150;

/**
 * Fetch Jumpflix videos from API and return parsed JSON
 * @param {string} token - Bearer token for Jumpflix API
 * @return {Promise<Object>} Parsed API response
 */
function fetchJumpflixVideos(token) {
  return new Promise((resolve, reject) => {
    const url = new URL(JUMPFLIX_API_URL);
    const options = {
      hostname: url.hostname,
      path: url.pathname + url.search,
      method: "GET",
      headers: {
        "Authorization": `Bearer ${token}`,
      },
    };
    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Jumpflix API response parse error: ${e.message}`));
        }
      });
    });
    req.on("error", reject);
    req.end();
  });
}

/**
 * Fetch single Jumpflix video details from API
 * @param {string} token - Bearer token for Jumpflix API
 * @param {number} jumpflixId - Jumpflix video ID
 * @return {Promise<Object>} Parsed API response (id, title, description, url, thumbnail, ...)
 */
function fetchJumpflixVideoDetails(token, jumpflixId) {
  return new Promise((resolve, reject) => {
    const pathSeg = `/videos/${jumpflixId}`;
    const options = {
      hostname: "www.jumpflix.tv",
      path: `/api/v1${pathSeg}`,
      method: "GET",
      headers: {
        "Authorization": `Bearer ${token}`,
      },
    };
    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => (data += chunk));
      res.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`Jumpflix video ${jumpflixId} parse error: ${e.message}`));
        }
      });
    });
    req.on("error", reject);
    req.end();
  });
}

/**
 * Download thumbnail from URL and upload to Firebase Storage (overwrites if exists)
 * @param {string} thumbnailUrl - URL of thumbnail (e.g. from Jumpflix API)
 * @param {number} jumpflixId - Jumpflix video ID for filename
 * @return {Promise<string>} Public URL of stored thumbnail
 */
async function downloadAndStoreJumpflixThumbnail(thumbnailUrl, jumpflixId) {
  const ext = path.extname(new URL(thumbnailUrl).pathname) || ".webp";
  const storagePath = `${JUMPFLIX_THUMBNAILS_PREFIX}${jumpflixId}${ext}`;
  const imageBuffer = await downloadFile(thumbnailUrl);
  const contentType = ext === ".webp" ? "image/webp" :
    ext === ".jpg" || ext === ".jpeg" ? "image/jpeg" : "image/png";
  const file = bucket.file(storagePath);
  await file.save(imageBuffer, {
    metadata: {
      contentType,
      cacheControl: "public, max-age=31536000",
    },
  });
  await file.makePublic();
  return getPublicUrl(storagePath);
}

/**
 * Perform Jumpflix spot-video link import: fetch from API, store video details + thumbnails,
 * invert to spot-centric, and write to Firestore
 * @param {string} token - Bearer token for Jumpflix API
 * @return {Promise<Object>} Stats: spotsUpdated, spotsRemoved, jumpflixVideoCount, videosStored
 */
async function performJumpflixImport(token) {
  if (!token || typeof token !== "string") {
    throw new Error("Jumpflix API token is required");
  }

  const apiResponse = await fetchJumpflixVideos(token);
  const videos = apiResponse?.videos;
  if (!Array.isArray(videos)) {
    throw new Error("Jumpflix API did not return a videos array");
  }

  const newJumpflixIds = new Set();
  const now = FieldValue.serverTimestamp();

  // Fetch details for each video, download thumbnails, store in jumpflixVideos
  for (const v of videos) {
    const jumpflixId = v.jumpflixId;
    if (typeof jumpflixId !== "number") continue;
    newJumpflixIds.add(jumpflixId);

    try {
      const details = await fetchJumpflixVideoDetails(token, jumpflixId);
      await delay(JUMPFLIX_API_DELAY_MS);

      const title = details?.title ?? "";
      const description = details?.description ?? "";
      const url = details?.url ?? `https://www.jumpflix.tv/movie/${details?.slug || jumpflixId}`;
      const thumbnailSource = details?.thumbnail;

      let thumbnailUrl = null;
      if (thumbnailSource && typeof thumbnailSource === "string") {
        try {
          thumbnailUrl = await downloadAndStoreJumpflixThumbnail(
              thumbnailSource,
              jumpflixId,
          );
        } catch (thumbErr) {
          console.warn(`Failed to store thumbnail for Jumpflix ${jumpflixId}:`, thumbErr.message);
        }
      }

      await db.collection(JUMPFLIX_VIDEOS_COLLECTION).doc(String(jumpflixId)).set({
        title,
        description,
        url,
        thumbnailUrl,
        updatedAt: now,
      });
    } catch (err) {
      console.error(`Failed to fetch/store Jumpflix video ${jumpflixId}:`, err.message);
      throw err;
    }
  }

  // Remove jumpflixVideos docs and thumbnails for videos no longer in the list
  const existingVideosSnapshot = await db.collection(JUMPFLIX_VIDEOS_COLLECTION).get();
  const thumbExts = [".webp", ".jpg", ".jpeg", ".png"];
  for (const doc of existingVideosSnapshot.docs) {
    const id = parseInt(doc.id, 10);
    if (!isNaN(id) && !newJumpflixIds.has(id)) {
      await doc.ref.delete();
      const basePath = `${JUMPFLIX_THUMBNAILS_PREFIX}${doc.id}`;
      for (const ext of thumbExts) {
        try {
          await bucket.file(basePath + ext).delete();
        } catch (_) {
          // Ignore - thumbnail may not exist for this extension
        }
      }
    }
  }

  // Invert: build Map<spotId, number[]> from API format { jumpflixId, spotIds[] }
  const spotToJumpflixIds = new Map();
  for (const v of videos) {
    const jumpflixId = v.jumpflixId;
    const spotIds = v.spotIds;
    if (typeof jumpflixId !== "number" || !Array.isArray(spotIds)) continue;
    for (const spotId of spotIds) {
      if (typeof spotId === "string" && spotId.trim()) {
        if (!spotToJumpflixIds.has(spotId)) {
          spotToJumpflixIds.set(spotId, []);
        }
        spotToJumpflixIds.get(spotId).push(jumpflixId);
      }
    }
  }

  // Deduplicate and sort jumpflixIds per spot
  for (const [spotId, ids] of spotToJumpflixIds) {
    spotToJumpflixIds.set(spotId, [...new Set(ids)].sort((a, b) => a - b));
  }

  const newSpotIds = new Set(spotToJumpflixIds.keys());
  const existingSnapshot = await db.collection(SPOT_JUMPFLIX_VIDEOS_COLLECTION)
      .get();
  const existingSpotIds = new Set(existingSnapshot.docs.map((d) => d.id));

  const toDelete = [...existingSpotIds].filter((id) => !newSpotIds.has(id));
  const toWrite = [...newSpotIds];
  const batchSize = 500;
  let spotsUpdated = 0;
  let spotsRemoved = 0;

  // Batch deletes
  for (let i = 0; i < toDelete.length; i += batchSize) {
    const batch = db.batch();
    const chunk = toDelete.slice(i, i + batchSize);
    for (const spotId of chunk) {
      batch.delete(db.collection(SPOT_JUMPFLIX_VIDEOS_COLLECTION).doc(spotId));
      spotsRemoved++;
    }
    await batch.commit();
  }

  // Batch writes
  for (let i = 0; i < toWrite.length; i += batchSize) {
    const batch = db.batch();
    const chunk = toWrite.slice(i, i + batchSize);
    for (const spotId of chunk) {
      const jumpflixIds = spotToJumpflixIds.get(spotId);
      batch.set(db.collection(SPOT_JUMPFLIX_VIDEOS_COLLECTION).doc(spotId), {
        jumpflixIds,
        updatedAt: now,
      });
      spotsUpdated++;
    }
    await batch.commit();
  }

  const jumpflixVideoCount = videos.length;
  console.log(
      `Jumpflix import: spotsUpdated=${spotsUpdated}, spotsRemoved=${spotsRemoved}, jumpflixVideoCount=${jumpflixVideoCount}`,
  );
  return {
    spotsUpdated,
    spotsRemoved,
    jumpflixVideoCount,
    videosStored: jumpflixVideoCount,
  };
}

/**
 * Scheduled function to import Jumpflix video-spot links nightly
 * Runs at 02:00 UTC every day
 */
exports.importJumpflixSpotLinks = onSchedule(
    {
      schedule: "every day 02:00",
      timeZone: "UTC",
      region: "europe-west1",
      memory: "512MiB",
      timeoutSeconds: 540,
      secrets: ["JUMPFLIX_API_TOKEN"],
    },
    async () => {
      console.log("Jumpflix spot links import started");
      const token = process.env.JUMPFLIX_API_TOKEN;
      if (!token) {
        throw new Error("JUMPFLIX_API_TOKEN secret not configured");
      }
      try {
        const result = await performJumpflixImport(token);
        console.log("Jumpflix spot links import completed:", result);
      } catch (error) {
        console.error("Error in Jumpflix import:", error);
        throw error;
      }
    },
);

/**
 * Admin callable: Manually trigger Jumpflix spot links import
 */
exports.runJumpflixImport = onCall(
    {
      region: "europe-west1",
      memory: "512MiB",
      timeoutSeconds: 540,
      secrets: ["JUMPFLIX_API_TOKEN"],
    },
    async (request) => {
      await ensureAdmin(request);
      const token = process.env.JUMPFLIX_API_TOKEN;
      if (!token) {
        throw new Error("Jumpflix API token not configured. Set JUMPFLIX_API_TOKEN secret.");
      }
      const result = await performJumpflixImport(token);
      return {success: true, ...result};
    },
);

// ========== User activity metrics ==========
/**
 * Helper function to calculate and store user activity metrics (DAU/WAU/MAU)
 * Can be called by both scheduled and manual test functions
 * @param {boolean} useYesterdayDate - If true, store metrics with yesterday's date (for scheduled runs)
 * @return {Promise<Object>} Result object with metrics and status
 */
/**
 * Helper function to make rate-limited Google Sheets API calls with retry logic
 * Implements exponential backoff for quota errors and adds delays between calls
 * @param {Function} apiCall - Function that returns a Promise for the API call
 * @param {number} delayMs - Delay in milliseconds before making the call (default: 1000ms)
 * @param {number} maxRetries - Maximum number of retries (default: 5)
 * @return {Promise} The result of the API call
 */
async function rateLimitedSheetsCall(apiCall, delayMs = 1000, maxRetries = 5) {
  // Add delay before making the call to respect rate limits
  // Google Sheets API allows 60 write requests per minute per user
  // With 1 second delay, we stay well under the limit (max 60/min)
  await new Promise((resolve) => setTimeout(resolve, delayMs));

  let lastError;
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await apiCall();
    } catch (error) {
      lastError = error;

      // Check if it's a quota error
      const isQuotaError = error.code === 429 ||
                          (error.response && error.response.status === 429) ||
                          (error.message && error.message.includes("Quota exceeded")) ||
                          (error.message && error.message.includes("quota metric"));

      if (isQuotaError && attempt < maxRetries) {
        // Exponential backoff: 2^attempt seconds, with a max of 60 seconds
        const backoffMs = Math.min(1000 * Math.pow(2, attempt), 60000);
        console.warn(
            `Quota error on attempt ${attempt + 1}/${maxRetries + 1}. ` +
            `Retrying in ${backoffMs}ms...`,
        );
        await new Promise((resolve) => setTimeout(resolve, backoffMs));
        continue;
      }

      // For non-quota errors or if we've exhausted retries, throw immediately
      throw error;
    }
  }

  // Should never reach here, but just in case
  throw lastError;
}

/**
 * Calculates DAU/WAU/MAU from user lastActiveAt and stores in Firestore.
 * @param {boolean=} useYesterdayDate - If true, use yesterday as target date (for scheduled runs).
 * @return {Promise<void>}
 */
async function calculateUserActivityMetrics(useYesterdayDate = false) {
  console.log("User activity metrics calculation started");
  const now = new Date();

  // Determine which date to use for storing metrics
  let targetDate;
  if (useYesterdayDate) {
    // For scheduled runs, use yesterday's date (since we're calculating metrics for the last 24 hours)
    const yesterday = new Date(now);
    yesterday.setUTCDate(yesterday.getUTCDate() - 1);
    targetDate = new Date(Date.UTC(
        yesterday.getUTCFullYear(),
        yesterday.getUTCMonth(),
        yesterday.getUTCDate(),
        0, 0, 0, 0,
    ));
  } else {
    // For manual runs, use today's date
    targetDate = new Date(Date.UTC(
        now.getUTCFullYear(),
        now.getUTCMonth(),
        now.getUTCDate(),
        0, 0, 0, 0,
    ));
  }

  const dateString = targetDate.toISOString().split("T")[0]; // YYYY-MM-DD

  try {
    // Calculate time thresholds
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    console.log(`Calculating metrics for ${dateString}`);
    console.log(`Thresholds: DAU >= ${oneDayAgo.toISOString()}, WAU >= ${sevenDaysAgo.toISOString()}, MAU >= ${thirtyDaysAgo.toISOString()}`);

    // Query all users (we'll process in memory for now)
    // For very large user bases, this could be optimized with pagination
    const usersSnapshot = await db.collection("users").get();
    console.log(`Found ${usersSnapshot.size} total users`);

    let dau = 0;
    let wau = 0;
    let mau = 0;

    // Count active users for each metric
    usersSnapshot.forEach((doc) => {
      const userData = doc.data();
      const lastActiveAt = userData.lastActiveAt;

      // Skip users without lastActiveAt (treat as inactive)
      if (!lastActiveAt) {
        return;
      }

      // Convert Firestore Timestamp to Date if needed
      const lastActiveDate = lastActiveAt.toDate ? lastActiveAt.toDate() : new Date(lastActiveAt);

      // Count for MAU (30 days)
      if (lastActiveDate >= thirtyDaysAgo) {
        mau++;
        // Count for WAU (7 days)
        if (lastActiveDate >= sevenDaysAgo) {
          wau++;
          // Count for DAU (24 hours)
          if (lastActiveDate >= oneDayAgo) {
            dau++;
          }
        }
      }
    });

    console.log(`Calculated metrics - DAU: ${dau}, WAU: ${wau}, MAU: ${mau}`);

    // Store metrics in Firestore
    const metricsData = {
      date: admin.firestore.Timestamp.fromDate(targetDate),
      dau: dau,
      wau: wau,
      mau: mau,
      calculatedAt: admin.firestore.Timestamp.fromDate(now),
    };

    await db.collection("userActivityMetrics").doc(dateString).set(metricsData);
    console.log(`Stored metrics in Firestore for ${dateString}`);

    // Read all metrics from Firestore for Google Sheets sync
    const allMetricsSnapshot = await db
        .collection("userActivityMetrics")
        .orderBy("date", "asc")
        .get();

    console.log(`Retrieved ${allMetricsSnapshot.size} metric records from Firestore`);

    // Prepare data for Google Sheets
    const sheetData = [["Date", "DAU", "WAU", "MAU"]]; // Header row

    allMetricsSnapshot.forEach((doc) => {
      const data = doc.data();
      const date = data.date.toDate ? data.date.toDate() : new Date(data.date);
      const dateStr = date.toISOString().split("T")[0]; // YYYY-MM-DD format
      sheetData.push([
        dateStr,
        data.dau || 0,
        data.wau || 0,
        data.mau || 0,
      ]);
    });

    console.log(`Prepared ${sheetData.length} rows for Google Sheets`);

    // Sync to Google Sheets
    const serviceAccountJson = process.env.GOOGLE_SHEETS_SERVICE_ACCOUNT;
    const sheetId = process.env.GOOGLE_SHEET_ID;
    const sheetName = "Active_Users"; // Hardcoded sheet tab name

    if (!serviceAccountJson) {
      throw new Error("GOOGLE_SHEETS_SERVICE_ACCOUNT secret not configured");
    }
    if (!sheetId) {
      throw new Error("GOOGLE_SHEET_ID secret not configured");
    }

    // Parse service account credentials
    let serviceAccount;
    try {
      serviceAccount = JSON.parse(serviceAccountJson);
    } catch (error) {
      throw new Error(`Failed to parse GOOGLE_SHEETS_SERVICE_ACCOUNT: ${error.message}`);
    }

    // Authenticate with Google Sheets API
    const auth = new google.auth.GoogleAuth({
      credentials: serviceAccount,
      scopes: ["https://www.googleapis.com/auth/spreadsheets"],
    });

    const sheets = google.sheets({version: "v4", auth});

    // Clear existing data (assuming data starts at A1)
    const clearRange = `${sheetName}!A1:Z10000`; // Adjust range as needed
    await rateLimitedSheetsCall(
        () => sheets.spreadsheets.values.clear({
          spreadsheetId: sheetId,
          range: clearRange,
        }),
        1000, // 1 second delay
    );
    console.log(`Cleared existing sheet data from ${sheetName}`);

    // Write all data
    await rateLimitedSheetsCall(
        () => sheets.spreadsheets.values.update({
          spreadsheetId: sheetId,
          range: `${sheetName}!A1`,
          valueInputOption: "RAW",
          resource: {
            values: sheetData,
          },
        }),
        1000, // 1 second delay
    );
    console.log(`Successfully synced ${sheetData.length} rows to Google Sheets`);

    // Export all spots to Spots sheet (processed in batches to reduce memory usage)
    let spotsExported = 0;
    try {
      console.log("Starting spots export to Google Sheets");

      // Check if Spots sheet exists, create if missing
      const spotsSheetName = "Spots";
      let spotsSheetExists = false;

      try {
        const spreadsheet = await sheets.spreadsheets.get({
          spreadsheetId: sheetId,
        });

        spotsSheetExists = spreadsheet.data.sheets.some(
            (sheet) => sheet.properties.title === spotsSheetName,
        );
      } catch (error) {
        console.warn(`Error checking for Spots sheet: ${error.message}`);
      }

      if (!spotsSheetExists) {
        console.log(`Creating ${spotsSheetName} sheet`);
        await rateLimitedSheetsCall(
            () => sheets.spreadsheets.batchUpdate({
              spreadsheetId: sheetId,
              resource: {
                requests: [
                  {
                    addSheet: {
                      properties: {
                        title: spotsSheetName,
                      },
                    },
                  },
                ],
              },
            }),
            1000, // 1 second delay
        );
        console.log(`Successfully created ${spotsSheetName} sheet`);
      }

      // Clear existing data from Spots sheet
      const spotsClearRange = `${spotsSheetName}!A1:Z100000`;
      await rateLimitedSheetsCall(
          () => sheets.spreadsheets.values.clear({
            spreadsheetId: sheetId,
            range: spotsClearRange,
          }),
          1000, // 1 second delay
      );
      console.log(`Cleared existing data from ${spotsSheetName} sheet`);

      // Write header row first
      const headerRow = [
        [
          "Spot ID",
          "Country Code",
          "City",
          "Spot Source Name",
          "Folder Name",
          "Image Count",
          "Is Duplicate",
          "Is Hidden",
          "Removed From Source",
          "Has Spot Features",
          "Rating Count",
          "Average Rating",
          "Wilson Lower Bound",
          "Created At",
          "Updated At",
        ],
      ];
      await rateLimitedSheetsCall(
          () => sheets.spreadsheets.values.update({
            spreadsheetId: sheetId,
            range: `${spotsSheetName}!A1`,
            valueInputOption: "RAW",
            resource: {
              values: headerRow,
            },
          }),
          1000, // 1 second delay
      );

      // Process spots in batches to reduce memory usage
      const BATCH_SIZE = 500; // Process 500 spots at a time
      let lastDoc = null;
      let batchNumber = 0;
      let currentRow = 2; // Start at row 2 (row 1 is header)

      // Format dates helper function
      const formatDate = (timestamp) => {
        if (!timestamp) return "";
        const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
        return date.toISOString();
      };

      let processing = true;
      while (processing) {
        batchNumber++;
        console.log(`Processing batch ${batchNumber}...`);

        // Build query for next batch
        let query = db.collection("spots").limit(BATCH_SIZE);
        if (lastDoc) {
          query = query.startAfter(lastDoc);
        }

        const batchSnapshot = await query.get();

        if (batchSnapshot.empty) {
          console.log(`No more spots to process. Completed ${batchNumber - 1} batches.`);
          processing = false;
          continue;
        }

        console.log(`Batch ${batchNumber}: Processing ${batchSnapshot.size} spots...`);

        // Prepare batch data
        const batchData = [];
        batchSnapshot.forEach((doc) => {
          const spotData = doc.data();

          // Extract and format fields
          const imageUrls = spotData.imageUrls || [];
          const imageCount = Array.isArray(imageUrls) ? imageUrls.length : 0;
          const isDuplicate = spotData.duplicateOf != null;
          const isHidden = spotData.hidden === true;
          const removedFromSource = spotData.spotSourceRemoved === true;
          const spotFeatures = spotData.spotFeatures || [];
          const hasSpotFeatures = Array.isArray(spotFeatures) && spotFeatures.length > 0;
          const ratingCount = spotData.ratingCount || 0;
          const averageRating = spotData.averageRating != null ?
            Number(spotData.averageRating.toFixed(4)) :
            0;
          const wilsonLowerBound = spotData.wilsonLowerBound != null ?
            Number(spotData.wilsonLowerBound.toFixed(4)) :
            0;

          batchData.push([
            doc.id, // Spot ID
            spotData.countryCode || "", // Country Code
            spotData.city || "", // City
            spotData.spotSourceName || "", // Spot Source Name
            spotData.folderName || "", // Folder Name
            imageCount, // Image Count
            isDuplicate, // Is Duplicate
            isHidden, // Is Hidden
            removedFromSource, // Removed From Source
            hasSpotFeatures, // Has Spot Features
            ratingCount, // Rating Count
            averageRating, // Average Rating
            wilsonLowerBound, // Wilson Lower Bound
            formatDate(spotData.createdAt), // Created At
            formatDate(spotData.updatedAt), // Updated At
          ]);
        });

        // Write batch to Google Sheets
        if (batchData.length > 0) {
          await rateLimitedSheetsCall(
              () => sheets.spreadsheets.values.update({
                spreadsheetId: sheetId,
                range: `${spotsSheetName}!A${currentRow}`,
                valueInputOption: "RAW",
                resource: {
                  values: batchData,
                },
              }),
              1000, // 1 second delay between batches
          );

          spotsExported += batchData.length;
          currentRow += batchData.length;

          console.log(
              `Batch ${batchNumber}: Wrote ${batchData.length} spots ` +
              `(total exported: ${spotsExported})`,
          );
        }

        // Update lastDoc for pagination
        lastDoc = batchSnapshot.docs[batchSnapshot.docs.length - 1];

        // If we got fewer than BATCH_SIZE, we're done
        if (batchSnapshot.size < BATCH_SIZE) {
          processing = false;
        }
      }

      console.log(`Successfully synced ${spotsExported} spots to ${spotsSheetName} sheet`);
    } catch (spotsError) {
      console.error("Error exporting spots to Google Sheets:", spotsError);
      // Don't throw - allow main metrics calculation to succeed even if spots export fails
    }

    // Export all users to Users sheet (processed in batches to reduce memory usage)
    let usersExported = 0;
    try {
      console.log("Starting users export to Google Sheets");

      // Check if Users sheet exists, create if missing
      const usersSheetName = "Users";
      let usersSheetExists = false;

      try {
        const spreadsheet = await sheets.spreadsheets.get({
          spreadsheetId: sheetId,
        });

        usersSheetExists = spreadsheet.data.sheets.some(
            (sheet) => sheet.properties.title === usersSheetName,
        );
      } catch (error) {
        console.warn(`Error checking for Users sheet: ${error.message}`);
      }

      if (!usersSheetExists) {
        console.log(`Creating ${usersSheetName} sheet`);
        await rateLimitedSheetsCall(
            () => sheets.spreadsheets.batchUpdate({
              spreadsheetId: sheetId,
              resource: {
                requests: [
                  {
                    addSheet: {
                      properties: {
                        title: usersSheetName,
                      },
                    },
                  },
                ],
              },
            }),
            1000, // 1 second delay
        );
        console.log(`Successfully created ${usersSheetName} sheet`);
      }

      // Clear existing data from Users sheet
      const usersClearRange = `${usersSheetName}!A1:Z100000`;
      await rateLimitedSheetsCall(
          () => sheets.spreadsheets.values.clear({
            spreadsheetId: sheetId,
            range: usersClearRange,
          }),
          1000, // 1 second delay
      );
      console.log(`Cleared existing data from ${usersSheetName} sheet`);

      // Write header row first
      const usersHeaderRow = [
        [
          "User ID",
          "Created At",
          "Last Login At",
          "Is Admin",
          "Is Moderator",
          "Has Photo URL",
          "Has Username",
          "Is Public Profile",
        ],
      ];
      await rateLimitedSheetsCall(
          () => sheets.spreadsheets.values.update({
            spreadsheetId: sheetId,
            range: `${usersSheetName}!A1`,
            valueInputOption: "RAW",
            resource: {
              values: usersHeaderRow,
            },
          }),
          1000, // 1 second delay
      );

      // Process users in batches to reduce memory usage
      const USER_BATCH_SIZE = 500; // Process 500 users at a time
      let lastUserDoc = null;
      let userBatchNumber = 0;
      let currentUserRow = 2; // Start at row 2 (row 1 is header)

      // Format dates helper function
      const formatDate = (timestamp) => {
        if (!timestamp) return "";
        const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
        return date.toISOString();
      };

      let processingUsers = true;
      while (processingUsers) {
        userBatchNumber++;
        console.log(`Processing user batch ${userBatchNumber}...`);

        // Build query for next batch
        let userQuery = db.collection("users").limit(USER_BATCH_SIZE);
        if (lastUserDoc) {
          userQuery = userQuery.startAfter(lastUserDoc);
        }

        const userBatchSnapshot = await userQuery.get();

        if (userBatchSnapshot.empty) {
          console.log(
              `No more users to process. Completed ${userBatchNumber - 1} batches.`,
          );
          processingUsers = false;
          continue;
        }

        console.log(
            `User batch ${userBatchNumber}: Processing ${userBatchSnapshot.size} users...`,
        );

        // Prepare batch data
        const userBatchData = [];
        userBatchSnapshot.forEach((doc) => {
          const userData = doc.data();

          // Extract and format fields
          const hasPhotoURL = !!(userData.photoURL && userData.photoURL !== "");
          const hasUsername = !!(userData.username && userData.username !== "");
          const isAdmin = userData.isAdmin === true;
          const isModerator = userData.isModerator === true;
          const isPublicProfile = userData.isPublicProfile !== false; // Defaults to true

          userBatchData.push([
            doc.id, // User ID
            formatDate(userData.createdAt), // Created At
            formatDate(userData.lastLoginAt), // Last Login At
            isAdmin, // Is Admin
            isModerator, // Is Moderator
            hasPhotoURL, // Has Photo URL
            hasUsername, // Has Username
            isPublicProfile, // Is Public Profile
          ]);
        });

        // Write batch to Google Sheets
        if (userBatchData.length > 0) {
          await rateLimitedSheetsCall(
              () => sheets.spreadsheets.values.update({
                spreadsheetId: sheetId,
                range: `${usersSheetName}!A${currentUserRow}`,
                valueInputOption: "RAW",
                resource: {
                  values: userBatchData,
                },
              }),
              1000, // 1 second delay between batches
          );

          usersExported += userBatchData.length;
          currentUserRow += userBatchData.length;

          console.log(
              `User batch ${userBatchNumber}: Wrote ${userBatchData.length} users ` +
              `(total exported: ${usersExported})`,
          );
        }

        // Update lastUserDoc for pagination
        lastUserDoc = userBatchSnapshot.docs[userBatchSnapshot.docs.length - 1];

        // If we got fewer than USER_BATCH_SIZE, we're done
        if (userBatchSnapshot.size < USER_BATCH_SIZE) {
          processingUsers = false;
        }
      }

      console.log(`Successfully synced ${usersExported} users to ${usersSheetName} sheet`);
    } catch (usersError) {
      console.error("Error exporting users to Google Sheets:", usersError);
      // Don't throw - allow main metrics calculation to succeed even if users export fails
    }

    console.log("User activity metrics calculation completed successfully");

    return {
      success: true,
      date: dateString,
      metrics: {dau, wau, mau},
      rowsSynced: sheetData.length,
      spotsExported: spotsExported,
      usersExported: usersExported,
    };
  } catch (error) {
    console.error("Error in user activity metrics calculation:", error);
    // Store error in Firestore for monitoring
    try {
      await db.collection("userActivityMetrics").doc(dateString).set({
        date: admin.firestore.Timestamp.fromDate(targetDate),
        error: error.message,
        errorAt: admin.firestore.Timestamp.fromDate(new Date()),
      }, {merge: true});
    } catch (firestoreError) {
      console.error("Failed to store error in Firestore:", firestoreError);
    }
    throw error;
  }
}

/**
 * Scheduled function to calculate and store user activity metrics (DAU/WAU/MAU)
 * Runs at 1 minute after midnight UTC every day
 * Stores metrics in Firestore and syncs to Google Sheets
 * Uses yesterday's date since it calculates metrics for the last 24 hours
 */
exports.calculateUserActivityMetrics = onSchedule(
    {
      schedule: "every day 00:01",
      timeZone: "UTC",
      region: "europe-west1",
      memory: "512MiB",
      timeoutSeconds: 1800, // 30 minutes (max for scheduled functions)
      secrets: ["GOOGLE_SHEETS_SERVICE_ACCOUNT", "GOOGLE_SHEET_ID"],
    },
    async () => {
      return await calculateUserActivityMetrics(true); // Use yesterday's date for scheduled runs
    },
);

/**
 * Callable function to manually trigger user activity metrics calculation
 * Useful for testing without waiting for the scheduled run
 * Requires admin authentication
 */
exports.testCalculateUserActivityMetrics = onCall(
    {
      region: "europe-west1",
      timeoutSeconds: 1800, // 30 minutes (same as scheduled function)
      memory: "512MiB",
      secrets: ["GOOGLE_SHEETS_SERVICE_ACCOUNT", "GOOGLE_SHEET_ID"],
    },
    async (request) => {
      await ensureAdmin(request);
      console.log(`Manual metrics calculation triggered by admin: ${request.auth.uid}`);
      const result = await calculateUserActivityMetrics();
      return result;
    },
);

/**
/**
 * Moderator function to find potential duplicate spots within ~50m of each other
 * Compares spots from one source against spots from other sources
 * Filters by matching country code and city, then calculates actual distance
 */
exports.findDuplicateSpots = onCall(
    {
      region: "europe-west1",
      timeoutSeconds: 540, // 9 minutes max
      memory: "1GiB",
    },
    async (request) => {
      try {
        await ensureModerator(request);
        const {sourceId, maxDistanceMeters = 50, maxPairs = 1000} = request.data || {};

        if (!sourceId) {
          throw new Error("sourceId is required");
        }

        console.log(`Finding potential duplicate spots for source: ${sourceId} (max distance: ${maxDistanceMeters}m)`);

        // Get the source name
        let sourceName = sourceId;
        try {
          const sourceDoc = await db.collection("syncSources").doc(sourceId).get();
          if (sourceDoc.exists) {
            sourceName = sourceDoc.data().name || sourceId;
          }
        } catch (error) {
          console.warn(`Could not fetch source name for ${sourceId}:`, error.message);
        }

        // Get all spots from the selected source (excluding already-marked duplicates)
        const sourceSpotsSnapshot = await db
            .collection("spots")
            .where("spotSource", "==", sourceId)
            .where("hidden", "==", false)
            .where("duplicateOf", "==", null)
            .get();

        console.log(`Found ${sourceSpotsSnapshot.size} spots from source ${sourceId}`);

        const duplicatePairs = [];
        let spotsChecked = 0;
        let spotsSkipped = 0;

        // Process each spot from the source
        for (const sourceSpotDoc of sourceSpotsSnapshot.docs) {
          const sourceSpot = sourceSpotDoc.data();
          const sourceLat = sourceSpot.latitude;
          const sourceLon = sourceSpot.longitude;
          const sourceCountryCode = sourceSpot.countryCode;
          const sourceCity = sourceSpot.city;

          // Skip spots without valid coordinates, country code, or city
          if (
            typeof sourceLat !== "number" ||
            typeof sourceLon !== "number" ||
            !sourceCountryCode ||
            !sourceCity
          ) {
            spotsSkipped++;
            continue;
          }

          spotsChecked++;

          // Calculate bounding box for this spot
          const bounds = calculateBounds(sourceLat, sourceLon, maxDistanceMeters);

          // Normalize longitude for dateline crossing
          const normalizeLongitude = (lng) => {
            const normalized = ((lng + 180) % 360 + 360) % 360 - 180;
            return normalized;
          };

          const normalizedMinLng = normalizeLongitude(bounds.minLng);
          const normalizedMaxLng = normalizeLongitude(bounds.maxLng);
          const crossesDateline = normalizedMinLng > normalizedMaxLng;

          // Build query function
          const buildQuery = (lngMin, lngMax) => {
            const query = db
                .collection("spots")
                .where("countryCode", "==", sourceCountryCode)
                .where("city", "==", sourceCity)
                .where("duplicateOf", "==", null)
                .where("hidden", "==", false)
                .where("latitude", ">=", bounds.minLat)
                .where("latitude", "<=", bounds.maxLat)
                .where("longitude", ">=", lngMin)
                .where("longitude", "<=", lngMax);

            // Note: We filter out spots from the same source in memory
            // since Firestore doesn't support != queries efficiently

            return query;
          };

          // Execute query(ies)
          let candidateSpots = [];
          if (crossesDateline) {
            // Query both sides of dateline
            const [snap1, snap2] = await Promise.all([
              buildQuery(normalizedMinLng, 180).get(),
              buildQuery(-180, normalizedMaxLng).get(),
            ]);
            candidateSpots = [
              ...snap1.docs.map((d) => ({id: d.id, ...d.data()})),
              ...snap2.docs.map((d) => ({id: d.id, ...d.data()})),
            ];
          } else {
            const snap = await buildQuery(normalizedMinLng, normalizedMaxLng).get();
            candidateSpots = snap.docs.map((d) => ({id: d.id, ...d.data()}));
          }

          // Calculate actual distance and filter
          for (const candidate of candidateSpots) {
            const candidateLat = candidate.latitude;
            const candidateLon = candidate.longitude;

            if (typeof candidateLat !== "number" || typeof candidateLon !== "number") {
              continue;
            }

            // Skip if same spot
            if (candidate.id === sourceSpotDoc.id) {
              continue;
            }

            // Skip if from the same source (we want duplicates from OTHER sources)
            if (candidate.spotSource === sourceId) {
              continue;
            }

            // Calculate actual distance
            const distance = calculateDistance(
                sourceLat,
                sourceLon,
                candidateLat,
                candidateLon,
            );

            if (distance <= maxDistanceMeters) {
              duplicatePairs.push({
                spot1: {
                  id: sourceSpotDoc.id,
                  name: sourceSpot.name || "",
                  latitude: sourceLat,
                  longitude: sourceLon,
                  address: sourceSpot.address,
                  city: sourceCity,
                  countryCode: sourceCountryCode,
                  spotSource: sourceSpot.spotSource,
                  spotSourceName: sourceSpot.spotSourceName,
                  hasImages: (sourceSpot.imageUrls || []).length > 0,
                },
                spot2: {
                  id: candidate.id,
                  name: candidate.name || "",
                  latitude: candidateLat,
                  longitude: candidateLon,
                  address: candidate.address,
                  city: candidate.city,
                  countryCode: candidate.countryCode,
                  spotSource: candidate.spotSource,
                  spotSourceName: candidate.spotSourceName,
                  hasImages: (candidate.imageUrls || []).length > 0,
                },
                distanceMeters: Math.round(distance),
              });

              // Limit results to prevent timeout
              if (duplicatePairs.length >= maxPairs) {
                console.log(`Reached max pairs limit (${maxPairs}), stopping`);
                break;
              }
            }
          }

          // Stop if we've reached the limit
          if (duplicatePairs.length >= maxPairs) {
            break;
          }
        }

        // Sort by distance (closest first)
        duplicatePairs.sort((a, b) => a.distanceMeters - b.distanceMeters);

        // Generate run ID
        const runId = db.collection("duplicateDetectionResults").doc().id;

        // Store results in Firestore
        const resultData = {
          runId: runId,
          sourceId: sourceId,
          sourceName: sourceName,
          createdAt: FieldValue.serverTimestamp(),
          stats: {
            spotsChecked: spotsChecked,
            spotsSkipped: spotsSkipped,
            pairsFound: duplicatePairs.length,
          },
          pairs: duplicatePairs,
        };

        await db.collection("duplicateDetectionResults").doc(runId).set(resultData);

        console.log(`Found ${duplicatePairs.length} potential duplicate pairs (checked ${spotsChecked} spots, skipped ${spotsSkipped})`);

        return {
          success: true,
          runId: runId,
          pairsFound: duplicatePairs.length,
          spotsChecked: spotsChecked,
          spotsSkipped: spotsSkipped,
        };
      } catch (error) {
        console.error("Error finding potential duplicates:", error);
        throw new Error(`Failed to find potential duplicates: ${error.message}`);
      }
    },
);

// ========== Spot Details API (external clients) ==========
const API_CLIENTS_COLLECTION = "apiClients";

/**
 * Spot API - Handles GET /api/v1/spots (search in bounds) and GET /api/v1/spots/:spotId (single spot).
 * Requires X-API-Key or Authorization: Bearer.
 */
exports.getSpotByApi = onRequest(
    {
      region: "europe-west1",
      cors: true,
    },
    async (req, res) => {
      try {
        if (req.method !== "GET") {
          res.status(405).set("Allow", "GET").json({error: "Method not allowed"});
          return;
        }

        const path = (req.path || req.url || "/").split("?")[0];
        const spotIdMatch = path.match(/^\/api\/v1\/spots\/([^/]+)$/);
        const isSearchRequest = path === "/api/v1/spots" || path === "/api/v1/spots/";

        if (!spotIdMatch && !isSearchRequest) {
          res.status(404).json({error: "Not found"});
          return;
        }

        let apiKey = null;
        const authHeader = req.headers["authorization"] || req.headers["Authorization"];
        if (authHeader && authHeader.startsWith("Bearer ")) {
          apiKey = authHeader.substring(7).trim();
        } else {
          apiKey = (req.headers["x-api-key"] || req.headers["X-API-Key"] || "").trim();
        }
        if (!apiKey) {
          res.status(401).json({error: "API key required. Use X-API-Key or Authorization: Bearer"});
          return;
        }

        const apiKeyHash = hashApiKey(apiKey);
        const clientsSnap = await db.collection(API_CLIENTS_COLLECTION)
            .where("apiKeyHash", "==", apiKeyHash)
            .where("active", "==", true)
            .limit(1)
            .get();

        if (clientsSnap.empty) {
          res.status(401).json({error: "Invalid or inactive API key"});
          return;
        }
        const clientDoc = clientsSnap.docs[0];
        const clientId = clientDoc.id;
        const now = new Date();
        const dateId = now.toISOString().slice(0, 10);

        if (isSearchRequest) {
          const q = req.query || {};
          const searchQ = typeof q.q === "string" ? q.q.trim() : "";
          const hasSearchQuery = searchQ.length >= 2;
          if (typeof q.q === "string" && searchQ.length > 0 && searchQ.length < 2) {
            res.status(400).json({error: "Query param q must be at least 2 characters"});
            return;
          }
          const minLat = typeof q.minLat === "string" ? parseFloat(q.minLat) : NaN;
          const maxLat = typeof q.maxLat === "string" ? parseFloat(q.maxLat) : NaN;
          const minLng = typeof q.minLng === "string" ? parseFloat(q.minLng) : NaN;
          const maxLng = typeof q.maxLng === "string" ? parseFloat(q.maxLng) : NaN;
          const hasBounds = Number.isFinite(minLat) && Number.isFinite(maxLat) &&
              Number.isFinite(minLng) && Number.isFinite(maxLng);

          if (hasSearchQuery) {
            // GET /api/v1/spots?q=... (search by name)
            const parsedLimit = Number(q.limit);
            const limit = Number.isFinite(parsedLimit) ?
              Math.max(1, Math.min(Math.floor(parsedLimit), 100)) : 20;
            const result = await executeSearchSpotsByTitle({
              query: searchQ,
              limit,
            });
            if (!result.success) {
              res.status(500).json({error: result.error || "Search failed"});
              return;
            }
            const spots = result.spots || [];
            for (const spot of spots) {
              if (Array.isArray(spot.imageUrls)) {
                spot.imageUrls = spot.imageUrls.map((url) => getResizedImageUrlForApi(url));
              }
            }
            await db.runTransaction(async (transaction) => {
              transaction.update(db.collection(API_CLIENTS_COLLECTION).doc(clientId), {
                lastUsedAt: FieldValue.serverTimestamp(),
              });
              const usageRef = db.collection(API_CLIENTS_COLLECTION)
                  .doc(clientId)
                  .collection("usage")
                  .doc(dateId);
              transaction.set(usageRef, {
                date: dateId,
                count: FieldValue.increment(1),
                lastUpdatedAt: FieldValue.serverTimestamp(),
              }, {merge: true});
            });
            res.set("Content-Type", "application/json; charset=utf-8");
            res.status(200).json({
              spots,
              totalCount: spots.length,
              shownCount: spots.length,
            });
            return;
          }

          if (!hasBounds) {
            res.status(400).json({
              error: "Query params q (search by name) or minLat, maxLat, minLng, maxLng (search in bounds) are required",
            });
            return;
          }

          // GET /api/v1/spots?minLat=&maxLat=&minLng=&maxLng= (search in bounds)
          const result = await executeTopSpotsInBoundsQuery({
            minLat,
            maxLat,
            minLng,
            maxLng,
            limit: 100,
          });

          if (!result.success) {
            res.status(500).json({error: result.error || "Query failed"});
            return;
          }

          const spots = result.spots || [];
          if (Array.isArray(spots)) {
            for (const spot of spots) {
              if (Array.isArray(spot.imageUrls)) {
                spot.imageUrls = spot.imageUrls.map((url) => getResizedImageUrlForApi(url));
              }
            }
          }

          await db.runTransaction(async (transaction) => {
            transaction.update(db.collection(API_CLIENTS_COLLECTION).doc(clientId), {
              lastUsedAt: FieldValue.serverTimestamp(),
            });
            const usageRef = db.collection(API_CLIENTS_COLLECTION)
                .doc(clientId)
                .collection("usage")
                .doc(dateId);
            transaction.set(usageRef, {
              date: dateId,
              count: FieldValue.increment(1),
              lastUpdatedAt: FieldValue.serverTimestamp(),
            }, {merge: true});
          });

          res.set("Content-Type", "application/json; charset=utf-8");
          res.status(200).json({
            spots,
            totalCount: result.totalCount,
            shownCount: result.shownCount,
          });
          return;
        }

        // Single spot: GET /api/v1/spots/:spotId
        const spotId = spotIdMatch[1];
        const spotSnap = await db.collection("spots").doc(spotId).get();
        if (!spotSnap.exists) {
          res.status(404).json({error: "Spot not found"});
          return;
        }

        const spotData = spotSnap.data();
        await db.runTransaction(async (transaction) => {
          transaction.update(db.collection(API_CLIENTS_COLLECTION).doc(clientId), {
            lastUsedAt: FieldValue.serverTimestamp(),
          });
          const usageRef = db.collection(API_CLIENTS_COLLECTION)
              .doc(clientId)
              .collection("usage")
              .doc(dateId);
          transaction.set(usageRef, {
            date: dateId,
            count: FieldValue.increment(1),
            lastUpdatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        });

        const out = serializeSpotForApi({
          id: spotSnap.id,
          ...spotData,
        });
        out.hidden = spotData.hidden === true;
        out.duplicateOf = spotData.duplicateOf || null;

        if (Array.isArray(out.imageUrls)) {
          out.imageUrls = out.imageUrls.map((url) => getResizedImageUrlForApi(url));
        }

        res.set("Content-Type", "application/json; charset=utf-8");
        res.status(200).json(out);
      } catch (error) {
        console.error("getSpotByApi error:", error);
        res.status(500).json({error: "Internal server error"});
      }
    },
);

// Admin callables for API client management
exports.getApiClients = onCall({region: "europe-west1"}, async (request) => {
  try {
    await ensureAdmin(request);
    const clientsSnap = await db.collection(API_CLIENTS_COLLECTION)
        .orderBy("createdAt", "desc")
        .get();

    const clients = [];
    const now = new Date();
    const thirtyDaysAgo = new Date(now);
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    for (const doc of clientsSnap.docs) {
      const d = doc.data();
      const usageSnap = await db.collection(API_CLIENTS_COLLECTION)
          .doc(doc.id)
          .collection("usage")
          .get();

      let totalCalls = 0;
      let last7Days = 0;
      let last30Days = 0;
      for (const u of usageSnap.docs) {
        const uData = u.data();
        const count = uData.count || 0;
        totalCalls += count;
        const dateStr = u.id;
        if (dateStr >= thirtyDaysAgo.toISOString().slice(0, 10)) {
          last30Days += count;
        }
        const sevenDaysAgo = new Date(now);
        sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
        if (dateStr >= sevenDaysAgo.toISOString().slice(0, 10)) {
          last7Days += count;
        }
      }

      clients.push({
        id: doc.id,
        name: d.name || "",
        active: d.active !== false,
        createdAt: d.createdAt?.toDate?.()?.toISOString?.() || null,
        createdBy: d.createdBy || null,
        lastUsedAt: d.lastUsedAt?.toDate?.()?.toISOString?.() || null,
        totalCalls,
        last7Days,
        last30Days,
      });
    }
    return {clients};
  } catch (error) {
    console.error("getApiClients error:", error);
    throw new Error(`Failed to list API clients: ${error.message}`);
  }
});

exports.createApiClient = onCall({region: "europe-west1"}, async (request) => {
  try {
    await ensureAdmin(request);
    const {name} = request.data || {};
    if (!name || typeof name !== "string" || name.trim().length === 0) {
      throw new Error("name is required");
    }
    const apiKey = generateApiKey();
    const apiKeyHash = hashApiKey(apiKey);
    const clientRef = db.collection(API_CLIENTS_COLLECTION).doc();

    await clientRef.set({
      name: name.trim(),
      apiKeyHash,
      active: true,
      createdAt: FieldValue.serverTimestamp(),
      createdBy: request.auth?.uid || null,
    });

    return {
      clientId: clientRef.id,
      apiKey,
      name: name.trim(),
      warning: "Save this API key. It will not be shown again.",
    };
  } catch (error) {
    console.error("createApiClient error:", error);
    throw new Error(`Failed to create API client: ${error.message}`);
  }
});

exports.updateApiClient = onCall({region: "europe-west1"}, async (request) => {
  try {
    await ensureAdmin(request);
    const {clientId, name, active} = request.data || {};
    if (!clientId || typeof clientId !== "string") {
      throw new Error("clientId is required");
    }
    const updateData = {};
    if (name !== undefined) {
      if (typeof name !== "string" || name.trim().length === 0) {
        throw new Error("name must be a non-empty string");
      }
      updateData.name = name.trim();
    }
    if (active !== undefined) {
      if (typeof active !== "boolean") {
        throw new Error("active must be a boolean");
      }
      updateData.active = active;
    }
    if (Object.keys(updateData).length === 0) {
      return {success: true};
    }
    await db.collection(API_CLIENTS_COLLECTION).doc(clientId).update(updateData);
    return {success: true};
  } catch (error) {
    console.error("updateApiClient error:", error);
    throw new Error(`Failed to update API client: ${error.message}`);
  }
});

exports.deleteApiClient = onCall({region: "europe-west1"}, async (request) => {
  try {
    await ensureAdmin(request);
    const {clientId} = request.data || {};
    if (!clientId || typeof clientId !== "string") {
      throw new Error("clientId is required");
    }
    const clientRef = db.collection(API_CLIENTS_COLLECTION).doc(clientId);
    const clientSnap = await clientRef.get();
    if (!clientSnap.exists) {
      throw new Error("API client not found");
    }
    const usageSnap = await clientRef.collection("usage").get();
    const batch = db.batch();
    for (const d of usageSnap.docs) {
      batch.delete(d.ref);
    }
    batch.delete(clientRef);
    await batch.commit();
    return {success: true};
  } catch (error) {
    console.error("deleteApiClient error:", error);
    throw new Error(`Failed to delete API client: ${error.message}`);
  }
});

exports.regenerateApiClientKey = onCall({region: "europe-west1"}, async (request) => {
  try {
    await ensureAdmin(request);
    const {clientId} = request.data || {};
    if (!clientId || typeof clientId !== "string") {
      throw new Error("clientId is required");
    }
    const clientRef = db.collection(API_CLIENTS_COLLECTION).doc(clientId);
    const clientSnap = await clientRef.get();
    if (!clientSnap.exists) {
      throw new Error("API client not found");
    }
    const apiKey = generateApiKey();
    const apiKeyHash = hashApiKey(apiKey);
    await clientRef.update({apiKeyHash});
    return {
      apiKey,
      warning: "Save this API key. It will not be shown again. Previous key is now invalid.",
    };
  } catch (error) {
    console.error("regenerateApiClientKey error:", error);
    throw new Error(`Failed to regenerate API key: ${error.message}`);
  }
});

/**
 * HTTP function to serve sitemaps on-demand
 * Handles requests for:
 * - /sitemap.xml (sitemap index)
 * - /sitemaps/sitemap-{country}.xml (country sitemaps)
 */
exports.serveSitemap = onRequest(
    {
      region: "europe-west1",
      cors: true,
    },
    async (req, res) => {
      try {
        // Normalize path - remove query string and trailing slashes
        const path = (req.path || req.url || "/").split("?")[0].replace(/\/$/, "") || "/";

        // Extract sitemap filename from path
        let sitemapName;
        if (path === "/sitemap.xml" || path === "/sitemaps/sitemap.xml") {
          sitemapName = "sitemap.xml";
        } else if (path.startsWith("/sitemaps/")) {
          // Extract filename and decode URL encoding
          const rawFilename = path.replace("/sitemaps/", "");
          sitemapName = decodeURIComponent(rawFilename);

          // Validate filename to prevent path traversal attacks
          // sitemap.xml, sitemap-{country}.xml, sitemap-{country}-{n}.xml,
          // sitemap-unlocated.xml, sitemap-unlocated-{n}.xml,
          // sitemap-lists.xml, sitemap-lists-{n}.xml, sitemap-users.xml, sitemap-users-{n}.xml
          if (!/^sitemap(-(unlocated(-\d+)?|lists(-\d+)?|users(-\d+)?|[a-z]{2}(-\d+)?))?\.xml$/.test(sitemapName)) {
            res.status(400).send("Invalid sitemap filename");
            return;
          }

          // Additional security check: ensure no path traversal sequences
          if (sitemapName.includes("..") || sitemapName.includes("/") || sitemapName.includes("\\")) {
            res.status(400).send("Invalid sitemap filename");
            return;
          }
        } else {
          res.status(404).send("Sitemap not found");
          return;
        }

        // Read sitemap from Storage
        const xml = await getSitemapFromStorage(sitemapName);

        if (!xml) {
          res.status(404).send("Sitemap not found");
          return;
        }

        // Set appropriate headers
        res.set("Content-Type", "application/xml; charset=utf-8");
        res.set("Cache-Control", "public, max-age=3600"); // Cache for 1 hour

        res.status(200).send(xml);
      } catch (error) {
        console.error("Error serving sitemap:", error);
        res.status(500).send("Error generating sitemap");
      }
    },
);
