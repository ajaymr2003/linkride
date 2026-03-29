import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'passenger_request_detail_screen.dart';
import '../../../services/fcm_service.dart';
import '../../../services/booking_service.dart'; // <--- IMPORT ADDED

class RideRequestsPage extends StatefulWidget {
  const RideRequestsPage({super.key});

  @override
  State<RideRequestsPage> createState() => _RideRequestsPageState();
}

class _RideRequestsPageState extends State<RideRequestsPage> {
  final String currentDriverId = FirebaseAuth.instance.currentUser?.uid ?? "";
  final Color primaryGreen = const Color(0xFF11A860);
  String _selectedFilter = 'pending'; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Passenger Requests", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- 1. FILTER BUTTONS ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                children: [
                  _filterChip("pending", "Pending"),
                  _filterChip("accepted", "Accepted"),
                  _filterChip("rejected", "Rejected"),
                  _filterChip("cancelled", "Cancelled"),
                ],
              ),
            ),
          ),

          // --- 2. REQUESTS LIST ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('driver_uid', isEqualTo: currentDriverId)
                  .where('status', isEqualTo: _selectedFilter)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                var docs = snapshot.data!.docs;
                // Sort by time
                docs.sort((a, b) => (b['created_at'] as Timestamp).compareTo(a['created_at'] as Timestamp));

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var booking = docs[index];
                    var bData = booking.data() as Map<String, dynamic>;
                    return _buildRequestCard(booking.id, bData);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    bool isSelected = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: primaryGreen,
        onSelected: (bool selected) {
          if (selected) setState(() => _selectedFilter = value);
        },
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRequestCard(String bId, Map<String, dynamic> bData) {
    bool isPending = bData['status'] == 'pending';
    DateTime createdAt = (bData['created_at'] as Timestamp).toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Material( // Added Material for InkWell ripple effect
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // --- FULL CARD NAVIGATION ---
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PassengerRequestDetailScreen(
                  bookingId: bId,
                  bookingData: bData,
                ),
              ),
            );
          },
          child: Column(
            children: [
              // HEADER: DRIVER'S RIDE CONTEXT
              _buildRideContext(bData['ride_id']),

              // PASSENGER INFO SECTION
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(bData['passenger_uid']).get(),
                builder: (context, userSnap) {
                  var user = userSnap.data?.data() as Map<String, dynamic>?;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundImage: user?['profile_pic'] != null ? NetworkImage(user!['profile_pic']) : null,
                      child: user?['profile_pic'] == null ? const Icon(Icons.person) : null,
                    ),
                    title: Text(user?['name'] ?? "Loading...", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Text(DateFormat('MMM d, h:mm a').format(createdAt), style: const TextStyle(fontSize: 11)),
                    trailing: _statusBadge(bData['status']),
                  );
                },
              ),

              const Divider(height: 1, indent: 15, endIndent: 15),

              // ROUTE SECTION: WHERE IS THE PASSENGER GOING?
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    _routeRow(Icons.circle_outlined, "Pickup: ${bData['source']['name']}", Colors.grey),
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: SizedBox(height: 10, child: VerticalDivider(width: 1)),
                    ),
                    _routeRow(Icons.location_on, "Drop: ${bData['destination']['name']}", primaryGreen),
                  ],
                ),
              ),

              // ACTION FOOTER
              if (isPending)
                Padding(
                  padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _handleAction(bId, bData, 'rejected'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                          child: const Text("DECLINE"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                          onPressed: () => _handleAction(bId, bData, 'accepted'),
                          child: const Text("ACCEPT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Tap to view full details", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(width: 5),
                      Icon(Icons.arrow_forward_ios, size: 10, color: Colors.grey.shade400),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER: Shows WHICH ride this request belongs to ---
  Widget _buildRideContext(String rideId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('rides').doc(rideId).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        var ride = snap.data!.data() as Map<String, dynamic>;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Text(
            "FOR YOUR RIDE: ${ride['source']['name']} ➔ ${ride['destination']['name']}",
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }

  Widget _routeRow(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    switch (status) {
      case 'accepted': color = Colors.green; break;
      case 'rejected': color = Colors.red; break;
      case 'cancelled': color = Colors.grey; break;
      default: color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 9)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text("No $_selectedFilter requests found", style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // --- UPDATED LOGIC: USES SHARED SERVICE ---
  Future<void> _handleAction(String bId, Map<String, dynamic> bData, String status) async {
    try {
      if (status == 'accepted') {
        // Standardized accept logic via Service
        await BookingService.acceptRequest(
          bookingId: bId,
          bookingData: bData,
          currentDriverId: currentDriverId,
        );
      } else {
        // Standardized reject logic via Service
        await BookingService.rejectRequest(bId);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Request updated to $status"))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }
}