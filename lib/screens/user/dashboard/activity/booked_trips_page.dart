import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'ride_details_view.dart'; // Import the details page

class BookedTripsPage extends StatefulWidget {
  const BookedTripsPage({super.key});

  @override
  State<BookedTripsPage> createState() => _BookedTripsPageState();
}

class _BookedTripsPageState extends State<BookedTripsPage> {
  bool _showUpcoming = true;
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Logic: 
    // Upcoming = pending or accepted
    // Completed = completed or cancelled
    Query bookingQuery = FirebaseFirestore.instance
        .collection('bookings')
        .where('passenger_uid', isEqualTo: user?.uid);

    if (_showUpcoming) {
      bookingQuery = bookingQuery.where('status', whereIn: ['pending', 'accepted']);
    } else {
      bookingQuery = bookingQuery.where('status', whereIn: ['completed', 'cancelled']);
    }

    return Column(
      children: [
        // --- 1. FILTER TOGGLE BAR ---
        Container(
          margin: const EdgeInsets.all(15),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildFilterButton("Upcoming", _showUpcoming, () => setState(() => _showUpcoming = true)),
              _buildFilterButton("Completed", !_showUpcoming, () => setState(() => _showUpcoming = false)),
            ],
          ),
        ),

        // --- 2. TRIPS LIST ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: bookingQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(_showUpcoming);
              }

              // Sort: Upcoming (nearest first), Completed (most recent first)
              var docs = snapshot.data!.docs;
              docs.sort((a, b) {
                var d1 = (a.data() as Map<String, dynamic>)['ride_date'] as Timestamp;
                var d2 = (b.data() as Map<String, dynamic>)['ride_date'] as Timestamp;
                return _showUpcoming ? d1.compareTo(d2) : d2.compareTo(d1);
              });

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  DateTime dt = (data['ride_date'] as Timestamp).toDate();
                  String status = data['status'] ?? "pending";

                  return InkWell(
                    onTap: () {
                      // Navigate to details if the trip is completed
                      if (status == 'completed') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RideDetailsView(data: data, isDriverView: false),
                          ),
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(DateFormat('EEE, d MMM • h:mm a').format(dt), 
                                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                              _statusBadge(status),
                            ],
                          ),
                          const SizedBox(height: 15),
                          _locationRow(Icons.circle_outlined, data['source']['name'], Colors.grey),
                          const Padding(
                            padding: EdgeInsets.only(left: 7),
                            child: SizedBox(height: 10, child: VerticalDivider(width: 1)),
                          ),
                          _locationRow(Icons.location_on, data['destination']['name'], primaryGreen),
                          const Divider(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                                  const SizedBox(width: 5),
                                  Text(data['driver_name'] ?? "Driver", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              Text("₹${data['price']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          if(status == 'completed')
                            const Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Center(child: Text("Tap to view details", style: TextStyle(color: Colors.blue, fontSize: 11))),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? primaryGreen : Colors.grey))),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = status == 'accepted' ? Colors.green : (status == 'completed' ? Colors.blue : Colors.red);
    if (status == 'pending') color = Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _locationRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1)),
      ],
    );
  }

  Widget _buildEmptyState(bool isUpcoming) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isUpcoming ? Icons.calendar_today : Icons.history, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text(isUpcoming ? "No upcoming trips" : "No completed trips", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(isUpcoming ? "Rides you book will appear here." : "Your past ride history is empty.", style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}