import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import '../../../services/fcm_service.dart';

class RideViewScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;
  final Map<String, dynamic> passengerSource;
  final Map<String, dynamic> passengerDestination;

  const RideViewScreen({
    super.key,
    required this.rideId,
    required this.rideData,
    required this.passengerSource,
    required this.passengerDestination,
  });

  @override
  State<RideViewScreen> createState() => _RideViewScreenState();
}

class _RideViewScreenState extends State<RideViewScreen> {
  bool _isRequesting = false;
  String? _existingStatus;
  Map<String, dynamic>? _driverData;
  bool _isLoadingDriver = true;

  // Route state
  List<LatLng> _routePoints = [];
  final MapController _mapController = MapController();

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
    _fetchDriverData();
    _fetchRoute();
  }

  // --- FETCH ACTUAL DRIVING ROUTE VIA OSRM ---
  Future<void> _fetchRoute() async {
    final start = widget.passengerSource;
    final end = widget.passengerDestination;

    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start['lng']},${start['lat']};${end['lng']},${end['lat']}?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];

        if (mounted) {
          setState(() {
            _routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
          });
          _fitMap();
        }
      }
    } catch (e) {
      debugPrint("Route Fetch Error: $e");
    }
  }

  void _fitMap() {
    if (_routePoints.isEmpty) return;
    var bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  Future<void> _fetchDriverData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.rideData['driver_uid'])
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _driverData = doc.data();
          _isLoadingDriver = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDriver = false);
    }
  }

  Future<void> _checkExistingRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final query = await FirebaseFirestore.instance
        .collection('bookings')
        .where('ride_id', isEqualTo: widget.rideId)
        .where('passenger_uid', isEqualTo: user.uid)
        .get();

    if (query.docs.isNotEmpty && mounted) {
      setState(() => _existingStatus = query.docs.first['status']);
    }
  }

  // --- SEND REQUEST LOGIC WITH FCM PUSH NOTIFICATIONS ---
  Future<void> _sendRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isRequesting = true);
    try {
      // 1. Fetch Passenger name and Driver FCM token
      DocumentSnapshot passengerDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      DocumentSnapshot driverDoc = await FirebaseFirestore.instance.collection('users').doc(widget.rideData['driver_uid']).get();

      String passengerName = passengerDoc.exists ? (passengerDoc.get('name') ?? "A passenger") : "A passenger";
      String? driverToken = driverDoc.exists ? driverDoc.get('fcm_token') : null;
      String destinationName = widget.passengerDestination['name'] ?? "Destination";

      // 2. Transaction: Create Booking Entry and In-App Notification
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // A. Create the Booking entry in 'bookings' collection
        DocumentReference bookingRef = FirebaseFirestore.instance.collection('bookings').doc();
        transaction.set(bookingRef, {
          'ride_id': widget.rideId,
          'passenger_uid': user.uid,
          'passenger_name': passengerName,
          'driver_uid': widget.rideData['driver_uid'],
          'driver_name': driverDoc.exists ? (driverDoc.get('name') ?? "Driver") : "Driver",
          'status': 'pending',
          'created_at': FieldValue.serverTimestamp(),
          'price': widget.rideData['price_per_seat'],
          'source': widget.passengerSource,
          'destination': widget.passengerDestination,
          'ride_date': widget.rideData['departure_time'],
        });

        // B. Create In-App Notification record for the Driver's inbox
        DocumentReference notifRef = FirebaseFirestore.instance.collection('notifications').doc();
        transaction.set(notifRef, {
          'uid': widget.rideData['driver_uid'],
          'title': 'New Ride Request! 📩',
          'message': '$passengerName requested a seat to $destinationName.',
          'type': 'new_request',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      });

      // 3. Trigger External Push Notification to Driver's device
      if (driverToken != null && driverToken.isNotEmpty) {
        await FCMService.sendPushNotification(
          token: driverToken,
          title: "New Ride Request! 📩",
          body: "$passengerName wants to join your ride to $destinationName.",
        );
      }

      if (mounted) {
        setState(() => _existingStatus = 'pending');
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            title: const Text("Request Sent"),
            content: const Text("The driver has been notified and will review your request shortly."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close Dialog
                  Navigator.pop(context); // Go back to results
                },
                child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime depTime = (widget.rideData['departure_time'] as Timestamp).toDate();
    final LatLng start = LatLng(widget.passengerSource['lat'], widget.passengerSource['lng']);
    final LatLng end = LatLng(widget.passengerDestination['lat'], widget.passengerDestination['lng']);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Ride Details", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // --- 1. MAP VIEW ---
                SizedBox(
                  height: 250,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: start,
                      initialZoom: 12,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.linkride',
                      ),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(points: _routePoints, color: Colors.blue, strokeWidth: 5),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: start,
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: Icon(Icons.circle, color: primaryGreen, size: 14),
                            ),
                          ),
                          Marker(
                            point: end,
                            width: 40, height: 40,
                            child: const Icon(Icons.location_on, color: Colors.red, size: 35),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- 2. RIDE DATE/TIME ---
                      Text(
                        DateFormat('EEEE, d MMMM • h:mm a').format(depTime),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      _buildRouteRow(Icons.circle_outlined, widget.passengerSource['name'], Colors.grey),
                      const Padding(
                        padding: EdgeInsets.only(left: 11),
                        child: SizedBox(height: 20, child: VerticalDivider()),
                      ),
                      _buildRouteRow(Icons.location_on, widget.passengerDestination['name'], primaryGreen),

                      const Padding(padding: EdgeInsets.symmetric(vertical: 25), child: Divider()),

                      // --- 3. DRIVER INFO ---
                      const Text("Your Driver", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 15),
                      _isLoadingDriver
                          ? const Center(child: CircularProgressIndicator())
                          : Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: _driverData?['profile_pic'] != null
                                      ? NetworkImage(_driverData!['profile_pic'])
                                      : null,
                                  child: _driverData?['profile_pic'] == null ? const Icon(Icons.person) : null,
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_driverData?['name'] ?? "Driver",
                                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                      Row(
                                        children: [
                                          Icon(Icons.star, size: 16, color: Colors.amber[700]),
                                          const SizedBox(width: 4),
                                          Text("${_driverData?['rating'] ?? 'New'}",
                                              style: const TextStyle(fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 10),
                                          const Icon(Icons.verified, size: 14, color: Colors.blue),
                                          const Text(" Verified", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                      const Padding(padding: EdgeInsets.symmetric(vertical: 25), child: Divider()),

                      // --- 4. PRICE ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Total Price (1 seat)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                          Text("₹${widget.rideData['price_per_seat']}",
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryGreen)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- 5. ACTION BUTTON ---
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: _existingStatus != null
                  ? ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[200]),
                      child: Text("REQUEST ${_existingStatus!.toUpperCase()}",
                          style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    )
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: _isRequesting ? null : _sendRequest,
                      child: _isRequesting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("REQUEST SEAT",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRouteRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 15),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
      ],
    );
  }
}