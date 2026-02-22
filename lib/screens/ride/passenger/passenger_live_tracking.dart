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
import 'passenger_security_display.dart';

class PassengerLiveTracking extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final String rideId;

  const PassengerLiveTracking({
    super.key,
    required this.rideId,
    required this.rideData,
  });

  @override
  State<PassengerLiveTracking> createState() => _PassengerLiveTrackingState();
}

class _PassengerLiveTrackingState extends State<PassengerLiveTracking> {
  final MapController _mapController = MapController();
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  LatLng? _myPos;
  LatLng? _driverPos;
  List<LatLng> _routePoints = [];
  String _driverName = "Driver";

  @override
  void initState() {
    super.initState();
    _startBroadcasting();
    _listenToDriver();
    _fetchDriverName();
  }

  void _startBroadcasting() {
    Geolocator.getPositionStream().listen((pos) {
      if (mounted) {
        setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
        FirebaseDatabase.instance.ref('user_locations/$_myUid').update({
          'lat': pos.latitude,
          'lng': pos.longitude,
          'is_active': true,
          'last_updated': ServerValue.timestamp,
        });
      }
    });
  }

  void _listenToDriver() {
    String dUid = widget.rideData['driver_uid'];
    FirebaseDatabase.instance.ref('user_locations/$dUid').onValue.listen((
      event,
    ) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      if (mounted) {
        setState(() => _driverPos = LatLng(data['lat'], data['lng']));
        _fetchRoute();
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (_myPos == null || _driverPos == null) return;
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/${_driverPos!.longitude},${_driverPos!.latitude};${_myPos!.longitude},${_myPos!.latitude}?overview=full&geometries=geojson',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(
        () => _routePoints =
            (data['routes'][0]['geometry']['coordinates'] as List)
                .map((c) => LatLng(c[1], c[0]))
                .toList(),
      );
    }
  }

  Future<void> _fetchDriverName() async {
    var doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.rideData['driver_uid'])
        .get();
    if (doc.exists) setState(() => _driverName = doc.get('name').split(' ')[0]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myPos ?? const LatLng(11.25, 75.78),
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: Colors.green,
                      strokeWidth: 5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_driverPos != null)
                    Marker(
                      point: _driverPos!,
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),
                  if (_myPos != null)
                    Marker(
                      point: _myPos!,
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.orange,
                        size: 35,
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$_driverName is on the way",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: "${widget.rideId}_$_myUid",
                                otherUserName: _driverName,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.chat),
                          label: const Text("CHAT"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF11A860),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PassengerSecurityDisplay(
                                rideId: widget.rideId,
                              ),
                            ),
                          ),
                          child: const Text(
                            "VERIFY DRIVER",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
