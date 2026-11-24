/**
 * Shared HTTP(S) text download helper for event-sync feeds.
 *
 * Google Calendar public ICS feeds frequently return HTTP 429 to cloud
 * provider IPs. Retries with backoff (and Retry-After) make those syncs
 * resilient without changing caller code.
 *
 * Some site firewalls instead drop the connection for browser-like UAs that
 * don't look like a real browser. When a connection-level failure happens with
 * the browser-like UA, the next attempt switches to a plain bot UA. Others
 * answer such UAs with a small 200 block page; callers can pass
 * `validateBody` so an unexpected body also triggers the fallback UA.
 */

const http = require("http");
const https = require("https");

// Browser-like UA: calendar.google.com rate-limits opaque bot agents harder
// from Cloud Functions egress IPs.
const USER_AGENT =
  "Mozilla/5.0 (compatible; ParkourSpotEventSync/1.2; +https://parkour.spot) " +
  "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/142.0.0.0 Safari/537.36";

// Plain bot UA, used after the browser-like UA gets its connection dropped
// (e.g. monkeybizparkour.com's nginx resets the stream for USER_AGENT).
const FALLBACK_USER_AGENT =
  "ParkourSpotEventSync/1.2 (+https://parkour.spot)";

const DEFAULT_ACCEPT =
  "text/calendar, application/calendar+json, application/json, " +
  "text/plain, */*";

const DEFAULT_MAX_ATTEMPTS = 4;
const DEFAULT_TIMEOUT_MS = 20000;
const DEFAULT_BASE_DELAY_MS = 1500;
const DEFAULT_MAX_DELAY_MS = 20000;

/**
 * @param {number} ms
 * @return {Promise<void>}
 */
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * @param {*} value
 * @param {number} attempt 1-based
 * @param {number} baseDelayMs
 * @param {number} maxDelayMs
 * @return {number}
 */
function resolveRetryDelayMs(value, attempt, baseDelayMs, maxDelayMs) {
  if (typeof value === "string" && value.trim()) {
    const asSeconds = Number(value);
    if (Number.isFinite(asSeconds) && asSeconds >= 0) {
      return Math.min(Math.round(asSeconds * 1000), maxDelayMs);
    }
    const asDate = Date.parse(value);
    if (Number.isFinite(asDate)) {
      const fromHeader = asDate - Date.now();
      if (fromHeader > 0) return Math.min(fromHeader, maxDelayMs);
    }
  }
  const exponential = baseDelayMs * Math.pow(2, Math.max(0, attempt - 1));
  const jitter = Math.floor(Math.random() * 250);
  return Math.min(exponential + jitter, maxDelayMs);
}

/**
 * @param {number} statusCode
 * @return {boolean}
 */
function isRetryableStatus(statusCode) {
  return statusCode === 429 || statusCode === 502 ||
    statusCode === 503 || statusCode === 504;
}

/**
 * Downloads text content once and follows redirects.
 * @param {string} url
 * @param {Object=} options
 * @param {Object<string, string>=} options.headers
 * @param {number=} options.redirectCount
 * @param {number=} options.timeoutMs
 * @param {string=} options.userAgent
 * @return {Promise<{body: string, statusCode: number,
 *   headers: Object<string, string|string[]|undefined>}>}
 */
function downloadTextOnce(url, options = {}) {
  const redirectCount = typeof options.redirectCount === "number" ?
    options.redirectCount :
    0;
  /** @type {Object<string, string>} */
  const extraHeaders =
    options.headers && typeof options.headers === "object" ?
      options.headers :
      {};
  const timeoutMs = typeof options.timeoutMs === "number" ?
    options.timeoutMs :
    DEFAULT_TIMEOUT_MS;
  const userAgent = typeof options.userAgent === "string" &&
    options.userAgent ?
    options.userAgent :
    USER_AGENT;

  if (redirectCount > 5) {
    return Promise.reject(new Error("Too many redirects while fetching ICS"));
  }

  let parsedUrl;
  try {
    parsedUrl = new URL(url);
  } catch (error) {
    return Promise.reject(new Error("ICS URL must be a valid URL"));
  }
  if (parsedUrl.protocol !== "https:" && parsedUrl.protocol !== "http:") {
    return Promise.reject(new Error("ICS URL must use http or https"));
  }
  const client = parsedUrl.protocol === "http:" ? http : https;

  return new Promise((resolve, reject) => {
    const request = client.get(parsedUrl, {
      headers: {
        "User-Agent": userAgent,
        "Accept": DEFAULT_ACCEPT,
        "Accept-Language": "en-US,en;q=0.9",
        ...extraHeaders,
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
        resolve(downloadTextOnce(redirectedUrl, {
          redirectCount: redirectCount + 1,
          headers: extraHeaders,
          timeoutMs,
          userAgent,
        }));
        return;
      }

      const statusCode = response.statusCode || 0;
      if (statusCode >= 400) {
        response.resume();
        const error = new Error(`Failed fetching ICS (HTTP ${statusCode})`);
        error.statusCode = statusCode;
        error.retryAfter = response.headers["retry-after"];
        reject(error);
        return;
      }

      let body = "";
      response.setEncoding("utf8");
      response.on("data", (chunk) => {
        body += chunk;
      });
      response.on("end", () => {
        resolve({
          body,
          statusCode,
          headers: response.headers,
        });
      });
    });

    request.on("error", reject);
    request.setTimeout(timeoutMs, () => {
      request.destroy(new Error("ICS request timed out"));
    });
  });
}

const INVALID_BODY_CODE = "INVALID_BODY";

/**
 * @param {string} body
 * @param {string} userAgent
 * @return {Error}
 */
function invalidBodyError(body, userAgent) {
  const text = typeof body === "string" ? body : "";
  const snippet = text.replace(/\s+/g, " ").trim().slice(0, 200);
  const error = new Error(
      `Unexpected feed response (${text.length} bytes, ` +
      `UA ${userAgent === FALLBACK_USER_AGENT ? "fallback" : "browser"}): ` +
      (snippet || "<empty>"),
  );
  error.code = INVALID_BODY_CODE;
  return error;
}

/**
 * Whether an ICS download looks like an actual calendar.
 * @param {string} body
 * @return {boolean}
 */
function looksLikeIcs(body) {
  return typeof body === "string" && /BEGIN:VCALENDAR/i.test(body);
}

/**
 * Whether an error is a connection-level failure (no HTTP response), which
 * can mean a firewall dropped the request based on its User-Agent.
 * @param {*} error
 * @return {boolean}
 */
function isConnectionFailure(error) {
  if (!error || typeof error.statusCode === "number") return false;
  const message = error.message ? String(error.message) : "";
  const code = error.code ? String(error.code) : "";
  return message.includes("socket hang up") ||
    message.includes("timed out") ||
    message.includes("ECONNRESET") ||
    message.includes("ETIMEDOUT") ||
    code === "ECONNRESET" ||
    code === "ETIMEDOUT";
}

/**
 * Downloads text content with retries for transient failures (429/5xx).
 * @param {string} url
 * @param {Object|number=} options Or legacy redirectCount number.
 * @param {Object<string, string>=} options.headers
 * @param {number=} options.redirectCount
 * @param {number=} options.maxAttempts
 * @param {number=} options.timeoutMs
 * @param {number=} options.baseDelayMs
 * @param {number=} options.maxDelayMs
 * @param {function(string): boolean=} options.validateBody Returns false
 *   when the body is not the expected content (e.g. a firewall block page).
 *   That retries once with the fallback UA, then throws.
 * @param {Function=} options.downloadOnceFn Injectable for tests
 * @param {Function=} options.sleepFn Injectable for tests
 * @return {Promise<string>}
 */
async function downloadTextFromUrl(url, options = {}) {
  /** @type {Object} */
  let normalized = {};
  if (typeof options === "number") {
    normalized = {redirectCount: options};
  } else if (options && typeof options === "object") {
    normalized = options;
  }

  const maxAttempts = typeof normalized.maxAttempts === "number" ?
    normalized.maxAttempts :
    DEFAULT_MAX_ATTEMPTS;
  const baseDelayMs = typeof normalized.baseDelayMs === "number" ?
    normalized.baseDelayMs :
    DEFAULT_BASE_DELAY_MS;
  const maxDelayMs = typeof normalized.maxDelayMs === "number" ?
    normalized.maxDelayMs :
    DEFAULT_MAX_DELAY_MS;
  const downloadOnceFn = normalized.downloadOnceFn || downloadTextOnce;
  const sleepFn = normalized.sleepFn || sleep;

  let userAgent = USER_AGENT;
  let lastError = null;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      const result = await downloadOnceFn(url, {
        headers: normalized.headers,
        redirectCount: normalized.redirectCount,
        timeoutMs: normalized.timeoutMs,
        userAgent,
      });
      const body = typeof result === "string" ? result : result.body;
      if (
        typeof normalized.validateBody === "function" &&
        !normalized.validateBody(body)
      ) {
        throw invalidBodyError(body, userAgent);
      }
      return body;
    } catch (error) {
      if (error && error.code === INVALID_BODY_CODE) {
        lastError = error;
        if (userAgent !== FALLBACK_USER_AGENT && attempt < maxAttempts) {
          userAgent = FALLBACK_USER_AGENT;
          continue;
        }
        break;
      }
      lastError = error;
      const statusCode = error && typeof error.statusCode === "number" ?
        error.statusCode :
        0;
      const connectionFailure = isConnectionFailure(error);
      const retryable = isRetryableStatus(statusCode) || connectionFailure;
      if (!retryable || attempt === maxAttempts) {
        break;
      }
      if (connectionFailure && userAgent !== FALLBACK_USER_AGENT) {
        // Likely a UA-based block: retry right away with the plain bot UA.
        userAgent = FALLBACK_USER_AGENT;
        continue;
      }
      const delayMs = resolveRetryDelayMs(
          error && error.retryAfter,
          attempt,
          baseDelayMs,
          maxDelayMs,
      );
      await sleepFn(delayMs);
    }
  }

  throw lastError || new Error("Failed fetching ICS");
}

module.exports = {
  USER_AGENT,
  FALLBACK_USER_AGENT,
  DEFAULT_ACCEPT,
  DEFAULT_MAX_ATTEMPTS,
  downloadTextOnce,
  downloadTextFromUrl,
  resolveRetryDelayMs,
  isRetryableStatus,
  isConnectionFailure,
  looksLikeIcs,
};
