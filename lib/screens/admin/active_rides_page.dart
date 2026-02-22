import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminActiveRidesPage extends StatefulWidget {
  const AdminActiveRidesPage({super.key});

  @override
  State<AdminActiveRidesPage> createState() => _AdminActiveRidesPageState();
}

class _AdminActiveRidesPageState extends State<AdminActiveRidesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- DELETE LOGIC ---
  Future<void> _deleteRidePermanently(String rideId) async {
    bool confirm = await _showConfirmDialog(
      "Delete Ride?", 
      "This will permanently delete the ride and all associated bookings. This action cannot be undone."
    );

    if (confirm) {
      try {
        // 1. Delete associated bookings first
        var bookings = await FirebaseFirestore.instance
            .collection('bookings')
            .where('ride_id', isEqualTo: rideId)
            .get();
        
        WriteBatch batch = FirebaseFirestore.instance.batch();
        for (var doc in bookings.docs) {
          batch.delete(doc.reference);
        }
        
        // 2. Delete the ride itself
        batch.delete(FirebaseFirestore.instance.collection('rides').doc(rideId));
        
        await batch.commit();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride and associated data deleted.")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error deleting data.")));
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Ride Monitor", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: darkGreen,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryGreen,
          tabs: const [
            Tab(text: "Active / Scheduled"),
            Tab(text: "History (Completed/Cancelled)"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRideList(['active', 'scheduled', 'ongoing']), // Active Tab
          _buildRideList(['completed', 'cancelled']),         // History Tab
        ],
      ),
    );
  }

  Widget _buildRideList(List<String> statuses) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rides')
          .where('status', whereIn: statuses)
          .orderBy('departure_time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("No rides found", style: TextStyle(color: Colors.grey.shade400)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var rideDoc = snapshot.data!.docs[index];
            var rideData = rideDoc.data() as Map<String, dynamic>;
            return _buildRideCard(rideDoc.id, rideData);
          },
        );
      },
    );
  }

  Widget _buildRideCard(String rideId, Map<String, dynamic> data) {
    DateTime departure = (data['departure_time'] as Timestamp).toDate();
    String status = data['status'] ?? 'scheduled';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Status & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statusBadge(status),
              Text(DateFormat('EEE, d MMM • hh:mm a').format(departure),
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          
          // Route info
          _locationRow(Icons.radio_button_checked, Colors.green, data['source']['name']),
          Padding(padding: const EdgeInsets.only(left: 9), child: Container(width: 1, height: 15, color: Colors.grey.shade300)),
          _locationRow(Icons.location_on, Colors.red, data['destination']['name']),

          const Divider(height: 30),

          // Driver & Price Row
          Row(
            children: [
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(data['driver_uid']).get(),
                builder: (context, snap) {
                  String name = snap.hasData ? (snap.data!['name'] ?? "Driver") : "Loading...";
                  return Text("Driver: $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13));
                },
              ),
              const Spacer(),
              Text("₹${data['price_per_seat']}/seat", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
            ],
          ),

          const SizedBox(height: 15),

          // --- BOOKINGS SUB-SECTION ---
          const Text("Passengers & Bookings:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          _buildBookingStatusList(rideId),

          const SizedBox(height: 20),
          
          // Admin Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _deleteRidePermanently(rideId),
                icon: const Icon(Icons.delete_forever, size: 18, color: Colors.red),
                label: const Text("DELETE RIDE", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- LIST OF PASSENGERS FOR THIS SPECIFIC RIDE ---
  Widget _buildBookingStatusList(String rideId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('ride_id', isEqualTo: rideId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text("No bookings yet", style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey));
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            var bData = doc.data() as Map<String, dynamic>;
            String bStatus = bData['status'] ?? 'pending';
            Color statusColor = bStatus == 'accepted' ? Colors.green : (bStatus == 'pending' ? Colors.orange : Colors.red);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bData['passenger_name'] ?? "User", 
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)
                    )
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                    child: Text(bStatus.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.grey),
                    onPressed: () async {
                      bool confirm = await _showConfirmDialog("Delete Booking?", "Remove this passenger from the ride?");
                      if(confirm) await FirebaseFirestore.instance.collection('bookings').doc(doc.id).delete();
                    },
                  )
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'ongoing': color = Colors.blue; break;
      case 'completed': color = Colors.green; break;
      case 'cancelled': color = Colors.red; break;
      default: color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  Widget _locationRow(IconData icon, Color color, String name) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(name, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}