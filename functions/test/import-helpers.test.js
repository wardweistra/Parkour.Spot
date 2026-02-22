const {
  detectImportFormat,
  generateImageHash,
} = require("../lib/import-helpers");

describe("detectImportFormat", () => {
  it("returns kmz from URL", () => {
    expect(detectImportFormat(Buffer.alloc(0), "https://example.com/map.kmz")).toBe("kmz");
  });
  it("returns kml from URL", () => {
    expect(detectImportFormat(Buffer.alloc(0), "https://example.com/map.kml")).toBe("kml");
  });
  it("returns geojson from URL", () => {
    expect(detectImportFormat(Buffer.alloc(0), "https://umap.com/map/123/geojson/")).toBe("geojson");
    expect(detectImportFormat(Buffer.alloc(0), "https://example.com/data.json")).toBe("geojson");
  });
  it("detects KMZ from ZIP magic bytes", () => {
    const zipMagic = Buffer.from([0x50, 0x4b, 0x03, 0x04, 0, 0, 0, 0]);
    expect(detectImportFormat(zipMagic, "https://example.com/file")).toBe("kmz");
  });
  it("detects KML from XML content", () => {
    const xmlBuffer = Buffer.from("<kml><Document></Document></kml>", "utf8");
    expect(detectImportFormat(xmlBuffer, "https://example.com/")).toBe("kml");
  });
  it("detects GeoJSON from JSON content", () => {
    const jsonBuffer = Buffer.from("{\"type\":\"FeatureCollection\",\"features\":[]}", "utf8");
    expect(detectImportFormat(jsonBuffer, "https://example.com/")).toBe("geojson");
  });
  it("defaults to geojson for unknown", () => {
    expect(detectImportFormat(Buffer.alloc(0), "https://example.com/")).toBe("geojson");
  });
});

describe("generateImageHash", () => {
  it("returns deterministic SHA-256 hex", () => {
    const buf = Buffer.from("test");
    expect(generateImageHash(buf)).toBe(generateImageHash(buf));
    expect(generateImageHash(buf)).toMatch(/^[a-f0-9]{64}$/);
  });
});
