const {
  DEFAULT_SPOT_NAME,
  USER_AGENT,
  extractNaverShareId,
  naverSharePageUrl,
  naverBookmarksApiUrl,
  extractNaverCoordinates,
  pickNaverName,
  buildNaverDescription,
  mapNaverBookmarkToPlacemark,
  mapNaverBookmarksResponseToPlacemarks,
  fetchNaverBookmarkPlacemarks,
} = require("../lib/naver-bookmarks");

const SAMPLE_SHARE_ID = "3388be4a43592f4a6aef152f4b3f0e29";
const SAMPLE_API_URL =
  "https://pages.map.naver.com/save-pages/api/maps-bookmark/v3/shares/" +
  `${SAMPLE_SHARE_ID}/bookmarks?start=0&limit=5000&sort=lastUseTime`;

describe("naver-bookmarks helpers", () => {
  it("uses a browser User-Agent because Naver returns HTTP 500 otherwise", () => {
    expect(USER_AGENT.startsWith("Mozilla/5.0 ")).toBe(true);
  });

  describe("extractNaverShareId", () => {
    it("accepts a raw 32-character share id", () => {
      expect(extractNaverShareId(SAMPLE_SHARE_ID)).toBe(SAMPLE_SHARE_ID);
    });

    it("accepts the maps-bookmark API URL", () => {
      expect(extractNaverShareId(SAMPLE_API_URL)).toBe(SAMPLE_SHARE_ID);
    });

    it("accepts a public shared folder URL", () => {
      expect(extractNaverShareId(
          `https://map.naver.com/p/favorite/sharedPlace/folder/${SAMPLE_SHARE_ID}`,
      )).toBe(SAMPLE_SHARE_ID);
    });

    it("returns null for unrelated input", () => {
      expect(extractNaverShareId("https://example.com/list")).toBeNull();
      expect(extractNaverShareId("")).toBeNull();
      expect(extractNaverShareId(null)).toBeNull();
    });
  });

  describe("naver URL builders", () => {
    it("builds the public share page and paginated API URL", () => {
      expect(naverSharePageUrl(SAMPLE_SHARE_ID)).toBe(
          `https://map.naver.com/p/favorite/sharedPlace/folder/${SAMPLE_SHARE_ID}`,
      );
      expect(naverBookmarksApiUrl(SAMPLE_SHARE_ID, 500, 500)).toContain(
          `/shares/${SAMPLE_SHARE_ID}/bookmarks?`,
      );
      expect(naverBookmarksApiUrl(SAMPLE_SHARE_ID, 500, 500)).toContain(
          "start=500",
      );
    });
  });

  describe("extractNaverCoordinates", () => {
    it("maps px/py as longitude/latitude", () => {
      expect(extractNaverCoordinates({px: 126.82417, py: 37.31207})).toEqual({
        latitude: 37.31207,
        longitude: 126.82417,
        altitude: 0,
      });
    });

    it("parses numeric strings and rejects out-of-range values", () => {
      expect(extractNaverCoordinates({px: "127.0", py: "37.5"})).toEqual({
        latitude: 37.5,
        longitude: 127,
        altitude: 0,
      });
      expect(extractNaverCoordinates({px: 200, py: 37})).toBeNull();
      expect(extractNaverCoordinates({px: 127})).toBeNull();
    });
  });

  describe("pickNaverName", () => {
    it("prefers displayName then name then address", () => {
      expect(pickNaverName({
        displayName: "감천문화마을",
        name: "Busan Gamcheon Culture Village",
      })).toBe("감천문화마을");
      expect(pickNaverName({
        displayName: "",
        name: "Yaksasa Temple",
      })).toBe("Yaksasa Temple");
      expect(pickNaverName({
        name: "",
        address: "서울 용산구 도원동 1-59",
      })).toBe("서울 용산구 도원동 1-59");
      expect(pickNaverName({})).toBe(DEFAULT_SPOT_NAME);
    });
  });

  describe("buildNaverDescription", () => {
    it("joins memo and website url", () => {
      const text = buildNaverDescription({
        memo: "Rails and walls",
        url: "https://example.com",
      });
      expect(text).toContain("Rails and walls");
      expect(text).toContain("Website: https://example.com");
    });
  });

  describe("mapNaverBookmarkToPlacemark", () => {
    const placeBookmark = {
      bookmarkId: 4701568131,
      name: "Yaksasa Temple",
      displayName: "",
      px: 126.7126137,
      py: 37.4719918,
      type: "place",
      address: "인천 남동구 풀무로 48",
      memo: "",
      url: "",
      available: true,
      isIndoor: false,
    };

    it("maps a place bookmark with stable external id", () => {
      const placemark = mapNaverBookmarkToPlacemark(
          placeBookmark,
          "파쿠르 스팟",
      );
      expect(placemark).toMatchObject({
        name: "Yaksasa Temple",
        description: "",
        externalId: "bookmark/4701568131",
        address: "인천 남동구 풀무로 48",
        folderName: "파쿠르 스팟",
        folderPath: ["파쿠르 스팟"],
        coordinates: {
          latitude: 37.4719918,
          longitude: 126.7126137,
          altitude: 0,
        },
      });
      expect(placemark.spotFacilities).toBeUndefined();
    });

    it("skips unavailable bookmarks and missing coordinates", () => {
      expect(mapNaverBookmarkToPlacemark({
        ...placeBookmark,
        available: false,
      }, "폴더")).toBeNull();
      expect(mapNaverBookmarkToPlacemark({
        ...placeBookmark,
        px: null,
        py: null,
      }, "폴더")).toBeNull();
    });

    it("maps indoor places to covered and nested folder mappings", () => {
      const placemark = mapNaverBookmarkToPlacemark({
        ...placeBookmark,
        isIndoor: true,
        folderMappings: [{name: "Seoul gyms"}],
      }, "파쿠르 스팟");
      expect(placemark.spotFacilities).toEqual({covered: "yes"});
      expect(placemark.folderPath).toEqual(["파쿠르 스팟", "Seoul gyms"]);
      expect(placemark.folderName).toBe("Seoul gyms");
    });
  });

  describe("mapNaverBookmarksResponseToPlacemarks", () => {
    it("uses folder name and skips unavailable entries", () => {
      const placemarks = mapNaverBookmarksResponseToPlacemarks({
        folder: {name: "파쿠르 스팟"},
        bookmarkList: [
          {
            bookmarkId: 1,
            name: "Keep",
            px: 127,
            py: 37.5,
            address: "Seoul",
          },
          {
            bookmarkId: 2,
            name: "Closed",
            px: 127,
            py: 37.5,
            available: false,
          },
        ],
      });
      expect(placemarks).toHaveLength(1);
      expect(placemarks[0].name).toBe("Keep");
      expect(placemarks[0].folderName).toBe("파쿠르 스팟");
    });

    it("accepts a bookmarks alias used by older payloads", () => {
      const placemarks = mapNaverBookmarksResponseToPlacemarks({
        bookmarks: [{
          bookmarkId: 9,
          name: "Legacy",
          px: 126,
          py: 37,
        }],
      });
      expect(placemarks).toHaveLength(1);
      expect(placemarks[0].externalId).toBe("bookmark/9");
    });
  });

  describe("fetchNaverBookmarkPlacemarks", () => {
    it("paginates until a short page and maps bookmarks", async () => {
      const requests = [];
      const placemarks = await fetchNaverBookmarkPlacemarks(SAMPLE_API_URL, {
        pageSize: 2,
        maxAttempts: 1,
        getTextFn: async (url) => {
          requests.push(url);
          if (requests.length === 1) {
            return JSON.stringify({
              folder: {name: "파쿠르 스팟"},
              bookmarkList: [
                {bookmarkId: 1, name: "A", px: 126, py: 37},
                {bookmarkId: 2, name: "B", px: 127, py: 37.1},
              ],
            });
          }
          return JSON.stringify({
            folder: {name: "파쿠르 스팟"},
            bookmarkList: [
              {bookmarkId: 3, name: "C", px: 128, py: 37.2},
            ],
          });
        },
      });
      expect(requests).toHaveLength(2);
      expect(placemarks.map((p) => p.name)).toEqual(["A", "B", "C"]);
      expect(placemarks.map((p) => p.folderName)).toEqual([
        "파쿠르 스팟",
        "파쿠르 스팟",
        "파쿠르 스팟",
      ]);
    });

    it("keeps the first page folder name when later pages omit folder", async () => {
      let page = 0;
      const placemarks = await fetchNaverBookmarkPlacemarks(SAMPLE_SHARE_ID, {
        pageSize: 1,
        maxAttempts: 1,
        getTextFn: async () => {
          page += 1;
          if (page === 1) {
            return JSON.stringify({
              folder: {name: "파쿠르 스팟", bookmarkCount: 2},
              bookmarkList: [{bookmarkId: 1, name: "A", px: 126, py: 37}],
            });
          }
          return JSON.stringify({
            bookmarkList: [{bookmarkId: 2, name: "B", px: 127, py: 37}],
          });
        },
      });
      expect(placemarks).toHaveLength(2);
      expect(placemarks[1].folderName).toBe("파쿠르 스팟");
    });

    it("retries retryable failures then succeeds", async () => {
      let attempts = 0;
      const placemarks = await fetchNaverBookmarkPlacemarks(SAMPLE_SHARE_ID, {
        maxAttempts: 3,
        getTextFn: async () => {
          attempts += 1;
          if (attempts < 2) {
            throw new Error("Naver Map bookmarks request failed (HTTP 429)");
          }
          return JSON.stringify({
            bookmarkList: [{
              bookmarkId: 8,
              name: "Retry",
              px: 126,
              py: 37,
            }],
          });
        },
      });
      expect(attempts).toBe(2);
      expect(placemarks[0].name).toBe("Retry");
    });

    it("rejects invalid share URLs without fetching", async () => {
      await expect(fetchNaverBookmarkPlacemarks("https://example.com")).rejects
          .toThrow("Invalid Naver Map share URL");
    });
  });
});
