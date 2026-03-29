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
import 'package:intl/intl.dart';
import '../../../widgets/sos_button.dart';
import 'passenger_security_display.dart';
// --- ADDED IMPORT ---
import '../../user/dashboard/inbox/chat_screen.dart';

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
  LatLng? _pickupPos;

  List<LatLng> _driverRoutePoints = [];
  bool _isMapReady = false;

  String _distance = "--";
  String _duration = "--";
  String _arrivalTime = "--:--";

  // Guardian Mode variables
  bool _guardianModeEnabled = false;
  bool _isGuardianLinkSending = false;
  String? _passengerName;
  String? _guardianPhone;

  StreamSubscription<Position>? _myLocationSub;
  StreamSubscription<DatabaseEvent>? _driverLocationSub;

  @override
  void initState() {
    super.initState();
    _startMyTracking();
    _listenToDriver();
    _fetchPassengerData();
  }

  /// Fetch passenger name and guardian phone
  Future<void> _fetchPassengerData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_myUid)
          .get();
      if (doc.exists) {
        setState(() {
          _passengerName = doc.data()?['name'] ?? "Passenger";
          _guardianPhone = doc.data()?['guardian_phone'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching passenger data: $e");
    }
  }

  void _startMyTracking() {
    _myLocationSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((pos) {
          if (mounted) {
            setState(() => _myPos = LatLng(pos.latitude, pos.longitude));
            _fitMap();
          }
        });
  }

  void _listenToDriver() {
    String dUid = widget.rideData['driver_uid'];
    _driverLocationSub = FirebaseDatabase.instance
        .ref('user_locations/$dUid')
        .onValue
        .listen((event) {
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
    if (!_isMapReady ||
        _myPos == null ||
        _driverPos == null ||
        _pickupPos == null)
      return;
    var bounds = LatLngBounds.fromPoints([_myPos!, _driverPos!, _pickupPos!]);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(70)),
    );
  }

  Future<void> _fetchDriverRoadRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0];
        final double durationSeconds = route['duration'].toDouble();
        final DateTime arrivalTime = DateTime.now().add(
          Duration(seconds: durationSeconds.toInt()),
        );

        if (mounted) {
          setState(() {
            _driverRoutePoints = (route['geometry']['coordinates'] as List)
                .map((c) => LatLng(c[1], c[0]))
                .toList();
            _distance = "${(route['distance'] / 1000).toStringAsFixed(1)} km";
            _duration = "${(durationSeconds / 60).toStringAsFixed(0)} min";
            _arrivalTime = DateFormat('h:mm a').format(arrivalTime);
          });
        }
      }
    } catch (e) {}
  }

  Future<void> _handlePassengerArrived() async {
    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({'passenger_routes.$_myUid.passenger_clicked_arrived': true});

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PassengerSecurityDisplay(rideId: widget.rideId),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating arrival: $e");
    }
  }

  /// Handle Guardian Mode toggle
  Future<void> _handleGuardianModeToggle(bool value) async {
    setState(() => _isGuardianLinkSending = true);

    if (value) {
      // Enable Guardian Mode - send link to guardian
      debugPrint("🛡️ Enabling Guardian Mode...");

      bool success = await SosButton.sendGuardianLink(
        passengerUid: _myUid,
        guardianPhone: _guardianPhone,
        passengerName: _passengerName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? "✅ Guardian Mode enabled - link sent to ${_guardianPhone}"
                  : "⚠️ Guardian Mode enabled but link send failed",
            ),
            backgroundColor: success ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );

        setState(() {
          _guardianModeEnabled = value;
          _isGuardianLinkSending = false;
        });
      }
    } else {
      // Disable Guardian Mode
      if (mounted) {
        setState(() {
          _guardianModeEnabled = value;
          _isGuardianLinkSending = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Guardian Mode disabled"),
            backgroundColor: Colors.grey,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
        stream: FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var ride = snapshot.data!.data() as Map<String, dynamic>;

          var myRouteData = ride['passenger_routes'][_myUid];
          _pickupPos = LatLng(
            myRouteData['pickup']['lat'],
            myRouteData['pickup']['lng'],
          );

          // FETCH FLAG: Has driver marked arrival?
          bool isDriverArrived = myRouteData['driver_clicked_arrived'] ?? false;

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _pickupPos!,
                  initialZoom: 15,
                  onMapReady: () {
                    setState(() => _isMapReady = true);
                    _fitMap();
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.linkride',
                  ),
                  if (_driverRoutePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _driverRoutePoints,
                          color: Colors.blue,
                          strokeWidth: 5,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_driverPos != null)
                        Marker(
                          point: _driverPos!,
                          width: 80,
                          height: 80,
                          child: Column(
                            children: [
                              _labelContainer("Driver", Colors.blue),
                              const Icon(
                                Icons.directions_car,
                                color: Colors.blue,
                                size: 30,
                              ),
                            ],
                          ),
                        ),
                      Marker(
                        point: _pickupPos!,
                        width: 130,
                        height: 80,
                        child: Column(
                          children: [
                            _labelContainer("PICKUP", Colors.red),
                            const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ],
                        ),
                      ),
                      if (_myPos != null)
                        Marker(
                          point: _myPos!,
                          width: 110,
                          height: 80,
                          child: Column(
                            children: [
                              _labelContainer("YOU", Colors.orange),
                              const Icon(
                                Icons.person_pin_circle,
                                color: Colors.orange,
                                size: 35,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Floating Back Button
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

              // --- ARRIVAL NOTIFICATION BANNER ---
              if (isDriverArrived)
                Positioned(
                  top: 110,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.green, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 10),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 30,
                        ),
                        const SizedBox(width: 15),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Driver is here!",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                "Look for the car at your pickup point.",
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom Panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Driver is on the way",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Guardian Mode Toggle
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: _guardianModeEnabled
                              ? Colors.blue.shade50
                              : Colors.grey.shade100,
                          border: Border.all(
                            color: _guardianModeEnabled
                                ? Colors.blue
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield,
                              color: _guardianModeEnabled
                                  ? Colors.blue
                                  : Colors.grey,
                              size: 28,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Guardian Mode",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _guardianModeEnabled
                                        ? "Tracking link sent to guardian"
                                        : "Enable to share live location with guardian",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _guardianModeEnabled,
                              onChanged: _isGuardianLinkSending
                                  ? null
                                  : _handleGuardianModeToggle,
                              activeColor: Colors.blue,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _metric("Distance", _distance),
                          _metric("Duration", _duration),
                          _metric("Arrival At", _arrivalTime),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(
  child: OutlinedButton(
    onPressed: () {
      // 1. Construct the chatId: rideId + underscore + passengerUid
      // This matches the format used in BookingService: "${rId}_$pId"
      final String chatId = "${widget.rideId}_$_myUid";

      // 2. Get the Driver's name from the current stream data (ride)
      final String driverName = ride['driver_name'] ?? "Driver";

      // 3. Navigate to the Chat Screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: chatId,
            otherUserName: driverName,
          ),
        ),
      );
    },
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 15),
      side: BorderSide(color: Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: const Text(
      "MESSAGE",
      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
    ),
  ),
),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDriverArrived
                                    ? Colors.orange
                                    : const Color(0xFF11A860),
                              ),
                              onPressed: _handlePassengerArrived,
                              child: Text(
                                isDriverArrived
                                    ? "GO TO PIN"
                                    : "DRIVER ARRIVED",
                                style: const TextStyle(
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
          );
        },
      ),
    );
  }

  Widget _metric(String l, String v) => Column(
    children: [
      Text(
        v,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      Text(l, style: const TextStyle(color: Colors.grey, fontSize: 11)),
    ],
  );

  Widget _labelContainer(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
