const {
  NOT_FOUND_RETRY_MS,
  buildGeocodeQueryUrl,
  isCachedLocationUsable,
  locationQueryCacheId,
  normalizeLanguage,
  normalizeLocationQuery,
  parseGeocodeQueryResponse,
} = require("../lib/location-query-cache");

describe("location-query-cache helpers", () => {
  describe("normalizeLocationQuery", () => {
    it("lowercases and collapses whitespace and commas", () => {
      expect(normalizeLocationQuery("  Amsterdam ,   Netherlands ")).toBe(
          "amsterdam, netherlands",
      );
    });

    it("rejects empty, non-string and overly long input", () => {
      expect(normalizeLocationQuery("   ")).toBeNull();
      expect(normalizeLocationQuery(42)).toBeNull();
      expect(normalizeLocationQuery("a".repeat(121))).toBeNull();
    });
  });

  describe("normalizeLanguage", () => {
    it("accepts simple language tags", () => {
      expect(normalizeLanguage("nl")).toBe("nl");
      expect(normalizeLanguage("pt-BR")).toBe("pt-br");
    });

    it("drops invalid values", () => {
      expect(normalizeLanguage("not a language")).toBe("");
      expect(normalizeLanguage(undefined)).toBe("");
    });
  });

  describe("locationQueryCacheId", () => {
    it("is stable and differs per language", () => {
      const a = locationQueryCacheId("amsterdam, netherlands", "");
      expect(a).toBe(locationQueryCacheId("amsterdam, netherlands", ""));
      expect(a).not.toBe(locationQueryCacheId("amsterdam, netherlands", "nl"));
      expect(a).toMatch(/^[0-9a-f]{40}$/);
    });
  });

  describe("buildGeocodeQueryUrl", () => {
    it("encodes the query and adds the language", () => {
      const url = buildGeocodeQueryUrl("São Paulo, Brazil", "KEY", "pt");
      expect(url).toContain("/maps/api/geocode/json?");
      expect(url).toContain("address=S%C3%A3o+Paulo%2C+Brazil");
      expect(url).toContain("language=pt");
    });
  });

  describe("parseGeocodeQueryResponse", () => {
    it("maps an OK response to placeDetails-shaped details", () => {
      const parsed = parseGeocodeQueryResponse({
        status: "OK",
        results: [
          {
            formatted_address: "Amsterdam, Netherlands",
            types: ["locality", "political"],
            geometry: {
              location: {lat: 52.37, lng: 4.9},
              viewport: {
                northeast: {lat: 52.43, lng: 5.07},
                southwest: {lat: 52.28, lng: 4.73},
              },
            },
            address_components: [
              {long_name: "Amsterdam", short_name: "Amsterdam", types: ["locality"]},
              {long_name: "Netherlands", short_name: "NL", types: ["country"]},
            ],
          },
        ],
      });
      expect(parsed.status).toBe("ok");
      expect(parsed.details).toEqual({
        latitude: 52.37,
        longitude: 4.9,
        formattedAddress: "Amsterdam, Netherlands",
        city: "Amsterdam",
        countryCode: "NL",
        viewport: {
          northeast: {lat: 52.43, lng: 5.07},
          southwest: {lat: 52.28, lng: 4.73},
        },
        types: ["locality", "political"],
      });
    });

    it("treats ZERO_RESULTS as a cacheable not_found", () => {
      expect(parseGeocodeQueryResponse({status: "ZERO_RESULTS"}).status).toBe(
          "not_found",
      );
    });

    it("treats quota and request errors as non-cacheable", () => {
      const parsed = parseGeocodeQueryResponse({
        status: "OVER_QUERY_LIMIT",
        error_message: "quota",
      });
      expect(parsed.status).toBe("error");
      expect(parsed.error).toBe("quota");
    });
  });

  describe("isCachedLocationUsable", () => {
    const now = 1800000000000;

    it("serves ok entries with coordinates", () => {
      expect(
          isCachedLocationUsable({status: "ok", details: {latitude: 1}}, now),
      ).toBe(true);
      expect(isCachedLocationUsable({status: "ok", details: {}}, now)).toBe(
          false,
      );
    });

    it("serves not_found entries until the retry window passes", () => {
      expect(
          isCachedLocationUsable(
              {status: "not_found", checkedAtMs: now - 1000},
              now,
          ),
      ).toBe(true);
      expect(
          isCachedLocationUsable(
              {status: "not_found", checkedAtMs: now - NOT_FOUND_RETRY_MS - 1},
              now,
          ),
      ).toBe(false);
    });

    it("ignores missing entries", () => {
      expect(isCachedLocationUsable(undefined, now)).toBe(false);
    });
  });
});
