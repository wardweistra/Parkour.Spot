/**
 * One-off backfill: write `publicProfiles/{uid}` for every existing user.
 *
 * New and updated users are mirrored by the onUserWrittenSyncPublicProfile
 * trigger; this covers accounts that existed before it was deployed. Safe to
 * re-run: it only writes documents whose content differs.
 *
 *   cd functions
 *   GOOGLE_APPLICATION_CREDENTIALS=../firebase-service-account.json \
 *     node scripts/backfill-public-profiles.js [--dry-run]
 */

const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {
  buildPublicProfile,
  publicProfilesEqual,
} = require("../lib/public-profile");

const dryRun = process.argv.includes("--dry-run");

/** Backfills all public profiles in pages of 300 users. */
async function main() {
  initializeApp();
  const db = getFirestore();
  const pageSize = 300;
  let lastDoc = null;
  let scanned = 0;
  let written = 0;

  for (;;) {
    let query = db.collection("users").orderBy("__name__").limit(pageSize);
    if (lastDoc) query = query.startAfter(lastDoc);
    const page = await query.get();
    if (page.empty) break;

    const refs = page.docs.map((doc) =>
      db.collection("publicProfiles").doc(doc.id));
    const existing = await db.getAll(...refs);
    const batch = db.batch();
    let batchCount = 0;
    page.docs.forEach((doc, i) => {
      const next = buildPublicProfile(doc.data());
      const current = existing[i].exists ? existing[i].data() : null;
      if (publicProfilesEqual(current, next)) return;
      batch.set(refs[i], next);
      batchCount++;
    });
    if (batchCount > 0 && !dryRun) await batch.commit();

    scanned += page.size;
    written += batchCount;
    lastDoc = page.docs[page.docs.length - 1];
  }

  console.log(
      `${dryRun ? "[dry run] would write" : "Wrote"} ${written} of ` +
      `${scanned} public profiles.`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
