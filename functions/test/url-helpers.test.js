const {
  extractSpotIdFromPath,
  extractFilename,
  getResizedImageUrlForApi,
  getResizedPathInfo,
  getImageContentTypeForPath,
  isEphemeralImageHost,
  hostnameMatches,
  isFirebaseStorageUrl,
  isGoogleUserContentUrl,
} = require("../lib/url-helpers");

describe("extractSpotIdFromPath", () => {
  it("extracts spotId from /cc/city/spotId path", () => {
    expect(extractSpotIdFromPath("/nl/amsterdam/abc123")).toBe("abc123");
    expect(extractSpotIdFromPath("/gb/london/xyz789")).toBe("xyz789");
    expect(extractSpotIdFromPath("/US/new-york/spot1")).toBe("spot1");
  });
  it("extracts spotId from /spot/spotId path", () => {
    expect(extractSpotIdFromPath("/spot/xyz789")).toBe("xyz789");
    expect(extractSpotIdFromPath("/spot/abc123")).toBe("abc123");
  });
  it("returns null for non-matching paths", () => {
    expect(extractSpotIdFromPath("/explore")).toBeNull();
    expect(extractSpotIdFromPath("/")).toBeNull();
    expect(extractSpotIdFromPath("/nl")).toBeNull();
    expect(extractSpotIdFromPath("/nl/amsterdam")).toBeNull();
    expect(extractSpotIdFromPath("/nl/amsterdam/")).toBeNull();
  });
});

describe("extractFilename", () => {
  it("extracts filename from firebasestorage URLs with encoded path", () => {
    const url = "https://firebasestorage.googleapis.com/v0/b/bucket/o/spots%2Fimage.jpg";
    expect(extractFilename(url)).toBe("image.jpg");
  });
  it("extracts filename from storage.googleapis URLs", () => {
    const url = "https://storage.googleapis.com/bucket/spots/photo.png";
    expect(extractFilename(url)).toBe("photo.png");
  });
  it("removes query params in fallback", () => {
    const url = "https://example.com/path/to/file.jpg?token=abc";
    expect(extractFilename(url)).toBe("file.jpg");
  });
});

describe("getResizedImageUrlForApi", () => {
  it("returns original for non-Firebase URLs", () => {
    const url = "https://example.com/image.jpg";
    expect(getResizedImageUrlForApi(url)).toBe(url);
  });
  it("converts firebasestorage spots URL to resized", () => {
    const url = "https://firebasestorage.googleapis.com/v0/b/bucket/o/spots%2Fphoto.jpg";
    expect(getResizedImageUrlForApi(url)).toContain("spots%2Fresized%2Fphoto_1200x1200.webp");
  });
  it("converts storage.googleapis spots URL to resized", () => {
    const url = "https://storage.googleapis.com/bucket/spots/photo.png";
    expect(getResizedImageUrlForApi(url)).toContain("/spots/resized/photo_1200x1200.webp");
  });
  it("returns original if already resized", () => {
    const url = "https://storage.googleapis.com/bucket/spots/resized/photo_1200x1200.webp";
    expect(getResizedImageUrlForApi(url)).toBe(url);
  });
  it("returns original for non-string input", () => {
    expect(getResizedImageUrlForApi(null)).toBeNull();
  });
  it("converts firebasestorage events URL to resized", () => {
    const url = "https://firebasestorage.googleapis.com/v0/b/bucket/o/events%2Fphoto.jpg";
    expect(getResizedImageUrlForApi(url)).toContain("events%2Fresized%2Fphoto_1200x1200.webp");
  });
  it("converts storage.googleapis events URL to resized", () => {
    const url = "https://storage.googleapis.com/bucket/events/photo.png";
    expect(getResizedImageUrlForApi(url)).toContain("/events/resized/photo_1200x1200.webp");
  });
});

describe("getResizedPathInfo", () => {
  it("returns null for non-Firebase URLs", () => {
    expect(getResizedPathInfo("https://example.com/image.jpg")).toBeNull();
  });
  it("returns originalPath, resizedPath and resizedPathCandidates for firebasestorage spots URL", () => {
    const url = "https://firebasestorage.googleapis.com/v0/b/bucket/o/spots%2Fphoto.jpg";
    const info = getResizedPathInfo(url);
    expect(info).toEqual({
      originalPath: "spots/photo.jpg",
      resizedPath: "spots/resized/photo_1200x1200.webp",
      resizedPathCandidates: [
        "spots/resized/photo_1200x1200.webp",
        "spots/resized/photo_1200x630.webp",
      ],
    });
  });
  it("returns originalPath, resizedPath and resizedPathCandidates for storage.googleapis spots URL", () => {
    const url = "https://storage.googleapis.com/bucket/spots/photo.png";
    const info = getResizedPathInfo(url);
    expect(info).toEqual({
      originalPath: "spots/photo.png",
      resizedPath: "spots/resized/photo_1200x1200.webp",
      resizedPathCandidates: [
        "spots/resized/photo_1200x1200.webp",
        "spots/resized/photo_1200x630.webp",
      ],
    });
  });
  it("returns null for already resized URL", () => {
    const url = "https://storage.googleapis.com/bucket/spots/resized/photo_1200x1200.webp";
    expect(getResizedPathInfo(url)).toBeNull();
  });
  it("returns null for non-string input", () => {
    expect(getResizedPathInfo(null)).toBeNull();
  });
  it("returns path info for firebasestorage events URL", () => {
    const url = "https://firebasestorage.googleapis.com/v0/b/bucket/o/events%2Fphoto.jpg";
    const info = getResizedPathInfo(url);
    expect(info).toEqual({
      originalPath: "events/photo.jpg",
      resizedPath: "events/resized/photo_1200x1200.webp",
      resizedPathCandidates: [
        "events/resized/photo_1200x1200.webp",
        "events/resized/photo_1200x630.webp",
      ],
    });
  });
});

describe("getImageContentTypeForPath", () => {
  it("uses stored type when it is a recognized image type", () => {
    expect(getImageContentTypeForPath("spots/foo.jpg", "image/jpeg"))
        .toBe("image/jpeg");
    expect(getImageContentTypeForPath("spots/foo.png", "image/png"))
        .toBe("image/png");
  });
  it("derives from extension when stored type is application/octet-stream", () => {
    expect(getImageContentTypeForPath("spots/foo.jpg", "application/octet-stream"))
        .toBe("image/jpeg");
    expect(getImageContentTypeForPath("spots/photo.png", "application/octet-stream"))
        .toBe("image/png");
  });
  it("derives from extension when stored type is null or unknown", () => {
    expect(getImageContentTypeForPath("spots/foo.jpeg", null)).toBe("image/jpeg");
    expect(getImageContentTypeForPath("spots/foo.webp", undefined)).toBe("image/webp");
    expect(getImageContentTypeForPath("spots/x.gif", "text/plain")).toBe("image/gif");
  });
  it("defaults to image/jpeg for unknown extension", () => {
    expect(getImageContentTypeForPath("spots/foo.bmp", "application/octet-stream"))
        .toBe("image/jpeg");
  });
});

describe("isEphemeralImageHost", () => {
  it("returns true for mymaps.usercontent.google.com", () => {
    expect(isEphemeralImageHost("https://mymaps.usercontent.google.com/xxx")).toBe(true);
  });
  it("returns true for lh3.googleusercontent.com", () => {
    expect(isEphemeralImageHost("https://lh3.googleusercontent.com/xxx")).toBe(true);
  });
  it("returns false for other hosts", () => {
    expect(isEphemeralImageHost("https://storage.googleapis.com/bucket/foo")).toBe(false);
    expect(isEphemeralImageHost("https://example.com/image.jpg")).toBe(false);
  });
  it("returns false for invalid URL", () => {
    expect(isEphemeralImageHost("not-a-url")).toBe(false);
  });
});

describe("hostnameMatches", () => {
  it("matches exact host and subdomains only", () => {
    expect(hostnameMatches("youtube.com", "youtube.com")).toBe(true);
    expect(hostnameMatches("www.youtube.com", "youtube.com")).toBe(true);
    expect(hostnameMatches("youtube.com.evil.com", "youtube.com")).toBe(false);
    expect(hostnameMatches("notyoutube.com", "youtube.com")).toBe(false);
  });
});

describe("isFirebaseStorageUrl", () => {
  it("accepts real storage hosts and rejects spoofed substrings", () => {
    expect(isFirebaseStorageUrl(
        "https://firebasestorage.googleapis.com/v0/b/b/o/spots%2Fa.jpg",
    )).toBe(true);
    expect(isFirebaseStorageUrl(
        "https://storage.googleapis.com/bucket/spots/a.jpg",
    )).toBe(true);
    expect(isFirebaseStorageUrl(
        "https://evil.com/?q=firebasestorage.googleapis.com",
    )).toBe(false);
  });
});

describe("isGoogleUserContentUrl", () => {
  it("matches googleusercontent hosts only", () => {
    expect(isGoogleUserContentUrl("https://lh3.googleusercontent.com/a")).toBe(true);
    expect(isGoogleUserContentUrl(
        "https://evil.com/?q=googleusercontent.com",
    )).toBe(false);
  });
});
