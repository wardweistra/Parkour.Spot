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
    expect(
        shouldIncludeCandidate({
          candidateSpotSource: "feed-a",
          sourceId: "feed-a",
          includeWithinSourceClusters: false,
          pairKey: "a|b",
          seenPairKeys: new Set(),
        }),
    ).toBe(false);
  });

  it("includes same-source candidates when within-source clustering is enabled", () => {
    expect(
        shouldIncludeCandidate({
          candidateSpotSource: "feed-a",
          sourceId: "feed-a",
          includeWithinSourceClusters: true,
          pairKey: "a|b",
          seenPairKeys: new Set(),
        }),
    ).toBe(true);
  });

  it("deduplicates reversed spot pairs", () => {
    const seen = new Set(["a|b"]);
    expect(
        shouldIncludeCandidate({
          candidateSpotSource: "feed-a",
          sourceId: "feed-a",
          includeWithinSourceClusters: true,
          pairKey: duplicatePairKey("b", "a"),
          seenPairKeys: seen,
        }),
    ).toBe(false);
  });
});
