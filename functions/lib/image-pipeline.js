/* eslint-disable max-len */
/**
 * Cache-first image pipeline for spot sync.
 * Holds at most one image's working buffers; returns plain string arrays only.
 */

const http = require("http");
const https = require("https");
const path = require("path");
const sharp = require("sharp");
const {
  isEphemeralImageHost,
  isGoogleUserContentUrl,
} = require("./url-helpers");
const {generateImageHash} = require("./import-helpers");
const {
  extractYoutubeVideoIdFromThumbnailUrl,
  resolveYoutubeThumbnailUrl,
} = require("./youtube-thumbnails");
const {GOOGLE_EARTH_IMAGE_SIZE_CANDIDATES} = require("./google-earth-images");
const {
  ISSUE_YOUTUBE_MISSING_THUMBNAIL,
  ISSUE_YOUTUBE_UNCACHED_THUMBNAIL,
} = require("./sync-runs");

/** Skip downloads larger than this (bytes). */
const MAX_IMAGE_DOWNLOAD_BYTES = 25 * 1024 * 1024;

/**
 * Extracts a Storage object path from a public GCS URL for this bucket.
 * @param {string} publicUrl
 * @param {string} bucketName
 * @return {string|null}
 */
function storagePathFromPublicUrl(publicUrl, bucketName) {
  if (typeof publicUrl !== "string" || !publicUrl || !bucketName) {
    return null;
  }
  const prefix = `https://storage.googleapis.com/${bucketName}/`;
  if (publicUrl.startsWith(prefix)) {
    return decodeURIComponent(publicUrl.slice(prefix.length));
  }
  return null;
}

/**
 * Downloads a binary URL following redirects, with a size cap.
 * @param {string} url
 * @param {number=} redirectCount
 * @param {number=} maxBytes
 * @return {Promise<{buffer: Buffer, contentType: ?string, finalUrl: string}>}
 */
function downloadBinaryWithRedirects(
    url,
    redirectCount = 0,
    maxBytes = MAX_IMAGE_DOWNLOAD_BYTES,
) {
  if (redirectCount > 8) {
    return Promise.reject(new Error("Too many redirects while downloading image"));
  }

  let parsedUrl;
  try {
    parsedUrl = new URL(url);
  } catch (error) {
    return Promise.reject(new Error(`Invalid image URL: ${url}`));
  }
  if (parsedUrl.protocol !== "https:" && parsedUrl.protocol !== "http:") {
    return Promise.reject(new Error("Image URL must use http or https"));
  }
  const client = parsedUrl.protocol === "http:" ? http : https;

  return new Promise((resolve, reject) => {
    const request = client.get(parsedUrl, {
      headers: {
        "User-Agent": "ParkourSpotImageSync/1.0 (+https://parkour.spot)",
        "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
      },
    }, (response) => {
      if (
        response.statusCode &&
        response.statusCode >= 300 &&
        response.statusCode < 400 &&
        response.headers.location
      ) {
        response.resume();
        const redirectedUrl = new URL(
            response.headers.location,
            parsedUrl,
        ).toString();
        resolve(downloadBinaryWithRedirects(
            redirectedUrl,
            redirectCount + 1,
            maxBytes,
        ));
        return;
      }

      if (!response.statusCode || response.statusCode >= 400) {
        const statusCode = response.statusCode || 0;
        response.resume();
        reject(new Error(
            `Failed downloading image (HTTP ${statusCode}): ${url}`,
        ));
        return;
      }

      const contentType = response.headers["content-type"] ?
        String(response.headers["content-type"]).toLowerCase() :
        null;
      if (contentType && contentType.includes("text/html")) {
        response.resume();
        reject(new Error(
            `Refusing to treat HTML as image: ${url}`,
        ));
        return;
      }

      const contentLength = Number(response.headers["content-length"]);
      if (
        Number.isFinite(contentLength) &&
        contentLength > maxBytes
      ) {
        response.resume();
        reject(new Error(
            `Image too large (${contentLength} bytes): ${url}`,
        ));
        return;
      }

      const chunks = [];
      let totalSize = 0;
      response.on("data", (chunk) => {
        totalSize += chunk.length;
        if (totalSize > maxBytes) {
          response.destroy();
          reject(new Error(
              `Image too large (>${maxBytes} bytes): ${url}`,
          ));
          return;
        }
        chunks.push(chunk);
      });
      response.on("end", () => {
        resolve({
          buffer: Buffer.concat(chunks),
          contentType,
          finalUrl: parsedUrl.toString(),
        });
      });
      response.on("error", reject);
    });

    request.on("error", reject);
    request.setTimeout(60000, () => {
      request.destroy(new Error(`Image download timed out: ${url}`));
    });
  });
}

/**
 * Optimizes an image buffer with Sharp. Destroys the Sharp instance in finally.
 * @param {Buffer} imageBuffer
 * @return {Promise<Buffer|null>}
 */
async function optimizeImage(imageBuffer) {
  let sharpInstance = null;
  try {
    const metadata = await sharp(imageBuffer).metadata();
    if (!metadata || !metadata.format) {
      throw new Error("Unrecognized image format");
    }

    const maxWidth = 1920;
    const maxHeight = 1920;

    sharpInstance = sharp(imageBuffer);

    if (metadata.width > maxWidth || metadata.height > maxHeight) {
      sharpInstance = sharpInstance.resize(maxWidth, maxHeight, {
        fit: "inside",
        withoutEnlargement: true,
      });
    }

    const optimizedBuffer = await sharpInstance
        .jpeg({
          quality: 85,
          progressive: true,
          mozjpeg: true,
        })
        .toBuffer();

    console.log(
        `Image optimized: ${imageBuffer.length} bytes -> ` +
        `${optimizedBuffer.length} bytes (` +
        `${((1 - optimizedBuffer.length / imageBuffer.length) * 100).toFixed(1)}% reduction)`,
    );

    return optimizedBuffer;
  } catch (error) {
    console.error("Error optimizing image:", error);
    return null;
  } finally {
    if (sharpInstance && typeof sharpInstance.destroy === "function") {
      try {
        sharpInstance.destroy();
      } catch (_) {
        // ignore
      }
    }
    sharpInstance = null;
  }
}

/**
 * Creates an image pipeline bound to Firestore + Storage.
 * @param {Object} deps
 * @param {Object} deps.db Firestore instance
 * @param {Object} deps.bucket Storage bucket
 * @param {*} deps.FieldValue
 * @return {Object}
 */
function createImagePipeline(deps) {
  const {
    db,
    bucket,
    FieldValue,
    downloadBinaryWithRedirectsFn = downloadBinaryWithRedirects,
    optimizeImageFn = optimizeImage,
  } = deps;

  if (!db || !bucket || !FieldValue) {
    throw new Error("createImagePipeline requires db, bucket, and FieldValue");
  }

  /**
   * @param {string} fileName
   * @return {string}
   */
  function getPublicUrl(fileName) {
    return `https://storage.googleapis.com/${bucket.name}/${fileName}`;
  }

  /**
   * Checks whether a specific Storage object still exists.
   * @param {string} fileName
   * @return {Promise<boolean>}
   */
  async function storageObjectExists(fileName) {
    try {
      const [exists] = await bucket.file(fileName).exists();
      return Boolean(exists);
    } catch (error) {
      console.error("Error checking storage object:", error);
      return false;
    }
  }

  /**
   * Finds an existing Storage object by content hash (list under folder).
   * Prefer cache/publicUrl checks when possible to avoid listing.
   * @param {string} imageHash
   * @param {string=} storageFolder
   * @return {Promise<string|null>}
   */
  async function checkImageExists(imageHash, storageFolder = "spots") {
    try {
      const prefix = `${storageFolder}/`;
      const [files] = await bucket.getFiles({
        prefix,
        delimiter: "/",
      });

      for (const file of files) {
        const fileName = file.name;
        if (fileName.includes(`_${imageHash}_`)) {
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
   * Looks up imageCache and verifies the Storage object via publicUrl path
   * (no full-folder listing on the hit path).
   * @param {string} imageUrl
   * @param {string=} storageFolder
   * @return {Promise<Object|null>} `{url, hash}` or null
   */
  async function lookupImageCache(imageUrl, storageFolder = "spots") {
    try {
      if (isEphemeralImageHost(imageUrl)) {
        return null;
      }
      const imageCacheRef = db
          .collection("imageCache")
          .doc(encodeURIComponent(imageUrl));
      const imageCacheDoc = await imageCacheRef.get();

      if (!imageCacheDoc.exists) {
        return null;
      }

      const cacheData = imageCacheDoc.data() || {};
      const {hash, publicUrl} = cacheData;
      if (!publicUrl) {
        return null;
      }

      const fileName = storagePathFromPublicUrl(publicUrl, bucket.name);
      if (fileName) {
        if (await storageObjectExists(fileName)) {
          console.log(
              `Found cached image for URL: ${imageUrl.substring(0, 50)}...`,
          );
          return {url: publicUrl, hash: hash || null};
        }
      } else if (hash) {
        // Legacy / unexpected publicUrl shape — fall back to hash list.
        const existingFileName = await checkImageExists(hash, storageFolder);
        if (existingFileName) {
          return {url: getPublicUrl(existingFileName), hash};
        }
      }

      console.log(
          `Cached image no longer exists, removing from cache: ` +
          `${imageUrl.substring(0, 50)}...`,
      );
      await imageCacheRef.delete();
      return null;
    } catch (error) {
      console.error("Error checking image URL cache:", error);
      return null;
    }
  }

  /**
   * @param {string} imageUrl
   * @return {Promise<string|null>} public URL only (compat)
   */
  async function checkImageUrlCache(imageUrl) {
    const hit = await lookupImageCache(imageUrl);
    return hit ? hit.url : null;
  }

  /**
   * @param {string} imageUrl
   * @param {string} imageHash
   * @param {string} publicUrl
   * @return {Promise<void>}
   */
  async function cacheImageMetadata(imageUrl, imageHash, publicUrl) {
    try {
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
   * Downloads and uploads one image (cache-first). Buffers cleared before return.
   * @param {string} imageUrl
   * @param {string} spotName
   * @param {number} imageIndex
   * @param {string|null} storedHash
   * @param {string=} storageFolder
   * @return {Promise<{url: string, hash: string}|null>}
   */
  async function downloadAndUploadImage(
      imageUrl,
      spotName,
      imageIndex,
      storedHash = null,
      storageFolder = "spots",
  ) {
    let imageBuffer = null;
    let optimizedImageBuffer = null;
    try {
      console.log(`Processing image ${imageIndex + 1} for spot: ${spotName}`);

      const cached = await lookupImageCache(imageUrl, storageFolder);
      if (cached) {
        console.log(
            `Using cached image for URL: ${imageUrl.substring(0, 50)}...`,
        );
        return {url: cached.url, hash: cached.hash};
      }

      if (storedHash) {
        const existingFileName = await checkImageExists(
            storedHash,
            storageFolder,
        );
        if (existingFileName) {
          console.log(
              `Using stored hash for existing image: ` +
              `${storedHash.substring(0, 8)}...`,
          );
          const publicUrl = getPublicUrl(existingFileName);
          await cacheImageMetadata(imageUrl, storedHash, publicUrl);
          return {url: publicUrl, hash: storedHash};
        }
        console.log(
            `Stored hash no longer valid, will download and recalculate: ` +
            `${storedHash.substring(0, 8)}...`,
        );
      }

      const downloaded = await downloadBinaryWithRedirectsFn(imageUrl);
      imageBuffer = downloaded.buffer;

      const imageHash = generateImageHash(imageBuffer);
      console.log(`Generated hash for image: ${imageHash.substring(0, 8)}...`);

      if (storedHash && storedHash !== imageHash) {
        console.warn(
            `Hash mismatch! Stored: ${storedHash.substring(0, 8)}..., ` +
            `Calculated: ${imageHash.substring(0, 8)}...`,
        );
        console.warn("Image may have changed, using new hash");
      }

      const existingFileName = await checkImageExists(imageHash, storageFolder);
      if (existingFileName) {
        console.log(`Image already exists, reusing: ${existingFileName}`);
        const publicUrl = getPublicUrl(existingFileName);
        await cacheImageMetadata(imageUrl, imageHash, publicUrl);
        imageBuffer = null;
        return {url: publicUrl, hash: imageHash};
      }

      let extension = ".jpg";
      try {
        const pathExt = path.extname(
            new URL(downloaded.finalUrl || imageUrl).pathname,
        );
        if (pathExt && pathExt.length <= 5) {
          extension = pathExt;
        }
      } catch (_) {
        extension = ".jpg";
      }
      if (
        extension.toLowerCase() === ".html" ||
        extension.toLowerCase() === ".htm"
      ) {
        extension = ".jpg";
      }
      const safeFolder = storageFolder === "events" ? "events" : "spots";
      const filename =
        `${safeFolder}/${spotName.replace(/[^a-zA-Z0-9]/g, "_")}_` +
        `${imageHash}_${imageIndex}${extension}`;

      optimizedImageBuffer = await optimizeImageFn(imageBuffer);
      imageBuffer = null;

      if (!optimizedImageBuffer) {
        console.warn(
            `Skipping non-decodable image for spot: ${spotName} (${imageUrl})`,
        );
        return null;
      }

      const file = bucket.file(filename);
      await file.save(optimizedImageBuffer, {
        metadata: {
          contentType: "image/jpeg",
          cacheControl: "public, max-age=31536000",
        },
      });
      optimizedImageBuffer = null;

      await file.makePublic();

      const publicUrl = getPublicUrl(filename);
      console.log(`Uploaded new image to: ${publicUrl}`);

      await cacheImageMetadata(imageUrl, imageHash, publicUrl);

      return {url: publicUrl, hash: imageHash};
    } catch (error) {
      console.error(
          `Failed to download/upload image ${imageIndex + 1} for ` +
          `${spotName}:`,
          error,
      );
      return null;
    } finally {
      imageBuffer = null;
      optimizedImageBuffer = null;
    }
  }

  /**
   * Downloads a YouTube thumbnail and uploads it to Storage.
   * @param {string} videoId
   * @param {string} spotName
   * @param {number} imageIndex
   * @return {Promise<{url: string, hash: string}|null>}
   */
  async function downloadAndUploadYoutubeThumbnail(
      videoId,
      spotName,
      imageIndex,
  ) {
    const thumbUrl = await resolveYoutubeThumbnailUrl(videoId);
    if (!thumbUrl) {
      return null;
    }
    return downloadAndUploadImage(thumbUrl, spotName, imageIndex);
  }

  /**
   * Processes one source URL (YouTube normalize + cache-first upload).
   * @param {string} rawUrl
   * @param {string} spotName
   * @param {number} imageIndex
   * @param {Map<string, string>} urlToHashMap
   * @return {Promise<{url: string, hash: string, sourceUrl: string}|null>}
   */
  async function processOneSourceUrl(
      rawUrl,
      spotName,
      imageIndex,
      urlToHashMap,
  ) {
    let url = rawUrl;
    const youtubeVideoId = extractYoutubeVideoIdFromThumbnailUrl(url);
    if (youtubeVideoId) {
      const resolvedUrl = await resolveYoutubeThumbnailUrl(youtubeVideoId);
      if (!resolvedUrl) {
        console.warn(
            `Skipping unavailable YouTube thumbnail for video ${youtubeVideoId} ` +
            `(spot: ${spotName})`,
        );
        return null;
      }
      url = resolvedUrl;
    }

    let storedHash = null;
    if (urlToHashMap.has(url)) {
      storedHash = urlToHashMap.get(url);
    }

    let finalResult = await downloadAndUploadImage(
        url,
        spotName,
        imageIndex,
        storedHash,
    );

    if (
      !finalResult &&
      typeof url === "string" &&
      isGoogleUserContentUrl(url)
    ) {
      for (const size of GOOGLE_EARTH_IMAGE_SIZE_CANDIDATES) {
        const retryUrl = url.replace(/fife=s\d+/i, `fife=s${size}`);
        if (retryUrl === url) continue;
        finalResult = await downloadAndUploadImage(
            retryUrl,
            spotName,
            imageIndex,
            storedHash,
        );
        if (finalResult) {
          url = retryUrl;
          break;
        }
      }
    }

    if (!finalResult) {
      return null;
    }
    return {url: finalResult.url, hash: finalResult.hash, sourceUrl: url};
  }

  /**
   * Cache-first spot image ensure. Returns string arrays only (no buffers).
   * @param {Object} options
   * @param {string[]} options.sourceUrls
   * @param {string[]=} options.youtubeVideoIds
   * @param {Object|null=} options.existing Existing spot image fields
   * @param {string} options.mode `"light"` or `"full"`
   * @param {string} options.spotName
   * @param {string=} options.folderName
   * @return {Promise<Object>} `{imageUrls, imageHashes, youtubeVideoIds, issues}`
   */
  async function ensureSpotImages({
    sourceUrls = [],
    youtubeVideoIds = [],
    existing = null,
    mode = "full",
    spotName,
    folderName = "unknown",
  }) {
    if (mode === "light" && existing) {
      console.log(
          `Skipping image processing for existing spot: ${spotName} ` +
          `(preserving existing images)`,
      );
      return {
        imageUrls: Array.isArray(existing.imageUrls) ? existing.imageUrls : [],
        imageHashes: Array.isArray(existing.imageHashes) ?
          existing.imageHashes :
          [],
        youtubeVideoIds: Array.isArray(existing.youtubeVideoIds) ?
          existing.youtubeVideoIds :
          [],
        issues: [],
      };
    }

    const urls = Array.isArray(sourceUrls) ? sourceUrls.filter(Boolean) : [];
    const issues = [];
    const uploadedImageUrls = [];
    const imageHashes = [];
    /** @type {Set<string>} resolved thumb URLs that uploaded/cached successfully */
    const successfulThumbSourceUrls = new Set();

    const urlToHashMap = new Map();
    if (
      existing &&
      Array.isArray(existing.imageUrls) &&
      Array.isArray(existing.imageHashes)
    ) {
      for (let i = 0; i < existing.imageUrls.length; i++) {
        if (existing.imageUrls[i] && existing.imageHashes[i]) {
          urlToHashMap.set(existing.imageUrls[i], existing.imageHashes[i]);
        }
      }
    }

    if (urls.length > 0) {
      console.log(`Found ${urls.length} images for spot: ${spotName}`);
    }

    for (let i = 0; i < urls.length; i++) {
      console.log(
          `Processing image ${i + 1}/${urls.length} for spot: ${spotName}`,
      );
      const result = await processOneSourceUrl(
          urls[i],
          spotName,
          i,
          urlToHashMap,
      );
      if (result) {
        uploadedImageUrls.push(result.url);
        imageHashes.push(result.hash);
        if (result.sourceUrl) {
          successfulThumbSourceUrls.add(result.sourceUrl);
        }
      }
      if (global.gc) {
        global.gc();
      }
      if (i < urls.length - 1) {
        await new Promise((resolve) => setTimeout(resolve, 100));
      }
    }

    const filteredYoutubeVideoIds = [];
    const ids = Array.isArray(youtubeVideoIds) ?
      youtubeVideoIds.filter(Boolean) :
      [];

    for (const vid of ids) {
      const thumbUrl = await resolveYoutubeThumbnailUrl(vid);
      if (!thumbUrl) {
        console.warn(
            `Dropping YouTube ID ${vid} due to missing thumbnail ` +
            `(folder: ${folderName}, spot: ${spotName})`,
        );
        issues.push({
          type: ISSUE_YOUTUBE_MISSING_THUMBNAIL,
          videoId: vid,
          spotName,
          folderName,
        });
        continue;
      }

      // Prefer success from this spot's image pass; else require imageCache hit.
      if (successfulThumbSourceUrls.has(thumbUrl)) {
        filteredYoutubeVideoIds.push(vid);
        continue;
      }

      const cachedPublicUrl = await checkImageUrlCache(thumbUrl);
      if (!cachedPublicUrl) {
        console.warn(
            `Dropping YouTube ID ${vid} due to missing/cached thumbnail: ` +
            `${thumbUrl} (folder: ${folderName}, spot: ${spotName})`,
        );
        issues.push({
          type: ISSUE_YOUTUBE_UNCACHED_THUMBNAIL,
          videoId: vid,
          spotName,
          folderName,
          thumbnailUrl: thumbUrl,
        });
        continue;
      }
      filteredYoutubeVideoIds.push(vid);
    }

    console.log(
        `Successfully processed ${uploadedImageUrls.length} images ` +
        `for spot: ${spotName}`,
    );

    return {
      imageUrls: uploadedImageUrls,
      imageHashes,
      youtubeVideoIds: filteredYoutubeVideoIds,
      issues,
    };
  }

  return {
    MAX_IMAGE_DOWNLOAD_BYTES,
    getPublicUrl,
    storageObjectExists,
    checkImageExists,
    lookupImageCache,
    checkImageUrlCache,
    cacheImageMetadata,
    downloadAndUploadImage,
    downloadAndUploadYoutubeThumbnail,
    ensureSpotImages,
    optimizeImage,
    downloadBinaryWithRedirects,
  };
}

module.exports = {
  MAX_IMAGE_DOWNLOAD_BYTES,
  storagePathFromPublicUrl,
  downloadBinaryWithRedirects,
  optimizeImage,
  createImagePipeline,
};
