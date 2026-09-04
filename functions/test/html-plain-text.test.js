const {
  decodeBasicHtmlEntities,
  stripHtmlTags,
  htmlToPlainText,
} = require("../lib/html-plain-text");

describe("stripHtmlTags", () => {
  it("removes nested incomplete tags", () => {
    expect(stripHtmlTags("<scr<script>ipt>alert(1)</script>")).toBe("alert(1)");
  });
});

describe("decodeBasicHtmlEntities", () => {
  it("decodes common named and numeric entities", () => {
    expect(decodeBasicHtmlEntities("A&amp;B&lt;C&#39;")).toBe("A&B<C'");
  });
});

describe("htmlToPlainText", () => {
  it("converts br, strips tags, and decodes entities", () => {
    expect(htmlToPlainText("A<br>B <b>x</b> &amp; y")).toBe("A\nB x & y");
  });
  it("strips tags that only appear after entity decode", () => {
    expect(htmlToPlainText("&lt;script&gt;x&lt;/script&gt;")).toBe("x");
  });
});
