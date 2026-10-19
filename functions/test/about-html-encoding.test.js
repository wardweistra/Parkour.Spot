/** Keep in sync with about/src/lib/html.ts */
function escapeHtmlAttr(value) {
  const BRAND_SEP = "\u00b7";
  return value
      .replace(/&/g, "&amp;")
      .replace(/"/g, "&quot;")
      .replace(/</g, "&lt;")
      .replaceAll(BRAND_SEP, "&#183;");
}

describe("about html encoding", () => {
  it("uses numeric entities for brand middot in attributes", () => {
    expect(escapeHtmlAttr("About Parkour·Spot")).toBe(
        "About Parkour&#183;Spot",
    );
  });

  it("escapes quotes and ampersands", () => {
    expect(escapeHtmlAttr("Tom & Jerry \"wall\"")).toBe(
        "Tom &amp; Jerry &quot;wall&quot;",
    );
  });
});
