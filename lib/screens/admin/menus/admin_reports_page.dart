import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  bool _isLoading = true;

  // Store report numbers
  int totalRides = 0;
  int completedRides = 0;
  int totalBookings = 0;
  int acceptedBookings = 0;
  int driverReviews = 0;
  int passengerReviews = 0;

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    setState(() => _isLoading = true);
    try {
      final db = FirebaseFirestore.instance;

      // Fetching all counts in parallel
      final results = await Future.wait([
        db.collection('rides').count().get(),
        db.collection('rides').where('status', isEqualTo: 'completed').count().get(),
        db.collection('bookings').count().get(),
        db.collection('bookings').where('status', isEqualTo: 'accepted').count().get(),
        db.collection('reviews').where('type', isEqualTo: 'driver_review').count().get(),
        db.collection('reviews').where('type', isEqualTo: 'passenger_review').count().get(),
      ]);

      if (mounted) {
        setState(() {
          totalRides = results[0].count ?? 0;
          completedRides = results[1].count ?? 0;
          totalBookings = results[2].count ?? 0;
          acceptedBookings = results[3].count ?? 0;
          driverReviews = results[4].count ?? 0;
          passengerReviews = results[5].count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching reports: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF11A860);
    const darkGreen = Color(0xFF2B5145);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("System Reports", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: darkGreen,
        elevation: 0,
        actions: [
          IconButton(onPressed: _fetchReportData, icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("Ride Analytics"),
                  _buildStatGrid([
                    _statCard("Total Rides", totalRides.toString(), Icons.directions_car, Colors.blue),
                    _statCard("Completed", completedRides.toString(), Icons.check_circle, primaryGreen),
                  ]),
                  
                  const SizedBox(height: 25),
                  _buildSectionHeader("Passenger Requests"),
                  _buildStatGrid([
                    _statCard("Total Requests", totalBookings.toString(), Icons.person_add_alt_1, Colors.orange),
                    _statCard("Accepted", acceptedBookings.toString(), Icons.handshake, Colors.purple),
                  ]),
                  
                  const SizedBox(height: 25),
                  _buildSectionHeader("Feedback & Reviews"),
                  _buildStatGrid([
                    _statCard("Driver Reviews", driverReviews.toString(), Icons.stars, Colors.amber.shade700),
                    _statCard("Passenger Reviews", passengerReviews.toString(), Icons.rate_review, Colors.teal),
                  ]),

                  const SizedBox(height: 40),
                  _buildSummaryBox(darkGreen),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildStatGrid(List<Widget> children) {
    return Row(
      children: children.map((card) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: card))).toList(),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 15),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSummaryBox(Color color) {
    double conversionRate = totalBookings > 0 ? (acceptedBookings / totalBookings) * 100 : 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights, color: Colors.white, size: 30),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Request Acceptance Rate", style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text("${conversionRate.toStringAsFixed(1)}%", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}