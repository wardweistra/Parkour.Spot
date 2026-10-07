/* eslint-disable max-len */
/**
 * Generate and write about.parkour.spot Firestore snapshots, then optionally
 * trigger a GitHub Actions rebuild via repository_dispatch.
 */

const {getFirestore} = require("firebase-admin/firestore");
const {
  buildPlaceSnapshots,
  attachEventsAndBuildIndexes,
} = require("./lib/about-snapshots");

const db = getFirestore();

const GITHUB_REPO = process.env.ABOUT_GITHUB_REPO || "wardweistra/Parkour.Spot";
const GITHUB_DISPATCH_TYPE = "about-rebuild";

/**
 * Write snapshot docs in batches.
 * @param {Object} payload
 * @return {Promise<{countries: number, cities: number, events: number}>}
 */
async function writeAboutSnapshots(payload) {
  const {
    aboutIndex,
    eventsIndex,
    countryDocs,
    cityDocs,
    eventDetails,
  } = payload;

  await db.collection("snapshots").doc("about-index").set(aboutIndex);
  await db.collection("snapshots").doc("about-events-index").set(eventsIndex);

  // Ensure parent doc exists for subcollections
  await db.collection("snapshots").doc("about").set({
    updatedAt: aboutIndex.generatedAt,
  }, {merge: true});

  const writes = [];
  for (const [id, doc] of countryDocs.entries()) {
    writes.push(
        db.collection("snapshots").doc("about")
            .collection("countries").doc(id).set(doc),
    );
  }
  for (const [id, doc] of cityDocs.entries()) {
    writes.push(
        db.collection("snapshots").doc("about")
            .collection("cities").doc(id).set(doc),
    );
  }
  for (const [slug, doc] of eventDetails.entries()) {
    writes.push(
        db.collection("snapshots").doc("about")
            .collection("events").doc(slug).set(doc),
    );
  }

  const CHUNK = 40;
  for (let i = 0; i < writes.length; i += CHUNK) {
    await Promise.all(writes.slice(i, i + CHUNK));
  }

  return {
    countries: countryDocs.size,
    cities: cityDocs.size,
    events: eventDetails.size,
  };
}

/**
 * Fetch spots + events, build snapshots, write to Firestore.
 * @param {Object} [options]
 * @return {Promise<Object>}
 */
async function generateAboutSnapshots(options = {}) {
  const now = options.now || new Date();
  console.log("About snapshots: fetching spots...");

  const spotsSnap = await db.collection("spots")
      .where("hidden", "==", false)
      .get();
  const spots = spotsSnap.docs.map((doc) => ({id: doc.id, ...doc.data()}));

  console.log(`About snapshots: ${spots.length} non-hidden spots`);

  const eventsSnap = await db.collection("events").get();
  const events = eventsSnap.docs.map((doc) => ({id: doc.id, ...doc.data()}));
  console.log(`About snapshots: ${events.length} events scanned`);

  const placeState = buildPlaceSnapshots(spots, {
    generatedAt: now.toISOString(),
  });
  const assembled = attachEventsAndBuildIndexes(placeState, events, now);
  const counts = await writeAboutSnapshots(assembled);

  console.log("About snapshots written:", counts);
  return {
    generatedAt: assembled.aboutIndex.generatedAt,
    ...counts,
  };
}

/**
 * Trigger GitHub Actions via repository_dispatch.
 * Requires secret GITHUB_ABOUT_DEPLOY_TOKEN (fine-grained or classic with repo scope).
 * @return {Promise<Object>}
 */
async function dispatchAboutRebuild() {
  const token = process.env.GITHUB_ABOUT_DEPLOY_TOKEN;
  if (!token) {
    console.warn("GITHUB_ABOUT_DEPLOY_TOKEN not set; skipping about rebuild dispatch");
    return {ok: false, skipped: true};
  }

  const url = `https://api.github.com/repos/${GITHUB_REPO}/dispatches`;
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Accept": "application/vnd.github+json",
      "Authorization": `Bearer ${token}`,
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "parkourspot-about-snapshots",
    },
    body: JSON.stringify({
      event_type: GITHUB_DISPATCH_TYPE,
      client_payload: {
        source: "generateAboutSnapshots",
        at: new Date().toISOString(),
      },
    }),
  });

  if (!res.ok) {
    const text = await res.text();
    console.error("About rebuild dispatch failed:", res.status, text);
    return {ok: false, status: res.status, error: text};
  }

  console.log("About rebuild dispatch accepted");
  return {ok: true, status: res.status};
}

/**
 * Full pipeline: snapshots + optional GitHub dispatch.
 * @return {Promise<Object>}
 */
async function generateAboutSnapshotsAndDispatch() {
  const result = await generateAboutSnapshots();
  const dispatch = await dispatchAboutRebuild();
  return {...result, dispatch};
}

module.exports = {
  generateAboutSnapshots,
  generateAboutSnapshotsAndDispatch,
  writeAboutSnapshots,
  dispatchAboutRebuild,
  GITHUB_DISPATCH_TYPE,
};
