import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationTrackerScreen extends StatefulWidget {
  const LocationTrackerScreen({super.key});

  @override
  State<LocationTrackerScreen> createState() => _LocationTrackerScreenState();
}

class _LocationTrackerScreenState extends State<LocationTrackerScreen> {
  static const _markerId = MarkerId('current_location');
  static const _updateInterval = Duration(seconds: 10);
  static const _defaultCenter = LatLng(23.8103, 90.4125); // Dhaka, default

  // A Completer lets us safely await the controller even if the first
  // location arrives before the map has finished creating itself.
  final Completer<GoogleMapController> _mapController = Completer();

  // Every position we've received, in order. The polyline is drawn from this.
  final List<LatLng> _pathPoints = [];

  Timer? _timer;
  LatLng? _currentLatLng;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startTracking() async {
    final hasPermission = await _ensureLocationPermission();
    if (!hasPermission) return;

    // The screen could have been closed while the permission dialog was open.
    if (!mounted) return;

    await _updateLocation(); // get a first fix right away, don't wait 10s
    _timer = Timer.periodic(_updateInterval, (_) => _updateLocation());
  }

  Future<bool> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Location services are turned off. Please enable GPS.');
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      _showMessage('Location permission was denied.');
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      _showMessage(
        'Location permission is permanently denied. Enable it in app settings.',
      );
      return false;
    }
    return true;
  }

  Future<void> _updateLocation() async {
    // If a fix takes longer than the interval, skip instead of stacking requests.
    if (_isFetching) return;
    _isFetching = true;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;

      final latLng = LatLng(position.latitude, position.longitude);
      final isFirstFix = _currentLatLng == null;

      setState(() {
        _currentLatLng = latLng;
        _pathPoints.add(latLng);
      });

      await _moveCamera(latLng, isFirstFix: isFirstFix);
    } catch (e) {
      debugPrint('Could not get location: $e');
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _moveCamera(LatLng target, {required bool isFirstFix}) async {
    final controller = await _mapController.future;

    if (isFirstFix) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
      // Open the info window once so it matches the sample screenshot.
      await controller.showMarkerInfoWindow(_markerId);
    } else {
      // Keep the user's zoom level, only follow the position.
      await controller.animateCamera(CameraUpdate.newLatLng(target));
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Set<Marker> _buildMarkers() {
    final position = _currentLatLng;
    if (position == null) return {};

    return {
      Marker(
        markerId: _markerId,
        position: position,
        infoWindow: InfoWindow(
          title: 'My Current Location',
          snippet: '${position.latitude},${position.longitude}',
        ),
      ),
    };
  }

  Set<Polyline> _buildPolylines() {
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        // Pass a copy: the plugin diffs old vs new, and if we hand it the same
        // mutated list it thinks nothing changed and never redraws the line.
        points: List.of(_pathPoints),
        color: Colors.blue,
        width: 5,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Real-Time Location Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _defaultCenter,
          zoom: 12,
        ),
        onMapCreated: (controller) {
          if (!_mapController.isCompleted) _mapController.complete(controller);
        },
        markers: _buildMarkers(),
        polylines: _buildPolylines(),
        compassEnabled: true,
        zoomControlsEnabled: true,
      ),
    );
  }
}
