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
  String? _existingBookingId; // STORE BOOKING ID
  Map<String, dynamic>? _driverData;
  bool _isLoadingDriver = true;

  double _passengerDistanceKm = 0.0;
  double _minPrice = 0.0;
  double _maxPrice = 0.0;
  bool _isCalculatingPrice = true;

  List<LatLng> _routePoints = [];
  final MapController _mapController = MapController();

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
    _fetchDriverData();
    _initializeCalculations();
  }

  Future<void> _initializeCalculations() async {
    setState(() => _isCalculatingPrice = true);
    await _fetchRouteAndDistance(); 
    await _calculatePriceRange(); 
    if (mounted) setState(() => _isCalculatingPrice = false);
  }

  // --- EXISTING LOGIC: FETCH ROUTE ---
  Future<void> _fetchRouteAndDistance() async {
    final start = widget.passengerSource;
    final end = widget.passengerDestination;
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${start['lng']},${start['lat']};${end['lng']},${end['lat']}?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        final double distanceMeters = data['routes'][0]['distance'];

        if (mounted) {
          setState(() {
            _routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
            _passengerDistanceKm = distanceMeters / 1000;
          });
          _fitMap();
        }
      }
    } catch (e) {
      debugPrint("Route Fetch Error: $e");
    }
  }

  // --- EXISTING LOGIC: CALC PRICE ---
  Future<void> _calculatePriceRange() async {
    final dStart = widget.rideData['source'];
    final dEnd = widget.rideData['destination'];
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${dStart['lng']},${dStart['lat']};${dEnd['lng']},${dEnd['lat']}?overview=false');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        double driverTotalDistKm = data['routes'][0]['distance'] / 1000;
        double fullPrice = (widget.rideData['price_per_seat'] ?? 0).toDouble();
        double ratio = _passengerDistanceKm / driverTotalDistKm;
        if (ratio > 1.0) ratio = 1.0; 
        double basePrice = fullPrice * ratio;

        if (mounted) {
          setState(() {
            _minPrice = (basePrice * 0.85).floorToDouble();
            _maxPrice = (basePrice * 1.15).ceilToDouble();
            if (_maxPrice > fullPrice) _maxPrice = fullPrice;
            if (_minPrice < 0) _minPrice = 0;
            if (_maxPrice < 5 && _passengerDistanceKm > 0.1) _maxPrice = 10;
          });
        }
      }
    } catch (e) {
      debugPrint("Price range calc error: $e");
    }
  }

  void _fitMap() {
    if (_routePoints.isEmpty) return;
    var bounds = LatLngBounds.fromPoints(_routePoints);
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }

  Future<void> _fetchDriverData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.rideData['driver_uid']).get();
      if (doc.exists && mounted) {
        setState(() { _driverData = doc.data(); _isLoadingDriver = false; });
      }
    } catch (e) { if (mounted) setState(() => _isLoadingDriver = false); }
  }

  Future<void> _checkExistingRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final query = await FirebaseFirestore.instance
        .collection('bookings')
        .where('ride_id', isEqualTo: widget.rideId)
        .where('passenger_uid', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'accepted']) // Only active ones
        .get();

    if (query.docs.isNotEmpty && mounted) {
      setState(() {
        _existingStatus = query.docs.first['status'];
        _existingBookingId = query.docs.first.id;
      });
    }
  }

  // --- NEW LOGIC: CANCEL REQUEST ---
  Future<void> _cancelRequest() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Request?"),
        content: const Text("Are you sure you want to withdraw your request for this ride?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isRequesting = true);

    try {
      final String uid = FirebaseAuth.instance.currentUser!.uid;

      if (_existingStatus == 'accepted') {
        // If accepted, we must give the seat back to the driver
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference rideRef = FirebaseFirestore.instance.collection('rides').doc(widget.rideId);
          DocumentSnapshot rideSnap = await transaction.get(rideRef);

          if (rideSnap.exists) {
            int currentSeats = rideSnap['available_seats'] ?? 0;
            transaction.update(rideRef, {
              'available_seats': currentSeats + 1,
              'passengers': FieldValue.arrayRemove([uid]),
              'passenger_routes.$uid': FieldValue.delete(),
            });
          }
          transaction.update(FirebaseFirestore.instance.collection('bookings').doc(_existingBookingId), {
            'status': 'cancelled',
            'cancelled_at': FieldValue.serverTimestamp(),
          });
        });
      } else {
        // If just pending, just change status to cancelled
        await FirebaseFirestore.instance.collection('bookings').doc(_existingBookingId).update({
          'status': 'cancelled',
          'cancelled_at': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        setState(() {
          _existingStatus = null;
          _existingBookingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request cancelled successfully")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error cancelling request")));
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  // --- EXISTING LOGIC: SEND REQUEST ---
  Future<void> _sendRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isRequesting = true);

    try {
      DocumentSnapshot passengerDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String passengerName = passengerDoc.exists ? (passengerDoc.get('name') ?? "A passenger") : "A passenger";
      String? driverToken = _driverData?['fcm_token'];
      
      DocumentReference bookingRef = FirebaseFirestore.instance.collection('bookings').doc();

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(bookingRef, {
          'ride_id': widget.rideId,
          'passenger_uid': user.uid,
          'passenger_name': passengerName,
          'driver_uid': widget.rideData['driver_uid'],
          'driver_name': _driverData?['name'] ?? "Driver",
          'status': 'pending',
          'created_at': FieldValue.serverTimestamp(),
          'price_range': "₹${_minPrice.toInt()} - ₹${_maxPrice.toInt()}",
          'suggested_price': _maxPrice,
          'distance_km': _passengerDistanceKm.toStringAsFixed(1),
          'source': widget.passengerSource,
          'destination': widget.passengerDestination,
          'ride_date': widget.rideData['departure_time'],
        });

        transaction.set(FirebaseFirestore.instance.collection('notifications').doc(), {
          'uid': widget.rideData['driver_uid'],
          'title': 'New Request! 📩',
          'message': '$passengerName requested a seat.',
          'type': 'new_request',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'booking_id': bookingRef.id,
        });
      });

      if (driverToken != null) {
        await FCMService.sendPushNotification(token: driverToken, title: "New Request! 📩", body: "$passengerName wants to join your ride.");
      }

      if (mounted) {
        setState(() {
          _existingStatus = 'pending';
          _existingBookingId = bookingRef.id;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Sent!")));
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    bool isOwnRide = widget.rideData['driver_uid'] == currentUid;
    final DateTime depTime = (widget.rideData['departure_time'] as Timestamp).toDate();
    final LatLng start = LatLng(widget.passengerSource['lat'], widget.passengerSource['lng']);
    final LatLng end = LatLng(widget.passengerDestination['lat'], widget.passengerDestination['lng']);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Request Ride"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: 250,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(initialCenter: start, initialZoom: 12),
                    children: [
                      TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.linkride'),
                      if (_routePoints.isNotEmpty)
                        PolylineLayer(polylines: [Polyline(points: _routePoints, color: Colors.blue, strokeWidth: 5)]),
                      MarkerLayer(markers: [
                        Marker(point: start, child: Icon(Icons.circle, color: primaryGreen, size: 14)),
                        Marker(point: end, child: const Icon(Icons.location_on, color: Colors.red, size: 35)),
                      ]),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(DateFormat('EEEE, d MMMM • h:mm a').format(depTime), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      _buildRouteRow(Icons.circle_outlined, widget.passengerSource['name'], Colors.grey),
                      const Padding(padding: EdgeInsets.only(left: 11), child: SizedBox(height: 15, child: VerticalDivider())),
                      _buildRouteRow(Icons.location_on, widget.passengerDestination['name'], primaryGreen),
                      const SizedBox(height: 10),
                      Text("Total distance: ${_passengerDistanceKm.toStringAsFixed(1)} km", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
                      _isLoadingDriver ? const LinearProgressIndicator() : Row(
                        children: [
                          CircleAvatar(radius: 25, backgroundImage: _driverData?['profile_pic'] != null ? NetworkImage(_driverData!['profile_pic']) : null),
                          const SizedBox(width: 15),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_driverData?['name'] ?? "Driver", style: const TextStyle(fontWeight: FontWeight.bold)),
                            Row(children: [const Icon(Icons.star, color: Colors.amber, size: 14), Text(" ${_driverData?['rating'] ?? 'New'}")])
                          ])
                        ],
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider()),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(15)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                          children: [
                            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text("Approximate Fare", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                Text("Finalized by driver", style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ]),
                            _isCalculatingPrice 
                              ? const CircularProgressIndicator()
                              : Text("₹${_minPrice.toInt()} - ₹${_maxPrice.toInt()}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryGreen))
                          ]
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity, height: 55,
              child: isOwnRide
                  ? const ElevatedButton(onPressed: null, child: Text("YOUR OWN RIDE"))
                  : _existingStatus != null
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                          onPressed: _isRequesting ? null : _cancelRequest, 
                          child: _isRequesting 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : Text("CANCEL ${_existingStatus!.toUpperCase()} REQUEST", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), 
                          onPressed: (_isRequesting || _isCalculatingPrice) ? null : _sendRequest, 
                          child: _isRequesting 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : const Text("REQUEST TO JOIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
                        ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRouteRow(IconData icon, String text, Color color) {
    return Row(children: [Icon(icon, color: color, size: 22), const SizedBox(width: 15), Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))]);
  }
}