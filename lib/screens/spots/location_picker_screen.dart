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
  GoogleMapController? _mapController;

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
          TextButton(
            onPressed: _pickedLocation == null
                ? null
                : () {
                    Navigator.pop(context, _pickedLocation);
                  },
            child: const Text('Done'),
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: initialCameraPosition,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        liteModeEnabled: kIsWeb,
        compassEnabled: false,
        onMapCreated: (controller) {
          _mapController = controller;
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
