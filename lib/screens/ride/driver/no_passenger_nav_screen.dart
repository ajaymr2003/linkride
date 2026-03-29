import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class NoPassengerNavScreen extends StatefulWidget {
  final Map<String, dynamic> rideData;
  final String rideId;

  const NoPassengerNavScreen({super.key, required this.rideId, required this.rideData});

  @override
  State<NoPassengerNavScreen> createState() => _NoPassengerNavScreenState();
}

class _NoPassengerNavScreenState extends State<NoPassengerNavScreen> {
  final MapController _mapController = MapController();
  final String _myUid = FirebaseAuth.instance.currentUser!.uid;

  late String _currentRideId;
  late Map<String, dynamic> _currentRideData;
  LatLng? _currentPos;
  late LatLng _destinationPos;
  List<LatLng> _routePoints = [];

  double _speed = 0.0;
  String _distance = "-- km";
  String _duration = "-- min";
  bool _isEndingRide = false;

  StreamSubscription<Position>? _positionStream;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _currentRideId = widget.rideId;
    _currentRideData = widget.rideData;
    _updateInternalDestination();
    _fetchInitialLocationFromRTDB();
    _startLocationTracking();
  }

  void _updateInternalDestination() {
    _destinationPos = LatLng(
      _currentRideData['destination']['lat'],
      _currentRideData['destination']['lng'],
    );
    _fetchRouteToDestination();
  }

  // --- END RIDE LOGIC ---
  Future<void> _handleDestinationReached() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Destination Reached?"),
        content: const Text("This will mark this specific ride as completed and end the navigation."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Yes, Finish", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isEndingRide = true);

    try {
      // 1. Update Firestore status
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(_currentRideId)
          .update({
            'status': 'completed',
            'ride_status': 'completed',
            'completed_at': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      // 2. Check if there are other rides today
      final now = DateTime.now();
      final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
      final endOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59));

      var otherRidesQuery = await FirebaseFirestore.instance
          .collection('rides')
          .where('driver_uid', isEqualTo: _myUid)
          .where('departure_time', isGreaterThanOrEqualTo: startOfDay)
          .where('departure_time', isLessThanOrEqualTo: endOfDay)
          .where('status', isEqualTo: 'active')
          .get();

      if (otherRidesQuery.docs.isNotEmpty) {
        // Switch to the first available ride found
        var nextRide = otherRidesQuery.docs.first;
        setState(() {
          _currentRideId = nextRide.id;
          _currentRideData = nextRide.data();
          _isEndingRide = false;
          _updateInternalDestination();
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride completed! Switching to next trip.")));
      } else {
        // No more rides, go back
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("All rides completed. Well done!")));
      }
    } catch (e) {
      setState(() => _isEndingRide = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // --- RTDB FETCH ---
  Future<void> _fetchInitialLocationFromRTDB() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('user_locations/$_myUid').get();
      if (snapshot.exists) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        LatLng rtdbPos = LatLng((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());
        if (mounted) {
          setState(() => _currentPos = rtdbPos);
          _mapController.move(rtdbPos, 15);
          _fetchRouteToDestination();
        }
      }
    } catch (e) { debugPrint("RTDB Fetch Error: $e"); }
  }

  // --- GPS TRACKING ---
  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 10),
    ).listen((Position pos) {
      if (mounted) {
        LatLng newPos = LatLng(pos.latitude, pos.longitude);
        setState(() { _currentPos = newPos; _speed = pos.speed * 3.6; });
        FirebaseDatabase.instance.ref('user_locations/$_myUid').update({
          'lat': pos.latitude, 'lng': pos.longitude, 'is_active': true, 'last_updated': ServerValue.timestamp,
        });
        if (_isFirstLoad) { _mapController.move(newPos, 15); _isFirstLoad = false; }
        _fetchRouteToDestination();
      }
    });
  }

  Future<void> _fetchRouteToDestination() async {
    if (_currentPos == null) return;
    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${_currentPos!.longitude},${_currentPos!.latitude};${_destinationPos.longitude},${_destinationPos.latitude}?overview=full&geometries=geojson');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0];
        if (mounted) {
          setState(() {
            _routePoints = (route['geometry']['coordinates'] as List).map((c) => LatLng(c[1], c[0])).toList();
            _distance = "${(route['distance'] / 1000).toStringAsFixed(1)} km";
            _duration = "${(route['duration'] / 60).toStringAsFixed(0)} min";
          });
        }
      }
    } catch (e) { debugPrint("Route Error: $e"); }
  }

  @override
  void dispose() { _positionStream?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59));

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _currentPos ?? _destinationPos, initialZoom: 15),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.linkride.app'),
              if (_routePoints.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _routePoints, color: Colors.blueAccent, strokeWidth: 6)]),
              MarkerLayer(markers: [
                if (_currentPos != null) Marker(point: _currentPos!, child: const Icon(Icons.navigation, color: Colors.blue, size: 40)),
                Marker(point: _destinationPos, child: const Icon(Icons.location_on, color: Colors.red, size: 45)),
              ]),
            ],
          ),

          // TOP BANNER / SWITCHER
          Positioned(
            top: 50, left: 0, right: 0,
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 20),
                    CircleAvatar(backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context))),
                  ],
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('rides')
                      .where('driver_uid', isEqualTo: _myUid)
                      .where('departure_time', isGreaterThanOrEqualTo: startOfDay)
                      .where('departure_time', isLessThanOrEqualTo: endOfDay)
                      .where('status', isEqualTo: 'active') // Only show active rides
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.length <= 1) return const SizedBox.shrink();
                    var rides = snapshot.data!.docs;
                    return Container(
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: rides.length,
                        itemBuilder: (context, index) {
                          var rDoc = rides[index];
                          var rData = rDoc.data() as Map<String, dynamic>;
                          bool isCurrent = rDoc.id == _currentRideId;
                          return GestureDetector(
                            onTap: () { setState(() { _currentRideId = rDoc.id; _currentRideData = rData; _updateInternalDestination(); }); },
                            child: Container(
                              margin: const EdgeInsets.all(8), padding: const EdgeInsets.symmetric(horizontal: 15),
                              decoration: BoxDecoration(color: isCurrent ? Colors.blue : Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                              alignment: Alignment.center,
                              child: Text("To ${rData['destination']['name']}", style: TextStyle(color: isCurrent ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // BOTTOM PANEL
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metricItem("Distance", _distance, Icons.straighten),
                      _metricItem("Duration", _duration, Icons.timer),
                      _metricItem("Speed", "${_speed.toStringAsFixed(0)} km/h", Icons.speed),
                    ],
                  ),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B5145), // Dark green theme
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      onPressed: _isEndingRide ? null : _handleDestinationReached,
                      child: _isEndingRide 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("DESTINATION REACHED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
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

  Widget _metricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF11A860), size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}