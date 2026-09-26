const {
  decodeBasicHtmlEntities,
  htmlToPlainText,
} = require("../lib/html-plain-text");

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
  it("drops script and style blocks whose end tags contain junk before >", () => {
    expect(htmlToPlainText(
        "A<script>alert(1)</script\t\n bar>B<style>x{}</style\t\n bar>C",
    )).toBe("ABC");
  });
  it("does not keep a script element from nested incomplete tags", () => {
    const text = htmlToPlainText(
        "<p>Hi</p><scr<script>ipt>evil()</script><sty<style>le>x{}</style>",
    );
    expect(text.includes("<script")).toBe(false);
    expect(text.includes("<style")).toBe(false);
    expect(text.startsWith("Hi")).toBe(true);
  });
});
