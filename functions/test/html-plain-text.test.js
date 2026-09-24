const {
  decodeBasicHtmlEntities,
  stripHtmlTags,
  stripStyleAndScriptBlocks,
  htmlToPlainText,
} = require("../lib/html-plain-text");

describe("stripHtmlTags", () => {
  it("removes nested incomplete tags", () => {
    expect(stripHtmlTags("<scr<script>ipt>alert(1)</script>")).toBe("alert(1)");
  });
});

describe("stripStyleAndScriptBlocks", () => {
  it("removes blocks whose end tags have spaces before >", () => {
    expect(stripStyleAndScriptBlocks(
        "A<style>x</style >B<script>y</script >C",
    )).toBe("ABC");
  });
  it("drops nested incomplete script fragments across passes", () => {
    expect(stripStyleAndScriptBlocks(
        "keep<scr<script>ipt>evil()</script>end",
    )).toBe("keep<scrend");
  });
  it("drops nested incomplete style fragments across passes", () => {
    expect(stripStyleAndScriptBlocks(
        "keep<sty<style>le>evil{}</style>end",
    )).toBe("keep<styend");
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
  it("drops style and script block contents", () => {
    expect(htmlToPlainText(
        "<p>Hello</p><style>#block-x{color:red}</style><script>alert(1)</script>",
    )).toBe("Hello");
  });
  it("drops script blocks with spaced end tags", () => {
    expect(htmlToPlainText(
        "<p>Hi</p><script type=\"text/javascript\">alert(1)</script >",
    )).toBe("Hi");
  });
  it("drops nested script/style content before tag strip", () => {
    // Incomplete wrappers may leave harmless letter crumbs after <> removal.
    expect(htmlToPlainText(
        "<p>Hi</p><scr<script>ipt>evil()</script><sty<style>le>x{}</style>",
    )).toBe("Hiscrsty");
  });
});
