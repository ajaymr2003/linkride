import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' hide Query; // Resolves naming conflict
import 'package:intl/intl.dart';

import '../../driver_setup/driver_setup_controller.dart';
import '../../driver/ride_setup.dart';
import 'edit_ride_page.dart';
import '../../driver/ride_requests_page.dart';
import '../activity/rides_page.dart';

class DriverDashboard extends StatefulWidget {
  final VoidCallback? onBack;

  const DriverDashboard({super.key, this.onBack});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final Color primaryGreen = const Color(0xFF11A860);
  String _selectedFilter = "All";

  // Helper for persistent Chat ID (matches BookingService)
  String _getChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join("_");
  }

  // --- DELETE RIDE LOGIC WITH ROUTE-SPECIFIC NOTIFICATIONS ---
  Future<void> _deleteRide(BuildContext context, String rideId, Map<String, dynamic> rideData) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Ride?"),
        content: const Text("This will remove the ride and notify all booked passengers. This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Keep")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete & Notify", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      // Capture messenger before async gap to avoid "unsafe ancestor" error
      final messenger = ScaffoldMessenger.of(context);
      final String currentDriverId = FirebaseAuth.instance.currentUser?.uid ?? "";
      
      List passengers = rideData['passengers'] ?? [];
      
      // Extract specific names for the message
      String sourceName = rideData['source'] is Map ? rideData['source']['name'] : rideData['source'].toString();
      String destName = rideData['destination'] is Map ? rideData['destination']['name'] : rideData['destination'].toString();
      
      // The specific text you requested
      String cancellationText = "⚠️ The ride from $sourceName to $destName has been cancelled by the driver.";

      try {
        WriteBatch batch = FirebaseFirestore.instance.batch();
        DatabaseReference rtDb = FirebaseDatabase.instance.ref();

        // 1. Notify joined passengers via Notifications and Chat
        for (var pUid in passengers) {
          String pIdString = pUid.toString();

          // A. Create Firestore In-App Notification
          DocumentReference notifRef = FirebaseFirestore.instance.collection('notifications').doc();
          batch.set(notifRef, {
            'uid': pIdString,
            'title': 'Ride Cancelled ⚠️',
            'message': cancellationText,
            'type': 'ride_cancelled',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });

          // B. Send message to Realtime Database Persistent Chat
          String chatId = _getChatId(currentDriverId, pIdString);
          await rtDb.child("messages/$chatId").push().set({
            'senderId': 'system',
            'text': cancellationText,
            'timestamp': ServerValue.timestamp,
          });

          // C. Update Chat Meta for Inbox view
          batch.update(FirebaseFirestore.instance.collection('chats').doc(chatId), {
            'last_message': 'Ride cancelled by driver',
            'last_message_time': FieldValue.serverTimestamp(),
            'status': 'cancelled',
          });
        }

        // 2. Delete the Ride Document
        batch.delete(FirebaseFirestore.instance.collection('rides').doc(rideId));

        // 3. Execute all Firestore changes
        await batch.commit();
        
        if (!mounted) return;
        messenger.showSnackBar(const SnackBar(content: Text("Ride deleted and passengers notified")));

      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
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
      if (!mounted) return;
      Navigator.pop(context);

      String status = userDoc.data()?['driver_status'] ?? 'not_applied';

      if (status == 'approved') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RideSetupScreen()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverSetupController()));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  // --- DYNAMIC QUERY BUILDER ---
  Stream<QuerySnapshot> _getFilteredStream() {
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final startOfToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59, 59));

    Query query = FirebaseFirestore.instance
        .collection('rides')
        .where('driver_uid', isEqualTo: user?.uid);

    if (_selectedFilter == "Today") {
      query = query.where('departure_time', isGreaterThanOrEqualTo: startOfToday)
                   .where('departure_time', isLessThanOrEqualTo: endOfToday)
                   .where('status', isEqualTo: 'active');
    } else if (_selectedFilter == "Upcoming") {
      query = query.where('departure_time', isGreaterThan: endOfToday)
                   .where('status', isEqualTo: 'active');
    } else if (_selectedFilter == "Completed") {
      query = query.where('status', isEqualTo: 'completed');
    } else {
      query = query.where('status', isEqualTo: 'active');
    }

    return query.orderBy('departure_time', descending: _selectedFilter == "Completed").snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Driver Dashboard", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 1. ACTIONS SECTION
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
                      .where('driver_uid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
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

          // 2. FILTER & SEE ALL SECTION
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Manage Rides", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RidesPage())),
                  child: Text("See All", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          // 3. HORIZONTAL FILTER CHIPS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ["All", "Today", "Upcoming", "Completed"].map((filter) {
                  bool isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() => _selectedFilter = filter);
                      },
                      selectedColor: primaryGreen,
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 4. RIDES LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getFilteredStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
    bool isCompleted = data['status'] == 'completed';
    
    // Logic check: disable editing if passengers have joined
    bool hasPassengersJoined = passengers.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(15), 
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))],
        border: isCompleted ? Border.all(color: Colors.green.shade100, width: 1) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)), 
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.blue), 
                  const SizedBox(width: 5), 
                  Text(DateFormat('EEE, d MMM • h:mm a').format(dt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue))
                ]),
              ),
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                  child: const Text("COMPLETED", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                )
              else
                Text("₹${data['price_per_seat']}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen)),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Column(children: [const Icon(Icons.circle, size: 10, color: Colors.grey), Container(height: 25, width: 2, color: Colors.grey.shade300), Icon(Icons.location_on, size: 12, color: isCompleted ? Colors.grey : primaryGreen)]),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(from, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis), const SizedBox(height: 15), Text(to, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)])),
            ],
          ),
          
          if (passengers.isNotEmpty) ...[
            const Divider(height: 25),
            const Text("Confirmed Passengers:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            _buildPassengerList(passengers),
          ],

          const Divider(height: 25),
          Row(
            children: [
              Icon(isCompleted ? Icons.check_circle_outline : Icons.airline_seat_recline_normal, color: Colors.grey, size: 20),
              const SizedBox(width: 5),
              Text(
                isCompleted ? "Ride Finished" : "${data['available_seats']} seats left", 
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)
              ),
              const Spacer(),
              if (!isCompleted) ...[
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red), 
                  onPressed: () => _deleteRide(context, docId, data)
                ),
                // Lock Editing if passengers joined
                if (!hasPassengersJoined)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blue), 
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditRidePage(docId: docId, initialData: data)))
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Tooltip(
                      message: "Cannot edit ride with confirmed passengers",
                      child: Icon(Icons.edit_off, color: Colors.grey, size: 20),
                    ),
                  ),
              ] else 
                const Text("Archived", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
            ],
          )
        ],
      ),
    );
  }

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
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(height: 40), Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle), child: const Icon(Icons.drive_eta, size: 50, color: Colors.white)), const SizedBox(height: 20), Text("No rides found for '$_selectedFilter'", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)), const Text("Try changing the filter or publish a new ride.", style: TextStyle(color: Colors.grey))]));
  }
}