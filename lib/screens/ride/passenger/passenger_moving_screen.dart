import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:telephony/telephony.dart';

// Standalone SOS Widget
import '../../../widgets/sos_button.dart';
// Destination Screen
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
  String? _passengerName;

  StreamSubscription<DatabaseEvent>? _myPosSub;
  StreamSubscription<DatabaseEvent>? _driverSub;
  
  DateTime? _lastRouteFetch;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _initializePoints();
    _fetchUserData();
    _startTracking();
    _initPermissions(); 
  }

  // 1. Setup Drop-off point from Firestore data
  void _initializePoints() {
    var myRoute = widget.rideData['passenger_routes'][_uid]['dropoff'];
    _dropoffPos = LatLng(myRoute['lat'], myRoute['lng']);
  }

  // 2. Telephony permission for SOS logic (if used in widget)
  Future<void> _initPermissions() async {
    if (Platform.isAndroid) {
      await telephony.requestPhoneAndSmsPermissions;
    }
  }

  // 3. Fetch security PIN and Guardian details for this user
  Future<void> _fetchUserData() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (doc.exists) {
      setState(() {
        _userSecurityPin = doc.get('security_pin');
        _guardianPhone = doc.get('guardian_phone');
        _passengerName = doc.get('name') ?? "A Passenger";
      });
    }
  }

  // 4. Live Tracking from Realtime Database
  void _startTracking() {
    _myPosSub = FirebaseDatabase.instance.ref('user_locations/$_uid').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      LatLng currentPassengerPos = LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());

      if (mounted) {
        setState(() => _myPos = currentPassengerPos);
        
        // Fetch road geometry every 15 seconds to save battery/data
        if (_lastRouteFetch == null || DateTime.now().difference(_lastRouteFetch!).inSeconds > 15) {
          _fetchRoadRoute(currentPassengerPos, _dropoffPos);
          _lastRouteFetch = DateTime.now();
        }
        
        if (_isFirstLoad) {
          _mapController.move(currentPassengerPos, 15);
          _isFirstLoad = false;
        }
      }
    });

    // Listen to Driver's live location
    String dUid = widget.rideData['driver_uid'];
    _driverSub = FirebaseDatabase.instance.ref('user_locations/$dUid').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      if (mounted) {
        setState(() => _driverPos = LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble()));
      }
    });
  }

  // 5. OSRM Road Path Fetching
  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
    try {
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['routes'] == null || data['routes'].isEmpty) return;
        final route = data['routes'][0];
        final double durSeconds = route['duration'].toDouble();
        final DateTime eta = DateTime.now().add(Duration(seconds: durSeconds.toInt()));

        if (mounted) {
          setState(() {
            _routePoints = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList();
            _rawDistanceMeters = route['distance'].toDouble();
            _distance = "${(_rawDistanceMeters / 1000).toStringAsFixed(1)} km";
            _duration = "${(durSeconds / 60).toStringAsFixed(0)} min";
            _arrivalTime = DateFormat('h:mm a').format(eta);
          });
        }
      }
    } catch (e) { debugPrint("Route Error: $e"); }
  }

  // --- UI: MODERN PIN ENTRY BOTTOM SHEET ---
  void _verifyAndFinish() {
    final TextEditingController pinController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 30,
          top: 20, left: 30, right: 30,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            const Icon(Icons.verified_user, size: 50, color: Color(0xFF11A860)),
            const SizedBox(height: 15),
            const Text("Confirm Arrival", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Enter your 4-digit security PIN to confirm you reached your destination.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            
            // Large spaced PIN entry for better UX
            SizedBox(
              width: 220,
              child: TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                autofocus: true,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, letterSpacing: 25, fontWeight: FontWeight.bold, color: Color(0xFF2B5145)),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "••••",
                  hintStyle: TextStyle(color: Colors.grey.shade300, letterSpacing: 25),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade200, width: 2)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF11A860), width: 2)),
                ),
                onChanged: (val) {
                  if (val.length == 4) {
                    _processPinSubmit(ctx, val);
                  }
                },
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF11A860), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                onPressed: () => _processPinSubmit(ctx, pinController.text),
                child: const Text("FINISH TRIP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // --- LOGIC: VERIFY PIN & UPDATE FIRESTORE ---
  void _processPinSubmit(BuildContext modalCtx, String enteredPin) async {
    if (enteredPin == _userSecurityPin) {
      Navigator.pop(modalCtx); // Close Bottom Sheet
      
      try {
        // Update database with requested naming convention
        await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
          'passenger_routes.$_uid.passenger_destinatin_reached_clicked': true,
        });

        if (mounted) {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => PassengerPaymentPage(rideId: widget.rideId, rideData: widget.rideData))
          );
        }
      } catch (e) {
        debugPrint("Error: $e");
      }
    } else if (enteredPin.length == 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Incorrect Security PIN"), backgroundColor: Colors.red)
      );
    }
  }

  @override
  void dispose() {
    _myPosSub?.cancel();
    _driverSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isNearDropoff = _rawDistanceMeters < 400; // Check if within 400m

    return Scaffold(
      body: Stack(
        children: [
          // 1. THE MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _dropoffPos, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', 
                userAgentPackageName: 'com.example.linkride'
              ),
              if (_routePoints.isNotEmpty) 
                PolylineLayer(polylines: [
                  Polyline(points: _routePoints, color: const Color(0xFF11A860), strokeWidth: 6)
                ]),
              MarkerLayer(markers: [
                if (_driverPos != null) 
                  Marker(point: _driverPos!, width: 60, height: 60, child: Column(children: [_label("Driver", Colors.blue), const Icon(Icons.directions_car_filled, color: Colors.blue, size: 30)])),
                Marker(point: _dropoffPos, width: 100, height: 70, child: Column(children: [_label("Drop-off", Colors.red), const Icon(Icons.location_on, color: Colors.red, size: 40)])),
                if (_myPos != null) 
                  Marker(point: _myPos!, width: 100, height: 70, child: Column(children: [_label("You", Colors.orange), const Icon(Icons.person_pin_circle, color: Colors.orange, size: 35)])),
              ]),
            ],
          ),

          // 2. TOP BUTTONS (BACK & SOS)
          Positioned(
            top: 50, left: 20, right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
                
                // Calling the isolated SOS Button widget
                SosButton(
                  uid: _uid, 
                  passengerName: _passengerName, 
                  guardianPhone: _guardianPhone, 
                  currentPos: _myPos
                ),
              ],
            ),
          ),

          // 3. BOTTOM INFO PANEL
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

  Widget _label(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)));
  
  Widget _metric(String l, String v, IconData i) => Column(children: [Icon(i, color: const Color(0xFF11A860), size: 20), const SizedBox(height: 5), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(l, style: const TextStyle(color: Colors.grey, fontSize: 11))]);
}