const {describe, it} = require("node:test");
const assert = require("node:assert/strict");

/**
 * Mirrors pair deduplication in findDuplicateSpots (sorted spot id key).
 */
function duplicatePairKey(spotIdA, spotIdB) {
  return [spotIdA, spotIdB].sort().join("|");
}

function shouldIncludeCandidate({
  candidateSpotSource,
  sourceId,
  includeWithinSourceClusters,
  pairKey,
  seenPairKeys,
}) {
  const candidateFromSameSource = candidateSpotSource === sourceId;
  if (candidateFromSameSource && !includeWithinSourceClusters) {
    return false;
  }
  if (seenPairKeys.has(pairKey)) {
    return false;
  }
  return true;
}

describe("findDuplicateSpots candidate filtering", () => {
  it("skips same-source candidates when within-source clustering is disabled", () => {
    assert.equal(
        shouldIncludeCandidate({
          candidateSpotSource: "feed-a",
          sourceId: "feed-a",
          includeWithinSourceClusters: false,
          pairKey: "a|b",
          seenPairKeys: new Set(),
        }),
        false,
    );
  });

  it("includes same-source candidates when within-source clustering is enabled", () => {
    assert.equal(
        shouldIncludeCandidate({
          candidateSpotSource: "feed-a",
          sourceId: "feed-a",
          includeWithinSourceClusters: true,
          pairKey: "a|b",
          seenPairKeys: new Set(),
        }),
        true,
    );
  });

  it("deduplicates reversed spot pairs", () => {
    const seen = new Set(["a|b"]);
    assert.equal(
        shouldIncludeCandidate({
          candidateSpotSource: "feed-a",
          sourceId: "feed-a",
          includeWithinSourceClusters: true,
          pairKey: duplicatePairKey("b", "a"),
          seenPairKeys: seen,
        }),
        false,
    );
  });
});
