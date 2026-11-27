/* eslint-disable max-len */
/**
 * Minimal Brevo transactional email client (POST /v3/smtp/email).
 *
 * Without an API key in the Functions emulator, sends are logged and
 * reported as delivered with a `dry-run:` message id, so the queue can be
 * exercised locally without mailing anyone.
 */

const BREVO_SEND_URL = "https://api.brevo.com/v3/smtp/email";

/** Sender on the authenticated parkour.spot domain; nobody reads it. */
const DEFAULT_SENDER = Object.freeze({
  name: "Parkour·Spot",
  email: "noreply@parkour.spot",
});

/** Where replies go instead. */
const DEFAULT_REPLY_TO = Object.freeze({
  name: "Parkour·Spot",
  email: "parkour.spot@wardweistra.nl",
});

/** Error from Brevo; `retryable` for rate limits and server errors. */
class BrevoError extends Error {
  /**
   * @param {string} message
   * @param {number} status
   */
  constructor(message, status) {
    super(message);
    this.name = "BrevoError";
    this.status = status;
    this.retryable = status === 429 || status >= 500 || status === 0;
  }
}

/**
 * @param {Object} options
 * @param {string} options.apiKey
 * @param {{email: string, name: (string|undefined)}} options.to
 * @param {string} options.subject
 * @param {string} options.html
 * @param {string} options.text
 * @param {Object<string, string>=} options.headers
 * @param {string[]=} options.tags
 * @param {Object=} options.sender `{email, name}`
 * @param {Object=} options.replyTo `{email, name}`
 * @param {Function=} options.fetchImpl
 * @param {boolean=} options.isEmulator
 * @return {Promise<{messageId: string}>}
 */
async function sendBrevoEmail({
  apiKey,
  to,
  subject,
  html,
  text,
  headers = {},
  tags = [],
  sender = DEFAULT_SENDER,
  replyTo = DEFAULT_REPLY_TO,
  fetchImpl = fetch, // eslint-disable-line no-undef
  isEmulator = process.env.FUNCTIONS_EMULATOR === "true",
}) {
  if (!apiKey) {
    if (isEmulator) {
      console.log("[brevo dry-run]", {to: to.email, subject, tags});
      return {messageId: `dry-run:${Date.now()}`};
    }
    throw new BrevoError("BREVO_API_KEY is not set", 0);
  }
  const body = {
    sender,
    replyTo,
    to: [to.name ? {email: to.email, name: to.name.slice(0, 70)} : {email: to.email}],
    subject,
    htmlContent: html,
    textContent: text,
    headers,
    tags,
  };
  let response;
  try {
    response = await fetchImpl(BREVO_SEND_URL, {
      method: "POST",
      headers: {
        "api-key": apiKey,
        "content-type": "application/json",
        "accept": "application/json",
      },
      body: JSON.stringify(body),
    });
  } catch (error) {
    throw new BrevoError(`Brevo request failed: ${error.message}`, 0);
  }
  const raw = await response.text();
  let json = {};
  try {
    json = raw ? JSON.parse(raw) : {};
  } catch (_) {
    // Keep the raw text for the error below.
  }
  if (!response.ok) {
    const detail = json.message || json.code || raw || response.statusText;
    throw new BrevoError(`Brevo ${response.status}: ${detail}`, response.status);
  }
  const messageId = json.messageId ||
    (Array.isArray(json.messageIds) ? json.messageIds[0] : "") || "";
  return {messageId};
}

module.exports = {
  BREVO_SEND_URL,
  DEFAULT_SENDER,
  DEFAULT_REPLY_TO,
  BrevoError,
  sendBrevoEmail,
};
