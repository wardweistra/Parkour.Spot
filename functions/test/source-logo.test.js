const {
  buildSourceLogoStoragePath,
  decodeSourceLogoUpload,
  normalizeLogoContentType,
} = require("../lib/source-logo");

describe("source-logo", () => {
  it("builds stable storage paths", () => {
    expect(buildSourceLogoStoragePath("spot", "abc123", ".png"))
        .toBe("sourceLogos/spot/abc123/logo.png");
    expect(buildSourceLogoStoragePath("event", "evt-1", ".jpg"))
        .toBe("sourceLogos/event/evt-1/logo.jpg");
  });

  it("normalizes supported content types", () => {
    expect(normalizeLogoContentType("image/png")).toBe("image/png");
    expect(normalizeLogoContentType("IMAGE/JPEG; charset=binary"))
        .toBe("image/jpeg");
    expect(normalizeLogoContentType("text/plain")).toBeNull();
  });

  it("decodes base64 uploads with size guard", () => {
    const tinyPng = Buffer.from("iVBORw0KGgo=", "base64");
    const decoded = decodeSourceLogoUpload(
        tinyPng.toString("base64"),
        "image/png",
    );
    expect(decoded.contentType).toBe("image/png");
    expect(decoded.ext).toBe(".png");
    expect(decoded.imageBuffer.length).toBeGreaterThan(0);
  });
});
