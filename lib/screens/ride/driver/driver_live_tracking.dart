import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; 
import '../../user/dashboard/inbox/chat_screen.dart';
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

  LatLng? _driverCurrentPos; 
  LatLng? _targetPos;        
  List<LatLng> _routePoints = [];

  // Metrics
  String _distance = "--";
  String _duration = "--";
  String _arrivalTime = "--:--"; 

  StreamSubscription<DatabaseEvent>? _driverLocationSub;
  bool _isMapReady = false;
  bool _isHeaderExpanded = true;

  @override
  void initState() {
    super.initState();
    _listenToMyMovingLocation();
  }

  void _fitMap() {
    if (!_isMapReady || _driverCurrentPos == null || _targetPos == null) return;
    var bounds = LatLngBounds.fromPoints([_driverCurrentPos!, _targetPos!]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 50)),
    );
  }

  void _listenToMyMovingLocation() {
    _driverLocationSub = FirebaseDatabase.instance.ref('user_locations/$_myUid').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      LatLng newPos = LatLng(data['lat'], data['lng']);

      if (mounted) {
        setState(() => _driverCurrentPos = newPos);
        if (_targetPos != null) {
          _fetchRoadRoute(_driverCurrentPos!, _targetPos!);
          if (_routePoints.isEmpty) _fitMap();
        }
      }
    });
  }

  Future<void> _fetchRoadRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0];
        final double durationSeconds = route['duration'].toDouble();
        
        final DateTime now = DateTime.now();
        final DateTime arrivalDateTime = now.add(Duration(seconds: durationSeconds.toInt()));

        if (mounted) {
          setState(() {
            _routePoints = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList();
            _distance = "${(route['distance'] / 1000).toStringAsFixed(1)} km";
            _duration = "${(durationSeconds / 60).toStringAsFixed(0)} min";
            _arrivalTime = DateFormat('h:mm a').format(arrivalDateTime);
          });
        }
      }
    } catch (e) {
      debugPrint("OSRM Error: $e");
    }
  }

  // --- IMMEDIATE TRANSITION LOGIC ---
  Future<void> _handleArrivedPressed(String pUid, Map<String, dynamic> rideData) async {
    // 1. Move the Driver to the PIN verification screen immediately
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverSecurityVerify(
          rideId: widget.rideId,
          passengerUid: pUid,
          rideData: rideData,
        ),
      ),
    );

    // 2. Update the Database in the background (Passenger will see this)
    try {
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'passenger_routes.$pUid.driver_clicked_arrived': true,
      });
    } catch (e) {
      debugPrint("Background DB update error: $e");
    }
  }

  @override
  void dispose() {
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
          List passengers = ride['passengers'] ?? [];
          Map<String, dynamic> routes = ride['passenger_routes'] ?? {};
          
          String? pUid;
          for (var id in passengers) {
            if (routes[id]['ride_status'] != 'security_completed') {
              pUid = id.toString();
              break;
            }
          }

          bool hasActivePickup = pUid != null;
          String activePassengerName = hasActivePickup ? (routes[pUid]['passenger_name'] ?? "Passenger") : "";
          String activePickupAddress = hasActivePickup ? (routes[pUid]['pickup']['name'] ?? "Pickup Location") : "";

          if (hasActivePickup) {
            var pRoute = routes[pUid]['pickup'];
            _targetPos = LatLng(pRoute['lat'], pRoute['lng']);
          } else {
            _targetPos = LatLng(ride['destination']['lat'], ride['destination']['lng']);
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _driverCurrentPos ?? const LatLng(11.2, 75.7),
                  initialZoom: 14,
                  onMapReady: () { setState(() => _isMapReady = true); _fitMap(); },
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.linkride'),
                  if (_routePoints.isNotEmpty) 
                    PolylineLayer(polylines: [Polyline(points: _routePoints, color: Colors.blueAccent, strokeWidth: 5)]),
                  MarkerLayer(markers: [
                    if (_driverCurrentPos != null) Marker(point: _driverCurrentPos!, child: const Icon(Icons.navigation, color: Colors.blue, size: 35)),
                    Marker(point: _targetPos!, child: Icon(hasActivePickup ? Icons.person_pin_circle : Icons.location_on, color: hasActivePickup ? Colors.orange : Colors.red, size: 45)),
                  ]),
                ],
              ),

              Positioned(top: 50, left: 20, child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)))),

              if (hasActivePickup)
                Positioned(
                  top: 100, left: 20, right: 20,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(radius: 18, backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.person, color: Color(0xFF11A860), size: 20)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text("NEXT PICKUP", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                              Text(activePassengerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ])),
                            IconButton(
                              icon: Icon(_isHeaderExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.grey),
                              onPressed: () => setState(() => _isHeaderExpanded = !_isHeaderExpanded),
                            )
                          ],
                        ),
                        if (_isHeaderExpanded)
                          Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [
                            const Icon(Icons.location_on, color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(activePickupAddress, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
                          ])),
                      ],
                    ),
                  ),
                ),

              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)]),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(hasActivePickup ? "Driving to Pickup" : "Heading to Ride Destination", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _metricItem("Distance", _distance, Icons.straighten),
                          _metricItem("Duration", _duration, Icons.timer),
                          _metricItem("Arrival At", _arrivalTime, Icons.access_time),
                        ],
                      ),
                      const SizedBox(height: 25),
                      if (hasActivePickup)
                        Row(
                          children: [
                            Expanded(child: OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: "${widget.rideId}_$pUid", otherUserName: activePassengerName))), child: const Text("CHAT"))),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF11A860)), 
                                onPressed: pUid != null ? () => _handleArrivedPressed(pUid!, ride) : null, 
                                child: const Text("ARRIVED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                              )
                            ),
                          ],
                        )
                      else
                        const Text("Proceed to final destination", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
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

  Widget _metricItem(String label, String value, IconData icon) => Column(children: [Icon(icon, color: const Color(0xFF11A860), size: 22), const SizedBox(height: 5), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11))]);
}