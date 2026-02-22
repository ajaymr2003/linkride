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
import 'chat_screen.dart';
import 'ride_security_page.dart'; // Ensure you create this file next

class RideLiveTrackingPage extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final String rideId;

  const RideLiveTrackingPage({super.key, required this.rideId, required this.rideData});

  @override
  State<RideLiveTrackingPage> createState() => _RideLiveTrackingPageState();
}

class _RideLiveTrackingPageState extends State<RideLiveTrackingPage> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? "";
  
  // Logic Variables
  late bool _amIDriver;
  String? _targetUid;
  String _targetName = "Co-traveler";
  String _chatId = "";

  // Locations & Route
  LatLng? _driverPos;
  LatLng? _passengerPos;
  List<LatLng> _routePoints = [];
  
  // UI Status Flags
  bool _targetOnline = false;
  bool _isMyGpsOff = false; 

  // Real-time Metrics
  String _duration = "--";
  String _distance = "--";
  double _mySpeed = 0.0;

  final Color primaryGreen = const Color(0xFF11A860);
  StreamSubscription<Position>? _myPositionStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _amIDriver = _myUid == widget.rideData['driver_uid'];
    
    _initTargetData();
    _checkGpsStatus();
    _setupLiveListeners();
    
    // Start broadcasting immediately
    _startBroadcastingMyLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopBroadcastingMyLocation();
    super.dispose();
  }

  // --- 1. AUTO-FOCUS LOGIC ---
  void _fitMap() {
    if (_driverPos != null && _passengerPos != null) {
      var bounds = LatLngBounds.fromPoints([_driverPos!, _passengerPos!]);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
      );
    } else if (_driverPos != null) {
      _mapController.move(_driverPos!, 15);
    } else if (_passengerPos != null) {
      _mapController.move(_passengerPos!, 15);
    }
  }

  // --- 2. BROADCAST MY LOCATION ---
  Future<void> _startBroadcastingMyLocation() async {
    try {
      // Force initial position fetch
      Position initialPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      await FirebaseDatabase.instance.ref('user_locations/$_myUid').set({
        'lat': initialPos.latitude,
        'lng': initialPos.longitude,
        'is_active': true,
        'last_updated': ServerValue.timestamp,
      });

      // Stream updates
      _myPositionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5)
      ).listen((pos) {
        if (mounted) {
          setState(() => _mySpeed = pos.speed * 3.6);
          FirebaseDatabase.instance.ref('user_locations/$_myUid').update({
            'lat': pos.latitude,
            'lng': pos.longitude,
            'is_active': true,
            'last_updated': ServerValue.timestamp,
          });
        }
      }, onError: (e) => _checkGpsStatus());
    } catch (e) {
      debugPrint("Broadcasting Error: $e");
    }
  }

  void _stopBroadcastingMyLocation() {
    _myPositionStream?.cancel();
    FirebaseDatabase.instance.ref('user_locations/$_myUid').update({'is_active': false});
  }

  // --- 3. DATA & LISTENERS ---
  void _initTargetData() {
    List passengers = widget.rideData['passengers'] ?? [];
    String driverUid = widget.rideData['driver_uid'];

    if (_amIDriver) {
      _targetUid = passengers.isNotEmpty ? passengers.first.toString() : null;
      _chatId = _targetUid != null ? "${widget.rideId}_$_targetUid" : "";
    } else {
      _targetUid = driverUid;
      _chatId = "${widget.rideId}_$_myUid";
    }
    _fetchTargetName();
  }

  Future<void> _fetchTargetName() async {
    if (_targetUid == null) return;
    var doc = await FirebaseFirestore.instance.collection('users').doc(_targetUid).get();
    if (doc.exists && mounted) {
      setState(() => _targetName = (doc.get('name') ?? "User").split(' ')[0]);
    }
  }

  void _setupLiveListeners() {
    // Listen to Driver
    FirebaseDatabase.instance.ref('user_locations/${widget.rideData['driver_uid']}').onValue.listen((event) {
      _processLocationUpdate(event, updateDriver: true);
    });

    // Listen to Passenger
    String? pUid = _amIDriver ? _targetUid : _myUid;
    if (pUid != null) {
      FirebaseDatabase.instance.ref('user_locations/$pUid').onValue.listen((event) {
        _processLocationUpdate(event, updateDriver: false);
      });
    }
  }

  void _processLocationUpdate(DatabaseEvent event, {required bool updateDriver}) {
    if (!mounted) return;
    final data = event.snapshot.value != null ? Map<dynamic, dynamic>.from(event.snapshot.value as Map) : null;
    bool isActive = data != null && data['is_active'] == true && data['lat'] != null;
    LatLng? newPos = isActive ? LatLng(data['lat'], data['lng']) : null;

    setState(() {
      if (updateDriver) {
        _driverPos = newPos;
        if (!_amIDriver) _targetOnline = isActive; 
      } else {
        _passengerPos = newPos;
        if (_amIDriver) _targetOnline = isActive;
      }
    });

    if (_driverPos != null && _passengerPos != null) {
      _fetchInterceptRoute();
      _fitMap(); // Auto-focus
    }
  }

  Future<void> _fetchInterceptRoute() async {
    final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/${_driverPos!.longitude},${_driverPos!.latitude};${_passengerPos!.longitude},${_passengerPos!.latitude}?overview=full&geometries=geojson');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0];
        if (mounted) {
          setState(() {
            _routePoints = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList();
            _duration = "${(route['duration'] / 60).toStringAsFixed(0)} min";
            _distance = "${(route['distance'] / 1000).toStringAsFixed(1)} km";
          });
        }
      }
    } catch (_) {}
  }

  // --- 4. GPS & NAVIGATION ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkGpsStatus();
  }

  Future<void> _checkGpsStatus() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (mounted) setState(() => _isMyGpsOff = !enabled);
  }

  void _goToSecurity() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RideSecurityPage(
      rideId: widget.rideId, 
      isDriver: _amIDriver,
      passengerUid: _amIDriver ? _targetUid! : _myUid,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _driverPos ?? const LatLng(11.25, 75.78), initialZoom: 14),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.linkride'),
              if (_routePoints.isNotEmpty && _targetOnline && !_isMyGpsOff)
                PolylineLayer(polylines: [Polyline(points: _routePoints, color: primaryGreen, strokeWidth: 5)]),
              MarkerLayer(
                markers: [
                  if (_driverPos != null) Marker(point: _driverPos!, child: _buildMarker(Icons.directions_car, Colors.blue, "Driver")),
                  if (_passengerPos != null) Marker(point: _passengerPos!, child: _buildMarker(Icons.person_pin_circle, Colors.orange, "Passenger")),
                ],
              ),
            ],
          ),

          if (_isMyGpsOff)
            _buildOverlay(Icons.location_off, "GPS is Off", "Please enable location to coordinate pickup.", "OPEN SETTINGS", () => Geolocator.openLocationSettings(), Colors.red.shade900),

          if (!_targetOnline && !_isMyGpsOff)
            _buildOverlay(Icons.person_search, "Waiting for $_targetName", "Ask them to open the tracking map!", "SEND MESSAGE", () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: _chatId, otherUserName: _targetName, initialText: "Hi! I'm on the map. Please turn on your location!"))), Colors.black.withOpacity(0.85)),

          Positioned(top: 50, left: 20, child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)))),

          if (_targetOnline && !_isMyGpsOff)
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomPanel()),
        ],
      ),
    );
  }

  Widget _buildOverlay(IconData i, String t, String s, String b, VoidCallback p, Color c) => Container(
    color: c, width: double.infinity, height: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 40),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(i, color: Colors.white, size: 70), const SizedBox(height: 20),
      Text(t, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(s, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
      const SizedBox(height: 30),
      ElevatedButton(onPressed: p, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)), child: Text(b)),
    ]),
  );

  Widget _buildMarker(IconData icon, Color color, String label) => Column(children: [
    Container(decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: Icon(icon, color: Colors.white, size: 20)),
    Container(padding: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white, child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)))
  ]);

  Widget _buildBottomPanel() => Container(
    padding: const EdgeInsets.all(25),
    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)]),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _metric("Distance", _distance, Icons.straighten),
        _metric(_amIDriver ? "To Passenger" : "To You", _duration, Icons.timer),
        _metric("My Speed", "${_mySpeed.toStringAsFixed(0)} km/h", Icons.speed),
      ]),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity, height: 50, 
        child: ElevatedButton(
          onPressed: _goToSecurity,
          style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(_amIDriver ? "I HAVE ARRIVED" : "VERIFY DRIVER", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      )
    ]),
  );

  Widget _metric(String l, String v, IconData i) => Column(children: [Icon(i, color: Colors.grey, size: 20), Text(v, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey))]);
}