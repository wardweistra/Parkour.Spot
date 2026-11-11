/**
 * Check whether YouTube videos are still embeddable (public oEmbed endpoint).
 * Prefer this over thumbnail HEAD checks: removed videos often still return
 * a generic thumbnail with HTTP 200.
 */

const https = require("https");

const {isPlausibleYoutubeVideoId} = require("./youtube-thumbnails");

const OEMBED_BASE = "https://www.youtube.com/oembed";
const DEFAULT_USER_AGENT = "ParkourSpotAdmin/1.0 (+https://parkour.spot)";

/**
 * @param {number} ms
 * @return {Promise<void>}
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Normalizes a stored youtubeVideoIds entry (bare ID or URL) for lookups.
 * @param {string} raw
 * @return {string|null}
 */
function normalizeYoutubeVideoId(raw) {
  if (typeof raw !== "string") return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (isPlausibleYoutubeVideoId(trimmed) && !trimmed.includes("/")) {
    return trimmed;
  }
  try {
    const uri = new URL(trimmed);
    const host = uri.hostname.toLowerCase();
    if (host === "youtu.be" || host.endsWith(".youtu.be")) {
      const segments = uri.pathname.split("/").filter(Boolean);
      const last = segments[segments.length - 1];
      return last && isPlausibleYoutubeVideoId(last) ? last : null;
    }
    if (host.includes("youtube.com")) {
      const v = uri.searchParams.get("v");
      if (v && isPlausibleYoutubeVideoId(v)) return v;
      const segments = uri.pathname.split("/").filter(Boolean);
      const embedIdx = segments.indexOf("embed");
      if (embedIdx !== -1 && segments[embedIdx + 1]) {
        const id = segments[embedIdx + 1];
        return isPlausibleYoutubeVideoId(id) ? id : null;
      }
      const shortsIdx = segments.indexOf("shorts");
      if (shortsIdx !== -1 && segments[shortsIdx + 1]) {
        const id = segments[shortsIdx + 1];
        return isPlausibleYoutubeVideoId(id) ? id : null;
      }
    }
  } catch (_) {
    // not a URL
  }
  return isPlausibleYoutubeVideoId(trimmed) ? trimmed : null;
}

/**
 * @param {string} videoId
 * @param {Object=} options
 * @param {string=} options.userAgent
 * @return {Promise<Object>} availability result
 */
function checkYoutubeVideoOembedAvailability(videoId, options = {}) {
  const userAgent = options.userAgent || DEFAULT_USER_AGENT;
  const watchUrl =
    `https://www.youtube.com/watch?v=${encodeURIComponent(videoId)}`;
  const oembedUrl = new URL(OEMBED_BASE);
  oembedUrl.searchParams.set("url", watchUrl);
  oembedUrl.searchParams.set("format", "json");

  return new Promise((resolve) => {
    const request = https.get(
        oembedUrl.toString(),
        {
          headers: {
            "User-Agent": userAgent,
            "Accept": "application/json",
          },
        },
        (response) => {
          response.resume();
          const statusCode = response.statusCode || 0;
          if (statusCode === 200) {
            resolve({
              videoId,
              available: true,
              statusCode,
              reason: null,
              rateLimited: false,
            });
            return;
          }
          if (statusCode === 429) {
            resolve({
              videoId,
              available: null,
              statusCode,
              reason: "rate_limited",
              rateLimited: true,
            });
            return;
          }
          if (statusCode === 401 || statusCode === 403 || statusCode === 404) {
            resolve({
              videoId,
              available: false,
              statusCode,
              reason: "not_found_or_private",
              rateLimited: false,
            });
            return;
          }
          if (statusCode === 400) {
            resolve({
              videoId,
              available: false,
              statusCode,
              reason: "invalid_video_id",
              rateLimited: false,
            });
            return;
          }
          resolve({
            videoId,
            available: null,
            statusCode,
            reason: "unexpected_status",
            rateLimited: false,
          });
        },
    );
    request.on("error", (err) => {
      resolve({
        videoId,
        available: null,
        statusCode: 0,
        reason: err && err.message ? err.message : "network_error",
        rateLimited: false,
      });
    });
    request.setTimeout(15000, () => {
      request.destroy();
      resolve({
        videoId,
        available: null,
        statusCode: 0,
        reason: "timeout",
        rateLimited: false,
      });
    });
  });
}

module.exports = {
  sleep,
  normalizeYoutubeVideoId,
  checkYoutubeVideoOembedAvailability,
  DEFAULT_USER_AGENT,
};
