import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'passenger_payment_page.dart';

class PassengerMovingScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const PassengerMovingScreen({super.key, required this.rideId, required this.rideData});

  @override
  State<PassengerMovingScreen> createState() => _PassengerMovingScreenState();
}

class _PassengerMovingScreenState extends State<PassengerMovingScreen> {
  final MapController _mapController = MapController();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  LatLng? _myPos;          // Live Passenger GPS
  LatLng? _driverPos;      // Driver location from Realtime DB
  late LatLng _dropoffPos; // Specific drop-off from Firestore
  
  List<LatLng> _routePoints = [];
  String _distance = "--";
  String _duration = "--";
  double _rawDistanceMeters = 9999;
  String? _userSecurityPin; 

  StreamSubscription<Position>? _myPosSub;
  StreamSubscription<DatabaseEvent>? _driverSub;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _initializePoints();
    _fetchSecurityPin();
    _startTracking();
  }

  // --- 1. INITIALIZE DATA ---
  void _initializePoints() {
    // Get the drop-off location saved specifically for THIS passenger in the ride map
    var myRoute = widget.rideData['passenger_routes'][_uid]['dropoff'];
    _dropoffPos = LatLng(myRoute['lat'], myRoute['lng']);
  }

  Future<void> _fetchSecurityPin() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (doc.exists) {
      setState(() => _userSecurityPin = doc.get('security_pin'));
    }
  }

  // --- 2. LIVE TRACKING (Self and Driver) ---
  void _startTracking() {
    // A. Track Passenger (My) Current Location
    _myPosSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5)
    ).listen((pos) {
      LatLng currentPos = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _myPos = currentPos);
        _fetchRoadRoute(currentPos, _dropoffPos);
        
        if (_isFirstLoad) {
          _mapController.move(currentPos, 15);
          _isFirstLoad = false;
        }
      }
    });

    // B. Track Driver's Real-time Position (from RTDB)
    String dUid = widget.rideData['driver_uid'];
    _driverSub = FirebaseDatabase.instance.ref('user_locations/$dUid').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      if (mounted) {
        setState(() => _driverPos = LatLng(data['lat'], data['lng']));
      }
    });
  }

  // --- 3. FETCH DIRECTIONS (OSRM) ---
  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final route = data['routes'][0];
        setState(() {
          _routePoints = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList();
          _rawDistanceMeters = route['distance'].toDouble();
          _distance = "${(_rawDistanceMeters / 1000).toStringAsFixed(1)} km";
          _duration = "${(route['duration'] / 60).toStringAsFixed(0)} min";
        });
      }
    } catch (e) {
      debugPrint("Route Fetch Error: $e");
    }
  }

  // --- 4. VERIFY ARRIVAL ---
  void _verifyAndFinish() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reached Destination?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your 4-digit Security PIN to confirm safe arrival and proceed to payment."),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ""),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              if (controller.text == _userSecurityPin) {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (_) => PassengerPaymentPage(rideId: widget.rideId, rideData: widget.rideData))
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect PIN"), backgroundColor: Colors.red));
              }
            },
            child: const Text("CONFIRM"),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _myPosSub?.cancel();
    _driverSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isNearDropoff = _rawDistanceMeters < 400;

    return Scaffold(
      body: Stack(
        children: [
          // MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _dropoffPos, initialZoom: 15),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.linkride'),
              
              // LIVE ROUTE LINE
              if (_routePoints.isNotEmpty) 
                PolylineLayer(polylines: [
                  Polyline(points: _routePoints, color: const Color(0xFF11A860), strokeWidth: 6)
                ]),

              MarkerLayer(markers: [
                // DRIVER CAR MARKER
                if (_driverPos != null) 
                  Marker(
                    point: _driverPos!, 
                    width: 60, height: 60,
                    child: Column(
                      children: [
                        _label("Your Driver", Colors.blue),
                        const Icon(Icons.directions_car_filled, color: Colors.blue, size: 35),
                      ],
                    )
                  ),
                
                // PASSENGER DROP-OFF MARKER
                Marker(
                  point: _dropoffPos, width: 100, height: 70, 
                  child: Column(children: [_label("Drop-off", Colors.red), const Icon(Icons.location_on, color: Colors.red, size: 40)])
                ),
                
                // PASSENGER (YOU) MARKER
                if (_myPos != null) 
                  Marker(
                    point: _myPos!, width: 100, height: 70, 
                    child: Column(children: [_label("You", Colors.orange), const Icon(Icons.person_pin_circle, color: Colors.orange, size: 35)])
                  ),
              ]),
            ],
          ),

          // TOP BACK BUTTON
          Positioned(top: 50, left: 20, child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)))),

          // BOTTOM CONTROL PANEL
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
                  const Text("Trip in Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metric("Distance to Destination", _distance),
                      _metric("Time Remaining", _duration),
                    ],
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isNearDropoff ? const Color(0xFF11A860) : Colors.blueGrey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      onPressed: _verifyAndFinish,
                      child: const Text("I HAVE REACHED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _label(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)), 
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))
  );

  Widget _metric(String l, String v) => Column(
    children: [
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF11A860))),
      Text(l, style: const TextStyle(color: Colors.grey, fontSize: 11))
    ]
  );
}