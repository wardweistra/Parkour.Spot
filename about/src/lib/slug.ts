/**
 * Mirrors functions/utils.js slugify / normalizeToAscii.
 * Keep in sync when changing URL slug rules.
 */

const REPLACEMENTS: Record<string, string> = {
  à: "a",
  á: "a",
  â: "a",
  ã: "a",
  ä: "a",
  å: "a",
  À: "A",
  Á: "A",
  Â: "A",
  Ã: "A",
  Ä: "A",
  Å: "A",
  è: "e",
  é: "e",
  ê: "e",
  ë: "e",
  È: "E",
  É: "E",
  Ê: "E",
  Ë: "E",
  ì: "i",
  í: "i",
  î: "i",
  ï: "i",
  Ì: "I",
  Í: "I",
  Î: "I",
  Ï: "I",
  ò: "o",
  ó: "o",
  ô: "o",
  õ: "o",
  ö: "o",
  Ò: "O",
  Ó: "O",
  Ô: "O",
  Õ: "O",
  Ö: "O",
  ù: "u",
  ú: "u",
  û: "u",
  ü: "u",
  Ù: "U",
  Ú: "U",
  Û: "U",
  Ü: "U",
  ý: "y",
  ÿ: "y",
  Ý: "Y",
  Ÿ: "Y",
  ñ: "n",
  Ñ: "N",
  ç: "c",
  Ç: "C",
  ß: "ss",
};

export function normalizeToAscii(input: string): string {
  let result = input;
  for (const [char, replacement] of Object.entries(REPLACEMENTS)) {
    result = result.split(char).join(replacement);
  }
  return result;
}

export function slugify(input: string): string {
  const normalized = normalizeToAscii(input);
  const lowered = normalized.toLowerCase();
  return lowered
    .replace(/[^a-z0-9\s-_]/g, "")
    .replace(/[\s_]+/g, "-");
}

/** About-site event slug: slugify(title) + short id suffix. */
export function eventSlug(title: string, eventId: string): string {
  const base = slugify(title || "event").replace(/^-+|-+$/g, "") || "event";
  const suffix = String(eventId).slice(0, 8).toLowerCase();
  return `${base}-${suffix}`;
}
