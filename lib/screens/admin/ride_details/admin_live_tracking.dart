import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class AdminLiveTracking extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const AdminLiveTracking({super.key, required this.rideId, required this.rideData});

  @override
  State<AdminLiveTracking> createState() => _AdminLiveTrackingState();
}

class _AdminLiveTrackingState extends State<AdminLiveTracking> {
  final MapController _mapController = MapController();
  
  LatLng? _driverPos;
  // Store live positions of all passengers: {uid: LatLng}
  final Map<String, LatLng> _passengerLivePositions = {};
  
  List<LatLng> _roadPoints = []; 
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _listenToDriver();
    _listenToPassengers();
    _fetchRoadRoute(); 
  }

  // --- LISTENERS ---

  void _listenToDriver() {
    String dUid = widget.rideData['driver_uid'];
    var sub = FirebaseDatabase.instance.ref('user_locations/$dUid').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        if (mounted) {
          setState(() => _driverPos = LatLng(data['lat'], data['lng']));
          // Optional: Auto-follow driver
          // _mapController.move(_driverPos!, 14);
        }
      }
    });
    _subscriptions.add(sub);
  }

  void _listenToPassengers() {
    Map<String, dynamic> routes = widget.rideData['passenger_routes'] ?? {};
    
    for (String pUid in routes.keys) {
      var sub = FirebaseDatabase.instance.ref('user_locations/$pUid').onValue.listen((event) {
        if (event.snapshot.value != null) {
          final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
          if (mounted) {
            setState(() {
              _passengerLivePositions[pUid] = LatLng(data['lat'], data['lng']);
            });
          }
        }
      });
      _subscriptions.add(sub);
    }
  }

  // --- ROUTE FETCHING ---

  Future<void> _fetchRoadRoute() async {
    final source = widget.rideData['source'];
    final dest = widget.rideData['destination'];
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${source['lng']},${source['lat']};${dest['lng']},${dest['lat']}?overview=full&geometries=geojson');

    try {
      final response = await http.get(url, headers: {'User-Agent': 'LinkRide_Admin'});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        setState(() {
          _roadPoints = coords.map((c) => LatLng(c[1], c[0])).toList();
        });
      }
    } catch (e) {
      debugPrint("Route error: $e");
    }
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> passengerRoutes = widget.rideData['passenger_routes'] ?? {};
    LatLng rideStart = LatLng(widget.rideData['source']['lat'], widget.rideData['source']['lng']);
    LatLng rideEnd = LatLng(widget.rideData['destination']['lat'], widget.rideData['destination']['lng']);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Ride Monitor", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _driverPos ?? rideStart, 
              initialZoom: 13
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              if (_roadPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(points: _roadPoints, color: Colors.blue.withOpacity(0.4), strokeWidth: 5),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // 1. DRIVER PIN
                  if (_driverPos != null)
                    Marker(
                      point: _driverPos!, 
                      width: 50, height: 50,
                      child: const Icon(Icons.navigation, color: Colors.blue, size: 40)
                    ),
                  
                  // 2. GLOBAL RIDE START/END
                  Marker(point: rideStart, child: const Icon(Icons.trip_origin, color: Colors.black, size: 20)),
                  Marker(point: rideEnd, child: const Icon(Icons.flag, color: Colors.red, size: 35)),

                  // 3. PASSENGER SPECIFIC MARKERS
                  ...passengerRoutes.entries.expand((entry) {
                    String pUid = entry.key;
                    var data = entry.value;
                    LatLng pPickup = LatLng(data['pickup']['lat'], data['pickup']['lng']);
                    LatLng pDropoff = LatLng(data['dropoff']['lat'], data['dropoff']['lng']);
                    LatLng? pLive = _passengerLivePositions[pUid];

                    return [
                      // Pickup Point (Small orange circle)
                      Marker(
                        point: pPickup, 
                        child: const Icon(Icons.circle, color: Colors.orange, size: 12)
                      ),
                      // Dropoff Point (Small green circle)
                      Marker(
                        point: pDropoff, 
                        child: const Icon(Icons.circle, color: Colors.green, size: 12)
                      ),
                      // Live Passenger Position (Person icon)
                      if (pLive != null)
                        Marker(
                          point: pLive, 
                          width: 40, height: 40,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.orange, width: 1)),
                                child: Text(data['passenger_name'].toString().split(' ')[0], style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                              ),
                              const Icon(Icons.person_pin_circle, color: Colors.orange, size: 25),
                            ],
                          )
                        ),
                    ];
                  }),
                ],
              ),
            ],
          ),
          
          // --- TOP LEGEND ---
          Positioned(
            top: 20, left: 15, right: 15,
            child: _buildLegend(),
          ),

          // --- BOTTOM INFO PANEL ---
          Positioned(
            bottom: 30, left: 15, right: 15,
            child: _buildRideDetailsCard(passengerRoutes.length),
          )
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _legendItem(Icons.navigation, Colors.blue, "Driver"),
          _legendItem(Icons.person_pin_circle, Colors.orange, "Passenger"),
          _legendItem(Icons.circle, Colors.orange, "Pickup"),
          _legendItem(Icons.circle, Colors.green, "Dropoff"),
        ],
      ),
    );
  }

  Widget _legendItem(IconData icon, Color color, String label) => Row(
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    ],
  );

  Widget _buildRideDetailsCard(int passengerCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black12)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat("Onboard", "$passengerCount"),
              _buildStat("Price", "₹${widget.rideData['price_per_seat']}"),
              _buildStat("Status", widget.rideData['status'].toString().toUpperCase()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String val) => Column(
    children: [
      Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))
    ]
  );
}