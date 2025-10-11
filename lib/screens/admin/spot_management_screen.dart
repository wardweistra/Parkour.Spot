import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/spot_service.dart';
import '../../services/sync_source_service.dart';
import '../../models/spot.dart';

class SpotManagementScreen extends StatefulWidget {
  const SpotManagementScreen({super.key});

  @override
  State<SpotManagementScreen> createState() => _SpotManagementScreenState();
}

class _SpotManagementScreenState extends State<SpotManagementScreen> {
  String? _selectedSourceId;
  DateTime? _selectedTimestamp;
  List<Spot> _spots = [];
  bool _isLoading = false;
  String? _error;
  final Set<String> _selectedSpotIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSyncSources();
    });
  }

  Future<void> _loadSyncSources() async {
    final syncSourceService = Provider.of<SyncSourceService>(context, listen: false);
    await syncSourceService.fetchSyncSources(includeInactive: true);
  }

  Future<void> _searchSpots() async {
    if (_selectedTimestamp == null) {
      setState(() {
        _error = 'Please select a timestamp';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _spots = [];
      _selectedSpotIds.clear();
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final spots = await spotService.getSpotsBySourceAndTimestamp(
        _selectedSourceId ?? '', // Use empty string for native spots
        _selectedTimestamp!,
      );
      
      setState(() {
        _spots = spots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load spots: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSelectedSpots() async {
    if (_selectedSpotIds.isEmpty) {
      setState(() {
        _error = 'Please select spots to delete';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected Spots'),
        content: Text('Are you sure you want to delete ${_selectedSpotIds.length} selected spots? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      int deletedCount = 0;
      int failedCount = 0;

      for (final spotId in _selectedSpotIds) {
        final success = await spotService.deleteSpot(spotId);
        if (success) {
          deletedCount++;
        } else {
          failedCount++;
        }
      }

      setState(() {
        _isLoading = false;
        _selectedSpotIds.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted $deletedCount spots${failedCount > 0 ? ', $failedCount failed' : ''}'),
            backgroundColor: failedCount > 0 ? Colors.orange : Colors.green,
          ),
        );
      }

      // Refresh the spots list
      await _searchSpots();
    } catch (e) {
      setState(() {
        _error = 'Failed to delete spots: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleSpotSelection(String spotId) {
    setState(() {
      if (_selectedSpotIds.contains(spotId)) {
        _selectedSpotIds.remove(spotId);
      } else {
        _selectedSpotIds.add(spotId);
      }
    });
  }

  void _selectAllSpots() {
    setState(() {
      _selectedSpotIds.clear();
      _selectedSpotIds.addAll(_spots.map((spot) => spot.id!).whereType<String>());
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedSpotIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Spot Management')),
        body: const Center(
          child: Text('Administrator access required'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spot Management'),
        actions: [
          if (_selectedSpotIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelectedSpots,
              tooltip: 'Delete Selected (${_selectedSpotIds.length})',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search controls
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search Spots',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Source selection
                  Consumer<SyncSourceService>(
                    builder: (context, syncSourceService, child) {
                      return DropdownButtonFormField<String?>(
                        value: _selectedSourceId,
                        decoration: const InputDecoration(
                          labelText: 'Select Source',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Native Spots (No Source)'),
                          ),
                          ...syncSourceService.sources.map((source) => DropdownMenuItem<String?>(
                            value: source.id,
                            child: Text(source.name),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedSourceId = value;
                          });
                        },
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Timestamp selection
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _selectedTimestamp ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _selectedTimestamp = date;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Last Updated Before',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                        helperText: 'Find spots last updated before this date',
                      ),
                      child: Text(
                        _selectedTimestamp != null
                            ? '${_selectedTimestamp!.day}/${_selectedTimestamp!.month}/${_selectedTimestamp!.year}'
                            : 'Select a date',
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Search button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _searchSpots,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Search Spots'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Results section
          Expanded(
            child: _buildResultsSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = null;
                });
              },
              child: const Text('Clear Error'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_spots.isEmpty && _selectedTimestamp != null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No spots found last updated before the selected date',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_spots.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select a date to find spots last updated before that date',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Results header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Found ${_spots.length} spots',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (_spots.isNotEmpty) ...[
                TextButton(
                  onPressed: _selectedSpotIds.length == _spots.length ? _clearSelection : _selectAllSpots,
                  child: Text(
                    _selectedSpotIds.length == _spots.length ? 'Clear All' : 'Select All',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_selectedSpotIds.length} selected',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
        
        // Spots list
        Expanded(
          child: ListView.builder(
            itemCount: _spots.length,
            itemBuilder: (context, index) {
              final spot = _spots[index];
              final isSelected = _selectedSpotIds.contains(spot.id);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    if (spot.id != null) {
                      _toggleSpotSelection(spot.id!);
                    }
                  },
                  title: Text(
                    spot.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (spot.description.isNotEmpty)
                        Text(
                          spot.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              spot.address ?? '${spot.latitude.toStringAsFixed(4)}, ${spot.longitude.toStringAsFixed(4)}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      if (spot.updatedAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.update, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Last updated: ${spot.updatedAt!.day}/${spot.updatedAt!.month}/${spot.updatedAt!.year}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  secondary: spot.imageUrls?.isNotEmpty == true
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            spot.imageUrls!.first,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image_not_supported),
                              );
                            },
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
