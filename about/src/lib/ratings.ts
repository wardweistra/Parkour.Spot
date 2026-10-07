/**
 * Keep in sync with functions/lib/spot-rating-stats.js.
 * Explore stores at-or-above-average spots as wilsonLowerBound + 10.
 */
const ABOVE_AVERAGE_RANKING_OFFSET = 10;

export function isAboveAverageRanking(ranking: number): boolean {
  return Number.isFinite(ranking) && ranking >= ABOVE_AVERAGE_RANKING_OFFSET;
}

export function qualifyingSpots<T extends {ranking: number; ratingCount: number}>(
  spots: T[],
): T[] {
  return spots.filter(
    (spot) => spot.ratingCount >= 1 && isAboveAverageRanking(spot.ranking),
  );
}
