const {
  isAllowedOrigin,
  isJsonRpcNotification,
  jsonRpcResult,
  createMcpHandler,
  TOOLS,
  PROTOCOL_VERSION,
} = require("../lib/mcp-server");
const {SpotApiError} = require("../lib/spot-api");

describe("isAllowedOrigin", () => {
  it("allows missing origin", () => {
    expect(isAllowedOrigin(undefined)).toBe(true);
    expect(isAllowedOrigin("")).toBe(true);
  });
  it("allows https origins", () => {
    expect(isAllowedOrigin("https://parkour.spot")).toBe(true);
  });
  it("rejects garbage", () => {
    expect(isAllowedOrigin("not a url")).toBe(false);
  });
});

describe("isJsonRpcNotification", () => {
  it("detects notifications without id", () => {
    expect(isJsonRpcNotification({
      jsonrpc: "2.0",
      method: "notifications/initialized",
    })).toBe(true);
    expect(isJsonRpcNotification({
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
    })).toBe(false);
  });
});

function mockRes() {
  const res = {
    statusCode: 200,
    body: null,
    headers: {},
    status(code) {
      this.statusCode = code;
      return this;
    },
    set(key, value) {
      this.headers[key] = value;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
    send(payload) {
      this.body = payload;
      return this;
    },
  };
  return res;
}

describe("createMcpHandler", () => {
  function createApi(overrides = {}) {
    return {
      authenticateApiClient: jest.fn().mockResolvedValue({clientId: "c1"}),
      recordApiClientUsage: jest.fn().mockResolvedValue(undefined),
      searchSpotsForApi: jest.fn().mockResolvedValue({
        spots: [{id: "s1"}],
        totalCount: 1,
        shownCount: 1,
      }),
      getSpotForApi: jest.fn().mockResolvedValue({id: "s1", name: "Wall"}),
      ...overrides,
    };
  }

  it("rejects unauthorized requests", async () => {
    const api = createApi({
      authenticateApiClient: jest.fn().mockRejectedValue(
          new SpotApiError(401, "API key required"),
      ),
    });
    const handler = createMcpHandler(api);
    const res = mockRes();
    await handler({
      method: "POST",
      headers: {},
      body: {jsonrpc: "2.0", id: 1, method: "initialize"},
    }, res);
    expect(res.statusCode).toBe(401);
    expect(res.body.error).toMatch(/API key/);
  });

  it("handles initialize", async () => {
    const handler = createMcpHandler(createApi());
    const res = mockRes();
    await handler({
      method: "POST",
      headers: {},
      body: {jsonrpc: "2.0", id: 1, method: "initialize", params: {}},
    }, res);
    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual(jsonRpcResult(1, expect.objectContaining({
      protocolVersion: PROTOCOL_VERSION,
      serverInfo: expect.objectContaining({name: "parkourspot"}),
      capabilities: {tools: {}},
    })));
  });

  it("handles tools/list", async () => {
    const handler = createMcpHandler(createApi());
    const res = mockRes();
    await handler({
      method: "POST",
      headers: {},
      body: {jsonrpc: "2.0", id: 2, method: "tools/list"},
    }, res);
    expect(res.body.result.tools).toEqual(TOOLS);
  });

  it("handles notifications with 202", async () => {
    const handler = createMcpHandler(createApi());
    const res = mockRes();
    await handler({
      method: "POST",
      headers: {},
      body: {jsonrpc: "2.0", method: "notifications/initialized"},
    }, res);
    expect(res.statusCode).toBe(202);
  });

  it("calls search_spots tool", async () => {
    const api = createApi();
    const handler = createMcpHandler(api);
    const res = mockRes();
    await handler({
      method: "POST",
      headers: {},
      body: {
        jsonrpc: "2.0",
        id: 3,
        method: "tools/call",
        params: {
          name: "search_spots",
          arguments: {query: "wall", limit: 5},
        },
      },
    }, res);
    expect(api.searchSpotsForApi).toHaveBeenCalledWith({
      query: "wall",
      limit: 5,
      minLat: undefined,
      maxLat: undefined,
      minLng: undefined,
      maxLng: undefined,
    });
    expect(api.recordApiClientUsage).toHaveBeenCalledWith("c1");
    expect(res.body.result.isError).toBeUndefined();
    expect(res.body.result.content[0].text).toContain("s1");
  });

  it("calls get_spot tool", async () => {
    const api = createApi();
    const handler = createMcpHandler(api);
    const res = mockRes();
    await handler({
      method: "POST",
      headers: {},
      body: {
        jsonrpc: "2.0",
        id: 4,
        method: "tools/call",
        params: {name: "get_spot", arguments: {spotId: "s1"}},
      },
    }, res);
    expect(api.getSpotForApi).toHaveBeenCalledWith("s1");
    expect(res.body.result.content[0].text).toContain("Wall");
  });

  it("returns tool error for SpotApiError", async () => {
    const api = createApi({
      getSpotForApi: jest.fn().mockRejectedValue(
          new SpotApiError(404, "Spot not found"),
      ),
    });
    const handler = createMcpHandler(api);
    const res = mockRes();
    await handler({
      method: "POST",
      headers: {},
      body: {
        jsonrpc: "2.0",
        id: 5,
        method: "tools/call",
        params: {name: "get_spot", arguments: {spotId: "x"}},
      },
    }, res);
    expect(res.statusCode).toBe(200);
    expect(res.body.result.isError).toBe(true);
    expect(res.body.result.content[0].text).toBe("Spot not found");
  });

  it("rejects forbidden origin", async () => {
    const handler = createMcpHandler(createApi());
    const res = mockRes();
    await handler({
      method: "POST",
      headers: {origin: "totally-invalid"},
      body: {jsonrpc: "2.0", id: 1, method: "ping"},
    }, res);
    expect(res.statusCode).toBe(403);
  });
});
