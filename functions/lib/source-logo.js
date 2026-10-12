/* eslint-disable max-len */
/**
 * Public source logos for spot sync sources and event sync sources.
 */

const MAX_SOURCE_LOGO_BYTES = 2 * 1024 * 1024;

const EXT_BY_CONTENT_TYPE = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
  "image/gif": ".gif",
};

/**
 * @param {*} value
 * @return {string|null}
 */
function trimOrNull(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

/**
 * @param {*} contentType
 * @return {string|null}
 */
function normalizeLogoContentType(contentType) {
  const trimmed = trimOrNull(contentType);
  if (!trimmed) return null;
  const normalized = trimmed.toLowerCase().split(";")[0].trim();
  return EXT_BY_CONTENT_TYPE[normalized] ? normalized : null;
}

/**
 * @param {"spot"|"event"} kind
 * @param {string} sourceId
 * @param {string} ext
 * @return {string}
 */
function buildSourceLogoStoragePath(kind, sourceId, ext) {
  const safeId = String(sourceId).trim();
  if (!safeId) {
    throw new Error("sourceId is required");
  }
  if (kind !== "spot" && kind !== "event") {
    throw new Error("kind must be spot or event");
  }
  return `sourceLogos/${kind}/${safeId}/logo${ext}`;
}

/**
 * @param {import("@google-cloud/storage").Bucket} bucket
 * @param {string} storagePath
 * @param {Buffer} imageBuffer
 * @param {string} contentType
 * @return {Promise<string>}
 */
async function savePublicSourceLogo({bucket, storagePath, imageBuffer, contentType}) {
  const file = bucket.file(storagePath);
  await file.save(imageBuffer, {
    metadata: {
      contentType,
      cacheControl: "public, max-age=31536000",
    },
  });
  await file.makePublic();
  return `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
}

/**
 * @param {import("@google-cloud/storage").Bucket} bucket
 * @param {string|null|undefined} storagePath
 * @return {Promise<void>}
 */
async function deleteSourceLogoAtPath(bucket, storagePath) {
  const trimmed = trimOrNull(storagePath);
  if (!trimmed) return;
  try {
    await bucket.file(trimmed).delete({ignoreNotFound: true});
  } catch (error) {
    console.warn(`Failed to delete source logo at ${trimmed}:`, error);
  }
}

/**
 * @param {*} imageData Base64-encoded image bytes.
 * @param {*} contentType
 * @return {{imageBuffer: Buffer, contentType: string, ext: string}}
 */
function decodeSourceLogoUpload(imageData, contentType) {
  if (typeof imageData !== "string" || imageData.trim().length === 0) {
    throw new Error("imageData is required");
  }
  const normalizedContentType = normalizeLogoContentType(contentType) ||
    "image/jpeg";
  const ext = EXT_BY_CONTENT_TYPE[normalizedContentType];
  const imageBuffer = Buffer.from(imageData, "base64");
  if (!imageBuffer.length) {
    throw new Error("Uploaded logo is empty");
  }
  if (imageBuffer.length > MAX_SOURCE_LOGO_BYTES) {
    throw new Error("Uploaded logo exceeds 2 MB limit");
  }
  return {imageBuffer, contentType: normalizedContentType, ext};
}

module.exports = {
  MAX_SOURCE_LOGO_BYTES,
  buildSourceLogoStoragePath,
  savePublicSourceLogo,
  deleteSourceLogoAtPath,
  decodeSourceLogoUpload,
  normalizeLogoContentType,
  trimOrNull,
};
