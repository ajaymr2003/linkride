import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
                  // Update the import at the top
import 'edit_ride_page.dart';

// Inside _buildRideCard -> PopupMenuButton -> onSelected:

class RidesPage extends StatelessWidget {
  const RidesPage({super.key});

  final Color primaryGreen = const Color(0xFF11A860);

  // --- DELETE LOGIC ---
  Future<void> _deleteRide(BuildContext context, String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Ride?"),
        content: const Text("Are you sure you want to delete this ride? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No, Keep it")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('rides').doc(docId).delete();
    }
  }

  // --- EDIT LOGIC (Simple Dialog) ---
  void _showEditSheet(BuildContext context, String docId, Map<String, dynamic> data) {
    final TextEditingController seatController = TextEditingController(text: data['available_seats'].toString());
    final TextEditingController priceController = TextEditingController(text: data['price_per_seat'].toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(25, 20, 25, MediaQuery.of(ctx).viewInsets.bottom + 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Edit Ride Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: seatController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Available Seats", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Price per Seat (₹)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('rides').doc(docId).update({
                    'available_seats': int.parse(seatController.text),
                    'price_per_seat': double.parse(priceController.text),
                  });
                  if (context.mounted) Navigator.pop(ctx);
                },
                child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text("Your Rides", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            labelColor: primaryGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryGreen,
            tabs: const [Tab(text: "Upcoming"), Tab(text: "Past")],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRideList(isUpcoming: true),
            _buildRideList(isUpcoming: false),
          ],
        ),
      ),
    );
  }

  Widget _buildRideList({required bool isUpcoming}) {
    final user = FirebaseAuth.instance.currentUser;
    DateTime now = DateTime.now();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('rides')
          .where('driver_uid', isEqualTo: user!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        var filteredDocs = snapshot.data!.docs.where((doc) {
          DateTime rideTime = (doc['departure_time'] as Timestamp).toDate();
          return isUpcoming 
              ? rideTime.isAfter(now.subtract(const Duration(hours: 2))) 
              : rideTime.isBefore(now.subtract(const Duration(hours: 2)));
        }).toList();

        if (filteredDocs.isEmpty) return _buildEmptyState(isUpcoming);

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            return _buildRideCard(context, filteredDocs[index].id, filteredDocs[index].data() as Map<String, dynamic>, isUpcoming);
          },
        );
      },
    );
  }

  Widget _buildRideCard(BuildContext context, String docId, Map<String, dynamic> data, bool isUpcoming) {
    DateTime dt = (data['departure_time'] as Timestamp).toDate();
    String formattedDate = DateFormat('EEE, d MMM • h:mm a').format(dt);
    String price = data['price_per_seat'] == 0 ? "Free" : "₹${data['price_per_seat']}";

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
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
              Text(formattedDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              
              // --- ACTIONS MENU (Only for Upcoming Rides) ---
              if (isUpcoming)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),

                  onSelected: (val) {
                    if (val == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditRidePage(docId: docId, initialData: data),
                        ),
                      );
                    }
                    if (val == 'delete') _deleteRide(context, docId);
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text("Cancel Ride", style: TextStyle(color: Colors.red))])),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Text(price, style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _locationRow(Icons.circle_outlined, data['source'], Colors.grey),
          Padding(padding: const EdgeInsets.only(left: 6), child: Container(height: 15, width: 2, color: Colors.grey.shade300)),
          _locationRow(Icons.location_on, data['destination'], primaryGreen),
          const SizedBox(height: 15),
          const Divider(),
          Row(
            children: [
              Icon(Icons.directions_car, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 5),
              Text("${data['vehicle']['brand']} ${data['vehicle']['model']}", style: const TextStyle(fontSize: 12)),
              const Spacer(),
              const Icon(Icons.person, size: 14, color: Color.fromARGB(255, 34, 29, 29)),
              const SizedBox(width: 5),
              Text("${data['available_seats']} seats left", style: const TextStyle(fontSize: 12)),
              if (isUpcoming) ...[
                const SizedBox(width: 15),
                Text(price, style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
              ]
            ],
          )
        ],
      ),
    );
  }

  Widget _locationRow(IconData icon, String text, Color color) {
    return Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 15), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis))]);
  }

  Widget _buildEmptyState(bool isUpcoming) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isUpcoming ? Icons.directions_car_outlined : Icons.history, size: 80, color: Colors.grey.shade300), const SizedBox(height: 20), Text(isUpcoming ? "No upcoming rides" : "No past rides", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey))]));
  }
}