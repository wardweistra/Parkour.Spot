/**
 * Check whether YouTube videos are still embeddable (public oEmbed endpoint).
 * Prefer this over thumbnail HEAD checks: removed videos often still return
 * a generic thumbnail with HTTP 200.
 */

const https = require("https");

const {hostnameMatches} = require("./url-helpers");
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
    if (hostnameMatches(host, "youtu.be")) {
      const segments = uri.pathname.split("/").filter(Boolean);
      const last = segments[segments.length - 1];
      return last && isPlausibleYoutubeVideoId(last) ? last : null;
    }
    if (hostnameMatches(host, "youtube.com")) {
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
 * @param {*} response HTTP response stream
 * @return {Promise<string>}
 */
function readResponseBody(response) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    response.on("data", (chunk) => chunks.push(chunk));
    response.on("end", () => {
      resolve(Buffer.concat(chunks).toString("utf8"));
    });
    response.on("error", reject);
  });
}

/**
 * @param {string} videoId
 * @param {Object=} options
 * @param {string=} options.userAgent
 * @param {boolean=} options.includeBody Parse oEmbed JSON for title/channel.
 * @return {Promise<Object>} availability result (and meta when includeBody)
 */
function checkYoutubeVideoOembedAvailability(videoId, options = {}) {
  const userAgent = options.userAgent || DEFAULT_USER_AGENT;
  const includeBody = options.includeBody === true;
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
          const statusCode = response.statusCode || 0;
          const finish = (extra = {}) => {
            if (statusCode === 200) {
              resolve({
                videoId,
                available: true,
                statusCode,
                reason: null,
                rateLimited: false,
                ...extra,
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
                ...extra,
              });
              return;
            }
            if (statusCode === 401 ||
                statusCode === 403 ||
                statusCode === 404) {
              resolve({
                videoId,
                available: false,
                statusCode,
                reason: "not_found_or_private",
                rateLimited: false,
                ...extra,
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
                ...extra,
              });
              return;
            }
            resolve({
              videoId,
              available: null,
              statusCode,
              reason: "unexpected_status",
              rateLimited: false,
              ...extra,
            });
          };

          if (!includeBody) {
            response.resume();
            finish();
            return;
          }

          readResponseBody(response).then((raw) => {
            let title = "";
            let channelTitle = "";
            if (statusCode === 200 && raw) {
              try {
                const parsed = JSON.parse(raw);
                title = typeof parsed.title === "string" ?
                  parsed.title.trim() :
                  "";
                channelTitle = typeof parsed.author_name === "string" ?
                  parsed.author_name.trim() :
                  "";
              } catch (_) {
                // ignore JSON parse errors
              }
            }
            finish({title, channelTitle});
          }).catch((err) => {
            finish({
              title: "",
              channelTitle: "",
              reason: err && err.message ? err.message : "body_read_error",
            });
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
        title: "",
        channelTitle: "",
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
        title: "",
        channelTitle: "",
      });
    });
  });
}

/**
 * Fetches oEmbed title + channel for [videoId].
 * @param {string} videoId
 * @param {Object=} options
 * @return {Promise<Object>} meta with title, channelTitle, available
 */
async function fetchYoutubeVideoOembedMeta(videoId, options = {}) {
  const result = await checkYoutubeVideoOembedAvailability(videoId, {
    ...options,
    includeBody: true,
  });
  return {
    videoId: result.videoId,
    title: typeof result.title === "string" ? result.title : "",
    channelTitle: typeof result.channelTitle === "string" ?
      result.channelTitle :
      "",
    available: result.available,
    rateLimited: result.rateLimited === true,
    statusCode: result.statusCode,
    reason: result.reason || null,
  };
}

/**
 * @param {string[]} videoIds
 * @param {Object=} options
 * @param {number=} options.delayMs
 * @param {number=} options.limit
 * @return {Promise<Object[]>}
 */
async function fetchYoutubeVideoOembedMetaBatch(videoIds, options = {}) {
  const delayMs = typeof options.delayMs === "number" ? options.delayMs : 200;
  const limit = typeof options.limit === "number" ? options.limit : 20;
  const unique = [];
  const seen = new Set();
  for (const raw of videoIds || []) {
    const id = normalizeYoutubeVideoId(
      typeof raw === "string" ? raw : String(raw || ""),
    );
    if (!id || seen.has(id)) continue;
    seen.add(id);
    unique.push(id);
    if (unique.length >= limit) break;
  }

  const videos = [];
  for (let i = 0; i < unique.length; i++) {
    if (i > 0 && delayMs > 0) {
      await sleep(delayMs);
    }
    const meta = await fetchYoutubeVideoOembedMeta(unique[i], options);
    if (meta.title) {
      videos.push({
        videoId: meta.videoId,
        title: meta.title,
        channelTitle: meta.channelTitle || "",
      });
    }
  }
  return videos;
}

module.exports = {
  sleep,
  normalizeYoutubeVideoId,
  checkYoutubeVideoOembedAvailability,
  fetchYoutubeVideoOembedMeta,
  fetchYoutubeVideoOembedMetaBatch,
  DEFAULT_USER_AGENT,
};
