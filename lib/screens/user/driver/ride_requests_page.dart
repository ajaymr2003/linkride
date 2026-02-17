import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'passenger_request_detail_screen.dart';

class RideRequestsPage extends StatefulWidget {
  const RideRequestsPage({super.key});

  @override
  State<RideRequestsPage> createState() => _RideRequestsPageState();
}

class _RideRequestsPageState extends State<RideRequestsPage> {
  final String currentDriverId = FirebaseAuth.instance.currentUser?.uid ?? "";
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Passenger Requests", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('driver_uid', isEqualTo: currentDriverId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No requests found."));

          List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
          docs.sort((a, b) {
            Timestamp t1 = a['created_at'] ?? Timestamp.now();
            Timestamp t2 = b['created_at'] ?? Timestamp.now();
            return t2.compareTo(t1); 
          });

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var booking = docs[index];
              var bData = booking.data() as Map<String, dynamic>;
              return _buildRequestCard(booking.id, bData);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(String bId, Map<String, dynamic> bData) {
    bool isPending = bData['status'] == 'pending';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 15),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerRequestDetailScreen(bookingId: bId, bookingData: bData))),
        child: Column(
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(bData['passenger_uid']).get(),
              builder: (context, userSnap) {
                String pName = userSnap.hasData ? (userSnap.data!.get('name') ?? "Passenger") : "Loading...";
                String? pPic = userSnap.hasData ? (userSnap.data!.data() as Map)['profile_pic'] : null;
                
                return ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(backgroundImage: pPic != null ? NetworkImage(pPic) : null, child: pPic == null ? const Icon(Icons.person) : null),
                  title: Text(pName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("To: ${bData['destination']['name']}"),
                  trailing: _statusBadge(bData['status']),
                );
              },
            ),
            if (isPending)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleAction(bId, bData['ride_id'], bData['passenger_uid'], 'rejected'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text("DECLINE"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                        onPressed: () => _handleAction(bId, bData['ride_id'], bData['passenger_uid'], 'accepted'),
                        child: const Text("ACCEPT", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = status == 'accepted' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)));
  }

  // --- UPDATED HELPER: Accepts Ride and adds Passenger UID ---
  Future<void> _handleAction(String bId, String rId, String pId, String status) async {
    try {
      if (status == 'accepted') {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference rideRef = FirebaseFirestore.instance.collection('rides').doc(rId);
          DocumentSnapshot rideSnap = await transaction.get(rideRef);
          
          int seats = rideSnap['available_seats'] ?? 0;
          if (seats < 1) throw "No seats left";
          
          transaction.update(rideRef, {
            'available_seats': seats - 1,
            'passengers': FieldValue.arrayUnion([pId]), // Add UID to Ride
          });

          transaction.update(FirebaseFirestore.instance.collection('bookings').doc(bId), {
            'status': 'accepted',
            'responded_at': FieldValue.serverTimestamp(),
          });
        });
      } else {
        await FirebaseFirestore.instance.collection('bookings').doc(bId).update({
          'status': 'rejected',
          'responded_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Action failed: $e")));
    }
  }
}