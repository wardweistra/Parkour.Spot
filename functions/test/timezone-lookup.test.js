const {
  buildGoogleTimeZoneApiUrl,
  lookupTimeZoneFromCoordinates,
  parseGoogleTimeZoneResponse,
} = require("../lib/timezone-lookup");

describe("timezone-lookup helpers", () => {
  describe("parseGoogleTimeZoneResponse", () => {
    it("returns normalized IANA timezone on OK response", () => {
      expect(
          parseGoogleTimeZoneResponse({
            status: "OK",
            timeZoneId: "Europe/Amsterdam",
          }),
      ).toBe("Europe/Amsterdam");
    });

    it("returns null for invalid timezone ids", () => {
      expect(
          parseGoogleTimeZoneResponse({
            status: "OK",
            timeZoneId: "Not/AZone",
          }),
      ).toBeNull();
    });

    it("returns null for non-OK status", () => {
      expect(
          parseGoogleTimeZoneResponse({
            status: "ZERO_RESULTS",
            timeZoneId: "Europe/Amsterdam",
          }),
      ).toBeNull();
      expect(parseGoogleTimeZoneResponse(null)).toBeNull();
    });
  });

  describe("buildGoogleTimeZoneApiUrl", () => {
    it("builds a Google Time Zone API URL", () => {
      const url = buildGoogleTimeZoneApiUrl(52.37, 4.89, 1700000000, "test-key");
      expect(url).toContain("maps.googleapis.com/maps/api/timezone/json");
      expect(url).toContain("location=52.37%2C4.89");
      expect(url).toContain("timestamp=1700000000");
      expect(url).toContain("key=test-key");
    });
  });

  describe("lookupTimeZoneFromCoordinates", () => {
    it("returns timezone from mocked API response", async () => {
      const fetchJsonImpl = async () => ({
        status: "OK",
        timeZoneId: "America/New_York",
      });

      const timeZone = await lookupTimeZoneFromCoordinates(
          40.7128,
          -74.006,
          "test-key",
          fetchJsonImpl,
      );
      expect(timeZone).toBe("America/New_York");
    });

    it("returns null when API response has no timezone", async () => {
      const fetchJsonImpl = async () => ({
        status: "ZERO_RESULTS",
      });

      const timeZone = await lookupTimeZoneFromCoordinates(
          0,
          0,
          "test-key",
          fetchJsonImpl,
      );
      expect(timeZone).toBeNull();
    });

    it("throws when API key is missing", async () => {
      await expect(
          lookupTimeZoneFromCoordinates(52.37, 4.89, "", async () => ({})),
      ).rejects.toThrow("Google Maps API key not configured");
    });

    it("throws when coordinates are invalid", async () => {
      await expect(
          lookupTimeZoneFromCoordinates(
              Number.NaN,
              4.89,
              "test-key",
              async () => ({}),
          ),
      ).rejects.toThrow("latitude and longitude must be finite numbers");
    });
  });
});
