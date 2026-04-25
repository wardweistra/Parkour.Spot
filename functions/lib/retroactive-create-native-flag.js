const GET_ALL_CHUNK = 200;

/**
 * Marks native original spots as created via Create Native when any duplicate
 * points to them via duplicateOf.
 * @param {object} options
 * @param {object} options.db Firestore instance
 * @param {object} options.FieldValue admin.firestore.FieldValue
 * @return {Promise<object>}
 */
async function markRetroactiveCreateNativeFlags({db, FieldValue}) {
  let duplicatesQuery = db
      .collection("spots")
      .where("duplicateOf", "!=", null);
  if (typeof duplicatesQuery.select === "function") {
    duplicatesQuery = duplicatesQuery.select("duplicateOf");
  }
  const duplicatesSnap = await duplicatesQuery.get();

  const targetIds = new Set();
  for (const doc of duplicatesSnap.docs) {
    const duplicateOf = doc.data()?.duplicateOf;
    if (typeof duplicateOf === "string" && duplicateOf.trim().length > 0) {
      targetIds.add(duplicateOf.trim());
    }
  }

  if (targetIds.size === 0) {
    return {
      duplicateTargetsFound: 0,
      processed: 0,
      marked: 0,
      skippedAlreadyMarked: 0,
      skippedImported: 0,
      skippedMissing: 0,
      failed: 0,
      failedSpotIds: [],
    };
  }

  const targetIdList = Array.from(targetIds);
  let processed = 0;
  let marked = 0;
  let skippedAlreadyMarked = 0;
  let skippedImported = 0;
  let skippedMissing = 0;
  let failed = 0;
  const failedSpotIds = [];

  for (let i = 0; i < targetIdList.length; i += GET_ALL_CHUNK) {
    const chunk = targetIdList.slice(i, i + GET_ALL_CHUNK);
    const refs = chunk.map((spotId) => db.collection("spots").doc(spotId));
    const docs = typeof db.getAll === "function" ?
      await db.getAll(...refs) :
      await Promise.all(refs.map((ref) => ref.get()));

    for (let j = 0; j < docs.length; j++) {
      const spotDoc = docs[j];
      if (!spotDoc.exists) {
        skippedMissing++;
        continue;
      }

      processed++;
      const data = spotDoc.data() || {};
      const rawSpotSource = data.spotSource;
      const isNative = rawSpotSource == null ||
          String(rawSpotSource).trim() === "";
      if (!isNative) {
        skippedImported++;
        continue;
      }

      if (data.createdFromCreateNative === true) {
        skippedAlreadyMarked++;
        continue;
      }

      try {
        await spotDoc.ref.update({
          createdFromCreateNative: true,
          updatedAt: FieldValue.serverTimestamp(),
        });
        marked++;
      } catch (error) {
        failed++;
        failedSpotIds.push(spotDoc.id);
      }
    }
  }

  return {
    duplicateTargetsFound: targetIds.size,
    processed,
    marked,
    skippedAlreadyMarked,
    skippedImported,
    skippedMissing,
    failed,
    failedSpotIds,
  };
}

module.exports = {
  markRetroactiveCreateNativeFlags,
};
