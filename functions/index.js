/**
 * Firebase Cloud Functions for ParkourSpot App
 *
 * Import function triggers from their respective submodules:
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentCreated, onDocumentUpdated} = require(
 *     "firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at
 * https://firebase.google.com/docs/
 * functions
 */

const {onCall} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require(
    "firebase-functions/v2/firestore");
const admin = require("firebase-admin");
const yauzl = require("yauzl");
const xml2js = require("xml2js");
const https = require("https");
const path = require("path");

// Initialize Firebase Admin
admin.initializeApp();
const db = admin.firestore();
const bucket = admin.storage().bucket();

// Example function that can be called from your Flutter app
exports.helloWorld = onCall(
    {region: "europe-west1"},
    (request) => {
      return "Hello from ParkourSpot Firebase Functions!";
    });

// Trigger when a new spot is created
exports.onSpotCreated = onDocumentCreated(
    {document: "spots/{spotId}", region: "europe-west1"},
    (event) => {
      const spotData = event.data.data();
      console.log("New parkour spot created:", {
        spotId: event.params.spotId,
        name: spotData.name,
        createdBy: spotData.createdBy,
      });

      // You can add logic here like:
      // - Send notifications to nearby users
      // - Update search indexes
      // - Validate spot data
    });

// Trigger when a spot is updated
exports.onSpotUpdated = onDocumentUpdated(
    {document: "spots/{spotId}", region: "europe-west1"},
    (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();

      console.log("Parkour spot updated:", {
        spotId: event.params.spotId,
        name: afterData.name,
        ratingChanged: beforeData.rating !== afterData.rating,
      });

      // You can add logic here like:
      // - Update search indexes
      // - Send notifications about changes
      // - Log rating changes
    });

// Function to get nearby spots (can be called from Flutter app)
exports.getNearbySpots = onCall(
    {region: "europe-west1"},
    (request) => {
      const {latitude, longitude, radiusKm} = request.data;

      // This is a placeholder - you'd implement actual geospatial query logic
      return {
        message: "Nearby spots function called",
        params: {latitude, longitude, radiusKm},
      };
    });

// Utility function to download a file from URL
function downloadFile(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (response) => {
      if (response.statusCode !== 200) {
        reject(new Error(`HTTP ${response.statusCode}: ${response.statusMessage}`));
        return;
      }
      
      const chunks = [];
      response.on("data", (chunk) => chunks.push(chunk));
      response.on("end", () => resolve(Buffer.concat(chunks)));
      response.on("error", reject);
    }).on("error", reject);
  });
}

// Utility function to extract KML from KMZ
function extractKmlFromKmz(kmzBuffer) {
  return new Promise((resolve, reject) => {
    yauzl.fromBuffer(kmzBuffer, {lazyEntries: true}, (err, zipfile) => {
      if (err) return reject(err);
      
      zipfile.readEntry();
      zipfile.on("entry", (entry) => {
        if (entry.fileName.endsWith(".kml")) {
          zipfile.openReadStream(entry, (err, readStream) => {
            if (err) return reject(err);
            
            const chunks = [];
            readStream.on("data", (chunk) => chunks.push(chunk));
            readStream.on("end", () => {
              resolve(Buffer.concat(chunks).toString("utf8"));
            });
            readStream.on("error", reject);
          });
        } else {
          zipfile.readEntry();
        }
      });
      zipfile.on("end", () => {
        reject(new Error("No KML file found in KMZ"));
      });
      zipfile.on("error", reject);
    });
  });
}

// Utility function to clean HTML from description text
function cleanDescription(description) {
  if (!description) return "";
  
  // Remove HTML tags but preserve line breaks
  let cleaned = description
    .replace(/<br\s*\/?>/gi, '\n')  // Convert <br> tags to newlines
    .replace(/<img[^>]*>/gi, '')    // Remove <img> tags
    .replace(/<[^>]*>/g, '')        // Remove all other HTML tags
    .replace(/&nbsp;/g, ' ')        // Convert &nbsp; to spaces
    .replace(/&amp;/g, '&')         // Convert &amp; to &
    .replace(/&lt;/g, '<')          // Convert &lt; to <
    .replace(/&gt;/g, '>')          // Convert &gt; to >
    .replace(/&quot;/g, '"')        // Convert &quot; to "
    .replace(/&#39;/g, "'")         // Convert &#39; to '
    .replace(/&apos;/g, "'")        // Convert &apos; to '
    .replace(/\n\s*\n\s*\n/g, '\n\n') // Replace 3+ newlines with 2
    .replace(/\n\s*\n/g, '\n\n')    // Replace 2+ newlines with 2
    .trim();                        // Remove leading/trailing whitespace
  
  return cleaned;
}

// Utility function to extract image URLs from placemark data
function extractImageUrls(placemark) {
  const imageUrls = [];
  
  // Extract from description CDATA
  const description = placemark.description || "";
  const imgRegex = /<img[^>]+src="([^"]+)"/g;
  let match;
  while ((match = imgRegex.exec(description)) !== null) {
    imageUrls.push(match[1]);
  }
  
  // Extract from ExtendedData gx_media_links
  const extendedData = placemark.extendedData || {};
  if (extendedData.Data) {
    const mediaData = extendedData.Data.find(data => 
      data.$ && data.$.name === "gx_media_links"
    );
    if (mediaData && mediaData.value && mediaData.value[0]) {
      const mediaUrls = mediaData.value[0].split(" ").filter(url => url.trim());
      imageUrls.push(...mediaUrls);
    }
  }
  
  // Remove duplicates and filter out invalid URLs
  return [...new Set(imageUrls)].filter(url => 
    url && url.startsWith("http") && url.includes("google.com")
  );
}

// Utility function to download and upload image to Firebase Storage
async function downloadAndUploadImage(imageUrl, spotName, imageIndex) {
  try {
    console.log(`Downloading image ${imageIndex + 1} for spot: ${spotName}`);
    
    // Download image
    const imageBuffer = await downloadFile(imageUrl);
    
    // Generate filename
    const timestamp = Date.now();
    const extension = path.extname(new URL(imageUrl).pathname) || ".jpg";
    const filename = `spots/${spotName.replace(/[^a-zA-Z0-9]/g, "_")}_${timestamp}_${imageIndex}${extension}`;
    
    // Upload to Firebase Storage
    const file = bucket.file(filename);
    await file.save(imageBuffer, {
      metadata: {
        contentType: "image/jpeg",
        cacheControl: "public, max-age=31536000",
      },
    });
    
    // Make file publicly accessible
    await file.makePublic();
    
    // Return public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${filename}`;
    console.log(`Uploaded image to: ${publicUrl}`);
    
    return publicUrl;
  } catch (error) {
    console.error(`Failed to download/upload image ${imageIndex + 1} for ${spotName}:`, error);
    return null;
  }
}

// Utility function to process images for a placemark
async function processPlacemarkImages(placemark) {
  const imageUrls = extractImageUrls(placemark);
  
  if (imageUrls.length === 0) {
    return [];
  }
  
  console.log(`Found ${imageUrls.length} images for spot: ${placemark.name}`);
  
  const uploadedImageUrls = [];
  
  // Process images in parallel (limit to 5 concurrent downloads)
  const batchSize = 5;
  for (let i = 0; i < imageUrls.length; i += batchSize) {
    const batch = imageUrls.slice(i, i + batchSize);
    const batchPromises = batch.map((url, index) => 
      downloadAndUploadImage(url, placemark.name, i + index)
    );
    
    const batchResults = await Promise.all(batchPromises);
    uploadedImageUrls.push(...batchResults.filter(url => url !== null));
  }
  
  console.log(`Successfully uploaded ${uploadedImageUrls.length} images for spot: ${placemark.name}`);
  return uploadedImageUrls;
}

// Utility function to parse KML and extract Placemarks
function parseKmlPlacemarks(kmlContent) {
  return new Promise((resolve, reject) => {
    const parser = new xml2js.Parser();
    parser.parseString(kmlContent, (err, result) => {
      if (err) return reject(err);
      
      const placemarks = [];
      
      function extractPlacemarksFromFolder(folder) {
        if (folder.Placemark) {
          folder.Placemark.forEach((placemark) => {
            const name = (placemark.name && placemark.name[0]) || "Unnamed Spot";
            const description = (placemark.description && placemark.description[0]) || "";
            const coordinates = (placemark.Point && placemark.Point[0] && placemark.Point[0].coordinates && placemark.Point[0].coordinates[0]);
            
            if (coordinates) {
              const [longitude, latitude, altitude] = coordinates.split(",").map(Number);
              placemarks.push({
                name: name,
                description: description,
                coordinates: {latitude, longitude, altitude: altitude || 0},
                extendedData: (placemark.ExtendedData && placemark.ExtendedData[0]) || {},
              });
            }
          });
        }
        
        if (folder.Folder) {
          folder.Folder.forEach(extractPlacemarksFromFolder);
        }
      }
      
      if (result.kml && result.kml.Document && result.kml.Document[0] && result.kml.Document[0].Folder) {
        result.kml.Document[0].Folder.forEach(extractPlacemarksFromFolder);
      }
      
      resolve(placemarks);
    });
  });
}

// Function to sync KMZ data to spots collection
exports.syncKmzSpots = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        const {kmzUrl, spotSource} = request.data;
        
        if (!kmzUrl) {
          throw new Error("kmzUrl is required");
        }
        
        if (!spotSource) {
          throw new Error("spotSource is required");
        }
        
        console.log(`Starting KMZ sync from: ${kmzUrl}`);
        
        // Download KMZ file
        const kmzBuffer = await downloadFile(kmzUrl);
        console.log(`Downloaded KMZ file, size: ${kmzBuffer.length} bytes`);
        
        // Extract KML from KMZ
        const kmlContent = await extractKmlFromKmz(kmzBuffer);
        console.log(`Extracted KML content, length: ${kmlContent.length} characters`);
        
        // Parse KML and extract placemarks
        const placemarks = await parseKmlPlacemarks(kmlContent);
        console.log(`Found ${placemarks.length} placemarks`);
        
        let created = 0;
        let updated = 0;
        const skipped = 0;
        
        // Process each placemark
        for (const placemark of placemarks) {
          const {name, description, coordinates} = placemark;
          
          // Process images for this placemark
          console.log(`Processing images for spot: ${name}`);
          const imageUrls = await processPlacemarkImages(placemark);
          
          // Clean the description to remove HTML
          const cleanedDescription = cleanDescription(description);
          
          // Check if spot already exists with same coordinates and source
          const existingSpots = await db.collection("spots")
              .where("spotSource", "==", spotSource)
              .where("location", "==", new admin.firestore.GeoPoint(
                  coordinates.latitude, 
                  coordinates.longitude
              ))
              .get();
          
          const spotData = {
            name: name,
            description: cleanedDescription,
            location: new admin.firestore.GeoPoint(
                coordinates.latitude, 
                coordinates.longitude
            ),
            spotSource: spotSource,
            isPublic: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          
          // Add image URLs if any were found
          if (imageUrls.length > 0) {
            spotData.imageUrls = imageUrls;
          }
          
          if (existingSpots.empty) {
            // Create new spot
            spotData.createdAt = admin.firestore.FieldValue.serverTimestamp();
            await db.collection("spots").add(spotData);
            created++;
            console.log(`Created new spot: ${name} with ${imageUrls.length} images`);
          } else {
            // Update existing spot
            const existingSpot = existingSpots.docs[0];
            await existingSpot.ref.update(spotData);
            updated++;
            console.log(`Updated existing spot: ${name} (ID: ${existingSpot.id}) with ${imageUrls.length} images`);
          }
        }
        
        const result = {
          success: true,
          message: `KMZ sync completed successfully`,
          stats: {
            total: placemarks.length,
            created: created,
            updated: updated,
            skipped: skipped,
          },
        };
        
        console.log("KMZ sync result:", result);
        return result;
        
      } catch (error) {
        console.error("Error syncing KMZ spots:", error);
        throw new Error(`Failed to sync KMZ spots: ${error.message}`);
      }
    });

// Function to sync all sources from Firestore collection
exports.syncAllSources = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        console.log("Starting sync for all sources from Firestore");
        
        // Get all active sync sources
        const sourcesSnapshot = await db.collection("syncSources")
            .where("isActive", "==", true)
            .get();
        
        if (sourcesSnapshot.empty) {
          return {
            success: true,
            message: "No active sync sources found",
            results: [],
          };
        }
        
        const results = [];
        let totalCreated = 0;
        let totalUpdated = 0;
        let totalSkipped = 0;
        
        // Process each source
        for (const sourceDoc of sourcesSnapshot.docs) {
          const source = sourceDoc.data();
          const sourceId = sourceDoc.id;
          
          try {
            console.log(`Processing source: ${source.name} (${sourceId})`);
            
            // Download and process KMZ file
            const kmzBuffer = await downloadFile(source.kmzUrl);
            const kmlContent = await extractKmlFromKmz(kmzBuffer);
            const placemarks = await parseKmlPlacemarks(kmlContent);
            
            let created = 0;
            let updated = 0;
            const skipped = 0;
            
            // Process each placemark
            for (const placemark of placemarks) {
              const {name, description, coordinates} = placemark;
              
              // Process images for this placemark
              console.log(`Processing images for spot: ${name} from source: ${source.name}`);
              const imageUrls = await processPlacemarkImages(placemark);
              
              // Clean the description to remove HTML
              const cleanedDescription = cleanDescription(description);
              
              // Check if spot already exists with same coordinates and source
              const existingSpots = await db.collection("spots")
                  .where("spotSource", "==", sourceId)
                  .where("location", "==", new admin.firestore.GeoPoint(
                      coordinates.latitude, 
                      coordinates.longitude
                  ))
                  .get();
              
              const spotData = {
                name: name,
                description: cleanedDescription,
                location: new admin.firestore.GeoPoint(
                    coordinates.latitude, 
                    coordinates.longitude
                ),
                spotSource: sourceId,
                isPublic: source.isPublic !== false, // Default to true unless explicitly false
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              };
              
              // Add image URLs if any were found
              if (imageUrls.length > 0) {
                spotData.imageUrls = imageUrls;
              }
              
              if (existingSpots.empty) {
                // Create new spot
                spotData.createdAt = admin.firestore.FieldValue.serverTimestamp();
                await db.collection("spots").add(spotData);
                created++;
                console.log(`Created new spot: ${name} from source: ${source.name} with ${imageUrls.length} images`);
              } else {
                // Update existing spot
                const existingSpot = existingSpots.docs[0];
                await existingSpot.ref.update(spotData);
                updated++;
                console.log(`Updated existing spot: ${name} from source: ${source.name} with ${imageUrls.length} images`);
              }
            }
            
            // Update source last sync time
            await sourceDoc.ref.update({
              lastSyncAt: admin.firestore.FieldValue.serverTimestamp(),
              lastSyncStats: {
                total: placemarks.length,
                created: created,
                updated: updated,
                skipped: skipped,
              },
            });
            
            const sourceResult = {
              sourceId: sourceId,
              sourceName: source.name,
              success: true,
              stats: {
                total: placemarks.length,
                created: created,
                updated: updated,
                skipped: skipped,
              },
            };
            
            results.push(sourceResult);
            totalCreated += created;
            totalUpdated += updated;
            totalSkipped += skipped;
            
            console.log(`Completed sync for source: ${source.name}`, sourceResult.stats);
            
          } catch (sourceError) {
            console.error(`Error processing source ${source.name}:`, sourceError);
            
            results.push({
              sourceId: sourceId,
              sourceName: source.name,
              success: false,
              error: sourceError.message,
              stats: {
                total: 0,
                created: 0,
                updated: 0,
                skipped: 0,
              },
            });
          }
        }
        
        const overallResult = {
          success: true,
          message: `Sync completed for ${results.length} sources`,
          totalStats: {
            total: totalCreated + totalUpdated + totalSkipped,
            created: totalCreated,
            updated: totalUpdated,
            skipped: totalSkipped,
          },
          results: results,
        };
        
        console.log("Overall sync result:", overallResult);
        return overallResult;
        
      } catch (error) {
        console.error("Error syncing all sources:", error);
        throw new Error(`Failed to sync all sources: ${error.message}`);
      }
    });

// Function to create a new sync source
exports.createSyncSource = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        const {name, kmzUrl, description, isPublic = true, isActive = true} = request.data;
        
        if (!name || !kmzUrl) {
          throw new Error("name and kmzUrl are required");
        }
        
        const sourceData = {
          name: name,
          kmzUrl: kmzUrl,
          description: description || "",
          isPublic: isPublic,
          isActive: isActive,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        
        const docRef = await db.collection("syncSources").add(sourceData);
        
        return {
          success: true,
          message: "Sync source created successfully",
          sourceId: docRef.id,
          data: sourceData,
        };
        
      } catch (error) {
        console.error("Error creating sync source:", error);
        throw new Error(`Failed to create sync source: ${error.message}`);
      }
    });

// Function to update a sync source
exports.updateSyncSource = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        const {sourceId, name, kmzUrl, description, isPublic, isActive} = request.data;
        
        if (!sourceId) {
          throw new Error("sourceId is required");
        }
        
        const updateData = {
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        
        if (name !== undefined) updateData.name = name;
        if (kmzUrl !== undefined) updateData.kmzUrl = kmzUrl;
        if (description !== undefined) updateData.description = description;
        if (isPublic !== undefined) updateData.isPublic = isPublic;
        if (isActive !== undefined) updateData.isActive = isActive;
        
        await db.collection("syncSources").doc(sourceId).update(updateData);
        
        return {
          success: true,
          message: "Sync source updated successfully",
          sourceId: sourceId,
        };
        
      } catch (error) {
        console.error("Error updating sync source:", error);
        throw new Error(`Failed to update sync source: ${error.message}`);
      }
    });

// Function to delete a sync source
exports.deleteSyncSource = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        const {sourceId} = request.data;
        
        if (!sourceId) {
          throw new Error("sourceId is required");
        }
        
        await db.collection("syncSources").doc(sourceId).delete();
        
        return {
          success: true,
          message: "Sync source deleted successfully",
          sourceId: sourceId,
        };
        
      } catch (error) {
        console.error("Error deleting sync source:", error);
        throw new Error(`Failed to delete sync source: ${error.message}`);
      }
    });

// Function to get all sync sources
exports.getSyncSources = onCall(
    {region: "europe-west1"},
    async (request) => {
      try {
        const {includeInactive = false} = request.data;
        
        let query = db.collection("syncSources");
        
        if (!includeInactive) {
          query = query.where("isActive", "==", true);
        }
        
        const snapshot = await query.orderBy("createdAt", "desc").get();
        
        const sources = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));
        
        return {
          success: true,
          sources: sources,
          count: sources.length,
        };
        
      } catch (error) {
        console.error("Error getting sync sources:", error);
        throw new Error(`Failed to get sync sources: ${error.message}`);
      }
    });
