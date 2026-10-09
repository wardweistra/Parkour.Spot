/* eslint-disable max-len */
/**
 * Transactional exclusive worker lock for spot sync sources.
 * Distinguishes an unfinished job (syncInProgress) from an active Cloud Function
 * worker (syncStartedAt lease) so partial timeouts can be resumed immediately.
 */

/** Abandoned worker lease recovery window (callable timeout is up to 1 hour). */
const SPOT_SYNC_LOCK_STALE_MS = 2 * 60 * 60 * 1000;

const MODE_START = "start";
const MODE_RESUME = "resume";

/**
 * Thrown when a spot-sync lock cannot be acquired.
 * Callables should map this to HttpsError failed-precondition.
 */
class SpotSyncLockError extends Error {
  /**
   * @param {string} message
   */
  constructor(message) {
    super(message);
    this.name = "SpotSyncLockError";
  }
}

/**
 * @param {*} value
 * @return {Date|null}
 */
function toDateOrNull(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (typeof value.toDate === "function") {
    try {
      return value.toDate();
    } catch (_) {
      return null;
    }
  }
  return null;
}

/**
 * @param {Object} data
 * @param {number} nowMs
 * @return {Object} Lease inspection result
 */
function inspectLease(data, nowMs) {
  const startedAt = toDateOrNull(data && data.syncStartedAt);
  if (!startedAt) {
    return {held: false, startedAt: null, ageMs: 0};
  }
  const ageMs = Math.max(0, nowMs - startedAt.getTime());
  const held = ageMs < SPOT_SYNC_LOCK_STALE_MS;
  return {held, startedAt, ageMs};
}

/**
 * Acquires an exclusive spot-sync worker lock on a syncSources document.
 * @param {FirebaseFirestore.Firestore} db
 * @param {Object} FieldValue
 * @param {FirebaseFirestore.DocumentReference} sourceRef
 * @param {Object} options
 * @param {"start"|"resume"} options.mode
 * @param {number} [options.nowMs] - injectable clock for tests
 * @return {Promise<void>}
 */
async function acquireSpotSyncLock(db, FieldValue, sourceRef, options = {}) {
  const mode = options.mode === MODE_RESUME ? MODE_RESUME : MODE_START;
  const nowMs = typeof options.nowMs === "number" ? options.nowMs : Date.now();

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(sourceRef);
    if (!snap.exists) {
      throw new Error("Sync source not found");
    }
    const data = snap.data() || {};
    const inProgress = data.syncInProgress === true;
    const lease = inspectLease(data, nowMs);

    if (mode === MODE_START) {
      if (inProgress) {
        // Missing or fresh lease: another run owns the job (active or waiting
        // for resume after a partial). Only a stale lease may be stolen.
        if (!lease.startedAt || lease.held) {
          throw new SpotSyncLockError(
              "Sync already in progress for this source. " +
              "Wait for it to finish or resume it, then try again.",
          );
        }
      }
    } else {
      if (!inProgress) {
        throw new SpotSyncLockError("No sync in progress for this source");
      }
      if (lease.held) {
        throw new SpotSyncLockError(
            "Another sync worker is already running for this source. " +
            "Wait for it to finish, then try again.",
        );
      }
    }

    tx.update(sourceRef, {
      syncInProgress: true,
      syncStartedAt: FieldValue.serverTimestamp(),
    });
  });
}

/**
 * @param {*} error
 * @return {boolean}
 */
function isSpotSyncLockError(error) {
  return Boolean(
      error &&
      (error instanceof SpotSyncLockError ||
        error.name === "SpotSyncLockError"),
  );
}

module.exports = {
  SPOT_SYNC_LOCK_STALE_MS,
  MODE_START,
  MODE_RESUME,
  SpotSyncLockError,
  isSpotSyncLockError,
  inspectLease,
  acquireSpotSyncLock,
};
