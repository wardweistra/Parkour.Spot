/**
 * HTML → plain text helpers for imported / scraped descriptions.
 * Tag structure is handled by the parse5 HTML parser. Script and style
 * elements, including browser-forgiving end tags, are omitted with their
 * contents.
 */

const {parseFragment} = require("parse5");

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
 * Used for URL strings, which are not parsed as HTML documents.
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
 * Walk a parsed fragment and collect visible text.
 * @param {string} html
 * @param {boolean} dropNonVisible Omit script, style, and img elements.
 * @return {string}
 */
function textFromHtml(html, dropNonVisible) {
  const fragment = parseFragment(String(html));
  let out = "";
  const walk = (node) => {
    const name = node.nodeName;
    if (name === "#text") {
      out += node.value;
      return;
    }
    if (name === "br") {
      out += "\n";
      return;
    }
    if (dropNonVisible &&
        (name === "script" || name === "style" || name === "img")) {
      return;
    }
    const children = node.childNodes;
    if (!children) return;
    for (const child of children) walk(child);
  };
  walk(fragment);
  return out.replace(/\u00a0/g, " ");
}

/**
 * Convert HTML-ish description text to plain text.
 * Real script and style elements are dropped on the first parse. A second
 * parse unwraps tags that only exist because entities were decoded
 * (`&lt;b&gt;`), keeping that text.
 * @param {string} html
 * @return {string}
 */
function htmlToPlainText(html) {
  if (!html) return "";
  let text = textFromHtml(html, true);
  if (text.includes("<")) {
    text = textFromHtml(text, false);
  }
  return text
      .replace(/\n\s*\n\s*\n/g, "\n\n")
      .replace(/\n\s*\n/g, "\n\n")
      .trim();
}

module.exports = {
  decodeBasicHtmlEntities,
  htmlToPlainText,
};
