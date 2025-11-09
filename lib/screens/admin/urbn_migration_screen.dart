import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../services/spot_service.dart';

class UrbnMigrationScreen extends StatefulWidget {
  const UrbnMigrationScreen({super.key});

  @override
  State<UrbnMigrationScreen> createState() => _UrbnMigrationScreenState();
}

class _UrbnMigrationScreenState extends State<UrbnMigrationScreen> {
  int? _startIndex;
  int? _endIndex;
  bool _isLoading = false;
  String? _error;
  String? _status;
  int _totalSpots = 0;
  int _processedSpots = 0;
  int _createdSpots = 0;
  int _updatedSpots = 0;
  int _errorSpots = 0;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _loadAndProcessSpots() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _status = 'Loading JSON file...';
      _processedSpots = 0;
      _createdSpots = 0;
      _updatedSpots = 0;
      _errorSpots = 0;
    });

    try {
      // Download the NDJSON file from Firebase Storage
      setState(() {
        _status = 'Downloading JSON file from Firebase Storage...';
      });
      
      final storage = FirebaseStorage.instance;
      final ref = storage.ref('urbn/spots_export.ndjson');
      
      String jsonString;
      try {
        // For large files, use getDownloadURL and download via HTTP
        final downloadUrl = await ref.getDownloadURL();
        setState(() {
          _status = 'Downloading JSON file (23MB)...';
        });
        
        // Download via HTTP
        final response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode != 200) {
          throw Exception('Failed to download file: HTTP ${response.statusCode}');
        }
        jsonString = utf8.decode(response.bodyBytes);
      } catch (e) {
        // Fallback to getData() if getDownloadURL fails
        debugPrint('getDownloadURL failed, trying getData(): $e');
        try {
          final jsonBytes = await ref.getData();
          if (jsonBytes == null) {
            throw Exception('Failed to download JSON file from Firebase Storage: getData() returned null');
          }
          jsonString = utf8.decode(jsonBytes);
        } catch (e2) {
          throw Exception('Failed to download JSON file from Firebase Storage. getDownloadURL error: $e. getData() error: $e2');
        }
      }
      
      // Parse NDJSON (newline-delimited JSON)
      final lines = jsonString.split('\n').where((line) => line.trim().isNotEmpty).toList();
      final allSpots = <Map<String, dynamic>>[];

      for (int i = 0; i < lines.length; i++) {
        try {
          final spot = jsonDecode(lines[i]) as Map<String, dynamic>;
          allSpots.add(spot);
        } catch (e) {
          debugPrint('Failed to parse line ${i + 1}: $e');
        }
      }

      // Filter out hidden spots
      final visibleSpots = allSpots.where((spot) => spot['hidden'] != true).toList();
      _totalSpots = visibleSpots.length;

      // Apply range filter if specified
      List<Map<String, dynamic>> spotsToProcess = visibleSpots;
      if (_startIndex != null || _endIndex != null) {
        final start = _startIndex ?? 0;
        final end = _endIndex ?? visibleSpots.length;
        spotsToProcess = visibleSpots.sublist(start, end.clamp(0, visibleSpots.length));
      }

      setState(() {
        _status = 'Processing ${spotsToProcess.length} spots...';
      });

      // Process spots in batches of 20
      const batchSize = 20;
      final batches = <List<Map<String, dynamic>>>[];
      for (int i = 0; i < spotsToProcess.length; i += batchSize) {
        batches.add(spotsToProcess.sublist(i, (i + batchSize).clamp(0, spotsToProcess.length)));
      }

      final spotService = Provider.of<SpotService>(context, listen: false);

      // Process each batch
      for (int batchIdx = 0; batchIdx < batches.length; batchIdx++) {
        final batch = batches[batchIdx];
        
        // Process each spot in the batch
        final processedBatch = <Map<String, dynamic>>[];
        
        for (final spot in batch) {
          try {
            // Validate coordinates
            if (spot['location'] == null || 
                spot['location']['coordinates'] == null ||
                spot['location']['coordinates'] is! List ||
                (spot['location']['coordinates'] as List).length < 2) {
              throw Exception('Missing or invalid coordinates');
            }

            final coordinates = spot['location']['coordinates'] as List;
            final lng = coordinates[0] as num;
            final lat = coordinates[1] as num;

            if (lng.isNaN || lat.isNaN) {
              throw Exception('Invalid coordinate values');
            }

            // Get spot ID
            final spotId = spot['_id']?['\$oid'] ?? spot['_id'];
            if (spotId == null) {
              throw Exception('Missing _id');
            }

            // Get image IDs
            final imageIds = spot['images']?['images'] as List? ?? [];
            
            // Map tags to features
            final tags = spot['tags'] as List? ?? [];
            final spotFeatures = _mapTagsToFeatures(tags);

            // Create processed spot object
            final processedSpot = {
              'name': spot['name'] ?? '',
              'description': spot['description'] ?? '',
              'coordinates': [lng.toDouble(), lat.toDouble()],
              'spotId': spotId.toString(),
              'imageIds': imageIds.map((id) => id.toString()).toList(),
              'tags': tags.map((tag) => tag.toString()).toList(),
              'spotFeatures': spotFeatures,
            };

            processedBatch.add(processedSpot);
          } catch (e) {
            _errorSpots++;
            debugPrint('Error processing spot: $e');
          }
        }

        if (processedBatch.isEmpty) {
          continue;
        }

        setState(() {
          _status = 'Sending batch ${batchIdx + 1}/${batches.length} (${processedBatch.length} spots)...';
        });

        // Send batch to cloud function
        try {
          final result = await spotService.importUrbnSpots(processedBatch);
          
          if (result['success'] == true) {
            final stats = result['stats'] as Map<String, dynamic>;
            _createdSpots += stats['created'] as int? ?? 0;
            _updatedSpots += stats['updated'] as int? ?? 0;
            _errorSpots += stats['errors'] as int? ?? 0;
            _processedSpots += processedBatch.length;
          } else {
            _errorSpots += processedBatch.length;
            throw Exception(result['error'] ?? 'Unknown error');
          }
        } catch (e) {
          _errorSpots += processedBatch.length;
          throw Exception('Batch ${batchIdx + 1} failed: $e');
        }

        setState(() {
          _status = 'Completed batch ${batchIdx + 1}/${batches.length}';
        });
      }

      setState(() {
        _status = 'Migration completed!';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<String> _mapTagsToFeatures(List<dynamic> tags) {
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

    final features = <String>{};
    for (final tag in tags) {
      final tagStr = tag.toString();
      final feature = tagMapping[tagStr];
      if (feature != null) {
        features.add(feature);
      }
    }
    return features.toList();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('URBN Migration')),
        body: const Center(child: Text('Administrator access required')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('URBN Migration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import URBN Spots',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Import spots from URBN Jumpers JSON file. The file is stored in Firebase Storage at urbn/spots_export.ndjson',
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startController,
                            decoration: const InputDecoration(
                              labelText: 'Start Index (optional)',
                              hintText: '0',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _startIndex = value.isEmpty ? null : int.tryParse(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _endController,
                            decoration: const InputDecoration(
                              labelText: 'End Index (optional)',
                              hintText: '100',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              _endIndex = value.isEmpty ? null : int.tryParse(value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadAndProcessSpots,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload),
                      label: Text(_isLoading ? 'Processing...' : 'Start Migration'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_status != null || _error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: _error != null ? Colors.red.shade50 : Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_status != null) ...[
                        Text(
                          'Status',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_status!),
                        const SizedBox(height: 16),
                      ],
                      if (_error != null) ...[
                        Text(
                          'Error',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_error!),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (_totalSpots > 0 || _processedSpots > 0) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Statistics',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildStatRow('Total Spots', _totalSpots.toString()),
                      _buildStatRow('Processed', _processedSpots.toString()),
                      _buildStatRow('Created', _createdSpots.toString(), Colors.green),
                      _buildStatRow('Updated', _updatedSpots.toString(), Colors.blue),
                      _buildStatRow('Errors', _errorSpots.toString(), Colors.red),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

