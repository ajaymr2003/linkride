import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; 
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
  
  LatLng? _driverPos;           
  LatLng? _passengerDropoff;    
  late LatLng _driverFinalDest; 
  
  List<LatLng> _liveRoutePoints = [];   
  List<LatLng> _finalRoutePoints = [];  
  
  String _distance = "--";
  String _duration = "--";
  String _arrivalTime = "--:--"; 
  double _rawDistanceMeters = 9999;

  StreamSubscription<Position>? _positionStream;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _driverFinalDest = LatLng(
      widget.rideData['destination']['lat'], 
      widget.rideData['destination']['lng']
    );
    _startLiveTracking();
  }

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

  Future<void> _getLiveRoadRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0];
        final double durSeconds = route['duration'].toDouble();
        
        final DateTime eta = DateTime.now().add(Duration(seconds: durSeconds.toInt()));

        if (mounted) {
          setState(() {
            _liveRoutePoints = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList();
            _rawDistanceMeters = route['distance'].toDouble();
            _distance = "${(_rawDistanceMeters / 1000).toStringAsFixed(1)} km";
            _duration = "${(durSeconds / 60).toStringAsFixed(0)} min";
            _arrivalTime = DateFormat('h:mm a').format(eta);
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _getStaticFinalLeg(LatLng dropoff) async {
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${dropoff.longitude},${dropoff.latitude};${_driverFinalDest.longitude},${_driverFinalDest.latitude}?overview=full&geometries=geojson');
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

  Future<void> _handleReachedDestination(String pUid, String pName, dynamic pPrice) async {
    try {
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'passenger_routes.$pUid.driver_clicked_destination_reached': true,
      });

      if (mounted) {
        Navigator.push(
          context, 
          MaterialPageRoute(
            builder: (_) => DriverPaymentConfirmPage(
              rideId: widget.rideId, 
              passengerUid: pUid, 
              passengerName: pName, 
              price: pPrice, // Passing the specific fare
            )
          )
        );
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF11A860);
    const darkGreen = Color(0xFF2B5145);

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var data = snapshot.data!.data() as Map<String, dynamic>;
          Map<String, dynamic> routes = data['passenger_routes'] ?? {};

          String? activeUid;
          String passengerName = "Passenger";
          String dropoffName = "Destination";
          dynamic activePassengerFare = 0;
          
          for (var uid in routes.keys) {
            if (routes[uid]['ride_status'] == 'security_completed') {
              activeUid = uid;
              passengerName = routes[uid]['passenger_name'] ?? "Passenger";
              dropoffName = routes[uid]['dropoff']['name'] ?? "Destination";
              
              // --- UPDATED: Get specific fare stored for this user ---
              activePassengerFare = routes[uid]['fare'] ?? data['price_per_seat'] ?? 0;

              LatLng newDropoff = LatLng(routes[uid]['dropoff']['lat'], routes[uid]['dropoff']['lng']);
              if (_passengerDropoff == null || _passengerDropoff != newDropoff) {
                _passengerDropoff = newDropoff;
                _getStaticFinalLeg(newDropoff);
              }
              break;
            }
          }

          bool isNearDropoff = _rawDistanceMeters < 400; 

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _passengerDropoff ?? _driverFinalDest,
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.linkride'),
                  if (_liveRoutePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _liveRoutePoints, color: Colors.blueAccent, strokeWidth: 6)]),
                  if (_finalRoutePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _finalRoutePoints, color: Colors.redAccent, strokeWidth: 4, isDotted: true)]),
                  MarkerLayer(
                    markers: [
                      if (_driverPos != null) Marker(point: _driverPos!, child: const Icon(Icons.navigation, color: Colors.blue, size: 35)),
                      if (_passengerDropoff != null) Marker(point: _passengerDropoff!, width: 100, height: 70, child: Column(children: [_label("Drop-off", Colors.orange), const Icon(Icons.person_pin_circle, color: Colors.orange, size: 40)])),
                      Marker(point: _driverFinalDest, width: 100, height: 70, child: Column(children: [_label("Final Dest", Colors.red), const Icon(Icons.flag, color: Colors.red, size: 35)])),
                    ],
                  ),
                ],
              ),

              Positioned(top: 50, left: 20, child: CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)))),

              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(25, 20, 25, 30),
                  decoration: const BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)), 
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, spreadRadius: 5)]
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(radius: 26, backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.person, color: primaryGreen, size: 32)),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(passengerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: darkGreen)),
                                Text("To: $dropoffName", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _metricItem("DISTANCE", _distance, Icons.straighten),
                          _metricItem("TIME LEFT", _duration, Icons.timer_outlined),
                          _metricItem("REACHING AT", _arrivalTime, Icons.access_time_rounded),
                        ],
                      ),

                      const SizedBox(height: 25),

                      SizedBox(
                        width: double.infinity, height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isNearDropoff ? primaryGreen : Colors.blueGrey.shade600,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          onPressed: activeUid == null ? null : () => _handleReachedDestination(
                            activeUid!, 
                            passengerName, 
                            activePassengerFare // <--- PASSING STORED FARE
                          ),
                          child: const Text(
                            "DESTINATION REACHED", 
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)
                          ),
                        ),
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

  Widget _label(String text, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)), child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)));
  
  Widget _metricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF11A860), size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF2B5145))),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }
}