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
const crypto = require("crypto");

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();
const bucket = admin.storage().bucket();

// Import shared HTML template
const { generateHtmlPage, htmlEscape } = require('./html-template');

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
    const canonicalHost = host.includes('parkour.spot') ? host : "parkour.spot";
    const fullUrl = `https://${canonicalHost}${originalUrl}`;


    function extractSpotIdFromPath(pathname) {
      // Match: /<cc>/<city>/<spotId>
      let m = pathname.match(/^\/[a-zA-Z]{2}\/[^/]+\/([^/?#]+)$/);
      if (m && m[1]) return m[1];
      // Match: /spot/<spotId>
      m = pathname.match(/^\/spot\/([^/?#]+)$/);
      if (m && m[1]) return m[1];
      // Fallback: query param ?id=
      const urlObj = new URL(`https://dummy${pathname}${req.url.includes('?') ? '' : ''}`);
      const qpId = (req.query && (req.query.id || req.query.spotId)) || null;
      return qpId ? String(qpId) : null;
    }

    const pathname = (() => {
      try {
        const u = new URL(fullUrl);
        return u.pathname;
      } catch (_) {
        return req.path || "/";
      }
    })();

    const spotId = extractSpotIdFromPath(pathname);

    let spot = null;
    if (spotId) {
      const snap = await db.collection("spots").doc(spotId).get();
      if (snap.exists) {
        spot = {id: snap.id, ...snap.data()};
      }
    }

    const siteName = "Parkour.Spot";
    const defaultTitle = `${siteName}`;
    const defaultDescription = "Discover and share parkour spots around the world";
    const defaultImage = `https://${canonicalHost}/icons/Icon-512.png`;

    const title = spot && spot.name ? `${spot.name} - Parkour·Spot` : defaultTitle;

    function buildDescription(s) {
      if (!s) return defaultDescription;
      const parts = [];
      if (s.address && String(s.address).trim().length > 0) {
        parts.push(`📍 ${String(s.address).trim()}`);
      }
      if (typeof s.averageRating === "number" && !isNaN(s.averageRating) && s.ratingCount > 0 && s.averageRating > 0) {
        parts.push(`⭐ ${s.averageRating.toFixed(1)}`);
      }
      if (s.description && String(s.description).trim().length > 0) {
        const d = String(s.description).trim().replace(/\s+/g, " ");
        // Keep description concise
        const clipped = d.length > 220 ? d.slice(0, 217) + "…" : d;
        parts.push(`💬 ${clipped}`);
      }
      return parts.length ? parts.join("\n") : defaultDescription;
    }

    const description = buildDescription(spot);
    const imageUrl = (spot && Array.isArray(spot.imageUrls) && spot.imageUrls.length > 0)
      ? spot.imageUrls[0]
      : defaultImage;

    // Basic caching for crawlers and share scrapers
    res.set("Cache-Control", "public, max-age=300, s-maxage=600");
    res.set("Content-Type", "text/html; charset=utf-8");

    const html = generateHtmlPage({
      title: title,
      description: description,
      image: imageUrl,
      url: fullUrl,
      siteName: siteName,
      isDynamic: true,
      serviceWorkerVersion: null
    });

    res.status(200).send(html);
  } catch (err) {
    console.error("spotPage error", err);
    res.status(500).send("Internal Server Error");
  }
});

/**
 * Removes undefined values from an object to make it Firestore-safe
 * @param {Object} obj - The object to clean
 * @return {Object} The cleaned object
 */
function cleanUndefinedValues(obj) {
  const cleaned = {};
  for (const [key, value] of Object.entries(obj)) {
    if (value !== undefined) {
      cleaned[key] = value;
    }
  }
  return cleaned;
}

// ========== Ranked Spots within Bounds ==========
/**
 * Returns the top N spots within given map bounds ranked by Wilson score,
 * along with total count.
 * Ordering rules:
 *  - Spots with ratingCount > 0 and wilsonLowerBound > average go first
 *    (desc by wilsonLowerBound)
 *  - Spots without ratings next (treated as average); secondary sort by
 *    createdAt desc then name
 *  - Spots with ratingCount > 0 and wilsonLowerBound <= average last
 *    (desc by wilsonLowerBound)
 */
exports.getTopSpotsInBounds = onCall(
    {region: "europe-west1", timeoutSeconds: 60, memory: "512MiB"},
    async (request) => {
      try {
        const {
          minLat,
          maxLat,
          minLng,
          maxLng,
          limit = 100,
        } = request.data || {};

        if (
          typeof minLat !== "number" ||
        typeof maxLat !== "number" ||
        typeof minLng !== "number" ||
        typeof maxLng !== "number"
        ) {
          throw new Error(
              "minLat, maxLat, minLng, maxLng are required numbers");
        }

        // Handle dateline crossing
        const crossesDateline = minLng > maxLng;

        // Fetch precomputed average wilson from settings
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
            else if (
              v &&
                typeof v === "object" &&
                typeof v.toNumber === "function"
            ) {
              averageWilson = v.toNumber();
            }
          }
        } catch (avgErr) {
          console.warn(
              "Failed to load wilsonLowerBoundAvg from settings, " +
              "defaulting to 0",
              avgErr,
          );
        }

        // Fields to return to reduce payload size
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
          "isPublic",
          "spotSource",
          "spotSourceName",
          "averageRating",
          "ratingCount",
          "wilsonLowerBound",
          "createdAt",
          "updatedAt",
          "random",
        ];

        /**
       * Base query function for building Firestore queries
       * @param {number} lngMin - Minimum longitude
       * @param {number} lngMax - Maximum longitude
       * @param {string|null} type - Query type
       * @return {Object} Firestore query
       */
        function baseQuery(lngMin, lngMax, type = null) {
          let q = db.collection("spots").where("isPublic", "==", true);

          // For spots without ratings (type 'zero'), order by random field
          if (type === "zero") {
            q = q.orderBy("random");
          } else {
          // For other types, use the original longitude/latitude ordering
            q = q.orderBy("longitude");
          }

          q = q
              .where("latitude", ">=", minLat)
              .where("latitude", "<=", maxLat)
              .where("longitude", ">=", lngMin)
              .where("longitude", "<=", lngMax);

          // Add latitude ordering for non-zero types
          if (type !== "zero") {
            q = q.orderBy("latitude");
          }

          q = q.select(...projection);
          return q;
        }

        /**
       * Run segmented query for a specific type
       * @param {string} type - Query type
       * @param {number} remaining - Remaining spots to fetch
       * @return {Array} Array of spots
       */
        async function runSegmentedQuery(type, remaining) {
          if (remaining <= 0) return [];
          const perSide = crossesDateline ?
          Math.max(1, Math.ceil(remaining / 2)) :
          remaining;

          const build = (lngMin, lngMax) => {
            let q = baseQuery(lngMin, lngMax, type);
            if (type === "above") {
              q = q.where("wilsonLowerBound", ">", averageWilson);
            } else if (type === "zero") {
              q = q.where("wilsonLowerBound", "==", 0);
            } else if (type === "below") {
            // strictly below average and greater than zero to avoid duplicates
              q = q
                  .where("wilsonLowerBound", ">", 0)
                  .where("wilsonLowerBound", "<=", averageWilson);
            }
            return q.limit(perSide);
          };

          if (crossesDateline) {
            const [q1, q2] = await Promise.all([
              build(minLng, 180).get(),
              build(-180, maxLng).get(),
            ]);
            return [
              ...q1.docs.map((d) => ({id: d.id, ...d.data()})),
              ...q2.docs.map((d) => ({id: d.id, ...d.data()})),
            ];
          } else {
            const snap = await build(minLng, maxLng).get();
            return snap.docs.map((d) => ({id: d.id, ...d.data()}));
          }
        }

        /**
       * Get total count of spots in bounds
       * @return {number} Total count
       */
        async function getTotalCount() {
          const build = (lngMin, lngMax) =>
            db
                .collection("spots")
                .where("isPublic", "==", true)
                .orderBy("longitude")
                .where("latitude", ">=", minLat)
                .where("latitude", "<=", maxLat)
                .where("longitude", ">=", lngMin)
                .where("longitude", "<=", lngMax)
                .orderBy("latitude");
          try {
            if (crossesDateline) {
              const [c1, c2] = await Promise.all([
                build(minLng, 180).count().get(),
                build(-180, maxLng).count().get(),
              ]);
              const n1 = c1.data().count || 0;
              const n2 = c2.data().count || 0;
              return n1 + n2;
            } else {
              const c = await build(minLng, maxLng).count().get();
              return c.data().count || 0;
            }
          } catch (e) {
          // Fallback: if count aggregates are unavailable, return -1
            console.warn("Count aggregate failed, returning unknown total", e);
            return -1;
          }
        }

        const totalCount = await getTotalCount();

        const maxItems = Math.max(0, Math.min(200, Number(limit) || 100));
        const collected = [];
        const seen = new Set();

        // 1) Above average
        const above = await runSegmentedQuery("above", maxItems);
        for (const s of above) {
          if (!seen.has(s.id) && collected.length < maxItems) {
            seen.add(s.id);
            collected.push(s);
          }
        }
        let remaining = maxItems - collected.length;

        // 2) Unrated (wilsonLowerBound == 0)
        if (remaining > 0) {
          const zeros = await runSegmentedQuery("zero", remaining);
          for (const s of zeros) {
            if (!seen.has(s.id) && collected.length < maxItems) {
              seen.add(s.id);
              collected.push(s);
            }
          }
          remaining = maxItems - collected.length;
        }

        // 3) Below average (and > 0)
        if (remaining > 0) {
          const below = await runSegmentedQuery("below", remaining);
          for (const s of below) {
            if (!seen.has(s.id) && collected.length < maxItems) {
              seen.add(s.id);
              collected.push(s);
            }
          }
        }

        // Normalize Firestore Timestamp fields to ISO strings for client
        const normalize = (s) => {
          const createdAt =
          s.createdAt && s.createdAt.toDate ?
            s.createdAt.toDate().toISOString() :
            s.createdAt || null;
          const updatedAt =
          s.updatedAt && s.updatedAt.toDate ?
            s.updatedAt.toDate().toISOString() :
            s.updatedAt || null;
          return {...s, createdAt, updatedAt};
        };

        return {
          success: true,
          totalCount,
          averageWilson,
          shownCount: collected.length,
          spots: collected.map(normalize),
        };
      } catch (error) {
        console.error("getTopSpotsInBounds error", error);
        return {success: false, error: error.message};
      }
    },
);

// ========== Ratings Aggregation Helpers ==========
/**
 * Recomputes rating aggregates for a spot and updates the spot document.
 * averageRating: mean of ratings (0..5)
 * ratingCount: number of ratings
 * wilsonLowerBound: Wilson score lower bound over normalized stars (0..5)
 * @param {string} spotId
 */
async function recomputeSpotRatingAggregates(spotId) {
  try {
    if (!spotId) return;
    const ratingsSnap = await db
        .collection("ratings")
        .where("spotId", "==", spotId)
        .get();

    const count = ratingsSnap.size;

    if (count === 0) {
      await db.collection("spots").doc(spotId).set(
          {
            averageRating: 0,
            ratingCount: 0,
            wilsonLowerBound: 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
      );
      return;
    }

    let sum = 0;
    ratingsSnap.forEach((doc) => {
      const data = doc.data();
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

    await db
        .collection("spots")
        .doc(spotId)
        .set(
            {
              averageRating: Number(average.toFixed(4)),
              ratingCount: count,
              wilsonLowerBound: Number(wilsonLowerBound.toFixed(4)),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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

// ========== Rating Triggers ==========
exports.onRatingCreated = onDocumentCreated(
    {document: "ratings/{ratingId}", region: "europe-west1"},
    async (event) => {
      try {
        const data = event.data.data();
        const spotId = data && data.spotId;
        await recomputeSpotRatingAggregates(spotId);
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

        // If spotId changed (unlikely), recompute both
        if (beforeSpotId && beforeSpotId !== afterSpotId) {
          await Promise.all([
            recomputeSpotRatingAggregates(beforeSpotId),
            recomputeSpotRatingAggregates(afterSpotId),
          ]);
        } else {
          await recomputeSpotRatingAggregates(afterSpotId);
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
      } catch (e) {
        console.error("onRatingDeleted error", e);
      }
    },
);

// Example function that can be called from your Flutter app
exports.helloWorld = onCall({region: "europe-west1"}, (request) => {
  return "Hello from ParkourSpot Firebase Functions!";
});

// Trigger when a new spot is created
exports.onSpotCreated = onDocumentCreated(
    {document: "spots/{spotId}", region: "europe-west1"},
    (event) => {
      const spotData = event.data.data();
      console.log("New parkour spot created:", {
        spotId: event.params.spotId,
        name: spotData.name,
        createdBy: spotData.createdBy,
      });

    // You can add logic here like:
    // - Send notifications to nearby users
    // - Update search indexes
    // - Validate spot data
    },
);

// Trigger when a spot is updated
exports.onSpotUpdated = onDocumentUpdated(
    {document: "spots/{spotId}", region: "europe-west1"},
    (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();

      console.log("Parkour spot updated:", {
        spotId: event.params.spotId,
        name: afterData.name,
        ratingChanged: beforeData.rating !== afterData.rating,
      });

    // You can add logic here like:
    // - Update search indexes
    // - Send notifications about changes
    // - Log rating changes
    },
);

// Function to get nearby spots (can be called from Flutter app)
exports.getNearbySpots = onCall({region: "europe-west1"}, (request) => {
  const {latitude, longitude, radiusKm} = request.data;

  // This is a placeholder - you'd implement actual geospatial query logic
  return {
    message: "Nearby spots function called",
    params: {latitude, longitude, radiusKm},
  };
});

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
 * Detects import format based on URL and file buffer
 * @param {Buffer} buffer - The downloaded file buffer
 * @param {string} url - The original URL
 * @return {"kmz"|"kml"|"geojson"} The detected format
 */
function detectImportFormat(buffer, url) {
  const lowerUrl = (url || "").toLowerCase();
  // URL-based hints first
  if (lowerUrl.endsWith(".kmz")) return "kmz";
  if (lowerUrl.endsWith(".kml")) return "kml";
  if (lowerUrl.endsWith(".json") || lowerUrl.includes("/geojson")) {
    return "geojson";
  }

  // Content-based detection
  if (buffer && buffer.length >= 4) {
    // PK\x03\x04 -> ZIP (KMZ)
    if (buffer[0] === 0x50 && buffer[1] === 0x4b && buffer[2] === 0x03 && buffer[3] === 0x04) {
      return "kmz";
    }
    const text = buffer.slice(0, 256).toString("utf8").trimStart();
    if (text.startsWith("<")) return "kml"; // assume XML KML
    if (text.startsWith("{") || text.startsWith("[")) return "geojson";
  }

  // Default to GeoJSON since uMap often serves without extension
  return "geojson";
}

/**
 * Generates a content-based hash for an image buffer
 * @param {Buffer} imageBuffer - The image buffer
 * @return {string} The SHA-256 hash of the image content
 */
function generateImageHash(imageBuffer) {
  return crypto.createHash("sha256").update(imageBuffer).digest("hex");
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
 * Determines whether a given image URL belongs to an ephemeral Google host
 * whose links are unstable and should not be cached by original URL.
 * @param {string} imageUrl
 * @return {boolean}
 */
function isEphemeralImageHost(imageUrl) {
  try {
    const host = new URL(imageUrl).hostname.toLowerCase();
    return (
      host === "mymaps.usercontent.google.com" ||
      host === "lh3.googleusercontent.com"
    );
  } catch (_) {
    return false;
  }
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
 * Cleans HTML from description text
 * @param {string} description - The description text to clean
 * @return {string} The cleaned description text
 */
function cleanDescription(description) {
  if (!description) return "";

  // Remove HTML tags but preserve line breaks
  let cleaned = description
      .replace(/<br\s*\/?>/gi, "\n") // Convert <br> tags to newlines
      .replace(/<img[^>]*>/gi, "") // Remove <img> tags
      .replace(/<[^>]*>/g, "") // Remove all other HTML tags
      .replace(/&nbsp;/g, " ") // Convert &nbsp; to spaces
      .replace(/&amp;/g, "&") // Convert &amp; to &
      .replace(/&lt;/g, "<") // Convert &lt; to <
      .replace(/&gt;/g, ">") // Convert &gt; to >
      .replace(/&quot;/g, "\"") // Convert &quot; to "
      .replace(/&apos;/g, "'") // Convert &apos; to '
      .replace(/\n\s*\n\s*\n/g, "\n\n") // Replace 3+ newlines with 2
      .replace(/\n\s*\n/g, "\n\n") // Replace 2+ newlines with 2
      .trim(); // Remove leading/trailing whitespace

  // Remove YouTube URLs since we extract video IDs separately
  cleaned = cleaned
      .replace(/https?:\/\/(www\.)?youtube\.com\/watch\?v=[^\s\n]+/g, "") // Remove watch URLs
      .replace(/https?:\/\/(www\.)?youtube\.com\/embed\/[^\s\n]+/g, "") // Remove embed URLs
      .replace(/https?:\/\/(www\.)?youtube\.com\/shorts\/[^\s\n]+/g, "") // Remove shorts URLs
      .replace(/https?:\/\/youtu\.be\/[^\s\n]+/g, "") // Remove youtu.be URLs
      .replace(/\]\]>/g, "") // Remove CDATA closing tags
      .replace(/\n\s*\n\s*\n/g, "\n\n") // Clean up extra newlines again
      .replace(/\n\s*\n/g, "\n\n") // Replace 2+ newlines with 2
      .trim(); // Remove leading/trailing whitespace

  return cleaned;
}

/**
 * Extract YouTube video IDs from an HTML/text description
 * Supports urls like:
 *  - youtu.be/<id>
 *  - youtube.com/watch?v=<id>
 *  - youtube.com/embed/<id>
 *  - youtube.com/shorts/<id>
 * @param {string} description
 * @return {string[]} unique list of video IDs
 */
function extractYoutubeVideoIdsFromDescription(description) {
  if (!description) return [];
  const ids = new Set();

  // Generic URL matcher to scan the description - more precise
  const urlRegex = /(https?:\/\/[^\s"'<>)]+)/g;
  let match;
  while ((match = urlRegex.exec(description)) !== null) {
    // eslint-disable-line no-cond-assign
    const url = match[1];
    try {
      const uri = new URL(url);
      const host = uri.hostname.toLowerCase();
      const segments = uri.pathname.split("/").filter(Boolean);

      if (host.includes("youtu.be")) {
        const last = segments[segments.length - 1];
        if (last) ids.add(last);
        continue;
      }

      if (host.includes("youtube.com") || host.includes("www.youtube.com")) {
        const v = uri.searchParams.get("v");
        if (v) {
          ids.add(v);
          continue;
        }
        const embedIdx = segments.indexOf("embed");
        if (embedIdx !== -1 && embedIdx + 1 < segments.length) {
          ids.add(segments[embedIdx + 1]);
          continue;
        }
        const shortsIdx = segments.indexOf("shorts");
        if (shortsIdx !== -1 && shortsIdx + 1 < segments.length) {
          ids.add(segments[shortsIdx + 1]);
          continue;
        }
      }
    } catch (_) {
      // Ignore parse errors
    }
  }

  return Array.from(ids);
}

/**
 * Extracts image URLs from placemark data
 * @param {Object} placemark - The placemark data
 * @return {string[]} The image URLs
 */
function extractImageUrls(placemark) {
  const imageUrls = [];

  // Extract from description CDATA
  const description = placemark.description || "";
  const imgRegex = /<img[^>]+src="([^"]+)"/g;
  let match;
  while ((match = imgRegex.exec(description)) !== null) {
    imageUrls.push(match[1]);
  }

  // Also add YouTube thumbnails for any YouTube links present in the description
  const youtubeIds = extractYoutubeVideoIdsFromDescription(description);
  for (const vid of youtubeIds) {
    // Check if we already have a YouTube thumbnail for this video ID
    const existingThumbnail = imageUrls.find(
        (url) =>
          url.includes(`img.youtube.com/vi/${vid}/`) &&
        (url.includes("hqdefault.jpg") ||
          url.includes("mqdefault.jpg") ||
          url.includes("default.jpg")),
    );

    if (existingThumbnail) {
      // Replace the existing lower quality thumbnail with maxresdefault
      const index = imageUrls.indexOf(existingThumbnail);
      imageUrls[index] = `https://img.youtube.com/vi/${vid}/maxresdefault.jpg`;
    } else {
      // Add maxresdefault thumbnail if no existing YouTube thumbnail found
      imageUrls.push(`https://img.youtube.com/vi/${vid}/maxresdefault.jpg`);
    }
  }

  // Extract from ExtendedData gx_media_links
  const extendedData = placemark.extendedData || {};
  if (extendedData.Data) {
    const mediaData = extendedData.Data.find(
        (data) => data.$ && data.$.name === "gx_media_links",
    );
    if (mediaData && mediaData.value && mediaData.value[0]) {
      const mediaUrls = mediaData.value[0]
          .split(" ")
          .filter((url) => url.trim());
      imageUrls.push(...mediaUrls);
    }
  }

  // Remove duplicates and filter out invalid URLs
  const filteredUrls = [...new Set(imageUrls)].filter((url) => {
    if (!url || !url.startsWith("http")) {
      return false;
    }
    try {
      const host = new URL(url).hostname.toLowerCase();
      const isValid =
        host.includes("google.com") ||
        host.includes("googleusercontent.com") ||
        host.includes("img.youtube.com") ||
        host.includes("ytimg.com");
      return isValid;
    } catch (_) {
      return false;
    }
  });
  return filteredUrls;
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
      lastChecked: admin.firestore.FieldValue.serverTimestamp(),
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
  try {
    // Get image metadata
    const metadata = await sharp(imageBuffer).metadata();
    
    // Set maximum dimensions to reduce file size while maintaining quality
    const maxWidth = 1920;
    const maxHeight = 1920;
    
    let sharpInstance = sharp(imageBuffer);
    
    // Resize if image is too large
    if (metadata.width > maxWidth || metadata.height > maxHeight) {
      sharpInstance = sharpInstance.resize(maxWidth, maxHeight, {
        fit: 'inside',
        withoutEnlargement: true
      });
    }
    
    // Convert to JPEG with optimization
    const optimizedBuffer = await sharpInstance
      .jpeg({
        quality: 85, // Good balance between quality and file size
        progressive: true, // Progressive JPEG for better loading
        mozjpeg: true // Use mozjpeg encoder for better compression
      })
      .toBuffer();
    
    console.log(`Image optimized: ${imageBuffer.length} bytes -> ${optimizedBuffer.length} bytes (${((1 - optimizedBuffer.length / imageBuffer.length) * 100).toFixed(1)}% reduction)`);
    
    return optimizedBuffer;
  } catch (error) {
    console.error("Error optimizing image:", error);
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
 * @return {Promise<Object>} A promise that resolves to an object containing
 *     imageUrls and imageHashes arrays
 */
async function processPlacemarkImages(placemark, existingSpotData = null) {
  const imageUrls = extractImageUrls(placemark);

  if (imageUrls.length === 0) {
    return {imageUrls: [], imageHashes: []};
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

  // Process images in parallel batches to reduce total processing time
  const BATCH_SIZE = 3; // Process 3 images at a time to balance speed and memory usage

  for (let i = 0; i < imageUrls.length; i += BATCH_SIZE) {
    const batch = imageUrls.slice(i, i + BATCH_SIZE);
    console.log(`Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(imageUrls.length / BATCH_SIZE)} (${batch.length} images)`);
    
    const batchPromises = batch.map(async (url, batchIndex) => {
      const globalIndex = i + batchIndex;
      
      // Check if we have a stored hash for this specific image URL
      let storedHash = null;
      if (urlToHashMap.has(url)) {
        storedHash = urlToHashMap.get(url);
      }

      const result = await downloadAndUploadImage(
          url,
          placemark.name,
          globalIndex,
          storedHash,
      );
      
      // Force garbage collection hint after each image
      if (global.gc) {
        global.gc();
      }
      
      return result;
    });

    // Wait for all images in this batch to complete
    const batchResults = await Promise.all(batchPromises);
    
    // Add successful results to our arrays
    batchResults.forEach(result => {
      if (result) {
        uploadedImageUrls.push(result.url);
        imageHashes.push(result.hash);
      }
    });
    
    console.log(`Completed batch ${Math.floor(i / BATCH_SIZE) + 1}, processed ${batchResults.filter(r => r).length}/${batch.length} images successfully`);
  }

  console.log(
      `Successfully processed ${uploadedImageUrls.length} images ` +
      `for spot: ${placemark.name}`,
  );
  return {imageUrls: uploadedImageUrls, imageHashes};
}

/**
 * Cleans up the image cache by removing entries for images that no longer exist in storage
 * @return {Promise<Object>} A promise that resolves to cleanup statistics
 */
async function cleanupImageCache() {
  try {
    console.log("Starting image cache cleanup...");

    const imageCacheSnapshot = await db.collection("imageCache").get();
    const totalEntries = imageCacheSnapshot.size;
    let removedEntries = 0;
    let validEntries = 0;

    console.log(`Found ${totalEntries} entries in image cache`);

    // Process in batches to avoid memory issues
    const BATCH_SIZE = 50;
    const batches = [];

    for (let i = 0; i < imageCacheSnapshot.docs.length; i += BATCH_SIZE) {
      batches.push(imageCacheSnapshot.docs.slice(i, i + BATCH_SIZE));
    }

    for (const batch of batches) {
      const batchPromises = batch.map(async (doc) => {
        const cacheData = doc.data();
        const {hash, url} = cacheData;

        // Check if the image still exists in storage
        const existingFileName = await checkImageExists(hash);
        if (existingFileName) {
          validEntries++;
          return;
        } else {
          // Image no longer exists, remove from cache
          await doc.ref.delete();
          removedEntries++;
          console.log(
              `Removed cache entry for missing image: ${url.substring(0, 50)}...`,
          );
        }
      });

      await Promise.all(batchPromises);
    }

    const result = {
      totalEntries,
      validEntries,
      removedEntries,
      message: `Image cache cleanup completed. Removed ${removedEntries} invalid entries, kept ${validEntries} valid entries.`,
    };

    console.log(result.message);
    return result;
  } catch (error) {
    console.error("Error during image cache cleanup:", error);
    return {
      success: false,
      error: error.message,
    };
  }
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
          if (name.includes('adresse') || name.includes('address') || name.includes('location') || 
              name.includes('place') || name.includes('street')) {
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
 * @return {Promise<Object>} Processing result with statistics
 */
async function processSyncSource(source, sourceId, apiKey) {
  console.log(`Processing source: ${source.name} (${sourceId})`);

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
      propertiesName: json.properties ? json.properties.name : null
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

  // Clear file buffer to free memory
  fileBuffer = null;

  let created = 0;
  let updated = 0;
  let geocoded = 0;
  let geocodingFailed = 0;
  const skipped = 0;

  // Collect all unique folder names from successfully processed spots if recordFolderName is enabled
  const allFolders = new Set();

  if (source.recordFolderName === true) {
    console.log(
        `[FOLDER COLLECTION] Starting folder collection for source: ${source.name}`,
    );
    console.log(
        `[FOLDER COLLECTION] Total placemarks to process: ${placemarks.length}`,
    );

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

  // Process each placemark
  for (let i = 0; i < placemarks.length; i++) {
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
          altitude: 0
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
    );

    // Extract YouTube IDs from the raw description for storage and thumbnails
    const youtubeVideoIds = extractYoutubeVideoIdsFromDescription(
        description || "",
    );

    // Clean the description to remove HTML
    const cleanedDescription = cleanDescription(description);

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
      isPublic: source.isPublic !== false, // Default to true
      random: Math.random(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    // Optionally record folder name on spot if configured and available
    if (source.recordFolderName === true) {
      if (placemark.folderName) {
        spotData.folderName = placemark.folderName;
      } else {
        spotData.folderName = null;
      }
    }

    // Add YouTube video IDs if found
    if (youtubeVideoIds.length > 0) {
      spotData.youtubeVideoIds = youtubeVideoIds;
    }

    // Add image URLs and hashes if any were found
    if (imageResult.imageUrls.length > 0) {
      spotData.imageUrls = imageResult.imageUrls;
      spotData.imageHashes = imageResult.imageHashes;
    }

    if (existingSpots.empty) {
      // Create new spot - initialize rating fields to 0
      spotData.averageRating = 0;
      spotData.ratingCount = 0;
      spotData.wilsonLowerBound = 0;
      spotData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      await db.collection("spots").add(cleanUndefinedValues(spotData));
      created++;
      console.log(
          `Created new spot: ${name} from source: ${source.name} with ${imageResult.imageUrls.length} images and geocoded address`,
      );
    } else {
      // Update existing spot - preserve existing rating fields
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
      
      await existingSpot.ref.update(cleanUndefinedValues(spotData));
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
  }

  // Update source last sync time and folder information
  const sourceDoc = await db.collection("syncSources").doc(sourceId).get();
  if (sourceDoc.exists) {
    const updateData = {
      lastSyncAt: admin.firestore.FieldValue.serverTimestamp(),
      lastSyncStats: {
        total: placemarks.length,
        created: created,
        updated: updated,
        skipped: skipped,
        geocoded: geocoded,
        geocodingFailed: geocodingFailed,
        geocodingSuccessRate:
          placemarks.length > 0 ?
            ((geocoded / placemarks.length) * 100).toFixed(1) + "%" :
            "0%",
      },
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

  return {
    sourceId: sourceId,
    sourceName: source.name,
    stats: {
      total: placemarks.length,
      created: created,
      updated: updated,
      skipped: skipped,
      geocoded: geocoded,
      geocodingFailed: geocodingFailed,
      geocodingSuccessRate:
        placemarks.length > 0 ?
          ((geocoded / placemarks.length) * 100).toFixed(1) + "%" :
          "0%",
    },
  };
}

/**
 * Helper to ensure caller is admin (via custom claim or Firestore users/{uid}.isAdmin)
 * @param {Object} request - The request object
 * @return {Promise<void>} Resolves if admin, throws if not
 */
async function ensureAdmin(request) {
  const auth = request.auth;
  if (!auth || !auth.uid) {
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

// Function to sync a single source by ID (admin only)
exports.syncSingleSource = onCall(
    {
      region: "europe-west1",
      memory: "1GiB",
      timeoutSeconds: 3600,
      secrets: ["GOOGLE_MAPS_API_KEY"],
    },
    async (request) => {
      try {
        await ensureAdmin(request);
        const {sourceId} = request.data;

        if (!sourceId) {
          throw new Error("sourceId is required");
        }

        const apiKey = process.env.GOOGLE_MAPS_API_KEY;
        if (!apiKey) {
          throw new Error("Google Maps API key not configured");
        }

        console.log(`Starting sync for single source: ${sourceId}`);

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
          const result = await processSyncSource(source, sourceId, apiKey);

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

        console.log("Starting sync for all sources from Firestore");

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
            const result = await processSyncSource(source, sourceId, apiKey);

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
          isPublic = true,
          isActive = true,
          includeFolders,
          recordFolderName,
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
          isPublic: isPublic,
          isActive: isActive,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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

        const docRef = await db.collection("syncSources").add(sourceData);

        return {
          success: true,
          message: "Sync source created successfully",
          sourceId: docRef.id,
          data: sourceData,
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
          isPublic,
          isActive,
          includeFolders,
          recordFolderName,
        } = request.data;

        if (!sourceId) {
          throw new Error("sourceId is required");
        }

        const updateData = {
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        if (name !== undefined) updateData.name = name;
        if (kmzUrl !== undefined) updateData.kmzUrl = kmzUrl;
        if (description !== undefined) updateData.description = description;
        if (publicUrl !== undefined) updateData.publicUrl = publicUrl;
        if (instagramHandle !== undefined) {
          updateData.instagramHandle = instagramHandle;
        }
        if (isPublic !== undefined) updateData.isPublic = isPublic;
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
            updateData.includeFolders = admin.firestore.FieldValue.delete();
          }
        }
        if (recordFolderName !== undefined) {
          if (typeof recordFolderName === "boolean") {
            updateData.recordFolderName = recordFolderName;
          } else if (recordFolderName === null) {
            updateData.recordFolderName = admin.firestore.FieldValue.delete();
          }
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
    let {includeInactive = false} = request.data;

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

    const sources = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

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

// Admin function to update spot source names for existing spots
exports.updateSpotSourceNames = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        await ensureAdmin(request);
        const {sourceId} = request.data;

        console.log(`Starting spot source name update${sourceId ? ` for source: ${sourceId}` : ' for all sources'}`);

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
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
    {region: "europe-west1", memory: "1GiB", timeoutSeconds: 540},
    async (request) => {
      try {
        await ensureAdmin(request);

        console.log("Starting unused images cleanup");

        // Get all spots to find which images are currently in use
        const spotsSnapshot = await db.collection("spots").get();
        const usedImageUrls = new Set();

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
                }
              } catch (urlError) {
                console.warn(`Failed to parse URL: ${url}`, urlError);
                // Fallback to simple extraction
                const urlParts = url.split("/");
                const lastPart = urlParts[urlParts.length - 1];
                const filename = lastPart.split("?")[0]; // Remove query parameters
                if (filename) {
                  usedImageUrls.add(filename);
                }
              }
            });
          }
        });

        console.log(`Found ${usedImageUrls.size} images currently in use`);
        console.log(
            "Used image filenames:",
            Array.from(usedImageUrls).slice(0, 10),
        ); // Log first 10 for debugging

        // List all files in the spots folder
        const [files] = await bucket.getFiles({
          prefix: "spots/",
        });

        console.log(`Found ${files.length} total files in storage`);

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
        const movedFiles = [];

        for (const file of files) {
          const fileName = file.name;
          const fileNameOnly = fileName.split("/").pop();

          // Skip if file is currently in use
          if (usedImageUrls.has(fileNameOnly)) {
            skippedCount++;
            console.log(`Skipping used file: ${fileNameOnly}`);
            continue;
          }

          // Skip if already in trash folder
          if (fileName.startsWith("spots/trash/")) {
            skippedCount++;
            console.log(`Skipping file already in trash: ${fileNameOnly}`);
            continue;
          }

          try {
          // Move file to trash folder
            const trashFileName = `spots/trash/${fileNameOnly}`;
            console.log(`Moving ${fileNameOnly} to ${trashFileName}`);

            // Copy to trash location
            await file.copy(trashFileName);
            console.log(`Copied ${fileNameOnly} to trash`);

            // Delete original file
            await file.delete();
            console.log(`Deleted original ${fileNameOnly}`);

            movedCount++;
            movedFiles.push(fileName);
            console.log(
                `Successfully moved unused file to trash: ${fileNameOnly}`,
            );
          } catch (moveError) {
            console.error(`Failed to move file ${fileName} to trash:`, moveError);
          }
        }

        const result = {
          success: true,
          movedCount,
          skippedCount,
          totalFiles: files.length,
          movedFiles: movedFiles.slice(0, 10), // Limit to first 10 for response size
          message:
          `Cleanup completed. Moved ${movedCount} unused images to ` +
          `trash, skipped ${skippedCount} files.`,
        };

        console.log("Unused images cleanup completed:", result);
        return result;
      } catch (error) {
        console.error("Error during unused images cleanup:", error);
        return {
          success: false,
          error: error.message,
        };
      }
    },
);

// Function to cleanup image cache by removing entries for images that no longer exist (admin only)
exports.cleanupImageCache = onCall(
    {region: "europe-west1", memory: "512MiB", timeoutSeconds: 540},
    async (request) => {
      try {
        await ensureAdmin(request);
        const result = await cleanupImageCache();
        return {
          success: true,
          ...result,
        };
      } catch (error) {
        console.error("Error in cleanupImageCache:", error);
        return {
          success: false,
          error: error.message,
        };
      }
    },
);

// Function to find missing images and provide upload URLs (admin only)
exports.findMissingImages = onCall(
    {region: "europe-west1", memory: "512MiB", timeoutSeconds: 300},
    async (request) => {
      try {
        await ensureAdmin(request);

        console.log("Starting missing images check");

        // Get all spots to find which images are referenced
        const spotsSnapshot = await db.collection("spots").get();
        const referencedImages = new Set();
        const missingImages = [];

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
                  referencedImages.add(filename);
                }
              } catch (urlError) {
                console.warn(`Failed to parse URL: ${url}`, urlError);
                // Fallback to simple extraction
                const urlParts = url.split("/");
                const lastPart = urlParts[urlParts.length - 1];
                const filename = lastPart.split("?")[0]; // Remove query parameters
                if (filename) {
                  referencedImages.add(filename);
                }
              }
            });
          }
        });

        console.log(`Found ${referencedImages.size} referenced images`);

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

        // Find missing images
        referencedImages.forEach((filename) => {
          if (!existingFiles.has(filename)) {
            missingImages.push({
              filename: filename,
              spotId: null, // We'll populate this in the next step
              spotName: null,
              imageUrl: null,
            });
          }
        });

        // Find which spots reference each missing image
        const missingImagesWithSpots = [];
        for (const missingImage of missingImages) {
          const spotsWithThisImage = [];

          spotsSnapshot.forEach((doc) => {
            const spotData = doc.data();
            if (spotData.imageUrls && Array.isArray(spotData.imageUrls)) {
              spotData.imageUrls.forEach((url) => {
                let filename;
                try {
                  const urlObj = new URL(url);
                  const pathname = urlObj.pathname;

                  if (
                    url.includes("firebasestorage.googleapis.com") &&
                  pathname.includes("/o/")
                  ) {
                    const encodedPath = pathname.split("/o/")[1];
                    const decodedPath = decodeURIComponent(encodedPath);
                    filename = decodedPath.split("/").pop();
                  } else {
                    filename = pathname.split("/").pop();
                  }

                  if (filename === missingImage.filename) {
                    spotsWithThisImage.push({
                      spotId: doc.id,
                      spotName: spotData.name || "Unnamed Spot",
                      imageUrl: url,
                    });
                  }
                } catch (urlError) {
                // Skip invalid URLs
                }
              });
            }
          });

          if (spotsWithThisImage.length > 0) {
            missingImagesWithSpots.push({
              filename: missingImage.filename,
              spots: spotsWithThisImage,
            });
          }
        }

        const result = {
          success: true,
          totalReferencedImages: referencedImages.size,
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

        /**
         * Helper: perform geocoding for given lat/lng
         * @param {number} latitude - The latitude coordinate
         * @param {number} longitude - The longitude coordinate
         * @return {Promise<Object>} Geocoding result
         */
        async function geocodeLatLng(latitude, longitude) {
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

              const result = await geocodeLatLng(latitude, longitude);

              if (result.success) {
                await doc.ref.update({
                  address: result.address || null,
                  city: result.city || null,
                  countryCode: result.countryCode || null,
                  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
