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
import 'package:intl/intl.dart'; 
import 'package:telephony/telephony.dart'; 
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
  final Telephony telephony = Telephony.instance; 

  LatLng? _myPos;          
  LatLng? _driverPos;      
  late LatLng _dropoffPos; 
  
  List<LatLng> _routePoints = [];
  String _distance = "--";
  String _duration = "--";
  String _arrivalTime = "--:--"; 
  double _rawDistanceMeters = 9999;
  
  String? _userSecurityPin; 
  String? _guardianPhone;

  StreamSubscription<DatabaseEvent>? _myPosSub;
  StreamSubscription<DatabaseEvent>? _driverSub;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _initializePoints();
    _fetchUserData();
    _startTracking();
  }

  void _initializePoints() {
    var myRoute = widget.rideData['passenger_routes'][_uid]['dropoff'];
    _dropoffPos = LatLng(myRoute['lat'], myRoute['lng']);
  }

  Future<void> _fetchUserData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (doc.exists) {
      setState(() {
        _userSecurityPin = doc.get('security_pin');
        _guardianPhone = doc.get('guardian_phone');
      });
    }
  }

  // --- SOS EMERGENCY LOGIC (BACKGROUND SMS) ---
  Future<void> _triggerEmergencySOS() async {
    if (_guardianPhone == null || _myPos == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Guardian details or location not ready")));
      return;
    }

    final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=${_myPos!.latitude},${_myPos!.longitude}";
    final String message = "EMERGENCY ALERT from LinkRide! I need help. My current location: $googleMapsUrl";

    try {
      bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;

      if (permissionsGranted != null && permissionsGranted) {
        // Sends SMS silently in background on Android
        await telephony.sendSms(
          to: _guardianPhone!,
          message: message,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🆘 SOS ALERT SENT TO GUARDIAN"),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SMS Permissions Denied")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("SOS Failed: $e")));
    }
  }

  void _startTracking() {
    // 1. Fetch Passenger (My) Location from Database
    _myPosSub = FirebaseDatabase.instance.ref('user_locations/$_uid').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      LatLng currentPassengerPos = LatLng(data['lat'], data['lng']);

      if (mounted) {
        setState(() => _myPos = currentPassengerPos);
        _fetchRouteFromPassengerToDest(currentPassengerPos, _dropoffPos);

        if (_isFirstLoad) {
          _mapController.move(currentPassengerPos, 15);
          _isFirstLoad = false;
        }
      }
    });

    // 2. Fetch Driver Location from Database
    String dUid = widget.rideData['driver_uid'];
    _driverSub = FirebaseDatabase.instance.ref('user_locations/$dUid').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      if (mounted) setState(() => _driverPos = LatLng(data['lat'], data['lng']));
    });
  }

  Future<void> _fetchRouteFromPassengerToDest(LatLng start, LatLng end) async {
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
    
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final route = data['routes'][0];
        final double durationSeconds = route['duration'].toDouble();
        final DateTime reachingTime = DateTime.now().add(Duration(seconds: durationSeconds.toInt()));

        if (mounted) {
          setState(() {
            _routePoints = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList();
            _rawDistanceMeters = route['distance'].toDouble();
            _distance = "${(_rawDistanceMeters / 1000).toStringAsFixed(1)} km";
            _duration = "${(durationSeconds / 60).toStringAsFixed(0)} min";
            _arrivalTime = DateFormat('h:mm a').format(reachingTime);
          });
        }
      }
    } catch (e) {
      debugPrint("Routing error: $e");
    }
  }

  void _verifyAndFinish() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reached Destination?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter your 4-digit PIN to confirm safe arrival."),
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
            onPressed: () async {
              if (controller.text == _userSecurityPin) {
                await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
                  'passenger_routes.$_uid.dest_clicked_by_passenger': true,
                });
                if (mounted) {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PassengerPaymentPage(rideId: widget.rideId, rideData: widget.rideData)));
                }
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
          // 1. MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _dropoffPos, initialZoom: 15),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.linkride'),
              if (_routePoints.isNotEmpty) 
                PolylineLayer(polylines: [
                  Polyline(points: _routePoints, color: const Color(0xFF11A860), strokeWidth: 6)
                ]),

              MarkerLayer(markers: [
                if (_driverPos != null) 
                  Marker(
                    point: _driverPos!, width: 60, height: 60,
                    child: Column(children: [_label("Driver", Colors.blue), const Icon(Icons.directions_car_filled, color: Colors.blue, size: 30)])
                  ),
                Marker(
                  point: _dropoffPos, width: 100, height: 70, 
                  child: Column(children: [_label("Drop-off", Colors.red), const Icon(Icons.location_on, color: Colors.red, size: 40)])
                ),
                if (_myPos != null) 
                  Marker(
                    point: _myPos!, width: 100, height: 70, 
                    child: Column(children: [_label("You", Colors.orange), const Icon(Icons.person_pin_circle, color: Colors.orange, size: 35)])
                  ),
              ]),
            ],
          ),

          // 2. TOP BAR: BACK & SOS
          Positioned(
            top: 50, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
                
                ElevatedButton.icon(
                  onPressed: _triggerEmergencySOS,
                  icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                  label: const Text("SOS ALERT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    shape: const StadiumBorder(),
                    elevation: 5,
                  ),
                ),
              ],
            ),
          ),

          // 3. BOTTOM PANEL
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
                      _metric("Distance", _distance, Icons.straighten),
                      _metric("Time Left", _duration, Icons.timer),
                      _metric("Arrival", _arrivalTime, Icons.access_time), 
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
                      child: const Text("DESTINATION REACHED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _metric(String l, String v, IconData i) => Column(
    children: [
      Icon(i, color: const Color(0xFF11A860), size: 20),
      const SizedBox(height: 5),
      Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      Text(l, style: const TextStyle(color: Colors.grey, fontSize: 11))
    ]
  );
}