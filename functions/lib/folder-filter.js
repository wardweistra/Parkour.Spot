/**
 * Folder include/exclude filtering for sync sources.
 * Include and exclude modes are mutually exclusive: when both lists are
 * non-empty, include wins and exclude is ignored.
 */

/**
 * Normalize a folder list from array or comma-separated string.
 * @param {*} value Raw folder list value
 * @return {string[]} Normalized folder names
 */
function normalizeFolderList(value) {
  let list = [];
  if (Array.isArray(value)) {
    list = value;
  } else if (typeof value === "string") {
    list = value.split(",");
  }
  return list
      .map((s) => (typeof s === "string" ? s.trim() : ""))
      .filter((s) => s.length > 0);
}

/**
 * Whether a placemark's folderPath intersects the given folder set.
 * Matching is case-insensitive.
 * @param {Object} placemark Placemark with optional folderPath
 * @param {Set<string>} folderSetLower Lowercase folder names
 * @return {boolean} True if any path segment matches
 */
function placemarkMatchesFolderSet(placemark, folderSetLower) {
  const path = Array.isArray(placemark.folderPath) ?
    placemark.folderPath :
    [];
  return path.some((seg) => folderSetLower.has(String(seg).toLowerCase()));
}

/**
 * Sort placemarks by leaf folderName order in orderFolders.
 * @param {Array<Object>} placemarks Placemarks to sort
 * @param {string[]} orderFolders Preferred folder order
 * @return {Array<Object>} Sorted placemarks copy
 */
function sortPlacemarksByFolderOrder(placemarks, orderFolders) {
  return placemarks.slice().sort((a, b) => {
    const aFolderName = a.folderName ? a.folderName.toLowerCase() : "";
    const bFolderName = b.folderName ? b.folderName.toLowerCase() : "";

    const aIndex = orderFolders.findIndex(
        (folder) => folder.toLowerCase() === aFolderName,
    );
    const bIndex = orderFolders.findIndex(
        (folder) => folder.toLowerCase() === bFolderName,
    );

    if (aIndex !== -1 && bIndex !== -1) {
      return aIndex - bIndex;
    }
    if (aIndex !== -1) return -1;
    if (bIndex !== -1) return 1;
    return 0;
  });
}

/**
 * Apply include or exclude folder filtering to placemarks.
 * @param {Array<Object>} placemarks Placemarks to filter
 * @param {*} includeFoldersRaw Include folder list
 * @param {*} excludeFoldersRaw Exclude folder list
 * @return {Object} Filtered placemarks and mode metadata
 */
function applyFolderFilter(placemarks, includeFoldersRaw, excludeFoldersRaw) {
  const includeFolders = normalizeFolderList(includeFoldersRaw);
  const excludeFolders = normalizeFolderList(excludeFoldersRaw);

  if (includeFolders.length > 0 && excludeFolders.length > 0) {
    console.warn(
        "[FOLDER FILTER] Both includeFolders and excludeFolders are set; " +
        "using includeFolders and ignoring excludeFolders",
    );
  }

  if (includeFolders.length > 0) {
    const includeSetLower = new Set(
        includeFolders.map((f) => f.toLowerCase()),
    );
    const filtered = placemarks.filter((p) =>
      placemarkMatchesFolderSet(p, includeSetLower),
    );
    return {
      placemarks: sortPlacemarksByFolderOrder(filtered, includeFolders),
      includeFolders,
      excludeFolders,
      mode: "include",
    };
  }

  if (excludeFolders.length > 0) {
    const excludeSetLower = new Set(
        excludeFolders.map((f) => f.toLowerCase()),
    );
    const filtered = placemarks.filter(
        (p) => !placemarkMatchesFolderSet(p, excludeSetLower),
    );
    return {
      placemarks: filtered,
      includeFolders,
      excludeFolders,
      mode: "exclude",
    };
  }

  return {
    placemarks,
    includeFolders,
    excludeFolders,
    mode: "none",
  };
}

/**
 * Sort folder names by includeFolders order, then alphabetically.
 * @param {Iterable<string>} folders Folder names
 * @param {string[]} includeFolders Preferred order
 * @return {string[]} Sorted folder names
 */
function sortFoldersByIncludeOrder(folders, includeFolders) {
  const order = Array.isArray(includeFolders) ? includeFolders : [];
  return Array.from(folders).sort((a, b) => {
    const aIndex = order.findIndex(
        (folder) => folder.toLowerCase() === a.toLowerCase(),
    );
    const bIndex = order.findIndex(
        (folder) => folder.toLowerCase() === b.toLowerCase(),
    );

    if (aIndex !== -1 && bIndex !== -1) {
      return aIndex - bIndex;
    }
    if (aIndex !== -1) return -1;
    if (bIndex !== -1) return 1;
    return a.localeCompare(b);
  });
}

module.exports = {
  normalizeFolderList,
  placemarkMatchesFolderSet,
  sortPlacemarksByFolderOrder,
  applyFolderFilter,
  sortFoldersByIncludeOrder,
};
