const {
  storagePathFromPublicUrl,
  createImagePipeline,
  MAX_IMAGE_DOWNLOAD_BYTES,
} = require("../lib/image-pipeline");
const {
  ISSUE_YOUTUBE_MISSING_THUMBNAIL,
  ISSUE_YOUTUBE_UNCACHED_THUMBNAIL,
} = require("../lib/sync-runs");

jest.mock("../lib/youtube-thumbnails", () => ({
  extractYoutubeVideoIdFromThumbnailUrl: jest.fn((url) => {
    if (typeof url !== "string") return null;
    const match = url.match(/\/vi\/([a-zA-Z0-9_-]{6,20})\//);
    return match ? match[1] : null;
  }),
  resolveYoutubeThumbnailUrl: jest.fn(),
}));

const {
  resolveYoutubeThumbnailUrl,
} = require("../lib/youtube-thumbnails");

function mockFieldValue() {
  return {
    serverTimestamp: jest.fn(() => "SERVER_TIMESTAMP"),
  };
}

/**
 * @param {Object} options
 * @return {{pipeline: Object, downloadFn: jest.Mock, optimizeFn: jest.Mock, cacheGet: jest.Mock, fileExists: jest.Mock, fileSave: jest.Mock}}
 */
function buildPipeline(options = {}) {
  const cacheDocs = options.cacheDocs || new Map();
  const cacheGet = jest.fn(async function() {
    const data = cacheDocs.get(this._id);
    if (!data) {
      return {exists: false, data: () => null};
    }
    return {exists: true, data: () => data};
  });
  const cacheSet = jest.fn(async function(payload) {
    cacheDocs.set(this._id, payload);
  });
  const cacheDelete = jest.fn(async function() {
    cacheDocs.delete(this._id);
  });

  const db = {
    collection: jest.fn((name) => {
      expect(name).toBe("imageCache");
      return {
        doc: jest.fn((id) => ({
          _id: id,
          get: cacheGet,
          set: cacheSet,
          delete: cacheDelete,
        })),
      };
    }),
  };

  const fileExists = jest.fn(async () => [true]);
  const fileSave = jest.fn(async () => undefined);
  const makePublic = jest.fn(async () => undefined);
  const getFiles = jest.fn(async () => [[]]);

  const bucket = {
    name: "test-bucket",
    file: jest.fn((fileName) => ({
      name: fileName,
      exists: fileExists,
      save: fileSave,
      makePublic,
    })),
    getFiles,
  };

  const downloadFn = options.downloadFn || jest.fn();
  const optimizeFn = options.optimizeFn || jest.fn(async (buf) => buf);

  const pipeline = createImagePipeline({
    db,
    bucket,
    FieldValue: mockFieldValue(),
    downloadBinaryWithRedirectsFn: downloadFn,
    optimizeImageFn: optimizeFn,
  });

  return {
    pipeline,
    downloadFn,
    optimizeFn,
    cacheGet,
    cacheSet,
    fileExists,
    fileSave,
    getFiles,
    cacheDocs,
  };
}

describe("storagePathFromPublicUrl", () => {
  it("extracts the object path for this bucket", () => {
    expect(
        storagePathFromPublicUrl(
            "https://storage.googleapis.com/test-bucket/spots/foo_abc_0.jpg",
            "test-bucket",
        ),
    ).toBe("spots/foo_abc_0.jpg");
  });

  it("returns null for other hosts", () => {
    expect(
        storagePathFromPublicUrl("https://example.com/spots/a.jpg", "test-bucket"),
    ).toBeNull();
  });
});

describe("ensureSpotImages", () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it("light + existing returns existing arrays without downloading", async () => {
    const {pipeline, downloadFn} = buildPipeline();
    const result = await pipeline.ensureSpotImages({
      sourceUrls: ["https://example.com/a.jpg"],
      youtubeVideoIds: ["vid1234"],
      existing: {
        imageUrls: ["https://cdn/existing.jpg"],
        imageHashes: ["hash1"],
        youtubeVideoIds: ["oldvid"],
      },
      mode: "light",
      spotName: "Test Spot",
    });

    expect(downloadFn).not.toHaveBeenCalled();
    expect(result).toEqual({
      imageUrls: ["https://cdn/existing.jpg"],
      imageHashes: ["hash1"],
      youtubeVideoIds: ["oldvid"],
      issues: [],
    });
    expect(Object.values(result).every((v) =>
      Array.isArray(v) || typeof v === "object",
    )).toBe(true);
    expect(result).not.toHaveProperty("buffer");
  });

  it("full + cache hit reuses cached URL/hash without download", async () => {
    const sourceUrl = "https://example.com/photo.jpg";
    const publicUrl =
      "https://storage.googleapis.com/test-bucket/spots/Test_abc123_0.jpg";
    const {pipeline, downloadFn, fileExists} = buildPipeline({
      cacheDocs: new Map([
        [encodeURIComponent(sourceUrl), {hash: "abc123", publicUrl}],
      ]),
    });

    const result = await pipeline.ensureSpotImages({
      sourceUrls: [sourceUrl],
      youtubeVideoIds: [],
      existing: null,
      mode: "full",
      spotName: "Test",
    });

    expect(downloadFn).not.toHaveBeenCalled();
    expect(fileExists).toHaveBeenCalled();
    expect(result.imageUrls).toEqual([publicUrl]);
    expect(result.imageHashes).toEqual(["abc123"]);
    expect(result.issues).toEqual([]);
    expect(JSON.stringify(result)).not.toMatch(/Buffer/);
  });

  it("full + cache miss downloads once, uploads, writes cache", async () => {
    const sourceUrl = "https://example.com/new.jpg";
    const jpegBytes = Buffer.from([0xff, 0xd8, 0xff, 0xd9, 1, 2, 3, 4]);
    const {pipeline, downloadFn, optimizeFn, fileSave, cacheSet, getFiles} =
      buildPipeline({
        downloadFn: jest.fn(async () => ({
          buffer: jpegBytes,
          contentType: "image/jpeg",
          finalUrl: sourceUrl,
        })),
        optimizeFn: jest.fn(async () => Buffer.from("optimized")),
      });
    getFiles.mockResolvedValue([[]]);

    const result = await pipeline.ensureSpotImages({
      sourceUrls: [sourceUrl],
      youtubeVideoIds: [],
      existing: null,
      mode: "full",
      spotName: "New Spot",
    });

    expect(downloadFn).toHaveBeenCalledTimes(1);
    expect(optimizeFn).toHaveBeenCalledTimes(1);
    expect(fileSave).toHaveBeenCalledTimes(1);
    expect(cacheSet).toHaveBeenCalled();
    expect(result.imageUrls).toHaveLength(1);
    expect(result.imageUrls[0]).toContain("storage.googleapis.com/test-bucket/");
    expect(result.imageHashes).toHaveLength(1);
    expect(typeof result.imageHashes[0]).toBe("string");
    expect(result).not.toHaveProperty("buffer");
  });

  it("dead YouTube thumbnail yields issue and drops the ID", async () => {
    resolveYoutubeThumbnailUrl.mockResolvedValue(null);
    const {pipeline, downloadFn} = buildPipeline();

    const result = await pipeline.ensureSpotImages({
      sourceUrls: [],
      youtubeVideoIds: ["deadVideoId99"],
      existing: null,
      mode: "full",
      spotName: "YT Spot",
      folderName: "Folder A",
    });

    expect(downloadFn).not.toHaveBeenCalled();
    expect(result.youtubeVideoIds).toEqual([]);
    expect(result.issues).toEqual([
      {
        type: ISSUE_YOUTUBE_MISSING_THUMBNAIL,
        videoId: "deadVideoId99",
        spotName: "YT Spot",
        folderName: "Folder A",
      },
    ]);
  });

  it("uncached live YouTube thumbnail yields uncached issue", async () => {
    const thumb =
      "https://img.youtube.com/vi/liveVideoId1/maxresdefault.jpg";
    resolveYoutubeThumbnailUrl.mockResolvedValue(thumb);
    const {pipeline} = buildPipeline();

    const result = await pipeline.ensureSpotImages({
      sourceUrls: [],
      youtubeVideoIds: ["liveVideoId1"],
      existing: null,
      mode: "full",
      spotName: "YT Spot",
      folderName: "Folder B",
    });

    expect(result.youtubeVideoIds).toEqual([]);
    expect(result.issues).toEqual([
      {
        type: ISSUE_YOUTUBE_UNCACHED_THUMBNAIL,
        videoId: "liveVideoId1",
        spotName: "YT Spot",
        folderName: "Folder B",
        thumbnailUrl: thumb,
      },
    ]);
  });

  it("result object is strings only (no Buffer fields)", async () => {
    const {pipeline} = buildPipeline();
    const result = await pipeline.ensureSpotImages({
      sourceUrls: [],
      youtubeVideoIds: [],
      existing: {
        imageUrls: ["https://cdn/a.jpg"],
        imageHashes: ["h"],
        youtubeVideoIds: [],
      },
      mode: "light",
      spotName: "S",
    });

    const walk = (value) => {
      if (Buffer.isBuffer(value)) {
        throw new Error("unexpected Buffer in result");
      }
      if (Array.isArray(value)) {
        value.forEach(walk);
        return;
      }
      if (value && typeof value === "object") {
        Object.values(value).forEach(walk);
      }
    };
    walk(result);
    expect(MAX_IMAGE_DOWNLOAD_BYTES).toBeGreaterThan(1024 * 1024);
  });
});
