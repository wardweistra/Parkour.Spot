/**
 * Test script for KMZ sync functions
 * Run this with: node test-kmz-sync.js
 */

const {initializeApp} = require("firebase-admin/app");
const {getFunctions} = require("firebase-admin/functions");

// Initialize Firebase Admin (you'll need to set up service account key)
// initializeApp({
//   credential: admin.credential.applicationDefault(),
// });

// Example of how to call the functions from your Flutter app or another service
async function testKmzSync() {
  try {
    const functions = getFunctions();
    
    // 1. Create a sync source
    const createSource = functions.httpsCallable("createSyncSource");
    const createResult = await createSource({
      name: "Google Maps Parkour Spots",
      kmzUrl: "https://www.google.com/maps/d/u/0/kml?mid=1F8PHbPAtHhj4RaCQzbsw6Ko6FE0",
      description: "Parkour spots from Google My Maps",
      isActive: true
    });
    
    console.log("Created source:", createResult.data);
    
    // 2. Sync all sources
    const syncAll = functions.httpsCallable("syncAllSources");
    const syncResult = await syncAll({});
    
    console.log("Sync result:", syncResult.data);
    
  } catch (error) {
    console.error("Error calling sync function:", error);
  }
}

// Example of how to call it from Flutter/Dart
const flutterExample = `
// In your Flutter app, you would call it like this:
import 'package:cloud_functions/cloud_functions.dart';

class SyncSourceService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Create a new sync source
  Future<String> createSyncSource({
    required String name,
    required String kmzUrl,
    String? description,
    bool isActive = true,
  }) async {
    try {
      final callable = _functions.httpsCallable('createSyncSource');
      final result = await callable.call({
        'name': name,
        'kmzUrl': kmzUrl,
        'description': description,
        'isActive': isActive,
      });
      
      return result.data['sourceId'];
    } catch (e) {
      print('Error creating sync source: \$e');
      rethrow;
    }
  }
  
  // Sync all active sources
  Future<Map<String, dynamic>> syncAllSources() async {
    try {
      final callable = _functions.httpsCallable('syncAllSources');
      final result = await callable.call({});
      
      print('Sync completed: \${result.data}');
      return result.data;
    } catch (e) {
      print('Error syncing all sources: \$e');
      rethrow;
    }
  }
  
  // Get all sync sources
  Future<List<Map<String, dynamic>>> getSyncSources({bool includeInactive = false}) async {
    try {
      final callable = _functions.httpsCallable('getSyncSources');
      final result = await callable.call({
        'includeInactive': includeInactive,
      });
      
      return List<Map<String, dynamic>>.from(result.data['sources']);
    } catch (e) {
      print('Error getting sync sources: \$e');
      rethrow;
    }
  }
  
  // Update a sync source
  Future<void> updateSyncSource({
    required String sourceId,
    String? name,
    String? kmzUrl,
    String? description,
    bool? isActive,
  }) async {
    try {
      final callable = _functions.httpsCallable('updateSyncSource');
      await callable.call({
        'sourceId': sourceId,
        'name': name,
        'kmzUrl': kmzUrl,
        'description': description,
        'isActive': isActive,
      });
    } catch (e) {
      print('Error updating sync source: \$e');
      rethrow;
    }
  }
  
  // Delete a sync source
  Future<void> deleteSyncSource(String sourceId) async {
    try {
      final callable = _functions.httpsCallable('deleteSyncSource');
      await callable.call({'sourceId': sourceId});
    } catch (e) {
      print('Error deleting sync source: \$e');
      rethrow;
    }
  }
}

// Usage example:
// final syncService = SyncSourceService();
// 
// // Create a source
// final sourceId = await syncService.createSyncSource(
//   name: 'My Parkour Spots',
//   kmzUrl: 'https://example.com/spots.kmz',
//   description: 'My personal collection',
// );
// 
// // Sync all sources
// final result = await syncService.syncAllSources();
// print('Synced \${result['totalStats']['created']} new spots');
`;

console.log("Flutter example:");
console.log(flutterExample);

// Uncomment to run the test (requires Firebase setup)
// testKmzSync();
