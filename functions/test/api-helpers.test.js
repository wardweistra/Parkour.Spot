const {
  hashApiKey,
  generateApiKey,
  serializeSpotForApi,
} = require("../lib/api-helpers");

describe("hashApiKey", () => {
  it("returns deterministic SHA-256 hex hash", () => {
    const key = "ps_abc123";
    expect(hashApiKey(key)).toBe(hashApiKey(key));
    expect(hashApiKey(key)).toMatch(/^[a-f0-9]{64}$/);
  });
  it("different keys produce different hashes", () => {
    expect(hashApiKey("key1")).not.toBe(hashApiKey("key2"));
  });
});

describe("generateApiKey", () => {
  it("returns string with ps_ prefix", () => {
    const key = generateApiKey();
    expect(key).toMatch(/^ps_/);
  });
  it("generates 32 hex chars after prefix (16 bytes)", () => {
    const key = generateApiKey();
    expect(key).toMatch(/^ps_[a-f0-9]{32}$/);
    expect(key.length).toBe(35);
  });
  it("generates unique keys", () => {
    const keys = new Set();
    for (let i = 0; i < 10; i++) {
      keys.add(generateApiKey());
    }
    expect(keys.size).toBe(10);
  });
});

describe("serializeSpotForApi", () => {
  it("converts Firestore Timestamp to ISO string", () => {
    const mockTimestamp = {
      toDate: () => new Date("2024-01-15T12:00:00.000Z"),
    };
    const data = {id: "123", createdAt: mockTimestamp};
    expect(serializeSpotForApi(data)).toEqual({
      id: "123",
      createdAt: "2024-01-15T12:00:00.000Z",
    });
  });
  it("keeps primitive values unchanged", () => {
    const data = {name: "Spot", count: 5, active: true};
    expect(serializeSpotForApi(data)).toEqual(data);
  });
  it("omits undefined and null values", () => {
    const data = {a: 1, b: undefined, c: null, d: 2};
    expect(serializeSpotForApi(data)).toEqual({a: 1, d: 2});
  });
});
