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
import 'passenger_payment_page.dart'; // Import the new payment page

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

  LatLng? _myPos;          // Live GPS
  LatLng? _driverPos;      // From RTDB
  late LatLng _dropoffPos; // Fixed drop-off point
  List<LatLng> _routePoints = [];
  
  String _distance = "--";
  String _duration = "--";
  String? _userSecurityPin; // PIN from Firestore 'users' collection

  StreamSubscription<Position>? _myPosSub;
  StreamSubscription<DatabaseEvent>? _driverSub;

  @override
  void initState() {
    super.initState();
    _initializePoints();
    _fetchSecurityPin();
    _startTracking();
  }

  void _initializePoints() {
    // Get the drop-off location saved for this specific passenger
    var myRoute = widget.rideData['passenger_routes'][_uid]['dropoff'];
    _dropoffPos = LatLng(myRoute['lat'], myRoute['lng']);
  }

  Future<void> _fetchSecurityPin() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (doc.exists) {
      setState(() => _userSecurityPin = doc.get('security_pin'));
    }
  }

  void _startTracking() {
    // 1. My Location
    _myPosSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)
    ).listen((pos) {
      if (mounted) {
        setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
        _fetchRoute();
      }
    });

    // 2. Driver Location (Realtime Database)
    String dUid = widget.rideData['driver_uid'];
    _driverSub = FirebaseDatabase.instance.ref('user_locations/$dUid').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      if (mounted) setState(() => _driverPos = LatLng(data['lat'], data['lng']));
    });
  }

  Future<void> _fetchRoute() async {
    if (_myPos == null) return;
    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${_myPos!.longitude},${_myPos!.latitude};${_dropoffPos.longitude},${_dropoffPos.latitude}?overview=full&geometries=geojson');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final route = data['routes'][0];
        setState(() {
          _routePoints = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList();
          _distance = "${(route['distance'] / 1000).toStringAsFixed(1)} km";
          _duration = "${(route['duration'] / 60).toStringAsFixed(0)} min";
        });
      }
    } catch (e) {}
  }

  // --- PIN VERIFICATION DIALOG ---
  void _verifyAndFinish() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Drop-off"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your 4-digit Security PIN to confirm you have reached safely."),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 10),
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect PIN. Please try again."), backgroundColor: Colors.red));
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
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _dropoffPos, initialZoom: 15),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.linkride'),
              if (_routePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _routePoints, color: Colors.green, strokeWidth: 5)]),
              MarkerLayer(markers: [
                if (_driverPos != null) Marker(point: _driverPos!, child: const Icon(Icons.directions_car, color: Colors.blue, size: 30)),
                Marker(point: _dropoffPos, width: 100, height: 70, child: Column(children: [_label("Drop-off"), const Icon(Icons.location_on, color: Colors.red, size: 40)])),
                if (_myPos != null) Marker(point: _myPos!, width: 100, height: 70, child: Column(children: [_label("You"), const Icon(Icons.person_pin_circle, color: Colors.orange, size: 35)])),
              ]),
            ],
          ),
          Positioned(top: 50, left: 20, child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)))),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Trip in Progress", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metric("Distance Left", _distance),
                      _metric("Arrival in", _duration),
                    ],
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF11A860), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: _verifyAndFinish,
                      child: const Text("DESTINATION REACHED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _label(String text) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(5)), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9)));
  Widget _metric(String l, String v) => Column(children: [Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(l, style: const TextStyle(color: Colors.grey, fontSize: 11))]);
}