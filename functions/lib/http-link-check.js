/**
 * Lightweight HTTP reachability checks for admin outgoing-link scans.
 */

const http = require("http");
const https = require("https");
const {URL} = require("url");

const DEFAULT_USER_AGENT =
  "ParkourSpotLinkCheck/1.0 (+https://parkour.spot)";
const DEFAULT_TIMEOUT_MS = 15000;
const MAX_REDIRECTS = 5;

/**
 * @param {number} ms
 * @return {Promise<void>}
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Normalizes a stored URL for deduplicated checks.
 * @param {string} raw
 * @return {string|null}
 */
function normalizeHttpUrl(raw) {
  if (typeof raw !== "string") return null;
  const trimmed = raw.trim();
  if (!trimmed) return null;
  let candidate = trimmed;
  if (!/^[a-zA-Z][a-zA-Z\d+\-.]*:/.test(candidate)) {
    candidate = `https://${candidate}`;
  }
  let parsed;
  try {
    parsed = new URL(candidate);
  } catch (_) {
    return null;
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
    return null;
  }
  const host = parsed.hostname.toLowerCase();
  if (host === "localhost" || host === "127.0.0.1") {
    return null;
  }
  return parsed.toString();
}

/**
 * @param {string} method
 * @param {string} url
 * @param {Object} options
 * @return {Promise<{statusCode: number, rateLimited: boolean}>}
 */
function requestStatus(method, url, options) {
  const userAgent = options.userAgent || DEFAULT_USER_AGENT;
  const timeoutMs = options.timeoutMs || DEFAULT_TIMEOUT_MS;
  let parsed;
  try {
    parsed = new URL(url);
  } catch (_) {
    return Promise.resolve({
      statusCode: 0,
      rateLimited: false,
      invalid: true,
    });
  }
  const client = parsed.protocol === "http:" ? http : https;

  return new Promise((resolve) => {
    const req = client.request(
        parsed,
        {
          method,
          headers: {
            "User-Agent": userAgent,
            "Accept": "*/*",
          },
        },
        (response) => {
          response.resume();
          const statusCode = response.statusCode || 0;
          const location = response.headers.location || null;
          resolve({
            statusCode,
            location,
            rateLimited: statusCode === 429,
          });
        },
    );
    req.on("error", () => {
      resolve({statusCode: 0, rateLimited: false});
    });
    req.setTimeout(timeoutMs, () => {
      req.destroy();
      resolve({statusCode: 0, rateLimited: false, timeout: true});
    });
    req.end();
  });
}

/**
 * Follows redirects for HEAD/GET until a final status or redirect cap.
 * @param {string} method
 * @param {string} url
 * @param {number} redirectCount
 * @param {Object} options
 * @return {Promise<Object>}
 */
async function requestStatusWithRedirects(
    method,
    url,
    redirectCount,
    options,
) {
  if (redirectCount > MAX_REDIRECTS) {
    return {
      statusCode: 0,
      reason: "too_many_redirects",
      rateLimited: false,
      reachable: null,
    };
  }

  const result = await requestStatus(method, url, options);
  if (result.invalid) {
    return {
      url,
      statusCode: 0,
      reason: "invalid_url",
      rateLimited: false,
      reachable: false,
    };
  }

  const statusCode = result.statusCode;
  if (statusCode >= 300 && statusCode < 400) {
    if (!result.location) {
      return {
        url,
        statusCode,
        reason: "redirect_without_location",
        rateLimited: false,
        reachable: null,
      };
    }
    let baseUrl;
    try {
      baseUrl = new URL(url);
    } catch (_) {
      return {
        url,
        statusCode,
        reason: "invalid_url",
        rateLimited: false,
        reachable: false,
      };
    }
    const nextUrl = new URL(result.location, baseUrl).toString();
    return requestStatusWithRedirects(
        method,
        nextUrl,
        redirectCount + 1,
        options,
    );
  }

  if (result.rateLimited) {
    return {
      url,
      statusCode,
      reason: "rate_limited",
      rateLimited: true,
      reachable: null,
    };
  }

  if (
    method === "HEAD" &&
    (statusCode === 405 || statusCode === 501)
  ) {
    return requestStatusWithRedirects("GET", url, redirectCount, options);
  }

  const reachable = statusCode >= 200 && statusCode < 400;
  let reason = null;
  if (statusCode === 0) {
    reason = result.timeout ? "timeout" : "network_error";
  } else if (statusCode === 404 || statusCode === 410) {
    reason = "not_found";
  } else if (statusCode === 401 || statusCode === 403) {
    reason = "forbidden_to_checker";
  } else if (statusCode >= 500) {
    reason = "server_error";
  } else if (!reachable) {
    reason = "http_error";
  }

  return {
    url,
    statusCode,
    reason,
    rateLimited: false,
    reachable: statusCode === 401 || statusCode === 403 ?
      null :
      reachable,
  };
}

/**
 * HEAD-first reachability check with GET fallback when HEAD is unsupported.
 * @param {string} rawUrl
 * @param {Object=} options
 * @return {Promise<Object>}
 */
async function checkHttpUrlReachable(rawUrl, options = {}) {
  const normalized = normalizeHttpUrl(rawUrl);
  if (!normalized) {
    return {
      url: rawUrl,
      normalizedUrl: null,
      statusCode: 0,
      reason: "invalid_url",
      rateLimited: false,
      reachable: false,
    };
  }

  const head = await requestStatusWithRedirects(
      "HEAD",
      normalized,
      0,
      options,
  );
  return {
    ...head,
    normalizedUrl: normalized,
  };
}

/**
 * Maps check result to cache status string.
 * @param {Object} result
 * @return {string}
 */
function cacheStatusFromCheckResult(result) {
  if (result.rateLimited) return "rate_limited";
  if (result.reachable === true) return "ok";
  if (result.reachable === false) return "broken";
  if (result.reason === "forbidden_to_checker") return "blocked";
  return "unknown";
}

/**
 * True when an event is current or upcoming (by end or start).
 * @param {Object} data Firestore event fields
 * @param {Date} now
 * @return {boolean}
 */
function eventIsCurrentOrUpcoming(data, now) {
  if (!data || !data.startAt) return false;
  const toDate = (value) => {
    if (!value) return null;
    if (typeof value.toDate === "function") return value.toDate();
    const d = new Date(value);
    return Number.isNaN(d.getTime()) ? null : d;
  };
  const start = toDate(data.startAt);
  if (!start) return false;
  const end = toDate(data.endAt) || start;
  return end.getTime() >= now.getTime();
}

/**
 * Collects outgoing http(s) links from an event document.
 * @param {string} eventId
 * @param {Object} data
 * @return {Array<Object>}
 */
function collectEventOutgoingLinks(eventId, data) {
  const links = [];
  const website = data && data.websiteUrl;
  if (typeof website === "string" && website.trim()) {
    links.push({
      entityType: "event",
      entityId: eventId,
      entityName:
        typeof data.title === "string" && data.title.trim() ?
          data.title.trim() :
          "Unnamed event",
      field: "websiteUrl",
      rawUrl: website.trim(),
    });
  }
  return links;
}

/**
 * Collects outgoing http(s) links from a spot list document.
 * @param {string} listId
 * @param {Object} data
 * @return {Array<Object>}
 */
function collectSpotListOutgoingLinks(listId, data) {
  const links = [];
  const moreInfo = data && data.moreInfoUrl;
  const name =
    typeof data.name === "string" && data.name.trim() ?
      data.name.trim() :
      "Unnamed list";
  if (typeof moreInfo === "string" && moreInfo.trim()) {
    links.push({
      entityType: "spotList",
      entityId: listId,
      entityName: name,
      field: "moreInfoUrl",
      rawUrl: moreInfo.trim(),
    });
  }
  return links;
}

module.exports = {
  sleep,
  normalizeHttpUrl,
  checkHttpUrlReachable,
  cacheStatusFromCheckResult,
  eventIsCurrentOrUpcoming,
  collectEventOutgoingLinks,
  collectSpotListOutgoingLinks,
  DEFAULT_USER_AGENT,
};
