/**
 * HTML → plain text helpers for imported / scraped descriptions.
 * Tag removal loops until stable so nested fragments like
 * `<scr<script>ipt>` cannot survive a single-pass strip.
 */

const NAMED_ENTITIES = {
  amp: "&",
  lt: "<",
  gt: ">",
  quot: "\"",
  apos: "'",
  nbsp: " ",
};

/**
 * Decode a small set of HTML entities in one pass.
 * @param {string} s
 * @return {string}
 */
function decodeBasicHtmlEntities(s) {
  if (!s) return "";
  return s.replace(/&(#x?[0-9a-f]+|[a-z]+);?/gi, (match, entity) => {
    const lower = String(entity).toLowerCase();
    if (Object.prototype.hasOwnProperty.call(NAMED_ENTITIES, lower)) {
      return NAMED_ENTITIES[lower];
    }
    if (lower.startsWith("#x")) {
      const code = parseInt(lower.slice(2), 16);
      return Number.isFinite(code) ? String.fromCodePoint(code) : match;
    }
    if (lower.startsWith("#")) {
      const code = parseInt(lower.slice(1), 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : match;
    }
    return match;
  });
}

/**
 * Remove HTML tags, repeating until the string no longer changes.
 * Tag names cannot contain `<`, so nested fragments like
 * `<scr<script>ipt>` become a real tag and are removed on a later pass.
 * @param {string} s
 * @return {string}
 */
function stripHtmlTags(s) {
  let previous;
  let current = s;
  do {
    previous = current;
    current = current.replace(/<\/?[a-zA-Z][a-zA-Z0-9]*\b[^<>]*>/g, "");
  } while (current !== previous);
  return current.replace(/[<>]/g, "");
}

/**
 * Convert HTML-ish description text to plain text.
 * Decode before stripping so encoded tags become removable, and strip in a
 * loop so nested incomplete tags cannot survive.
 * @param {string} html
 * @return {string}
 */
function htmlToPlainText(html) {
  if (!html) return "";
  const brToNl = (value) => value.replace(/<br\s*\/?>/gi, "\n");
  let text = brToNl(String(html));
  text = decodeBasicHtmlEntities(text);
  text = brToNl(text);
  text = text.replace(/<img\b[^>]*>/gi, "");
  text = stripHtmlTags(text);
  return text
      .replace(/\n\s*\n\s*\n/g, "\n\n")
      .replace(/\n\s*\n/g, "\n\n")
      .trim();
}

module.exports = {
  decodeBasicHtmlEntities,
  stripHtmlTags,
  htmlToPlainText,
};
