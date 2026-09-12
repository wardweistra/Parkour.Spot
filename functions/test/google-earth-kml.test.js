const fs = require("fs");
const path = require("path");
const {
  buildGoogleEarthImageUrlCandidates,
  resolveGoogleEarthImageUrl,
} = require("../lib/google-earth-images");
const {
  parseKmlPlacemarks,
  parseKmlTopLevelFolders,
} = require("../lib/kml-parser");
const {getEffectiveSpotAttributeDefaults} = require("../lib/spot-attributes");
const {extractImageUrls} = require("../lib/text-processing");

const sampleKmlPath = path.join(__dirname, "fixtures/seattle_pk_atlas_sample.kml");

describe("google-earth-images", () => {
  it("resolves {size} placeholder to original size", () => {
    const template =
      "https://earth.usercontent.google.com/hostedimage/e/*/abc?authuser=0&fife=s{size}";
    expect(resolveGoogleEarthImageUrl(template)).toBe(
        "https://earth.usercontent.google.com/hostedimage/e/*/abc?authuser=0&fife=s0",
    );
  });

  it("builds candidates largest first", () => {
    const template =
      "https://earth.usercontent.google.com/example?fife=s{size}";
    const candidates = buildGoogleEarthImageUrlCandidates(template);
    expect(candidates[0]).toContain("fife=s0");
    expect(candidates.some((url) => url.includes("fife=s2048"))).toBe(true);
  });
});

describe("kml-parser Google Earth sample", () => {
  let kmlContent;

  beforeAll(() => {
    kmlContent = fs.readFileSync(sampleKmlPath, "utf8");
  });

  it("lists top-level folders", async () => {
    const folders = await parseKmlTopLevelFolders(kmlContent);
    expect(folders).toEqual(
        expect.arrayContaining(["Spots", "Gyms", "Ballard"]),
    );
  });

  it("extracts placemarks with folder paths and external ids", async () => {
    const placemarks = await parseKmlPlacemarks(kmlContent);
    expect(placemarks.length).toBeGreaterThan(0);

    const portageBay = placemarks.find(
        (p) => p.name === "Portage Bay Parking Garage",
    );
    expect(portageBay).toBeDefined();
    expect(portageBay.folderPath[0]).toBe("Spots");
    expect(portageBay.externalId).toBe("07DFCA5DC6236774047C");
    expect(portageBay.imageUrls?.length).toBeGreaterThan(0);
    expect(portageBay.imageUrls[0]).toContain("fife=s0");
  });

  it("extracts multiple carousel images", () => {
    const xmlSnippet = `
      <Placemark id="test-id">
        <name>Sample</name>
        <gx:Carousel>
          <gx:Image>
            <gx:imageUrl>https://earth.usercontent.google.com/a?fife=s{size}</gx:imageUrl>
          </gx:Image>
          <gx:Image>
            <gx:imageUrl>https://earth.usercontent.google.com/b?fife=s{size}</gx:imageUrl>
          </gx:Image>
        </gx:Carousel>
        <Point><coordinates>0,0,0</coordinates></Point>
      </Placemark>`;
    return parseKmlPlacemarks(`<kml xmlns:gx="http://www.google.com/kml/ext/2.2"><Document>${xmlSnippet}</Document></kml>`)
        .then((placemarks) => {
          expect(placemarks).toHaveLength(1);
          expect(placemarks[0].imageUrls).toHaveLength(2);
        });
  });
});

describe("spot attribute defaults with folder path", () => {
  it("applies top-level folder defaults to nested placemarks", () => {
    const lookup = {
      gyms: {spotFacilities: {covered: "yes"}},
    };
    const defaults = getEffectiveSpotAttributeDefaults(
        null,
        lookup,
        "University of Washington",
        ["Gyms", "University of Washington"],
    );
    expect(defaults.spotFacilities.covered).toBe("yes");
  });
});

describe("extractImageUrls Google Earth", () => {
  it("accepts explicit resolved Google Earth image URLs", () => {
    const urls = extractImageUrls({
      imageUrls: [
        "https://earth.usercontent.google.com/hostedimage/e/*/abc?fife=s0",
      ],
    });
    expect(urls).toHaveLength(1);
    expect(urls[0]).toContain("earth.usercontent.google.com");
  });
});
