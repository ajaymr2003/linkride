import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'booked_trips_page.dart';
import 'offered_rides_page.dart';

class RidesPage extends StatefulWidget {
  const RidesPage({super.key});

  @override
  State<RidesPage> createState() => _RidesPageState();
}

class _RidesPageState extends State<RidesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        title: const Text("Activity", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        bottom: TabBar(controller: _tabController, labelColor: primaryGreen, unselectedLabelColor: Colors.grey, indicatorColor: primaryGreen, indicatorWeight: 3, tabs: const [Tab(text: "Booked Trips"), Tab(text: "Offered Rides")]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const BookedTripsPage(),
          _buildDriverRideList(),
        ],
      ),
    );
  }

  Widget _buildDriverRideList() {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('bookings').where('driver_uid', isEqualTo: user?.uid).where('status', isEqualTo: 'pending').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();
            return Container(
              width: double.infinity, padding: const EdgeInsets.all(15), color: Colors.orange.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Booking Requests (${snapshot.data!.docs.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 10),
                  SizedBox(height: 100, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: snapshot.data!.docs.length, itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    return _buildRequestSmallCard(context, doc.id, doc.data() as Map<String, dynamic>);
                  })),
                ],
              ),
            );
          },
        ),
        const Expanded(child: OfferedRidesPage()),
      ],
    );
  }

  Widget _buildRequestSmallCard(BuildContext context, String bookingId, Map<String, dynamic> data) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(data['passenger_uid']).get(),
      builder: (context, snapshot) {
        String name = "Loading..."; String? pic;
        if (snapshot.hasData && snapshot.data!.exists) {
          var user = snapshot.data!.data() as Map<String, dynamic>;
          name = user['name'] ?? "User"; pic = user['profile_pic'];
        }
        return GestureDetector(
          onTap: () => _showRequestDetailSheet(context, bookingId, data, name, pic),
          child: Container(
            width: 150, margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(radius: 15, backgroundImage: pic != null ? NetworkImage(pic) : null),
              const SizedBox(height: 5),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
              Text("To ${data['destination']['name']}", style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
            ]),
          ),
        );
      },
    );
  }

  void _showRequestDetailSheet(BuildContext context, String bId, Map<String, dynamic> data, String name, String? pic) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) => Padding(padding: const EdgeInsets.all(25), child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: CircleAvatar(radius: 30, backgroundImage: pic != null ? NetworkImage(pic) : null), title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), subtitle: const Text("Verified Passenger")),
      const SizedBox(height: 25),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: () => _updateStatus(context, bId, data['ride_id'], data['passenger_uid'], 'rejected'), child: const Text("Reject", style: TextStyle(color: Colors.red)))),
        const SizedBox(width: 15),
        Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primaryGreen), onPressed: () => _updateStatus(context, bId, data['ride_id'], data['passenger_uid'], 'accepted'), child: const Text("Accept Request", style: TextStyle(color: Colors.white)))),
      ]),
      const SizedBox(height: 20),
    ])));
  }

  // --- UPDATED HELPER: Accepts Ride and updates Array ---
  Future<void> _updateStatus(BuildContext context, String bId, String rId, String pId, String status) async {
    Navigator.pop(context);
    try {
      if (status == 'accepted') {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference rideRef = FirebaseFirestore.instance.collection('rides').doc(rId);
          DocumentSnapshot rideSnap = await transaction.get(rideRef);
          int available = rideSnap['available_seats'] ?? 0;
          if (available < 1) throw "No seats available";
          
          transaction.update(rideRef, {
            'available_seats': available - 1,
            'passengers': FieldValue.arrayUnion([pId]),
          });
          transaction.update(FirebaseFirestore.instance.collection('bookings').doc(bId), {'status': 'accepted'});
        });
      } else {
        await FirebaseFirestore.instance.collection('bookings').doc(bId).update({'status': 'rejected'});
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}