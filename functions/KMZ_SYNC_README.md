# KMZ Spot Sync Functions

These Firebase functions allow you to manage and sync parkour spots from KMZ files (Google My Maps exports) to your Firestore database using a centralized source management system.

## Features

- **Source Management**: Create, update, delete, and list sync sources in Firestore
- **Bulk Sync**: Sync all active sources with a single function call
- **Individual Sync**: Sync specific sources by URL and source ID
- **Image Processing**: Automatically downloads and uploads images from placemark descriptions and ExtendedData
- **Duplicate Prevention**: Prevents duplicate spots by checking coordinates and source
- **Source Tracking**: Tracks spot source for data lineage and management
- **Error Handling**: Comprehensive error handling with detailed logging

## Setup

1. Install dependencies:
```bash
cd functions
npm install
```

2. Deploy the functions:
```bash
firebase deploy --only functions
```

## Available Functions

### 1. `syncAllSources` - Sync all active sources
Syncs all active sources from the `syncSources` collection.

### 2. `syncSingleSource` - Sync individual source
Syncs a specific source by its ID.

### 3. `createSyncSource` - Create new source
Creates a new sync source in the database.

### 4. `updateSyncSource` - Update existing source
Updates an existing sync source.

### 5. `deleteSyncSource` - Delete source
Deletes a sync source from the database.

### 6. `getSyncSources` - List sources
Gets all sync sources (active or all).

## Usage

### From Flutter App

```dart
import 'package:cloud_functions/cloud_functions.dart';

class SyncSourceService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Create a new sync source
  Future<String> createSyncSource({
    required String name,
    required String kmzUrl,
    String? description,
    bool isPublic = true,
    bool isActive = true,
  }) async {
    final callable = _functions.httpsCallable('createSyncSource');
    final result = await callable.call({
      'name': name,
      'kmzUrl': kmzUrl,
      'description': description,
      'isPublic': isPublic,
      'isActive': isActive,
    });
    
    return result.data['sourceId'];
  }
  
  // Sync all active sources
  Future<Map<String, dynamic>> syncAllSources() async {
    final callable = _functions.httpsCallable('syncAllSources');
    final result = await callable.call({});
    return result.data;
  }
  
  // Get all sync sources
  Future<List<Map<String, dynamic>>> getSyncSources({bool includeInactive = false}) async {
    final callable = _functions.httpsCallable('getSyncSources');
    final result = await callable.call({
      'includeInactive': includeInactive,
    });
    
    return List<Map<String, dynamic>>.from(result.data['sources']);
  }
}

// Usage example:
final syncService = SyncSourceService();

// Create a source
final sourceId = await syncService.createSyncSource(
  name: 'Google Maps Parkour Spots',
  kmzUrl: 'https://www.google.com/maps/d/u/0/kml?mid=1F8PHbPAtHhj4RaCQzbsw6Ko6FE0',
  description: 'Parkour spots from Google My Maps',
);

// Sync all sources
final result = await syncService.syncAllSources();
print('Synced ${result['totalStats']['created']} new spots');
```

### From Node.js/JavaScript

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Create a source
const createSource = functions.httpsCallable('createSyncSource');
const createResult = await createSource({
  name: 'My Parkour Spots',
  kmzUrl: 'https://example.com/spots.kmz',
  description: 'My personal collection',
  publicUrl: 'https://example.com/my-spots',
  instagramHandle: 'parkour_spots',
  isPublic: true,
  isActive: true
});

// Sync all sources
const syncAll = functions.httpsCallable('syncAllSources');
const syncResult = await syncAll({});
console.log('Sync result:', syncResult.data);
```

## Sync Sources Collection Structure

The `syncSources` collection stores source configurations:

```json
{
  "name": "Google Maps Parkour Spots",
  "kmzUrl": "https://www.google.com/maps/d/u/0/kml?mid=1F8PHbPAtHhj4RaCQzbsw6Ko6FE0",
  "description": "Parkour spots from Google My Maps",
  "publicUrl": "https://www.google.com/maps/d/u/0/viewer?mid=1F8PHbPAtHhj4RaCQzbsw6Ko6FE0",
  "instagramHandle": "parkour_spots",
  "isPublic": true,
  "isActive": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z",
  "lastSyncAt": "2024-01-01T00:00:00Z",
  "lastSyncStats": {
    "total": 150,
    "created": 120,
    "updated": 30,
    "skipped": 0
  }
}
```

## Response Formats

### syncAllSources Response
```json
{
  "success": true,
  "message": "Sync completed for 2 sources",
  "totalStats": {
    "total": 300,
    "created": 240,
    "updated": 60,
    "skipped": 0
  },
  "results": [
    {
      "sourceId": "source1",
      "sourceName": "Google Maps Spots",
      "success": true,
      "stats": {
        "total": 150,
        "created": 120,
        "updated": 30,
        "skipped": 0
      }
    }
  ]
}
```

## Spot Data Structure

Spots are stored in Firestore with the following structure:

```json
{
  "name": "Spot Name",
  "description": "Spot description",
  "location": {
    "latitude": 40.7128,
    "longitude": -74.0060
  },
  "latitude": 40.7128,
  "longitude": -74.0060,
  "imageUrls": [
    "https://storage.googleapis.com/your-bucket/spots/spot_name_1234567890_0.jpg",
    "https://storage.googleapis.com/your-bucket/spots/spot_name_1234567890_1.jpg"
  ],
  "spotSource": "google_maps_parkour_spots",
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:00Z"
}
```

### Image Processing

The sync functions automatically process images from placemark data:

1. **Description Images**: Extracts `<img>` tags from the placemark description CDATA
2. **ExtendedData Images**: Extracts URLs from the `gx_media_links` ExtendedData field
3. **Download & Upload**: Downloads images and uploads them to Firebase Storage
4. **Public URLs**: Makes images publicly accessible and stores the URLs in the spot data

Images are stored in Firebase Storage under the path: `spots/{spot_name}_{timestamp}_{index}.{extension}`

### KMZ Structure Support

The sync functions support various KMZ file structures:

1. **Simple KMZ**: KML file directly in the root of the KMZ archive
   ```
   myfile.kmz
   └── myfile.kml
   ```

2. **KMZ with Custom Icons**: KML file in a subfolder with custom icon files
   ```
   myfile.kmz
   ├── myfile.kml
   └── files/
       ├── icon1.png
       ├── icon2.png
       └── ...
   ```

3. **Multiple KML Files**: When multiple KML files are present, the function prefers:
   - KML files in the root directory (highest priority)
   - First available KML file if none in root

4. **File Filtering**: Automatically filters out system files like `__MACOSX/` directories

The `extractKmlFromKmz` function intelligently handles all these structures to ensure reliable KML extraction regardless of how the KMZ file was created.

**Note**: The function also handles KML files where placemarks are directly in the Document element (not inside Folders), which is common in Google My Maps exports.

### HTML Cleaning

The sync functions automatically clean HTML content from placemark descriptions:

1. **HTML Tag Removal**: Removes all HTML tags including `<img>`, `<br>`, `<p>`, `<strong>`, etc.
2. **Line Break Preservation**: Converts `<br>` tags to proper newlines
3. **Entity Decoding**: Converts HTML entities like `&quot;`, `&amp;`, `&apos;` to their text equivalents
4. **Whitespace Cleanup**: Removes excessive whitespace and normalizes line breaks

**Example transformation:**
```
Input:  <img src="image.jpg" /><br><br>Playground<br><br><img src="image2.jpg" />
Output: Playground
```

## Duplicate Prevention

The function prevents duplicate spots by checking:
1. Same coordinates (latitude and longitude)
2. Same spot source

If a spot with the same coordinates and source exists, it will be updated instead of creating a new one.

## Error Handling

The function includes comprehensive error handling for:
- Invalid URLs
- Network errors
- KMZ parsing errors
- KML parsing errors
- Firestore errors

## Testing

Use the provided test scripts:

```bash
cd functions

# Test KMZ sync functionality
node test-kmz-sync.js

# Test KMZ folder structure handling
node test-kmz-folder-structure.js
```

## Dependencies

- `yauzl`: For extracting files from KMZ archives
- `xml2js`: For parsing KML XML content
- `firebase-admin`: For Firestore operations
- `firebase-functions`: For Cloud Functions runtime
