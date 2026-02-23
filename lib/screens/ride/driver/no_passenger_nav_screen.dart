import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class NoPassengerNavScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final String rideId;

  const NoPassengerNavScreen({super.key, required this.rideId, required this.rideData});

  @override
  State<NoPassengerNavScreen> createState() => _NoPassengerNavScreenState();
}

class _NoPassengerNavScreenState extends State<NoPassengerNavScreen> {
  final MapController _mapController = MapController();
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  LatLng? _currentPos;
  late LatLng _destinationPos;
  List<LatLng> _routePoints = [];

  // Metrics
  double _speed = 0.0;
  String _distance = "-- km";
  String _duration = "-- min";

  StreamSubscription<Position>? _positionStream;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    // 1. Get destination from Ride Data
    _destinationPos = LatLng(
      widget.rideData['destination']['lat'],
      widget.rideData['destination']['lng'],
    );

    // 2. Start GPS Tracking
    _startLocationTracking();
  }

  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position pos) {
      if (mounted) {
        LatLng newPos = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _currentPos = newPos;
          _speed = pos.speed * 3.6; // Convert m/s to km/h
        });

        // Update RTDB for safety/sync
        FirebaseDatabase.instance.ref('user_locations/$_myUid').update({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'is_active': true,
          'last_updated': ServerValue.timestamp,
        });

        // Update Map View
        if (_isFirstLoad) {
          _mapController.move(newPos, 15);
          _isFirstLoad = false;
        }

        // Fetch Road Route from OSRM
        _fetchRoute();
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (_currentPos == null) return;

    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${_currentPos!.longitude},${_currentPos!.latitude};${_destinationPos.longitude},${_destinationPos.latitude}?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0];

        setState(() {
          // Parse coordinates for the polyline
          _routePoints = (route['geometry']['coordinates'] as List)
              .map((c) => LatLng(c[1], c[0]))
              .toList();

          // Parse Distance (convert meters to km)
          double distKm = route['distance'] / 1000;
          _distance = "${distKm.toStringAsFixed(1)} km";

          // Parse Duration (convert seconds to minutes)
          double durMin = route['duration'] / 60;
          _duration = "${durMin.toStringAsFixed(0)} min";
        });
      }
    } catch (e) {
      debugPrint("Route Fetch Error: $e");
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    FirebaseDatabase.instance.ref('user_locations/$_myUid').update({'is_active': false});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. THE MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPos ?? const LatLng(11.25, 75.78),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.linkride',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: _routePoints, color: Colors.blueAccent, strokeWidth: 6),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // My Car
                  if (_currentPos != null)
                    Marker(
                      point: _currentPos!,
                      child: const Icon(Icons.navigation, color: Colors.blue, size: 40),
                    ),
                  // Destination
                  Marker(
                    point: _destinationPos,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                  ),
                ],
              ),
            ],
          ),

          // 2. BACK BUTTON
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 3. METRICS PANEL
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Driving to Destination",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metricItem("Distance", _distance, Icons.straighten),
                      _metricItem("Duration", _duration, Icons.timer),
                      _metricItem("Speed", "${_speed.toStringAsFixed(0)} km/h", Icons.speed),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No passengers yet. We'll alert you if someone joins.",
                    style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _metricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF11A860), size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}