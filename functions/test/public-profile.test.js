const {
  buildPublicProfile,
  publicProfilesEqual,
} = require("../lib/public-profile");

const fullUser = {
  id: "uid-1",
  email: "someone@example.com",
  displayName: "Sam",
  photoURL: "https://example.com/sam.jpg",
  username: "sam",
  bio: "Traceur from Utrecht",
  instagramUrl: "https://instagram.com/sam",
  createdAt: "2025-01-01",
  lastActiveAt: "2026-11-01",
  wantToVisit: ["spot-1"],
  visited: ["spot-2"],
  favoriteSpots: ["spot-3"],
  isAdmin: false,
  isModerator: false,
  shareLastKnownLocationForAlerts: true,
  preferredLanguageCode: "nl",
  isAddedSpotsListPublic: true,
};

describe("buildPublicProfile", () => {
  it("returns null for a deleted user", () => {
    expect(buildPublicProfile(undefined)).toBeNull();
    expect(buildPublicProfile(null)).toBeNull();
  });

  it("never copies private fields", () => {
    const profile = buildPublicProfile(fullUser);
    for (const field of [
      "email",
      "wantToVisit",
      "visited",
      "favoriteSpots",
      "lastActiveAt",
      "isAdmin",
      "isModerator",
      "shareLastKnownLocationForAlerts",
      "preferredLanguageCode",
      "id",
    ]) {
      expect(profile).not.toHaveProperty(field);
    }
  });

  it("keeps public fields for a public profile", () => {
    expect(buildPublicProfile(fullUser)).toEqual({
      isPublicProfile: true,
      username: "sam",
      displayName: "Sam",
      photoURL: "https://example.com/sam.jpg",
      bio: "Traceur from Utrecht",
      instagramUrl: "https://instagram.com/sam",
      createdAt: "2025-01-01",
      isAddedSpotsListPublic: true,
      isRatedSpotsListPublic: false,
    });
  });

  it("treats a missing flag as public", () => {
    expect(fullUser).not.toHaveProperty("isPublicProfile");
    expect(buildPublicProfile(fullUser).isPublicProfile).toBe(true);
  });

  it("keeps only username and display name for a private profile", () => {
    expect(buildPublicProfile({...fullUser, isPublicProfile: false})).toEqual({
      isPublicProfile: false,
      username: "sam",
      displayName: "Sam",
    });
  });

  it("drops empty values", () => {
    expect(buildPublicProfile({email: "x@example.com", bio: "", photoURL: null}))
        .toEqual({
          isPublicProfile: true,
          isAddedSpotsListPublic: false,
          isRatedSpotsListPublic: false,
        });
  });
});

describe("publicProfilesEqual", () => {
  it("compares plain values", () => {
    const a = buildPublicProfile(fullUser);
    expect(publicProfilesEqual(a, {...a})).toBe(true);
    expect(publicProfilesEqual(a, {...a, bio: "changed"})).toBe(false);
    expect(publicProfilesEqual(a, null)).toBe(false);
    expect(publicProfilesEqual(null, null)).toBe(true);
  });

  it("uses isEqual for Firestore timestamps", () => {
    const ts = (v) => ({value: v, isEqual: (o) => o && o.value === v});
    expect(publicProfilesEqual({createdAt: ts(1)}, {createdAt: ts(1)}))
        .toBe(true);
    expect(publicProfilesEqual({createdAt: ts(1)}, {createdAt: ts(2)}))
        .toBe(false);
  });
});
