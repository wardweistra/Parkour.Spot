/**
 * Best-effort auditLog writes for Cloud Functions.
 * Never throws to callers — logging must not break mutations.
 */

/**
 * Resolves actor uid + display name from an onCall request.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} request
 * @return {Promise<{userId: (string|null), userName: (string|null)}>}
 */
async function resolveAuditActor(db, request) {
  const userId = request && request.auth && request.auth.uid ?
    String(request.auth.uid) :
    null;
  if (!userId) {
    return {userId: null, userName: null};
  }
  try {
    const snap = await db.collection("users").doc(userId).get();
    if (!snap.exists) {
      return {userId, userName: null};
    }
    const data = snap.data() || {};
    const displayName = typeof data.displayName === "string" ?
      data.displayName.trim() :
      "";
    const fallbackName = typeof data.name === "string" ?
      data.name.trim() :
      "";
    const name = displayName || fallbackName || null;
    return {userId, userName: name};
  } catch (error) {
    console.warn("resolveAuditActor failed:", error && error.message);
    return {userId, userName: null};
  }
}

/**
 * Writes one auditLog document. Swallows errors.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} FieldValue
 * @param {Object} payload
 * @return {Promise<void>}
 */
async function writeAuditLog(db, FieldValue, payload) {
  try {
    if (!payload || typeof payload.action !== "string" || !payload.action) {
      console.warn("writeAuditLog skipped: missing action");
      return;
    }
    const doc = {
      action: payload.action,
      userId: payload.userId != null ? payload.userId : null,
      userName: payload.userName != null ? payload.userName : null,
      timestamp: FieldValue.serverTimestamp(),
    };
    if (payload.spotId != null) doc.spotId = payload.spotId;
    if (payload.eventId != null) doc.eventId = payload.eventId;
    if (payload.reportId != null) doc.reportId = payload.reportId;
    if (payload.changes && typeof payload.changes === "object") {
      doc.changes = payload.changes;
    }
    if (payload.metadata && typeof payload.metadata === "object") {
      doc.metadata = payload.metadata;
    }
    await db.collection("auditLog").add(doc);
  } catch (error) {
    console.error(
        "writeAuditLog failed:",
        error && error.message ? error.message : error,
    );
  }
}

module.exports = {
  resolveAuditActor,
  writeAuditLog,
};
