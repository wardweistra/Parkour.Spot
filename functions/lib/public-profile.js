/**
 * Public projection of `users/{uid}` into `publicProfiles/{uid}`.
 *
 * `users/{uid}` holds private data (email, saved/visited spots, notification
 * and location settings) and is readable only by its owner and admins. Other
 * users and signed-out visitors read `publicProfiles/{uid}` instead, which only
 * Cloud Functions write.
 *
 * Every account keeps a public profile document so usernames stay unique and
 * ratings can show a name. A private profile exposes only its username and
 * display name; a public one adds the photo, bio, Instagram link, join date
 * and the visibility flags of its added/rated spot lists.
 */

const PRIVATE_PROFILE_FIELDS = ["username", "displayName"];
const PUBLIC_PROFILE_FIELDS = [
  ...PRIVATE_PROFILE_FIELDS,
  "photoURL",
  "bio",
  "instagramUrl",
  "createdAt",
  "isAddedSpotsListPublic",
  "isRatedSpotsListPublic",
];

/**
 * Builds the public profile document for a user document.
 * @param {object|undefined|null} userData Data of `users/{uid}`.
 * @return {object|null} Fields for `publicProfiles/{uid}`, or null when the
 *     user document no longer exists.
 */
function buildPublicProfile(userData) {
  if (!userData) return null;
  // Profiles without the flag predate the setting and default to public.
  const isPublicProfile = userData.isPublicProfile !== false;
  const fields = isPublicProfile ?
    PUBLIC_PROFILE_FIELDS :
    PRIVATE_PROFILE_FIELDS;
  const profile = {isPublicProfile};
  for (const field of fields) {
    const value = userData[field];
    if (value !== undefined && value !== null && value !== "") {
      profile[field] = value;
    }
  }
  if (isPublicProfile) {
    profile.isAddedSpotsListPublic = userData.isAddedSpotsListPublic === true;
    profile.isRatedSpotsListPublic = userData.isRatedSpotsListPublic === true;
  }
  return profile;
}

/**
 * Whether two public profile documents are equal, so unrelated user updates
 * (last active time, saved spots, ...) don't rewrite the public document.
 * @param {object|null} a
 * @param {object|null} b
 * @return {boolean}
 */
function publicProfilesEqual(a, b) {
  if (a === null || b === null) return a === b;
  const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
  for (const key of keys) {
    const left = a[key];
    const right = b[key];
    if (left && typeof left.isEqual === "function") {
      if (!left.isEqual(right)) return false;
    } else if (left !== right) {
      return false;
    }
  }
  return true;
}

module.exports = {
  PUBLIC_PROFILE_FIELDS,
  PRIVATE_PROFILE_FIELDS,
  buildPublicProfile,
  publicProfilesEqual,
};
