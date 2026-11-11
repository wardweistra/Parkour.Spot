/**
 * Stateless Streamable HTTP MCP server for ParkourSpot spots (API-key auth).
 */

const {SpotApiError} = require("./spot-api");

const PROTOCOL_VERSION = "2024-11-05";
const SERVER_INFO = {
  name: "parkourspot",
  version: "1.0.0",
};
const SERVER_INSTRUCTIONS =
  "Read-only parkour spot discovery for ParkourSpot. " +
  "Use search_spots to find spots by name or map bounds, get_spot for " +
  "full details, and list_spot_list_spots to list every spot in a public " +
  "or unlisted spot list when you already have the list id. " +
  "No writes, ratings, events, or admin tools.";

const TOOLS = [
  {
    name: "search_spots",
    description:
      "Search parkour spots by name query (q, min 2 characters) or by " +
      "geographic bounds (minLat, maxLat, minLng, maxLng). " +
      "Returns spots, totalCount, and shownCount.",
    inputSchema: {
      type: "object",
      properties: {
        query: {
          type: "string",
          description: "Name search query (at least 2 characters)",
        },
        limit: {
          type: "integer",
          description:
            "Max results (1–100). Default 20 for query, 100 for bounds.",
          minimum: 1,
          maximum: 100,
        },
        minLat: {type: "number", description: "Southern bound latitude"},
        maxLat: {type: "number", description: "Northern bound latitude"},
        minLng: {type: "number", description: "Western bound longitude"},
        maxLng: {type: "number", description: "Eastern bound longitude"},
      },
      additionalProperties: false,
    },
  },
  {
    name: "get_spot",
    description: "Get a single parkour spot by its document id.",
    inputSchema: {
      type: "object",
      properties: {
        spotId: {
          type: "string",
          description: "Firestore spot document id",
        },
      },
      required: ["spotId"],
      additionalProperties: false,
    },
  },
  {
    name: "list_spot_list_spots",
    description:
      "List every parkour spot in a public or unlisted spot list, in list " +
      "order. Requires the spot list id. Private lists are not available. " +
      "Returns list, spots, totalCount, and shownCount. A spot may include " +
      "listNote from the list entry.",
    inputSchema: {
      type: "object",
      properties: {
        listId: {
          type: "string",
          description: "Firestore spot list document id",
        },
      },
      required: ["listId"],
      additionalProperties: false,
    },
  },
];

/**
 * Allow missing Origin (non-browser clients). When present, require http(s)
 * or chrome-extension schemes to mitigate trivial DNS-rebinding abuse.
 * @param {string|undefined|null} origin
 * @return {boolean}
 */
function isAllowedOrigin(origin) {
  if (origin === undefined || origin === null || origin === "") {
    return true;
  }
  if (typeof origin !== "string") {
    return false;
  }
  if (origin === "null") {
    return true;
  }
  try {
    const url = new URL(origin);
    return url.protocol === "https:" ||
        url.protocol === "http:" ||
        url.protocol === "chrome-extension:";
  } catch (e) {
    return false;
  }
}

/**
 * @param {Object} body
 * @return {boolean}
 */
function isJsonRpcNotification(body) {
  return body &&
      typeof body === "object" &&
      body.jsonrpc === "2.0" &&
      typeof body.method === "string" &&
      !Object.prototype.hasOwnProperty.call(body, "id");
}

/**
 * @param {unknown} id
 * @param {Object} result
 * @return {Object}
 */
function jsonRpcResult(id, result) {
  return {jsonrpc: "2.0", id: id === undefined ? null : id, result};
}

/**
 * @param {unknown} id
 * @param {number} code
 * @param {string} message
 * @param {unknown} [data]
 * @return {Object}
 */
function jsonRpcError(id, code, message, data) {
  const error = {code, message};
  if (data !== undefined) {
    error.data = data;
  }
  return {jsonrpc: "2.0", id: id === undefined ? null : id, error};
}

/**
 * @param {Object} spotApi createSpotApi() instance
 * @return {Function}
 */
function createMcpHandler(spotApi) {
  /**
   * @param {Object} args
   * @param {string} clientId
   * @return {Promise<Object>}
   */
  async function callSearchSpots(args, clientId) {
    const input = args || {};
    const result = await spotApi.searchSpotsForApi({
      query: input.query,
      limit: input.limit,
      minLat: input.minLat,
      maxLat: input.maxLat,
      minLng: input.minLng,
      maxLng: input.maxLng,
    });
    await spotApi.recordApiClientUsage(clientId);
    return result;
  }

  /**
   * @param {Object} args
   * @param {string} clientId
   * @return {Promise<Object>}
   */
  async function callGetSpot(args, clientId) {
    const spotId = args && args.spotId;
    const spot = await spotApi.getSpotForApi(spotId);
    await spotApi.recordApiClientUsage(clientId);
    return spot;
  }

  /**
   * @param {Object} args
   * @param {string} clientId
   * @return {Promise<Object>}
   */
  async function callListSpotListSpots(args, clientId) {
    const listId = args && args.listId;
    const result = await spotApi.listSpotsForSpotList(listId);
    await spotApi.recordApiClientUsage(clientId);
    return result;
  }

  /**
   * @param {Object} body
   * @param {string} clientId
   * @return {Promise<Object|null>}
   */
  async function handleJsonRpc(body, clientId) {
    if (!body || body.jsonrpc !== "2.0" || typeof body.method !== "string") {
      return jsonRpcError(
          body && body.id !== undefined ? body.id : null,
          -32600,
          "Invalid Request",
      );
    }

    const {method, id, params} = body;

    if (method === "notifications/initialized" ||
        method.startsWith("notifications/")) {
      return null;
    }

    if (method === "initialize") {
      return jsonRpcResult(id, {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: {
          tools: {},
        },
        serverInfo: SERVER_INFO,
        instructions: SERVER_INSTRUCTIONS,
      });
    }

    if (method === "ping") {
      return jsonRpcResult(id, {});
    }

    if (method === "tools/list") {
      return jsonRpcResult(id, {tools: TOOLS});
    }

    if (method === "tools/call") {
      const name = params && params.name;
      const args = (params && params.arguments) || {};
      if (typeof name !== "string") {
        return jsonRpcError(id, -32602, "Invalid params: name is required");
      }
      try {
        let toolResult;
        if (name === "search_spots") {
          toolResult = await callSearchSpots(args, clientId);
        } else if (name === "get_spot") {
          toolResult = await callGetSpot(args, clientId);
        } else if (name === "list_spot_list_spots") {
          toolResult = await callListSpotListSpots(args, clientId);
        } else {
          return jsonRpcResult(id, {
            content: [{type: "text", text: `Unknown tool: ${name}`}],
            isError: true,
          });
        }
        return jsonRpcResult(id, {
          content: [{
            type: "text",
            text: JSON.stringify(toolResult, null, 2),
          }],
        });
      } catch (error) {
        if (error instanceof SpotApiError) {
          return jsonRpcResult(id, {
            content: [{type: "text", text: error.message}],
            isError: true,
          });
        }
        console.error("mcp tools/call error:", error);
        return jsonRpcResult(id, {
          content: [{type: "text", text: "Internal server error"}],
          isError: true,
        });
      }
    }

    return jsonRpcError(id, -32601, `Method not found: ${method}`);
  }

  return async function mcpHandler(req, res) {
    try {
      const origin = req.headers.origin || req.headers.Origin;
      if (!isAllowedOrigin(origin)) {
        res.status(403).json(
            jsonRpcError(null, -32000, "Forbidden origin"),
        );
        return;
      }

      if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
      }

      if (req.method === "GET") {
        res.status(405)
            .set("Allow", "POST, OPTIONS")
            .json({error: "MCP endpoint accepts POST JSON-RPC only"});
        return;
      }

      if (req.method !== "POST") {
        res.status(405)
            .set("Allow", "POST, OPTIONS")
            .json({error: "Method not allowed"});
        return;
      }

      let clientId;
      try {
        const auth = await spotApi.authenticateApiClient(req);
        clientId = auth.clientId;
      } catch (error) {
        if (error instanceof SpotApiError) {
          res.status(error.status).json({error: error.message});
          return;
        }
        throw error;
      }

      let message = req.body;
      if (Buffer.isBuffer(message)) {
        try {
          message = JSON.parse(message.toString("utf8"));
        } catch (e) {
          res.status(400).json(jsonRpcError(null, -32700, "Parse error"));
          return;
        }
      } else if (typeof message === "string") {
        try {
          message = JSON.parse(message);
        } catch (e) {
          res.status(400).json(jsonRpcError(null, -32700, "Parse error"));
          return;
        }
      } else if (
        (message === undefined || message === null ||
          (typeof message === "object" && !Array.isArray(message) &&
            Object.keys(message).length === 0)) &&
        req.rawBody
      ) {
        try {
          const raw = Buffer.isBuffer(req.rawBody) ?
            req.rawBody.toString("utf8") :
            String(req.rawBody);
          message = JSON.parse(raw);
        } catch (e) {
          res.status(400).json(jsonRpcError(null, -32700, "Parse error"));
          return;
        }
      }

      if (!message || typeof message !== "object") {
        res.status(400).json(jsonRpcError(null, -32700, "Parse error"));
        return;
      }

      if (isJsonRpcNotification(message)) {
        await handleJsonRpc(message, clientId);
        res.status(202).send("");
        return;
      }

      const response = await handleJsonRpc(message, clientId);
      if (response === null) {
        res.status(202).send("");
        return;
      }
      res.set("Content-Type", "application/json; charset=utf-8");
      res.status(200).json(response);
    } catch (error) {
      console.error("mcpServer error:", error);
      res.status(500).json(
          jsonRpcError(null, -32603, "Internal server error"),
      );
    }
  };
}

module.exports = {
  PROTOCOL_VERSION,
  SERVER_INFO,
  SERVER_INSTRUCTIONS,
  TOOLS,
  isAllowedOrigin,
  isJsonRpcNotification,
  jsonRpcResult,
  jsonRpcError,
  createMcpHandler,
};
