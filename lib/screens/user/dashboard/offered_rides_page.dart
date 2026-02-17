import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../driver/ride_steps/edit_ride_page.dart';

class OfferedRidesPage extends StatefulWidget {
  const OfferedRidesPage({super.key});

  @override
  State<OfferedRidesPage> createState() => _OfferedRidesPageState();
}

class _OfferedRidesPageState extends State<OfferedRidesPage> {
  bool _showUpcoming = true;
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final now = Timestamp.now();

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

        // --- 2. RIDES LIST ---
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _showUpcoming 
              ? FirebaseFirestore.instance
                  .collection('rides')
                  .where('driver_uid', isEqualTo: user?.uid)
                  .where('departure_time', isGreaterThanOrEqualTo: now)
                  .orderBy('departure_time', descending: false)
                  .snapshots()
              : FirebaseFirestore.instance
                  .collection('rides')
                  .where('driver_uid', isEqualTo: user?.uid)
                  .where('departure_time', isLessThan: now)
                  .orderBy('departure_time', descending: true)
                  .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(_showUpcoming);
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  DateTime dt = (data['departure_time'] as Timestamp).toDate();
                  List passengers = data['passengers'] ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('EEE, d MMM • h:mm a').format(dt), 
                                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                            if (_showUpcoming)
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditRidePage(docId: doc.id, initialData: data))),
                              )
                            else
                              const Icon(Icons.check_circle, color: Colors.grey, size: 20),
                          ],
                        ),
                        _locationRow(Icons.circle_outlined, data['source']['name'] ?? "Source", Colors.grey),
                        _locationRow(Icons.location_on, data['destination']['name'] ?? "Dest", primaryGreen),
                        
                        const Divider(height: 25),

                        // --- NEW: PASSENGER NAMES SECTION ---
                        if (passengers.isNotEmpty) ...[
                          const Text("Confirmed Passengers:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          _buildPassengerNames(passengers),
                          const SizedBox(height: 12),
                        ],

                        Row(
                          children: [
                            const Icon(Icons.airline_seat_recline_normal, size: 16, color: Colors.grey),
                            const SizedBox(width: 5),
                            Text(_showUpcoming ? "${data['available_seats']} seats left" : "Ride Finished", 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                            const Spacer(),
                            Text("₹${data['price_per_seat']}", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
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

  // --- HELPER: FETCH AND BUILD PASSENGER NAMES ---
  Widget _buildPassengerNames(List uids) {
    return FutureBuilder<QuerySnapshot>(
      // Query users collection where document ID is in the passengers list
      future: FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: uids)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text("Loading...", style: TextStyle(fontSize: 12));
        
        // Extract names from documents
        List names = snapshot.data!.docs.map((d) => d['name'].toString().split(' ')[0]).toList();

        return Wrap(
          spacing: 8,
          children: names.map((name) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 12, color: Color(0xFF11A860)),
                const SizedBox(width: 4),
                Text(name, style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          )).toList(),
        );
      },
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
            boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)] : [],
          ),
          child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? primaryGreen : Colors.grey))),
        ),
      ),
    );
  }

  Widget _locationRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isUpcoming) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isUpcoming ? Icons.drive_eta : Icons.history, size: 70, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          Text(isUpcoming ? "No upcoming rides" : "No ride history", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          Text(isUpcoming ? "Rides you publish will appear here." : "Your completed rides will show up here.", style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}