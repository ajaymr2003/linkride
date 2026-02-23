import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'passenger_security_display.dart';

class PassengerLiveTracking extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final String rideId;

  const PassengerLiveTracking({super.key, required this.rideId, required this.rideData});

  @override
  State<PassengerLiveTracking> createState() => _PassengerLiveTrackingState();
}

class _PassengerLiveTrackingState extends State<PassengerLiveTracking> {
  final MapController _mapController = MapController();
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  // Locations
  LatLng? _myPos;       // Passenger's Live GPS
  LatLng? _driverPos;   // Driver's Live GPS (from RTDB)
  LatLng? _pickupPos;   // Fixed Point (from Firestore)
  
  List<LatLng> _driverRoutePoints = []; // Road path
  bool _isMapReady = false;

  String _distance = "--";
  String _duration = "--";

  StreamSubscription<Position>? _myLocationSub;
  StreamSubscription<DatabaseEvent>? _driverLocationSub;

  @override
  void initState() {
    super.initState();
    _startMyTracking();
    _listenToDriver();
  }

  // --- 1. TRACK PASSENGER'S OWN LIVE LOCATION ---
  void _startMyTracking() {
    _myLocationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)
    ).listen((pos) {
      if (mounted) {
        setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
        _fitMap();
      }
    });
  }

  // --- 2. LISTEN TO DRIVER'S LIVE LOCATION FROM RTDB ---
  void _listenToDriver() {
    String dUid = widget.rideData['driver_uid'];
    _driverLocationSub = FirebaseDatabase.instance.ref('user_locations/$dUid').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      
      if (mounted) {
        setState(() => _driverPos = LatLng(data['lat'], data['lng']));
        if (_pickupPos != null) {
          _fetchDriverRoadRoute(_driverPos!, _pickupPos!);
        }
        _fitMap();
      }
    });
  }

  // --- 3. AUTO-ZOOM TO FIT ALL THREE POINTS ---
  void _fitMap() {
    if (!_isMapReady || _myPos == null || _driverPos == null || _pickupPos == null) return;

    var bounds = LatLngBounds.fromPoints([_myPos!, _driverPos!, _pickupPos!]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(70)),
    );
  }

  // --- 4. FETCH ROAD ROUTE FOR DRIVER ---
  Future<void> _fetchDriverRoadRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0];
        if (mounted) {
          setState(() {
            _driverRoutePoints = (route['geometry']['coordinates'] as List)
                .map((c) => LatLng(c[1], c[0])).toList();
            _distance = "${(route['distance'] / 1000).toStringAsFixed(1)} km";
            _duration = "${(route['duration'] / 60).toStringAsFixed(0)} min";
          });
        }
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    _myLocationSub?.cancel();
    _driverLocationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var ride = snapshot.data!.data() as Map<String, dynamic>;
          // Fetch Pickup coordinates saved during Driver Acceptance
          var myRoute = ride['passenger_routes'][_myUid]['pickup'];
          _pickupPos = LatLng(myRoute['lat'], myRoute['lng']);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _pickupPos!,
                  initialZoom: 15,
                  onMapReady: () {
                    setState(() => _isMapReady = true);
                    _fitMap();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.linkride',
                  ),
                  
                  // LAYER 1: DRIVER ROAD ROUTE (Solid Blue)
                  if (_driverRoutePoints.isNotEmpty)
                    PolylineLayer(polylines: [
                      Polyline(points: _driverRoutePoints, color: Colors.blue, strokeWidth: 5),
                    ]),

                  // LAYER 2: PASSENGER TO PICKUP (Dotted Orange)
                  if (_myPos != null && _pickupPos != null)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: [_myPos!, _pickupPos!],
                        color: Colors.orange,
                        strokeWidth: 3,
                        isDotted: true, // <--- THE DOTTED LINE
                      ),
                    ]),

                  MarkerLayer(markers: [
                    // Driver Marker
                    if (_driverPos != null)
                      Marker(point: _driverPos!, child: const Icon(Icons.directions_car, color: Colors.blue, size: 30)),
                    
                    // Pickup Point Marker
                    Marker(point: _pickupPos!, child: const Icon(Icons.location_on, color: Colors.red, size: 40)),

                    // Passenger Live Marker
                    if (_myPos != null)
                      Marker(point: _myPos!, child: const Icon(Icons.person_pin_circle, color: Colors.orange, size: 35)),
                  ]),
                ],
              ),

              Positioned(top: 50, left: 20, child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)))),

              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Driver is on the way", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _metric("Distance", _distance),
                          _metric("Arrival in", _duration),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton(onPressed: () {}, child: const Text("MESSAGE"))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF11A860)),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerSecurityDisplay(rideId: widget.rideId))),
                              child: const Text("GET PIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _metric(String l, String v) => Column(children: [Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(l, style: const TextStyle(color: Colors.grey, fontSize: 11))]);
}