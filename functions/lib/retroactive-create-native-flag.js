const GET_ALL_CHUNK = 200;
const BATCH_SIZE = 500;

/**
 * Marks native original spots as created via Create Native when any duplicate
 * points to them via duplicateOf.
 * @param {object} options
 * @param {object} options.db Firestore instance
 * @param {object} options.FieldValue admin.firestore.FieldValue
 * @return {Promise<object>}
 */
async function markRetroactiveCreateNativeFlags({db, FieldValue}) {
  const duplicatesSnap = await db
      .collection("spots")
      .where("duplicateOf", "!=", null)
      .select("duplicateOf")
      .get();

  const targetIds = new Set();
  for (const doc of duplicatesSnap.docs) {
    const duplicateOf = doc.data()?.duplicateOf;
    if (typeof duplicateOf === "string" && duplicateOf.trim().length > 0) {
      targetIds.add(duplicateOf.trim());
    }
  }

  if (targetIds.size === 0) {
    return {
      candidateCount: 0,
      existingTargetCount: 0,
      updatedCount: 0,
      alreadyMarkedCount: 0,
      skippedNonNativeCount: 0,
      missingTargetCount: 0,
    };
  }

  const targetIdList = Array.from(targetIds);
  let existingTargetCount = 0;
  let updatedCount = 0;
  let alreadyMarkedCount = 0;
  let skippedNonNativeCount = 0;
  let missingTargetCount = 0;

  let batch = db.batch();
  let ops = 0;
  for (let i = 0; i < targetIdList.length; i += GET_ALL_CHUNK) {
    const chunk = targetIdList.slice(i, i + GET_ALL_CHUNK);
    const refs = chunk.map((spotId) => db.collection("spots").doc(spotId));
    const docs = await db.getAll(...refs);

    for (let j = 0; j < docs.length; j++) {
      const spotDoc = docs[j];
      if (!spotDoc.exists) {
        missingTargetCount++;
        continue;
      }

      existingTargetCount++;
      const data = spotDoc.data() || {};
      const rawSpotSource = data.spotSource;
      const isNative = rawSpotSource == null ||
          String(rawSpotSource).trim() === "";
      if (!isNative) {
        skippedNonNativeCount++;
        continue;
      }

      if (data.createdFromCreateNative === true) {
        alreadyMarkedCount++;
        continue;
      }

      batch.update(spotDoc.ref, {
        createdFromCreateNative: true,
        updatedAt: FieldValue.serverTimestamp(),
      });
      updatedCount++;
      ops++;

      if (ops >= BATCH_SIZE) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
  }

  if (ops > 0) {
    await batch.commit();
  }

  return {
    candidateCount: targetIds.size,
    existingTargetCount,
    updatedCount,
    alreadyMarkedCount,
    skippedNonNativeCount,
    missingTargetCount,
  };
}

module.exports = {
  markRetroactiveCreateNativeFlags,
};
