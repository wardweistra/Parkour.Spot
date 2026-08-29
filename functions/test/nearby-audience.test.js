const {
  normalizeAlertRadiusKm,
  locationMatchesPoint,
  findUserIdsNearPoint,
  filterUserIdsByFlag,
  DEFAULT_ALERT_RADIUS_KM,
} = require("../lib/nearby-audience");
const {calculateBounds, calculateDistance} = require("../lib/geo");

const ORIGIN_LAT = 52.37;
const ORIGIN_LNG = 4.89;

/**
 * @param {string} userId
 * @param {object} data
 * @return {object} mock QueryDocumentSnapshot
 */
function mockLoiDoc(userId, data) {
  return {
    data: () => data,
    ref: {
      parent: {
        parent: {id: userId},
      },
    },
  };
}

/**
 * Point due north of origin at approximately targetMeters.
 * @param {number} targetMeters
 * @return {{latitude: number, longitude: number}}
 */
function northOfOrigin(targetMeters) {
  return {
    latitude: ORIGIN_LAT + (targetMeters / 111000),
    longitude: ORIGIN_LNG,
  };
}

describe("normalizeAlertRadiusKm", () => {
  it("returns 10, 50, or 100 when allowed", () => {
    expect(normalizeAlertRadiusKm(10)).toBe(10);
    expect(normalizeAlertRadiusKm(50)).toBe(50);
    expect(normalizeAlertRadiusKm(100)).toBe(100);
  });

  it("defaults missing and invalid values to 50", () => {
    expect(normalizeAlertRadiusKm(undefined)).toBe(DEFAULT_ALERT_RADIUS_KM);
    expect(normalizeAlertRadiusKm(null)).toBe(DEFAULT_ALERT_RADIUS_KM);
    expect(normalizeAlertRadiusKm(5)).toBe(DEFAULT_ALERT_RADIUS_KM);
    expect(normalizeAlertRadiusKm(25)).toBe(DEFAULT_ALERT_RADIUS_KM);
    expect(normalizeAlertRadiusKm("50")).toBe(50);
    expect(normalizeAlertRadiusKm("nope")).toBe(DEFAULT_ALERT_RADIUS_KM);
  });
});

describe("locationMatchesPoint", () => {
  it("treats missing alertRadiusKm as 50 km", () => {
    const at40km = northOfOrigin(40000);
    expect(locationMatchesPoint(at40km, ORIGIN_LAT, ORIGIN_LNG)).toBe(true);
    expect(locationMatchesPoint(
        {...at40km, alertRadiusKm: 10},
        ORIGIN_LAT,
        ORIGIN_LNG,
    )).toBe(false);
  });

  it("matches ~40 km at 50 km radius but not at 10 km", () => {
    const at40km = northOfOrigin(40000);
    const dist = calculateDistance(
        ORIGIN_LAT, ORIGIN_LNG, at40km.latitude, at40km.longitude,
    );
    expect(dist).toBeGreaterThan(10000);
    expect(dist).toBeLessThan(50000);
    expect(locationMatchesPoint(
        {...at40km, alertRadiusKm: 50},
        ORIGIN_LAT,
        ORIGIN_LNG,
    )).toBe(true);
    expect(locationMatchesPoint(
        {...at40km, alertRadiusKm: 10},
        ORIGIN_LAT,
        ORIGIN_LNG,
    )).toBe(false);
  });

  it("matches ~80 km at 100 km radius only", () => {
    const at80km = northOfOrigin(80000);
    const dist = calculateDistance(
        ORIGIN_LAT, ORIGIN_LNG, at80km.latitude, at80km.longitude,
    );
    expect(dist).toBeGreaterThan(50000);
    expect(dist).toBeLessThan(100000);
    expect(locationMatchesPoint(
        {...at80km, alertRadiusKm: 50},
        ORIGIN_LAT,
        ORIGIN_LNG,
    )).toBe(false);
    expect(locationMatchesPoint(
        {...at80km, alertRadiusKm: 100},
        ORIGIN_LAT,
        ORIGIN_LNG,
    )).toBe(true);
  });

  it("excludes a 100 km box corner outside the circle", () => {
    const bounds = calculateBounds(ORIGIN_LAT, ORIGIN_LNG, 100000);
    const corner = {
      latitude: bounds.maxLat,
      longitude: bounds.maxLng,
      alertRadiusKm: 100,
    };
    const dist = calculateDistance(
        ORIGIN_LAT, ORIGIN_LNG, corner.latitude, corner.longitude,
    );
    expect(dist).toBeGreaterThan(100000);
    expect(locationMatchesPoint(corner, ORIGIN_LAT, ORIGIN_LNG)).toBe(false);
  });

  it("rejects invalid coordinates", () => {
    expect(locationMatchesPoint(
        {latitude: NaN, longitude: ORIGIN_LNG},
        ORIGIN_LAT,
        ORIGIN_LNG,
    )).toBe(false);
    expect(locationMatchesPoint(undefined, ORIGIN_LAT, ORIGIN_LNG)).toBe(false);
  });
});

describe("findUserIdsNearPoint", () => {
  it("notifies when one of two LOIs is in range", async () => {
    const inRange = northOfOrigin(40000);
    const outOfRange = northOfOrigin(80000);
    const locSnap = {
      empty: false,
      size: 2,
      docs: [
        mockLoiDoc("u1", {...inRange, alertRadiusKm: 50}),
        mockLoiDoc("u1", {...outOfRange, alertRadiusKm: 50}),
      ],
    };
    const queryChain = {
      where: jest.fn(() => queryChain),
      limit: jest.fn(() => queryChain),
      startAfter: jest.fn(() => queryChain),
      get: jest.fn(async () => locSnap),
    };
    const db = {collectionGroup: jest.fn(() => queryChain)};
    const result = await findUserIdsNearPoint({
      db,
      lat: ORIGIN_LAT,
      lng: ORIGIN_LNG,
    });
    expect(result.userIds).toEqual(["u1"]);
    expect(result.matchedLocationCount).toBe(1);
  });

  it("dedupes user ids and drops excludeUserId", async () => {
    const locSnap = {
      empty: false,
      size: 3,
      docs: [
        mockLoiDoc("a", {latitude: ORIGIN_LAT, longitude: ORIGIN_LNG}),
        mockLoiDoc("a", {latitude: ORIGIN_LAT, longitude: ORIGIN_LNG}),
        mockLoiDoc("b", {latitude: ORIGIN_LAT, longitude: ORIGIN_LNG}),
      ],
    };
    const queryChain = {
      where: jest.fn(() => queryChain),
      limit: jest.fn(() => queryChain),
      startAfter: jest.fn(() => queryChain),
      get: jest.fn(async () => locSnap),
    };
    const db = {collectionGroup: jest.fn(() => queryChain)};
    const result = await findUserIdsNearPoint({
      db,
      lat: ORIGIN_LAT,
      lng: ORIGIN_LNG,
      excludeUserId: "b",
    });
    expect(result.userIds).toEqual(["a"]);
    expect(result.matchedLocationCount).toBe(3);
  });

  it("skips LOIs in the box that fail the haversine check", async () => {
    const bounds = calculateBounds(ORIGIN_LAT, ORIGIN_LNG, 100000);
    const locSnap = {
      empty: false,
      size: 1,
      docs: [
        mockLoiDoc("u1", {
          latitude: bounds.maxLat,
          longitude: bounds.maxLng,
          alertRadiusKm: 100,
        }),
      ],
    };
    const queryChain = {
      where: jest.fn(() => queryChain),
      limit: jest.fn(() => queryChain),
      startAfter: jest.fn(() => queryChain),
      get: jest.fn(async () => locSnap),
    };
    const db = {collectionGroup: jest.fn(() => queryChain)};
    const result = await findUserIdsNearPoint({
      db,
      lat: ORIGIN_LAT,
      lng: ORIGIN_LNG,
    });
    expect(result.userIds).toEqual([]);
    expect(result.matchedLocationCount).toBe(0);
  });
});

describe("filterUserIdsByFlag", () => {
  it("keeps users when the flag is missing or true", async () => {
    const db = {
      collection: jest.fn(() => ({
        doc: jest.fn((uid) => ({path: `users/${uid}`})),
      })),
      getAll: jest.fn(async () => [
        {exists: true, data: () => ({})},
        {exists: true, data: () => ({notifyNewSpotsNearby: true})},
        {exists: true, data: () => ({notifyNewSpotsNearby: false})},
        {exists: false, data: () => ({})},
      ]),
    };
    const kept = await filterUserIdsByFlag(
        db, ["a", "b", "c", "d"], "notifyNewSpotsNearby",
    );
    expect(kept).toEqual(["a", "b"]);
  });
});
