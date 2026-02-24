import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'driver_payment_confirm_page.dart';

class RideMovingScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const RideMovingScreen({super.key, required this.rideId, required this.rideData});

  @override
  State<RideMovingScreen> createState() => _RideMovingScreenState();
}

class _RideMovingScreenState extends State<RideMovingScreen> {
  final MapController _mapController = MapController();
  
  LatLng? _driverPos;
  LatLng? _passengerDropoff;
  late LatLng _driverFinalDest;

  String? _onboardPassengerUid; 
  String _passengerName = "Passenger";
  String _dropoffLocationName = "Drop-off Point";

  List<LatLng> _routePoints = []; 
  String _distanceStr = "--";
  String _durationStr = "--";
  double _rawDistanceMeters = 9999; 

  StreamSubscription<Position>? _posSub;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _initializePoints();
    _startTracking();
  }

  void _initializePoints() {
    // 1. Set the ultimate destination of the ride
    _driverFinalDest = LatLng(
      widget.rideData['destination']['lat'], 
      widget.rideData['destination']['lng']
    );

    // 2. Find the specific passenger who is currently onboard
    Map<String, dynamic> routes = widget.rideData['passenger_routes'] ?? {};
    
    routes.forEach((pId, routeData) {
      if (routeData['ride_status'] == 'security_completed') {
        _onboardPassengerUid = pId;
        var dropData = routeData['dropoff'];
        _passengerDropoff = LatLng(dropData['lat'], dropData['lng']);
        _passengerName = routeData['passenger_name'] ?? "Passenger";
        _dropoffLocationName = dropData['name'] ?? "Drop-off Point";
      }
    });
  }

  void _startTracking() {
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, 
        distanceFilter: 10
      )
    ).listen((pos) {
      LatLng currentPos = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _driverPos = currentPos);
        
        // 3. Calculate route to the passenger's specific drop-off
        if (_passengerDropoff != null) {
          _fetchRoute(currentPos, _passengerDropoff!);
        }

        if (_isFirstLoad) {
          _mapController.move(currentPos, 14);
          _isFirstLoad = false;
        }
      }
    });
  }

  Future<void> _fetchRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');

    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final route = data['routes'][0];
        final points = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList();

        setState(() {
          _routePoints = points;
          _rawDistanceMeters = route['distance'].toDouble();
          _distanceStr = "${(_rawDistanceMeters / 1000).toStringAsFixed(1)} km";
          _durationStr = "${(route['duration'] / 60).toStringAsFixed(0)} min";
        });
      }
    } catch (e) {
      debugPrint("OSRM Error: $e");
    }
  }

  @override
  void dispose() { 
    _posSub?.cancel(); 
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    // Determine if driver is close enough to show "Reached" button (e.g., 300 meters)
    bool isAtDropoff = _rawDistanceMeters < 300; 

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _driverPos ?? const LatLng(11.2, 75.7), 
              initialZoom: 14
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.linkride'
              ),
              // Route Line to Drop-off
              if (_routePoints.isNotEmpty) 
                PolylineLayer(
                  polylines: [
                    Polyline(points: _routePoints, color: Colors.blue, strokeWidth: 6)
                  ]
                ),
              MarkerLayer(
                markers: [
                  if (_driverPos != null) 
                    Marker(
                      point: _driverPos!, 
                      child: const Icon(Icons.navigation, color: Colors.blue, size: 35)
                    ),
                  if (_passengerDropoff != null) 
                    Marker(
                      point: _passengerDropoff!, 
                      child: const Icon(Icons.person_pin_circle, color: Colors.orange, size: 40)
                    ),
                  Marker(
                    point: _driverFinalDest, 
                    child: const Icon(Icons.flag, color: Colors.red, size: 30)
                  ),
                ]
              ),
            ],
          ),

          // Bottom UI Overlay
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Dropping off $_passengerName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(_dropoffLocationName, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metric("To Drop-off", _distanceStr),
                      _metric("Time", _durationStr),
                    ],
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAtDropoff ? const Color(0xFF11A860) : Colors.grey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      onPressed: !isAtDropoff ? null : () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DriverPaymentConfirmPage(
                          rideId: widget.rideId, 
                          passengerUid: _onboardPassengerUid!, 
                          passengerName: _passengerName, 
                          price: widget.rideData['price_per_seat'] ?? 0,
                        )));
                      }, 
                      child: Text(
                        isAtDropoff ? "ARRIVED AT DROP-OFF" : "NAVIGATING...", 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _metric(String l, String v) => Column(
    children: [
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue)),
      Text(l, style: const TextStyle(color: Colors.grey, fontSize: 11))
    ]
  );
}