import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'driver_live_tracking.dart';
import 'ride_moving_screen.dart';
import 'no_passenger_nav_screen.dart';

class RideSummaryPage extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const RideSummaryPage({super.key, required this.rideId, required this.rideData});

  @override
  State<RideSummaryPage> createState() => _RideSummaryPageState();
}

class _RideSummaryPageState extends State<RideSummaryPage> {
  String _totalDistance = "-- km";
  String _totalDuration = "-- min";
  bool _isLoadingRoute = true;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _fetchRouteStats();
  }

  Future<void> _fetchRouteStats() async {
    final source = widget.rideData['source'];
    final dest = widget.rideData['destination'];
    final url = Uri.parse('http://router.project-osrm.org/route/v1/driving/${source['lng']},${source['lat']};${dest['lng']},${dest['lat']}?overview=false');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0];
        if (mounted) {
          setState(() {
            _totalDistance = "${(route['distance'] / 1000).toStringAsFixed(1)} km";
            _totalDuration = "${(route['duration'] / 60).toStringAsFixed(0)} min";
            _isLoadingRoute = false;
          });
        }
      }
    } catch (e) { if (mounted) setState(() => _isLoadingRoute = false); }
  }

  // --- UPDATED: SET BOOLEAN FLAG ON BUTTON PRESS ---
  Future<void> _startRideNavigation() async {
    setState(() => _isStarting = true);

    try {
      // Set simple boolean flag to true
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
            'live_navigation_pressed': true, 
          });

      if (!mounted) return;

      List passengers = widget.rideData['passengers'] ?? [];
      
      // Determine correct live screen
      if (passengers.isEmpty) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => NoPassengerNavScreen(rideId: widget.rideId, rideData: widget.rideData)));
        return;
      }

      Map<String, dynamic> routes = widget.rideData['passenger_routes'] ?? {};
      bool anyPendingPickup = false;
      for (var pId in passengers) {
        if (routes[pId] == null || routes[pId]['ride_status'] != 'security_completed') {
          anyPendingPickup = true;
          break;
        }
      }

      if (anyPendingPickup) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DriverLiveTracking(rideData: widget.rideData, rideId: widget.rideId)));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => RideMovingScreen(rideId: widget.rideId, rideData: widget.rideData)));
      }

    } catch (e) {
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateTime depTime = (widget.rideData['departure_time'] as Timestamp).toDate();
    final Map<String, dynamic> passengerRoutes = widget.rideData['passenger_routes'] ?? {};
    final String driverSource = widget.rideData['source']['name'] ?? "Unknown Start";
    final String driverDest = widget.rideData['destination']['name'] ?? "Unknown End";
    final Color primaryGreen = const Color(0xFF11A860);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text("Trip Summary"), elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel("YOUR OVERALL ROUTE"),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _routeRow(Icons.radio_button_checked, driverSource, Colors.blue),
                  _routeDivider(),
                  _routeRow(Icons.location_on, driverDest, Colors.red),
                  const Divider(height: 40),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statItem("Time", DateFormat('h:mm a').format(depTime), Icons.access_time),
                      _statItem("Distance", _totalDistance, Icons.straighten),
                      _statItem("Duration", _totalDuration, Icons.timer),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _sectionLabel("PASSENGER LIST (${passengerRoutes.length})"),
            if (passengerRoutes.isEmpty)
              _buildEmptyState()
            else
              ...passengerRoutes.entries.map((entry) => _buildPassengerCard(entry.value, primaryGreen)).toList(),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomSheet: _buildBottomAction(primaryGreen),
    );
  }

  Widget _sectionLabel(String text) => Padding(padding: const EdgeInsets.only(left: 5, bottom: 10), child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)));
  Widget _routeRow(IconData icon, String addr, Color col) => Row(children: [Icon(icon, color: col, size: 20), const SizedBox(width: 15), Expanded(child: Text(addr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))]);
  Widget _routeDivider() => Padding(padding: const EdgeInsets.only(left: 9), child: Container(width: 2, height: 20, color: Colors.grey.shade200));
  Widget _statItem(String l, String v, IconData i) => Column(children: [Icon(i, color: const Color(0xFF11A860), size: 18), Text(v, style: const TextStyle(fontWeight: FontWeight.bold)), Text(l, style: const TextStyle(color: Colors.grey, fontSize: 10))]);
  
  Widget _buildPassengerCard(Map<String, dynamic> p, Color col) {
    bool isOn = (p['ride_status'] == 'security_completed' || p['ride_status'] == 'completed');
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(children: [
        Row(children: [const Icon(Icons.person, size: 20), const SizedBox(width: 10), Text(p['passenger_name'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), _badge(isOn)]),
        const Divider(),
        _pPoint("Pickup", p['pickup']['name'], Colors.blue),
        const SizedBox(height: 5),
        _pPoint("Drop", p['dropoff']['name'], Colors.red),
      ]),
    );
  }

  Widget _badge(bool isOn) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isOn ? Colors.green.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(20)), child: Text(isOn ? "ONBOARD" : "PENDING", style: TextStyle(color: isOn ? Colors.green : Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)));
  Widget _pPoint(String l, String a, Color c) => Row(children: [Icon(Icons.circle, size: 8, color: c), const SizedBox(width: 10), Expanded(child: Text("$l: $a", style: const TextStyle(fontSize: 12)))]);
  Widget _buildEmptyState() => Container(width: double.infinity, padding: const EdgeInsets.all(20), child: const Center(child: Text("No passengers yet")));
  
  Widget _buildBottomAction(Color col) => Container(
    padding: const EdgeInsets.all(20), color: Colors.white,
    child: SizedBox(width: double.infinity, height: 55, child: ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: col, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
      onPressed: _isStarting ? null : _startRideNavigation,
      child: _isStarting ? const CircularProgressIndicator(color: Colors.white) : const Text("GO TO LIVE NAVIGATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    )),
  );
}