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

  LatLng? _myPos;       
  LatLng? _driverPos;   
  LatLng? _pickupPos;   
  
  List<LatLng> _driverRoutePoints = []; 
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

  void _listenToDriver() {
    String dUid = widget.rideData['driver_uid'];
    _driverLocationSub = FirebaseDatabase.instance.ref('user_locations/$dUid').onValue.listen((event) {
      if (event.snapshot.value == null) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      
      if (mounted) {
        setState(() => _driverPos = LatLng(data['lat'], data['lng']));
        if (_pickupPos != null && _driverPos != null) {
          _fetchDriverRoadRoute(_driverPos!, _pickupPos!);
        }
        _fitMap();
      }
    });
  }

  void _fitMap() {
    if (!_isMapReady || _myPos == null || _driverPos == null || _pickupPos == null) return;
    var bounds = LatLngBounds.fromPoints([_myPos!, _driverPos!, _pickupPos!]);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(70)));
  }

  Future<void> _fetchDriverRoadRoute(LatLng start, LatLng end) async {
    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0];
        if (mounted) {
          setState(() {
            _driverRoutePoints = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList();
            _distance = "${(route['distance'] / 1000).toStringAsFixed(1)} km";
            _duration = "${(route['duration'] / 60).toStringAsFixed(0)} min";
          });
        }
      }
    } catch (e) {}
  }

  void _confirmDriverArrived(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Driver Arrived?"),
        content: const Text("Is the driver at your location? Confirming will generate the security PIN to start your ride."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("NO")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerSecurityDisplay(rideId: widget.rideId)));
            }, 
            child: const Text("YES, DRIVER IS HERE", style: TextStyle(color: Color(0xFF11A860), fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
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
          
          try {
             var myRoute = ride['passenger_routes'][_myUid]['pickup'];
             _pickupPos = LatLng(myRoute['lat'], myRoute['lng']);
          } catch (e) {
             _pickupPos = LatLng(ride['source']['lat'], ride['source']['lng']);
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _pickupPos!,
                  initialZoom: 15,
                  onMapReady: () { setState(() => _isMapReady = true); _fitMap(); },
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.linkride'),
                  if (_driverRoutePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _driverRoutePoints, color: Colors.blue, strokeWidth: 5)]),
                  if (_myPos != null && _pickupPos != null) PolylineLayer(polylines: [Polyline(points: [_myPos!, _pickupPos!], color: Colors.orange, strokeWidth: 3, isDotted: true)]),
                  MarkerLayer(markers: [
                    if (_driverPos != null) Marker(point: _driverPos!, width: 80, height: 80, child: Column(children: [_labelContainer("Driver", Colors.blue), const Icon(Icons.directions_car, color: Colors.blue, size: 30)])),
                    Marker(point: _pickupPos!, width: 130, height: 80, child: Column(children: [_labelContainer("PICKUP LOCATION", Colors.red), const Icon(Icons.location_on, color: Colors.red, size: 40)])),
                    if (_myPos != null) Marker(point: _myPos!, width: 110, height: 80, child: Column(children: [_labelContainer("YOUR LOCATION", Colors.orange), const Icon(Icons.person_pin_circle, color: Colors.orange, size: 35)])),
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
                              onPressed: () => _confirmDriverArrived(context),
                              child: const Text("DRIVER ARRIVED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Widget _labelContainer(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}