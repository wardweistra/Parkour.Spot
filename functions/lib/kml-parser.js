/* eslint-disable max-len */
/**
 * KML/KMZ placemark parsing for ParkourSpot sync sources.
 */

const xml2js = require("xml2js");
const {
  buildGoogleEarthImageUrlCandidates,
} = require("./google-earth-images");

/**
 * Extracts address text from a KML placemark when coordinates are missing.
 * @param {Object} placemark
 * @return {string|null}
 */
function extractAddressFromPlacemark(placemark) {
  if (placemark.address && placemark.address[0]) {
    return placemark.address[0].trim();
  }

  if (placemark.ExtendedData && placemark.ExtendedData[0]) {
    const extendedData = placemark.ExtendedData[0];
    if (extendedData.Data) {
      for (const data of extendedData.Data) {
        if (data.$ && data.$.name) {
          const name = data.$.name.toLowerCase();
          if (
            name.includes("adresse") ||
            name.includes("address") ||
            name.includes("location") ||
            name.includes("place") ||
            name.includes("street")
          ) {
            if (data.value && data.value[0]) {
              return data.value[0].trim();
            }
          }
        }
      }
    }
  }

  if (placemark.description && placemark.description[0]) {
    const description = placemark.description[0];
    const addressPatterns = [
      /adresse complète[:\s]+([^\n\r<]+)/i,
      /address[:\s]+([^\n\r<]+)/i,
      /location[:\s]+([^\n\r<]+)/i,
      /place[:\s]+([^\n\r<]+)/i,
      /street[:\s]+([^\n\r<]+)/i,
    ];
    for (const pattern of addressPatterns) {
      const match = description.match(pattern);
      if (match && match[1]) {
        return match[1].trim();
      }
    }
  }

  if (placemark.name && placemark.name[0]) {
    const name = placemark.name[0];
    if (
      name.match(
          /\d+.*(street|st|avenue|ave|road|rd|boulevard|blvd|way|drive|dr|lane|ln|place|pl)/i,
      )
    ) {
      return name.trim();
    }
  }

  return null;
}

/**
 * Extracts Google Earth gx:imageUrl values from a placemark.
 * @param {Object} placemark
 * @return {string[]}
 */
function extractGoogleEarthImageTemplates(placemark) {
  const templates = [];
  const seen = new Set();
  const addTemplate = (raw) => {
    if (typeof raw !== "string") return;
    const trimmed = raw.trim();
    if (!trimmed || seen.has(trimmed)) return;
    seen.add(trimmed);
    templates.push(trimmed);
  };

  const carousel = placemark["gx:Carousel"];
  if (Array.isArray(carousel)) {
    for (const carouselNode of carousel) {
      const images = carouselNode["gx:Image"];
      if (!Array.isArray(images)) continue;
      for (const imageNode of images) {
        const imageUrl = imageNode["gx:imageUrl"];
        if (Array.isArray(imageUrl) && imageUrl[0]) {
          addTemplate(imageUrl[0]);
        }
      }
    }
  }

  return templates;
}

/**
 * Resolves Google Earth image templates to preferred download URLs (largest first).
 * @param {Object} placemark
 * @return {string[]}
 */
function extractGoogleEarthImageUrls(placemark) {
  const urls = [];
  const seen = new Set();
  for (const template of extractGoogleEarthImageTemplates(placemark)) {
    const candidates = buildGoogleEarthImageUrlCandidates(template);
    if (candidates.length === 0) continue;
    const preferred = candidates[0];
    if (!seen.has(preferred)) {
      seen.add(preferred);
      urls.push(preferred);
    }
  }
  return urls;
}

/**
 * Reads stable external id from a KML placemark node.
 * @param {Object} placemark
 * @return {string|null}
 */
function extractPlacemarkExternalId(placemark) {
  if (placemark.$ && typeof placemark.$.id === "string") {
    const id = placemark.$.id.trim();
    if (id) return id;
  }
  return null;
}

/**
 * Builds a normalized placemark object from a raw KML placemark node.
 * @param {Object} placemark
 * @param {string[]} folderPath
 * @return {Object|null}
 */
function buildPlacemarkFromKmlNode(placemark, folderPath) {
  const name = (placemark.name && placemark.name[0]) || "Unnamed Spot";
  const description = (placemark.description && placemark.description[0]) || "";
  const coordinates =
    placemark.Point &&
    placemark.Point[0] &&
    placemark.Point[0].coordinates &&
    placemark.Point[0].coordinates[0];

  const nextFolderPath = Array.isArray(folderPath) ? folderPath : [];
  const folderName =
    nextFolderPath.length > 0 ?
      nextFolderPath[nextFolderPath.length - 1].trim() :
      null;
  const topLevelFolderName =
    nextFolderPath.length > 0 ? nextFolderPath[0].trim() : null;
  const imageUrls = extractGoogleEarthImageUrls(placemark);
  const externalId = extractPlacemarkExternalId(placemark);

  const base = {
    name,
    description,
    extendedData: (placemark.ExtendedData && placemark.ExtendedData[0]) || {},
    folderPath: nextFolderPath,
    folderName,
    topLevelFolderName,
    imageUrls: imageUrls.length > 0 ? imageUrls : undefined,
    externalId: externalId || undefined,
  };

  if (coordinates) {
    const [longitude, latitude, altitude] = coordinates.split(",").map(Number);
    return {
      ...base,
      coordinates: {latitude, longitude, altitude: altitude || 0},
    };
  }

  const address = extractAddressFromPlacemark(placemark);
  if (!address) return null;

  return {
    ...base,
    coordinates: null,
    address,
  };
}

/**
 * Recursively extracts placemarks from a KML folder node.
 * @param {Object} folder
 * @param {string[]} folderPath
 * @param {Array<Object>} placemarks
 */
function extractPlacemarksFromFolder(folder, folderPath, placemarks) {
  let currentFolderName = null;
  if (folder.name && Array.isArray(folder.name) && folder.name[0]) {
    currentFolderName = String(folder.name[0]).trim();
  }
  const nextFolderPath = currentFolderName ?
    [...folderPath, currentFolderName] :
    [...folderPath];

  if (folder.Placemark) {
    for (const placemark of folder.Placemark) {
      const parsed = buildPlacemarkFromKmlNode(placemark, nextFolderPath);
      if (parsed) placemarks.push(parsed);
    }
  }

  if (folder.Folder) {
    for (const sub of folder.Folder) {
      extractPlacemarksFromFolder(sub, nextFolderPath, placemarks);
    }
  }
}

/**
 * Parses KML XML and returns top-level folder names from the Document.
 * @param {string} kmlContent
 * @return {Promise<string[]>}
 */
function parseKmlTopLevelFolders(kmlContent) {
  return new Promise((resolve, reject) => {
    const parser = new xml2js.Parser();
    parser.parseString(kmlContent, (err, result) => {
      if (err) return reject(err);
      const folders = [];
      const document = result?.kml?.Document?.[0];
      if (!document?.Folder) {
        resolve(folders);
        return;
      }
      for (const folder of document.Folder) {
        if (folder.name && folder.name[0]) {
          const name = String(folder.name[0]).trim();
          if (name) folders.push(name);
        }
      }
      resolve(folders);
    });
  });
}

/**
 * Parses KML and extracts placemarks, including folder hierarchy when present.
 * @param {string} kmlContent
 * @return {Promise<Object[]>}
 */
function parseKmlPlacemarks(kmlContent) {
  return new Promise((resolve, reject) => {
    const parser = new xml2js.Parser();
    parser.parseString(kmlContent, (err, result) => {
      if (err) return reject(err);

      const placemarks = [];
      if (!result.kml || !result.kml.Document || !result.kml.Document[0]) {
        resolve(placemarks);
        return;
      }

      const document = result.kml.Document[0];

      if (document.Placemark) {
        for (const placemark of document.Placemark) {
          const parsed = buildPlacemarkFromKmlNode(placemark, []);
          if (parsed) placemarks.push(parsed);
        }
      }

      if (document.Folder) {
        for (const folder of document.Folder) {
          extractPlacemarksFromFolder(folder, [], placemarks);
        }
      }

      resolve(placemarks);
    });
  });
}

module.exports = {
  extractAddressFromPlacemark,
  extractGoogleEarthImageTemplates,
  extractGoogleEarthImageUrls,
  extractPlacemarkExternalId,
  parseKmlTopLevelFolders,
  parseKmlPlacemarks,
};
