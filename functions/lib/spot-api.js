/**
 * Spot API helpers shared by REST (/api/v1) and MCP.
 */

const {hashApiKey, serializeSpotForApi} = require("./api-helpers");
const {
  effectiveSpotIdsFromList,
  isExpandableListVisibility,
} = require("./event-map-pins");
const {resolveApiImageUrls} = require("./url-helpers");

const API_CLIENTS_COLLECTION = "apiClients";
const SPOT_GET_ALL_CHUNK = 10;

/**
 * Note from the first section entry for each spot. Flat lists have none.
 * @param {Object} listData
 * @return {Map<string, string>}
 */
function firstListNotesBySpotId(listData) {
  const notes = new Map();
  const sections = listData && listData.sections;
  if (!Array.isArray(sections) || sections.length === 0) {
    return notes;
  }
  for (const section of sections) {
    const entries = section && Array.isArray(section.entries) ?
      section.entries :
      [];
    for (const entry of entries) {
      const spotId = entry && typeof entry.spotId === "string" ?
        entry.spotId.trim() :
        "";
      if (spotId.length === 0 || notes.has(spotId)) continue;
      const note = entry && typeof entry.note === "string" ?
        entry.note.trim() :
        "";
      notes.set(spotId, note);
    }
  }
  return notes;
}

/**
 * Stable visibility string for API clients. Missing means unlisted.
 * @param {*} visibility
 * @return {string}
 */
function listVisibilityLabel(visibility) {
  if (typeof visibility !== "string") return "unlisted";
  const normalized = visibility.trim().toLowerCase();
  if (normalized === "public" || normalized === "unlisted" ||
      normalized === "private") {
    return normalized;
  }
  return "unlisted";
}

/**
 * Same spot payload as getSpotForApi, before image URL resolution.
 * @param {FirebaseFirestore.DocumentSnapshot} snap
 * @return {Object}
 */
function serializeSpotSnapshot(snap) {
  const spotData = snap.data() || {};
  const out = serializeSpotForApi({
    id: snap.id,
    ...spotData,
  });
  out.hidden = spotData.hidden === true;
  out.duplicateOf = spotData.duplicateOf || null;
  return out;
}

/**
 * API/domain error with an HTTP status for REST and MCP mapping.
 */
class SpotApiError extends Error {
  /**
   * @param {number} status
   * @param {string} message
   */
  constructor(status, message) {
    super(message);
    this.status = status;
    this.name = "SpotApiError";
  }
}

/**
 * Extract API key from X-API-Key or Authorization: Bearer.
 * @param {Object} req
 * @return {string}
 */
function extractApiKeyFromRequest(req) {
  const headers = (req && req.headers) || {};
  const authHeader = headers["authorization"] || headers["Authorization"];
  if (authHeader && typeof authHeader === "string" &&
      authHeader.startsWith("Bearer ")) {
    return authHeader.substring(7).trim();
  }
  const raw = headers["x-api-key"] || headers["X-API-Key"] || "";
  return typeof raw === "string" ? raw.trim() : "";
}

/**
 * @param {unknown} raw
 * @param {number} defaultLimit
 * @return {number}
 */
function parseLimit(raw, defaultLimit = 20) {
  const parsedLimit = Number(raw);
  if (!Number.isFinite(parsedLimit)) {
    return defaultLimit;
  }
  return Math.max(1, Math.min(Math.floor(parsedLimit), 100));
}

/**
 * @param {Object} deps
 * @param {FirebaseFirestore.Firestore} deps.db
 * @param {Object} deps.bucket
 * @param {Object} deps.FieldValue
 * @param {Function} deps.executeSearchSpotsByTitle
 * @param {Function} deps.executeTopSpotsInBoundsQuery
 * @return {Object}
 */
function createSpotApi(deps) {
  const {
    db,
    bucket,
    FieldValue,
    executeSearchSpotsByTitle,
    executeTopSpotsInBoundsQuery,
  } = deps;

  /**
   * @param {Object} req
   * @return {Promise<{clientId: string}>}
   */
  async function authenticateApiClient(req) {
    const apiKey = extractApiKeyFromRequest(req);
    if (!apiKey) {
      throw new SpotApiError(
          401,
          "API key required. Use X-API-Key or Authorization: Bearer",
      );
    }
    const apiKeyHash = hashApiKey(apiKey);
    const clientsSnap = await db.collection(API_CLIENTS_COLLECTION)
        .where("apiKeyHash", "==", apiKeyHash)
        .where("active", "==", true)
        .limit(1)
        .get();
    if (clientsSnap.empty) {
      throw new SpotApiError(401, "Invalid or inactive API key");
    }
    return {clientId: clientsSnap.docs[0].id};
  }

  /**
   * @param {string} clientId
   * @return {Promise<void>}
   */
  async function recordApiClientUsage(clientId) {
    const dateId = new Date().toISOString().slice(0, 10);
    await db.runTransaction(async (transaction) => {
      transaction.update(db.collection(API_CLIENTS_COLLECTION).doc(clientId), {
        lastUsedAt: FieldValue.serverTimestamp(),
      });
      const usageRef = db.collection(API_CLIENTS_COLLECTION)
          .doc(clientId)
          .collection("usage")
          .doc(dateId);
      transaction.set(usageRef, {
        date: dateId,
        count: FieldValue.increment(1),
        lastUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
    });
  }

  /**
   * @param {Array<Object>} spots
   * @return {Promise<Array<Object>>}
   */
  async function resolveSpotImages(spots) {
    for (const spot of spots) {
      if (Array.isArray(spot.imageUrls)) {
        spot.imageUrls = await resolveApiImageUrls(spot.imageUrls, bucket);
      }
    }
    return spots;
  }

  /**
   * Search by title query and/or geographic bounds.
   * @param {Object} params
   * @return {Promise<{spots: Array, totalCount: number, shownCount: number}>}
   */
  async function searchSpotsForApi(params) {
    const input = params || {};
    const query = typeof input.query === "string" ? input.query.trim() : "";
    if (query.length > 0 && query.length < 2) {
      throw new SpotApiError(
          400,
          "Query param q must be at least 2 characters",
      );
    }
    const hasSearchQuery = query.length >= 2;
    const minLat = Number(input.minLat);
    const maxLat = Number(input.maxLat);
    const minLng = Number(input.minLng);
    const maxLng = Number(input.maxLng);
    const hasBounds = Number.isFinite(minLat) && Number.isFinite(maxLat) &&
        Number.isFinite(minLng) && Number.isFinite(maxLng);

    if (hasSearchQuery) {
      const limit = parseLimit(input.limit, 20);
      const result = await executeSearchSpotsByTitle({query, limit});
      if (!result.success) {
        throw new SpotApiError(500, result.error || "Search failed");
      }
      const spots = await resolveSpotImages(result.spots || []);
      return {
        spots,
        totalCount: spots.length,
        shownCount: spots.length,
      };
    }

    if (!hasBounds) {
      throw new SpotApiError(
          400,
          "Query params q (search by name) or minLat, maxLat, minLng, maxLng " +
          "(search in bounds) are required",
      );
    }

    const result = await executeTopSpotsInBoundsQuery({
      minLat,
      maxLat,
      minLng,
      maxLng,
      limit: parseLimit(input.limit, 100),
    });
    if (!result.success) {
      throw new SpotApiError(500, result.error || "Query failed");
    }
    const spots = await resolveSpotImages(result.spots || []);
    return {
      spots,
      totalCount: result.totalCount,
      shownCount: result.shownCount,
    };
  }

  /**
   * @param {string} spotId
   * @return {Promise<Object>}
   */
  async function getSpotForApi(spotId) {
    if (!spotId || typeof spotId !== "string") {
      throw new SpotApiError(400, "spotId is required");
    }
    const spotSnap = await db.collection("spots").doc(spotId).get();
    if (!spotSnap.exists) {
      throw new SpotApiError(404, "Spot not found");
    }
    const out = serializeSpotSnapshot(spotSnap);
    if (Array.isArray(out.imageUrls)) {
      out.imageUrls = await resolveApiImageUrls(out.imageUrls, bucket);
    }
    return out;
  }

  /**
   * Every spot on a public or unlisted list, in list order.
   * Missing and private lists both 404 so a private id is not confirmed.
   * @param {string} listId
   * @return {Promise<Object>}
   */
  async function listSpotsForSpotList(listId) {
    const trimmed = typeof listId === "string" ? listId.trim() : "";
    if (!trimmed) {
      throw new SpotApiError(400, "listId is required");
    }
    const listSnap = await db.collection("spotLists").doc(trimmed).get();
    if (!listSnap.exists) {
      throw new SpotApiError(404, "Spot list not found");
    }
    const listData = listSnap.data() || {};
    if (!isExpandableListVisibility(listData.visibility)) {
      throw new SpotApiError(404, "Spot list not found");
    }

    const spotIds = effectiveSpotIdsFromList(listData);
    const notes = firstListNotesBySpotId(listData);
    const snapsById = new Map();
    for (let i = 0; i < spotIds.length; i += SPOT_GET_ALL_CHUNK) {
      const chunk = spotIds.slice(i, i + SPOT_GET_ALL_CHUNK);
      const refs = chunk.map((id) => db.collection("spots").doc(id));
      // eslint-disable-next-line no-await-in-loop
      const snaps = await db.getAll(...refs);
      for (const snap of snaps) {
        if (snap && snap.exists) {
          snapsById.set(snap.id, snap);
        }
      }
    }

    const spots = [];
    for (const spotId of spotIds) {
      const snap = snapsById.get(spotId);
      if (!snap) continue;
      const out = serializeSpotSnapshot(snap);
      const note = notes.get(spotId);
      if (note) out.listNote = note;
      spots.push(out);
    }
    await resolveSpotImages(spots);
    return {
      list: {
        id: trimmed,
        name: typeof listData.name === "string" ? listData.name : "",
        visibility: listVisibilityLabel(listData.visibility),
      },
      spots,
      totalCount: spots.length,
      shownCount: spots.length,
    };
  }

  return {
    authenticateApiClient,
    recordApiClientUsage,
    searchSpotsForApi,
    getSpotForApi,
    listSpotsForSpotList,
  };
}

module.exports = {
  API_CLIENTS_COLLECTION,
  SpotApiError,
  extractApiKeyFromRequest,
  parseLimit,
  createSpotApi,
};
