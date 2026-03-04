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
  List<LatLng> _roadPoints = []; 
  StreamSubscription? _posSub;

  @override
  void initState() {
    super.initState();
    _listenToDriver();
    _fetchRoadRoute(); 
  }

  Future<void> _fetchRoadRoute() async {
    final source = widget.rideData['source'];
    final dest = widget.rideData['destination'];
    
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${source['lng']},${source['lat']};${dest['lng']},${dest['lat']}?overview=full&geometries=geojson');

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'LinkRide_Admin_App_v1', // Identifying OSRM request
      });
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

  void _listenToDriver() {
    String dUid = widget.rideData['driver_uid'];
    _posSub = FirebaseDatabase.instance.ref('user_locations/$dUid').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        if (mounted) {
          setState(() {
            _driverPos = LatLng(data['lat'], data['lng']);
          });
          // Move camera to follow driver if they moved significantly
          _mapController.move(_driverPos!, 14);
        }
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LatLng start = LatLng(widget.rideData['source']['lat'], widget.rideData['source']['lng']);
    LatLng end = LatLng(widget.rideData['destination']['lat'], widget.rideData['destination']['lng']);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Tracking", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _driverPos ?? start, 
              initialZoom: 13
            ),
            children: [
              TileLayer(
                // --- FIX: Switch to CartoDB Voyager tiles ( cleaner & more reliable ) ---
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.linkride.app', 
              ),
              if (_roadPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _roadPoints, 
                      color: Colors.blue.withOpacity(0.5), 
                      strokeWidth: 6,
                    ),
                  ],
                ),
              MarkerLayer(markers: [
                // DRIVER PIN
                if (_driverPos != null)
                  Marker(
                    point: _driverPos!, 
                    width: 60, height: 60,
                    child: const Icon(Icons.navigation, color: Colors.blue, size: 45)
                  ),
                
                // PICKUP PIN
                Marker(
                  point: start, 
                  child: const Icon(Icons.circle, color: Colors.green, size: 18)
                ),
                
                // DESTINATION PIN
                Marker(
                  point: end, 
                  width: 40, height: 40,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 40)
                ),
              ]),
            ],
          ),
          
          // --- TOP INFO OVERLAY ---
          Positioned(
            top: 20, left: 15, right: 15,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.1))]
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Monitoring Driver UID: ...${widget.rideData['driver_uid'].substring(0, 8)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  _statusPill(widget.rideData['status']),
                ],
              ),
            ),
          ),

          // --- BOTTOM DETAIL PANEL ---
          Positioned(
            bottom: 30, left: 15, right: 15,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, 
                borderRadius: BorderRadius.circular(20), 
                boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black.withOpacity(0.15))]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("RIDE DETAILS", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat("Passengers", "${(widget.rideData['passengers'] ?? []).length}"),
                      _buildStat("Price", "₹${widget.rideData['price_per_seat']}"),
                      _buildStat("Remaining", "${widget.rideData['available_seats']} Seats"),
                    ],
                  ),
                  const SizedBox(height: 15),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Tracking is live. Driver position updates every few seconds.",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
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

  Widget _statusPill(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(5)),
      child: Text(status.toUpperCase(), 
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 9)),
    );
  }

  Widget _buildStat(String label, String val) => Column(
    children: [
      Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey))
    ]
  );
}