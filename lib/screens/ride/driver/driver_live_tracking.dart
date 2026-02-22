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
import 'package:linkride/screens/user/dashboard/inbox/chat_screen.dart';
import 'driver_security_verify.dart';

class DriverLiveTracking extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final String rideId;

  const DriverLiveTracking({super.key, required this.rideId, required this.rideData});

  @override
  State<DriverLiveTracking> createState() => _DriverLiveTrackingState();
}

class _DriverLiveTrackingState extends State<DriverLiveTracking> {
  final MapController _mapController = MapController();
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;
  
  LatLng? _myPos;
  LatLng? _passengerPos;
  List<LatLng> _routePoints = [];
  String? _passengerUid;
  String _passengerName = "Passenger";
  bool _passengerOnline = false;

  final Color primaryGreen = const Color(0xFF11A860);
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _passengerUid = (widget.rideData['passengers'] as List).first.toString();
    _fetchPassengerName();
    _startBroadcasting();
    _listenToPassenger();
  }

  void _startBroadcasting() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5)
    ).listen((pos) {
      if (mounted) {
        setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
        FirebaseDatabase.instance.ref('user_locations/$_myUid').update({
          'lat': pos.latitude, 'lng': pos.longitude, 'is_active': true, 'last_updated': ServerValue.timestamp,
        });
      }
    });
  }

  void _listenToPassenger() {
    FirebaseDatabase.instance.ref('user_locations/$_passengerUid').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      if (mounted) {
        setState(() {
          _passengerOnline = data['is_active'] ?? false;
          _passengerPos = LatLng(data['lat'], data['lng']);
        });
        _fetchRoute();
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (_myPos == null || _passengerPos == null) return;
    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${_myPos!.longitude},${_myPos!.latitude};${_passengerPos!.longitude},${_passengerPos!.latitude}?overview=full&geometries=geojson');
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        _routePoints = (data['routes'][0]['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList();
      });
    }
  }

  Future<void> _fetchPassengerName() async {
    var doc = await FirebaseFirestore.instance.collection('users').doc(_passengerUid).get();
    if (doc.exists) setState(() => _passengerName = doc.get('name').split(' ')[0]);
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
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _myPos ?? const LatLng(11.25, 75.78), initialZoom: 15),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              if (_routePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _routePoints, color: Colors.blue, strokeWidth: 5)]),
              MarkerLayer(markers: [
                if (_myPos != null) Marker(point: _myPos!, child: const Icon(Icons.directions_car, color: Colors.blue, size: 30)),
                if (_passengerPos != null) Marker(point: _passengerPos!, child: const Icon(Icons.person_pin_circle, color: Colors.orange, size: 35)),
              ]),
            ],
          ),
          Positioned(top: 50, left: 20, child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)))),
          
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Coordinating with $_passengerName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: "${widget.rideId}_$_passengerUid", otherUserName: _passengerName))),
                          icon: const Icon(Icons.chat), label: const Text("CHAT"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DriverSecurityVerify(rideId: widget.rideId))),
                          child: const Text("I HAVE ARRIVED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}