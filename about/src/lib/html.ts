import {BRAND_SEP} from "./brand";

/** Escape text for HTML attribute values; middot uses &#183; for legacy crawlers. */
export function escapeHtmlAttr(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;")
    .replaceAll(BRAND_SEP, "&#183;");
}
