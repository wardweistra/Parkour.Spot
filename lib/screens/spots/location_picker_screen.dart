import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _pickedLocation;
  bool _isSatelliteView = false;

  @override
  void initState() {
    super.initState();
    _pickedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    final CameraPosition initialCameraPosition = CameraPosition(
      target: widget.initialLocation ?? const LatLng(37.7749, -122.4194),
      zoom: widget.initialLocation != null ? 16 : 10,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        actions: [
          // Satellite view toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Standard',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: !_isSatelliteView 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Switch(
                value: _isSatelliteView,
                onChanged: (value) {
                  setState(() {
                    _isSatelliteView = value;
                  });
                },
              ),
              Text(
                'Satellite',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _isSatelliteView 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),

        ],
      ),
      body: GoogleMap(
        initialCameraPosition: initialCameraPosition,
        mapType: _isSatelliteView ? MapType.satellite : MapType.normal,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        liteModeEnabled: kIsWeb,
        compassEnabled: false,
        onMapCreated: (controller) {
          // Controller is not used in this implementation
        },
        onTap: (LatLng position) {
          setState(() {
            _pickedLocation = position;
          });
        },
        markers: _pickedLocation == null
            ? {}
            : {
                Marker(
                  markerId: const MarkerId('picked'),
                  position: _pickedLocation!,
                  draggable: true,
                  onDragEnd: (LatLng position) {
                    setState(() {
                      _pickedLocation = position;
                    });
                  },
                ),
              },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickedLocation == null
            ? null
            : () {
                Navigator.pop(context, _pickedLocation);
              },
        icon: const Icon(Icons.check),
        label: const Text('Use this location'),
      ),
    );
  }
}
