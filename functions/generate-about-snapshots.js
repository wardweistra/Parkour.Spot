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
const {activityWindowStart, buildAboutStats} = require("./lib/about-stats");

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
 * Run a count() aggregate. A failed count becomes null so one missing index
 * or collection does not block the nightly snapshot.
 * @param {string} label
 * @param {Object} query
 * @return {Promise<number|null>}
 */
async function safeCount(label, query) {
  try {
    const snap = await query.count().get();
    return snap.data().count;
  } catch (error) {
    console.warn(`About stats: ${label} count failed:`, error.message);
    return null;
  }
}

/**
 * @return {Promise<number|null>}
 */
async function latestMonthlyActiveUsers() {
  try {
    const snap = await db.collection("userActivityMetrics")
        .orderBy("date", "desc")
        .limit(1)
        .get();
    if (snap.empty) return null;
    const mau = Number(snap.docs[0].data().mau);
    return Number.isFinite(mau) ? mau : null;
  } catch (error) {
    console.warn("About stats: MAU lookup failed:", error.message);
    return null;
  }
}

/**
 * Activity and curation totals for the about stats block.
 * @param {Date} now
 * @return {Promise<Object>}
 */
async function loadActivityCounts(now) {
  const since = activityWindowStart(now);
  const [
    deduplicatedCount,
    ratingCount,
    ratings30d,
    checkIns30d,
    plansOpen30d,
    plansConverted30d,
    improvementSuggestionCount,
    monthlyActiveUsers,
  ] = await Promise.all([
    safeCount("deduplicated", db.collection("spots").where("duplicateOf", "!=", null)),
    safeCount("ratings", db.collection("ratings")),
    safeCount("ratings30d", db.collection("ratings").where("createdAt", ">=", since)),
    safeCount("checkIns30d", db.collection("spotCheckIns").where("checkedInAt", ">=", since)),
    safeCount("plans30d", db.collection("spotTrainingPlans").where("createdAt", ">=", since)),
    // Plans are deleted when converted to a check-in; the check-in keeps the plan's createdAt.
    safeCount("convertedPlans30d", db.collection("spotCheckIns").where("convertedPlanCreatedAt", ">=", since)),
    safeCount("spotReports", db.collection("spotReports")),
    latestMonthlyActiveUsers(),
  ]);
  const trainingPlans30d = plansOpen30d == null && plansConverted30d == null ?
    null :
    (plansOpen30d || 0) + (plansConverted30d || 0);
  return {
    deduplicatedCount,
    ratingCount,
    ratings30d,
    checkIns30d,
    trainingPlans30d,
    improvementSuggestionCount,
    monthlyActiveUsers,
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
  assembled.aboutIndex.stats = buildAboutStats({
    spots,
    upcomingEvents: assembled.eventsIndex.events,
    counts: await loadActivityCounts(now),
    now,
  });
  console.log("About stats:", assembled.aboutIndex.stats);
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
