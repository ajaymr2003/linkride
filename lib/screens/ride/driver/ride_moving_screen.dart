import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'driver_payment_confirm_page.dart';

class RideMovingScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const RideMovingScreen({super.key, required this.rideId, required this.rideData});

  @override
  State<RideMovingScreen> createState() => _RideMovingScreenState();
}

class _RideMovingScreenState extends State<RideMovingScreen> {
  final MapController _mapController = MapController();
  
  LatLng? _driverPos;           // Live Driver GPS
  LatLng? _passengerDropoff;    // Target 1
  late LatLng _driverFinalDest; // Target 2 (Ride End)
  
  String? _activePassengerUid;
  String _passengerName = "Passenger";
  String _dropoffName = "Destination";

  List<LatLng> _liveRoutePoints = [];   // Solid line to passenger
  List<LatLng> _finalRoutePoints = [];  // Dotted line to driver's end
  
  String _distance = "--";
  String _duration = "--";
  double _rawDistanceMeters = 9999;

  StreamSubscription<Position>? _positionStream;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _initializePoints();
    _startLiveTracking();
  }

  // --- 1. INITIALIZE DATA ---
  void _initializePoints() {
    // A. Driver's actual ride destination
    _driverFinalDest = LatLng(
      widget.rideData['destination']['lat'], 
      widget.rideData['destination']['lng']
    );

    // B. Identifying the onboard passenger
    Map<String, dynamic> routes = widget.rideData['passenger_routes'] ?? {};
    routes.forEach((uid, data) {
      if (data['ride_status'] == 'security_completed') {
        setState(() {
          _activePassengerUid = uid;
          _passengerName = data['passenger_name'] ?? "Passenger";
          _dropoffName = data['dropoff']['name'] ?? "Drop-off";
          _passengerDropoff = LatLng(
            data['dropoff']['lat'], 
            data['dropoff']['lng']
          );
        });
        // Fetch the static leg (Passenger Dropoff -> Driver Final Destination)
        _getStaticFinalLeg();
      }
    });
  }

  // --- 2. LIVE GPS TRACKING (LEG 1) ---
  void _startLiveTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      LatLng currentPos = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() => _driverPos = currentPos);

        if (_isFirstLoad) {
          _mapController.move(currentPos, 14);
          _isFirstLoad = false;
        }

        if (_passengerDropoff != null) {
          _getLiveRoadRoute(currentPos, _passengerDropoff!);
        }
      }
    });
  }

  // --- 3. FETCH LIVE ROUTE (SOLID BLUE) ---
  Future<void> _getLiveRoadRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        setState(() {
          _liveRoutePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
          _rawDistanceMeters = data['routes'][0]['distance'].toDouble();
          _distance = "${(_rawDistanceMeters / 1000).toStringAsFixed(1)} km";
          _duration = "${(data['routes'][0]['duration'] / 60).toStringAsFixed(0)} min";
        });
      }
    } catch (e) {}
  }

  // --- 4. FETCH FINAL LEG (DOTTED RED) ---
  Future<void> _getStaticFinalLeg() async {
    if (_passengerDropoff == null) return;
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${_passengerDropoff!.longitude},${_passengerDropoff!.latitude};${_driverFinalDest.longitude},${_driverFinalDest.latitude}?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'] as List;
        setState(() {
          _finalRoutePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
        });
      }
    } catch (e) {}
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isAtDestination = _rawDistanceMeters < 300;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _passengerDropoff ?? const LatLng(11.2, 75.7),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.linkride',
              ),
              
              // 1. LIVE LEG (SOLID BLUE)
              if (_liveRoutePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: _liveRoutePoints, color: Colors.blueAccent, strokeWidth: 6),
                ]),
              
              // 2. FINAL LEG (DOTTED RED)
              if (_finalRoutePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: _finalRoutePoints, color: Colors.redAccent, strokeWidth: 4, isDotted: true),
                ]),

              MarkerLayer(
                markers: [
                  // Driver Marker
                  if (_driverPos != null)
                    Marker(point: _driverPos!, child: const Icon(Icons.navigation, color: Colors.blue, size: 35)),
                  
                  // Passenger Drop-off Marker
                  if (_passengerDropoff != null)
                    Marker(
                      point: _passengerDropoff!, width: 100, height: 70,
                      child: Column(children: [_label("Drop-off", Colors.orange), const Icon(Icons.person_pin_circle, color: Colors.orange, size: 40)]),
                    ),
                  
                  // Driver Final Destination Marker
                  Marker(
                    point: _driverFinalDest, width: 100, height: 70,
                    child: Column(children: [_label("Final Dest", Colors.red), const Icon(Icons.flag, color: Colors.red, size: 35)]),
                  ),
                ],
              ),
            ],
          ),

          // UI OVERLAYS
          Positioned(top: 50, left: 20, child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)))),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.person, color: Color(0xFF11A860))),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Driving $_passengerName", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Text("Target: $_dropoffName", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metricItem("Distance", _distance),
                      _metricItem("Arrival", _duration),
                    ],
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity, height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAtDestination ? const Color(0xFF11A860) : Colors.blueGrey,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => DriverPaymentConfirmPage(
                          rideId: widget.rideId, 
                          passengerUid: _activePassengerUid!, 
                          passengerName: _passengerName, 
                          price: widget.rideData['price_per_seat'] ?? 0,
                        )));
                      },
                      child: Text(
                        isAtDestination ? "REACHED DESTINATION" : "ARRIVED / COLLECT PAYMENT", 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                      ),
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
  
  Widget _metricItem(String label, String value) {
    return Column(children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blueAccent)), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11))]);
  }
}