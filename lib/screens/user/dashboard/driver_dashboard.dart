import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../driver_setup/driver_setup_controller.dart';
import '../driver/ride_setup.dart';
import '../driver/ride_steps/edit_ride_page.dart';
import '../driver/ride_requests_page.dart';

class DriverDashboard extends StatelessWidget {
  final VoidCallback? onBack;

  const DriverDashboard({super.key, this.onBack});

  final Color primaryGreen = const Color(0xFF11A860);

  // --- DELETE RIDE LOGIC ---
  Future<void> _deleteRide(BuildContext context, String rideId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Ride?"),
        content: const Text("This will remove the ride and notify any booked passengers."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Keep")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('rides').doc(rideId).delete();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride deleted")));
      }
    }
  }

  // --- PUBLISH LOGIC ---
  Future<void> _handlePublish(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF11A860))),
    );

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!context.mounted) return;
      Navigator.pop(context);

      String status = userDoc.data()?['driver_status'] ?? 'not_applied';

      if (status == 'approved') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RideSetupScreen()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverSetupController()));
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Driver Dashboard", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: onBack ?? () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ACTIONS SECTION
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () => _handlePublish(context),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text("PUBLISH NEW RIDE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('bookings')
                      .where('driver_uid', isEqualTo: user?.uid)
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  builder: (context, snapshot) {
                    int pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                    return InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideRequestsPage())),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: pendingCount > 0 ? Colors.orange.shade50 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: pendingCount > 0 ? Colors.orange.shade200 : Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.people_outline, color: pendingCount > 0 ? Colors.orange : Colors.grey),
                            const SizedBox(width: 15),
                            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Passenger Requests", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text("Review and approve bookings", style: TextStyle(fontSize: 12, color: Colors.grey))])),
                            if (pendingCount > 0) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(20)), child: Text("$pendingCount NEW", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, 10), child: Align(alignment: Alignment.centerLeft, child: Text("Your Active Rides", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))))),

          // RIDES LIST (STREAM)
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rides')
                  .where('driver_uid', isEqualTo: user?.uid)
                  .orderBy('departure_time', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return _buildRideCard(context, doc.id, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(BuildContext context, String docId, Map<String, dynamic> data) {
    DateTime dt = (data['departure_time'] as Timestamp).toDate();
    String from = data['source'] is Map ? (data['source']['name'] ?? "Unknown") : data['source'].toString();
    String to = data['destination'] is Map ? (data['destination']['name'] ?? "Unknown") : data['destination'].toString();
    List passengers = data['passengers'] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.calendar_today, size: 14, color: Colors.blue), const SizedBox(width: 5), Text(DateFormat('EEE, d MMM • h:mm a').format(dt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue))])),
              Text("₹${data['price_per_seat']}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Column(children: [const Icon(Icons.circle, size: 10, color: Colors.grey), Container(height: 25, width: 2, color: Colors.grey.shade300), Icon(Icons.location_on, size: 12, color: primaryGreen)]),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(from, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis), const SizedBox(height: 15), Text(to, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)])),
            ],
          ),
          
          // --- PASSENGER NAMES SECTION ---
          if (passengers.isNotEmpty) ...[
            const Divider(height: 25),
            const Text("Confirmed Passengers:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildPassengerList(passengers),
          ],

          const Divider(height: 25),
          Row(
            children: [
              const Icon(Icons.airline_seat_recline_normal, color: Colors.grey, size: 20),
              const SizedBox(width: 5),
              Text("${data['available_seats']} seats left", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteRide(context, docId)),
              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditRidePage(docId: docId, initialData: data)))),
            ],
          )
        ],
      ),
    );
  }

  // --- HELPER: PASSENGER FETCHER ---
  Widget _buildPassengerList(List uids) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('users').where(FieldPath.documentId, whereIn: uids).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        List names = snapshot.data!.docs.map((d) => d['name'].toString().split(' ')[0]).toList();

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: names.map((name) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 10, color: Color(0xFF11A860)),
                const SizedBox(width: 4),
                Text(name, style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          )).toList(),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle), child: const Icon(Icons.drive_eta, size: 50, color: Colors.white)), const SizedBox(height: 20), const Text("No rides published yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)), const Text("Create your first ride above!", style: TextStyle(color: Colors.grey))]));
  }
}