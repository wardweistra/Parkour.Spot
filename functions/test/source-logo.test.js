const {
  buildSourceLogoStoragePath,
  decodeSourceLogoUpload,
  normalizeLogoContentType,
  savePublicSourceLogo,
} = require("../lib/source-logo");

describe("source-logo", () => {
  it("builds stable storage paths", () => {
    expect(buildSourceLogoStoragePath("spot", "abc123", ".png"))
        .toBe("sourceLogos/spot/abc123/logo.png");
    expect(buildSourceLogoStoragePath("event", "evt-1", ".jpg"))
        .toBe("sourceLogos/event/evt-1/logo.jpg");
  });

  it("returns a cache-busted public URL after save", async () => {
    const saved = [];
    const bucket = {
      name: "test-bucket",
      file: (storagePath) => ({
        save: async (buffer, options) => {
          saved.push({storagePath, buffer, options});
        },
        makePublic: async () => {},
      }),
    };

    const url = await savePublicSourceLogo({
      bucket,
      storagePath: "sourceLogos/spot/abc/logo.png",
      imageBuffer: Buffer.from("png"),
      contentType: "image/png",
    });

    expect(saved).toHaveLength(1);
    expect(url).toMatch(
        /^https:\/\/storage\.googleapis\.com\/test-bucket\/sourceLogos\/spot\/abc\/logo\.png\?v=\d+$/,
    );
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
