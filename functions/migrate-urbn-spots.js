const fs = require('fs');
const path = require('path');
const https = require('https');
const admin = require('firebase-admin');
const {S3Client, HeadObjectCommand, GetObjectCommand} = require('@aws-sdk/client-s3');
const {getSignedUrl} = require('@aws-sdk/s3-request-presigner');

// Initialize Firebase Admin (will use default credentials from environment)
if (!admin.apps.length) {
  // Try to get project ID from environment variable first
  const projectIdFromEnv = process.env.FIREBASE_PROJECT_ID;
  
  if (projectIdFromEnv) {
    admin.initializeApp({
      projectId: projectIdFromEnv,
    });
  } else {
    admin.initializeApp();
  }
}

// Get project ID for function URL
let projectId = admin.app().options.projectId || process.env.FIREBASE_PROJECT_ID;
if (!projectId) {
  throw new Error('Firebase project ID not found. Please set FIREBASE_PROJECT_ID environment variable or ensure Firebase Admin is properly initialized with credentials.');
}

// S3 bucket configuration
const S3_BUCKET = 'ward.urbn-jumpers.com';
const S3_BASE_URL = `https://${S3_BUCKET}`;

// Initialize S3 client with credentials from environment variables
const s3Client = new S3Client({
  region: process.env.AWS_REGION || 'us-east-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
  },
});

// Common image extensions to check
const IMAGE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'webp', 'gif'];

/**
 * Check if a file exists in S3
 * @param {string} key - The S3 object key (path)
 * @return {Promise<boolean>} True if file exists, false otherwise
 */
async function checkFileExistsInS3(key) {
  try {
    const command = new HeadObjectCommand({
      Bucket: S3_BUCKET,
      Key: key,
    });
    await s3Client.send(command);
    return true;
  } catch (error) {
    if (error.name === 'NotFound' || error.$metadata?.httpStatusCode === 404) {
      return false;
    }
    // For other errors, log and return false
    console.warn(`Error checking S3 file ${key}:`, error.message);
    return false;
  }
}

/**
 * Find the largest available image for an image ID
 * Checks original first, then resized versions
 * @param {string} spotId - The spot ID (from _id.$oid)
 * @param {string} imageId - The image ID
 * @return {Promise<{url: string, width: number}|null>} The largest image URL and width, or null if not found
 */
/**
 * Generate a signed URL for an S3 object
 * @param {string} key - The S3 object key
 * @return {Promise<string>} Signed URL valid for 1 hour
 */
async function getSignedS3Url(key) {
  const command = new GetObjectCommand({
    Bucket: S3_BUCKET,
    Key: key,
  });
  // Generate signed URL valid for 1 hour
  const signedUrl = await getSignedUrl(s3Client, command, {expiresIn: 3600});
  return signedUrl;
}

async function findLargestImage(spotId, imageId) {
  const s3Prefix = `media/${spotId}/${imageId}`;

  // First, check for original images
  for (const ext of IMAGE_EXTENSIONS) {
    const key = `${s3Prefix}.${ext}`;
    if (await checkFileExistsInS3(key)) {
      const signedUrl = await getSignedS3Url(key);
      console.log(`Found original image: ${key}`);
      return {url: signedUrl, width: Infinity}; // Original is considered largest
    }
  }

  // If no original found, check for resized versions
  const resizedImages = [];
  const commonWidths = [1200, 1000, 800, 600, 400, 300];

  // Check common widths first
  for (const width of commonWidths) {
    for (const ext of IMAGE_EXTENSIONS) {
      const key = `${s3Prefix}_${width}.${ext}`;
      if (await checkFileExistsInS3(key)) {
        const signedUrl = await getSignedS3Url(key);
        resizedImages.push({url: signedUrl, width, key});
        break; // Found one for this width, move to next width
      }
    }
  }

  // If we found resized images, return the one with largest width
  if (resizedImages.length > 0) {
    resizedImages.sort((a, b) => b.width - a.width);
    const largest = resizedImages[0];
    console.log(`Found resized image: ${largest.key} (width: ${largest.width})`);
    return {url: largest.url, width: largest.width};
  }

  // If still nothing found, try to find any resized version by checking a wider range
  // This is a fallback in case there are non-standard widths
  for (let width = 2000; width >= 200; width -= 50) {
    for (const ext of IMAGE_EXTENSIONS) {
      const key = `${s3Prefix}_${width}.${ext}`;
      if (await checkFileExistsInS3(key)) {
        const signedUrl = await getSignedS3Url(key);
        console.log(`Found resized image (fallback): ${key} (width: ${width})`);
        return {url: signedUrl, width};
      }
    }
  }

  return null;
}

/**
 * Map URBN tags to spot features
 * @param {Array<string>} tags - Array of URBN tags
 * @return {Array<string>} Array of spot feature keys
 */
function mapTagsToFeatures(tags) {
  const tagMapping = {
    'WALL5+': 'walls_high',
    'WALL2_5': 'walls_medium',
    'WALL2-': 'walls_low',
    'PULL_BAR': 'bars_high',
    'MEDIUM_BAR': 'bars_medium',
    'LOW_BAR': 'bars_low',
    'TREE': 'climbing_tree',
    'ROCK5+': 'rocks',
    'ROCK2_5': 'rocks',
    'ROCK2-': 'rocks',
    'SANDPIT': 'soft_landing_pit',
    'FOAMPIT': 'soft_landing_pit',
    'TRAMPOLINE': 'bouncy_equipment',
    'SPRING_FLOOR': 'bouncy_equipment',
    'ROOFTOP_CIRCUIT': 'roof_gap',
  };

  const features = new Set();
  for (const tag of tags || []) {
    const feature = tagMapping[tag];
    if (feature) {
      features.add(feature);
    }
  }
  return Array.from(features);
}

/**
 * Get an access token for authentication
 * For server-to-server calls, we'll use the service account access token
 * @return {Promise<string>} Access token
 */
async function getAccessToken() {
  // Check if we have service account credentials
  const credential = admin.app().options.credential;
  if (!credential) {
    throw new Error('Firebase Admin credentials not found. Please set up service account credentials. See: https://firebase.google.com/docs/admin/setup');
  }
  
  try {
    // Get access token from service account
    const accessTokenResult = await credential.getAccessToken();
    return accessTokenResult.access_token;
  } catch (error) {
    throw new Error(`Failed to get access token: ${error.message}. Make sure Firebase Admin is properly configured with service account credentials.`);
  }
}

/**
 * Call the cloud function via HTTP
 * @param {string} functionName - Name of the cloud function
 * @param {Object} data - Data to send to the function
 * @return {Promise<Object>} Result from cloud function
 */
async function callCloudFunction(functionName, data) {
  const region = 'europe-west1';
  const url = `https://${region}-${projectId}.cloudfunctions.net/${functionName}`;
  
  // Get access token for authentication (service account token)
  const accessToken = await getAccessToken();
  
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({data});
    
    const urlObj = new URL(url);
    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        'Authorization': `Bearer ${accessToken}`,
      },
    };
    
    const req = https.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        try {
          const result = JSON.parse(responseData);
          if (res.statusCode === 200) {
            resolve({data: result});
          } else {
            // Log the full error for debugging
            console.error(`Function returned status ${res.statusCode}:`, JSON.stringify(result, null, 2));
            const errorMessage = result.error?.message || result.error || responseData;
            reject(new Error(`Function returned status ${res.statusCode}: ${errorMessage}`));
          }
        } catch (error) {
          // If response isn't JSON, log the raw response
          console.error(`Non-JSON response (status ${res.statusCode}):`, responseData);
          reject(new Error(`Failed to parse response: ${error.message}. Raw response: ${responseData.substring(0, 200)}`));
        }
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    req.write(postData);
    req.end();
  });
}

/**
 * Process a batch of spots and send to cloud function
 * @param {Array} spots - Array of processed spot objects
 * @param {number} batchNumber - Current batch number
 * @return {Promise<Object>} Result from cloud function
 */
async function processBatch(spots, batchNumber) {
  console.log(`\nProcessing batch ${batchNumber} with ${spots.length} spots...`);

  const result = await callCloudFunction('importUrbnSpots', {
    spots: spots,
  });

  return result;
}

/**
 * Main migration function
 */
async function main() {
  // Validate AWS credentials
  if (!process.env.AWS_ACCESS_KEY_ID || !process.env.AWS_SECRET_ACCESS_KEY) {
    console.error('❌ Error: AWS credentials not found!');
    console.error('Please set the following environment variables:');
    console.error('  - AWS_ACCESS_KEY_ID');
    console.error('  - AWS_SECRET_ACCESS_KEY');
    console.error('  - AWS_REGION (optional, defaults to us-east-1)');
    process.exit(1);
  }
  
  // Validate Firebase credentials
  if (!process.env.FIREBASE_API_KEY) {
    console.error('❌ Error: FIREBASE_API_KEY not found!');
    console.error('Please set the FIREBASE_API_KEY environment variable.');
    process.exit(1);
  }
  
  // Check if Firebase Admin has credentials
  const credential = admin.app().options.credential;
  if (!credential) {
    console.error('❌ Error: Firebase Admin credentials not found!');
    console.error('Please set up Firebase Admin with service account credentials.');
    console.error('Options:');
    console.error('  1. Set GOOGLE_APPLICATION_CREDENTIALS to point to your service account key file');
    console.error('  2. Or use Application Default Credentials (gcloud auth application-default login)');
    console.error('  3. Or initialize Firebase Admin with explicit credentials in the script');
    process.exit(1);
  }

  // Parse command-line arguments
  const args = process.argv.slice(2);
  let startIndex = null;
  let endIndex = null;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--start' && i + 1 < args.length) {
      startIndex = parseInt(args[i + 1], 10);
      i++;
    } else if (args[i] === '--end' && i + 1 < args.length) {
      endIndex = parseInt(args[i + 1], 10);
      i++;
    }
  }

  // Read and parse NDJSON file (newline-delimited JSON)
  const jsonPath = path.join(__dirname, '..', 'urbn', 'spots_export.ndjson');
  console.log(`Reading spots from: ${jsonPath}`);

  if (!fs.existsSync(jsonPath)) {
    throw new Error(`NDJSON file not found: ${jsonPath}`);
  }

  const fileContent = fs.readFileSync(jsonPath, 'utf8');
  const lines = fileContent.split('\n').filter(line => line.trim().length > 0);
  const allSpots = [];

  for (let i = 0; i < lines.length; i++) {
    try {
      const spot = JSON.parse(lines[i]);
      allSpots.push(spot);
    } catch (error) {
      console.warn(`Failed to parse line ${i + 1} in NDJSON file: ${error.message}`);
      // Continue processing other lines
    }
  }

  console.log(`Total spots in NDJSON: ${allSpots.length}`);

  // Filter out hidden spots
  const visibleSpots = allSpots.filter((spot) => !spot.hidden);
  console.log(`Visible spots (not hidden): ${visibleSpots.length}`);

  // Apply range filter if specified
  let spotsToProcess = visibleSpots;
  if (startIndex !== null || endIndex !== null) {
    const start = startIndex !== null ? startIndex : 0;
    const end = endIndex !== null ? endIndex : visibleSpots.length;
    spotsToProcess = visibleSpots.slice(start, end);
    console.log(`Processing range: ${start} to ${end} (${spotsToProcess.length} spots)`);
  }

  // Process each spot
  const processedSpots = [];
  let validationErrors = 0;

  for (let i = 0; i < spotsToProcess.length; i++) {
    const spot = spotsToProcess[i];
    const spotIndex = (startIndex !== null ? startIndex : 0) + i;

    try {
      // Validate coordinates
      if (!spot.location || !spot.location.coordinates || !Array.isArray(spot.location.coordinates) || spot.location.coordinates.length < 2) {
        throw new Error(`Spot at index ${spotIndex} (${spot.name || 'unnamed'}) is missing coordinates`);
      }

      const [lng, lat] = spot.location.coordinates;
      if (typeof lng !== 'number' || typeof lat !== 'number' || isNaN(lng) || isNaN(lat)) {
        throw new Error(`Spot at index ${spotIndex} (${spot.name || 'unnamed'}) has invalid coordinates`);
      }

      // Get spot ID
      const spotId = spot._id?.$oid || spot._id;
      if (!spotId) {
        throw new Error(`Spot at index ${spotIndex} (${spot.name || 'unnamed'}) is missing _id`);
      }

      // Process images
      const imageIds = spot.images?.images || [];
      const imageUrls = [];

      console.log(`\nProcessing spot ${spotIndex + 1}/${spotsToProcess.length}: ${spot.name || 'unnamed'}`);
      console.log(`  Spot ID: ${spotId}`);
      console.log(`  Image IDs: ${imageIds.length}`);

      for (let imgIdx = 0; imgIdx < imageIds.length; imgIdx++) {
        const imageId = imageIds[imgIdx];
        console.log(`  Checking image ${imgIdx + 1}/${imageIds.length}: ${imageId}`);

        const imageResult = await findLargestImage(spotId, imageId);
        if (!imageResult) {
          throw new Error(`Spot at index ${spotIndex} (${spot.name || 'unnamed'}) - Image ID ${imageId} not found in S3`);
        }

        imageUrls.push(imageResult.url);
      }

      // Map tags to features
      const tags = spot.tags || [];
      const spotFeatures = mapTagsToFeatures(tags);

      // Create processed spot object
      const processedSpot = {
        name: spot.name || '',
        description: spot.description || '',
        coordinates: [lng, lat], // Keep MongoDB format for cloud function
        spotId: spotId,
        imageUrls: imageUrls, // Pre-validated S3 URLs
        tags: tags,
        spotFeatures: spotFeatures,
      };

      processedSpots.push(processedSpot);
      console.log(`  ✓ Processed successfully (${imageUrls.length} images, ${spotFeatures.length} features)`);
    } catch (error) {
      validationErrors++;
      console.error(`  ✗ Error processing spot at index ${spotIndex}: ${error.message}`);
      // Continue processing other spots
    }
  }

  console.log(`\n=== Validation Summary ===`);
  console.log(`Total spots to process: ${spotsToProcess.length}`);
  console.log(`Successfully processed: ${processedSpots.length}`);
  console.log(`Validation errors: ${validationErrors}`);

  if (validationErrors > 0) {
    console.error(`\n⚠️  ${validationErrors} spots failed validation and will be skipped`);
  }

  if (processedSpots.length === 0) {
    console.error('\n❌ No spots to migrate. Exiting.');
    process.exit(1);
  }

  // Process in batches of 50
  const BATCH_SIZE = 50;
  const batches = [];
  for (let i = 0; i < processedSpots.length; i += BATCH_SIZE) {
    batches.push(processedSpots.slice(i, i + BATCH_SIZE));
  }

  console.log(`\n=== Migration Summary ===`);
  console.log(`Total batches: ${batches.length}`);
  console.log(`Spots per batch: ${BATCH_SIZE}`);

  let totalCreated = 0;
  let totalUpdated = 0;
  let totalErrors = 0;

  // Process each batch
  for (let batchIdx = 0; batchIdx < batches.length; batchIdx++) {
    const batch = batches[batchIdx];
    try {
      const result = await processBatch(batch, batchIdx + 1);
      const data = result.data || result;
      if (data.success) {
        totalCreated += data.stats?.created || 0;
        totalUpdated += data.stats?.updated || 0;
        totalErrors += data.stats?.errors || 0;
        console.log(`Batch ${batchIdx + 1}/${batches.length} completed: ${data.stats?.created || 0} created, ${data.stats?.updated || 0} updated, ${data.stats?.errors || 0} errors`);
      } else {
        console.error(`Batch ${batchIdx + 1}/${batches.length} failed: ${data.error || 'Unknown error'}`);
        totalErrors += batch.length;
      }
    } catch (error) {
      console.error(`Batch ${batchIdx + 1}/${batches.length} failed with exception:`, error.message);
      totalErrors += batch.length;
    }

    // Small delay between batches
    if (batchIdx < batches.length - 1) {
      await new Promise((resolve) => setTimeout(resolve, 1000));
    }
  }

  console.log(`\n=== Final Summary ===`);
  console.log(`Total created: ${totalCreated}`);
  console.log(`Total updated: ${totalUpdated}`);
  console.log(`Total errors: ${totalErrors}`);
  console.log(`Validation errors: ${validationErrors}`);
}

// Run the migration
main().catch((error) => {
  console.error('Migration failed:', error);
  process.exit(1);
});

