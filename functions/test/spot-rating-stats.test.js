const {
  uniqueRatingsByUser,
  computeSpotRatingAggregates,
  clampRating,
  rankingFromWilson,
} = require("../lib/spot-rating-stats");

describe("spot-rating-stats", () => {
  describe("uniqueRatingsByUser", () => {
    it("keeps one rating per user and prefers the latest updatedAt", () => {
      const unique = uniqueRatingsByUser([
        {userId: "a", rating: 3, updatedAt: {seconds: 100, nanoseconds: 0}},
        {userId: "a", rating: 5, updatedAt: {seconds: 200, nanoseconds: 0}},
        {userId: "b", rating: 4, updatedAt: {seconds: 150, nanoseconds: 0}},
      ]);
      expect(unique).toEqual([
        {userId: "a", rating: 5, updatedAt: {seconds: 200, nanoseconds: 0}},
        {userId: "b", rating: 4, updatedAt: {seconds: 150, nanoseconds: 0}},
      ]);
    });

    it("falls back to createdAt when updatedAt is missing", () => {
      const unique = uniqueRatingsByUser([
        {userId: "a", rating: 2, createdAt: {seconds: 10, nanoseconds: 0}},
        {userId: "a", rating: 4, createdAt: {seconds: 20, nanoseconds: 0}},
      ]);
      expect(unique).toHaveLength(1);
      expect(unique[0].rating).toBe(4);
    });

    it("skips ratings without a userId", () => {
      expect(uniqueRatingsByUser([
        {rating: 5},
        {userId: "  ", rating: 4},
        {userId: "a", rating: 3},
      ])).toEqual([{userId: "a", rating: 3}]);
    });
  });

  describe("computeSpotRatingAggregates", () => {
    it("counts a user once when they rated native and duplicate listings", () => {
      const result = computeSpotRatingAggregates([
        {
          userId: "a",
          rating: 5,
          spotId: "native",
          updatedAt: {seconds: 10, nanoseconds: 0},
        },
        {
          userId: "a",
          rating: 1,
          spotId: "dup",
          updatedAt: {seconds: 20, nanoseconds: 0},
        },
        {
          userId: "b",
          rating: 5,
          spotId: "dup",
          updatedAt: {seconds: 15, nanoseconds: 0},
        },
      ], 2.5);

      expect(result.empty).toBe(false);
      expect(result.ratingCount).toBe(2);
      expect(result.averageRating).toBe(3);
    });

    it("returns empty aggregates when there are no usable ratings", () => {
      expect(computeSpotRatingAggregates([], 2.5)).toEqual({
        empty: true,
        averageRating: 0,
        ratingCount: 0,
        wilsonLowerBound: 0,
        ranking: null,
      });
    });

    it("uses unique count for Wilson ranking", () => {
      const doubled = computeSpotRatingAggregates([
        {userId: "a", rating: 5, updatedAt: {seconds: 1, nanoseconds: 0}},
        {userId: "a", rating: 5, updatedAt: {seconds: 2, nanoseconds: 0}},
      ], 0);
      const once = computeSpotRatingAggregates([
        {userId: "a", rating: 5, updatedAt: {seconds: 2, nanoseconds: 0}},
      ], 0);
      expect(doubled.ratingCount).toBe(1);
      expect(doubled.wilsonLowerBound).toBe(once.wilsonLowerBound);
      expect(doubled.ranking).toBe(once.ranking);
    });
  });

  describe("clampRating", () => {
    it("clamps to 0..5", () => {
      expect(clampRating(-1)).toBe(0);
      expect(clampRating(9)).toBe(5);
      expect(clampRating(3.5)).toBe(3.5);
    });
  });

  describe("rankingFromWilson", () => {
    it("treats equal as above average", () => {
      expect(rankingFromWilson(2.5, 2.5)).toBe(12.5);
      expect(rankingFromWilson(1, 2)).toBe(-9);
    });
  });
});
