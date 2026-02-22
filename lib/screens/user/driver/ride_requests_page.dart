import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'passenger_request_detail_screen.dart';
import '../../../services/fcm_service.dart';

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
        title: const Text(
          "Passenger Requests",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Center(child: Text("No requests found."));

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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PassengerRequestDetailScreen(
              bookingId: bId,
              bookingData: bData,
            ),
          ),
        ),
        child: Column(
          children: [
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(bData['passenger_uid'])
                  .get(),
              builder: (context, userSnap) {
                String pName = userSnap.hasData
                    ? (userSnap.data!.get('name') ?? "Passenger")
                    : "Loading...";
                String? pPic = userSnap.hasData
                    ? (userSnap.data!.data() as Map)['profile_pic']
                    : null;

                return ListTile(
                  contentPadding: const EdgeInsets.all(15),
                  leading: CircleAvatar(
                    backgroundImage: pPic != null ? NetworkImage(pPic) : null,
                    child: pPic == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(
                    pName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                        onPressed: () => _handleAction(
                          bId,
                          bData['ride_id'],
                          bData['passenger_uid'],
                          'rejected',
                          '',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text("DECLINE"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                        ),
                        onPressed: () => _handleAction(
                          bId,
                          bData['ride_id'],
                          bData['passenger_uid'],
                          'accepted',
                          bData['destination']['name'],
                        ),
                        child: const Text(
                          "ACCEPT",
                          style: TextStyle(color: Colors.white),
                        ),
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
    Color color = status == 'accepted'
        ? Colors.green
        : (status == 'rejected' ? Colors.red : Colors.orange);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  // --- UPDATED HELPER: Accepts Ride and adds Passenger UID with Push Notification ---
  Future<void> _handleAction(
    String bId,
    String rId,
    String pId,
    String status,
    String destName,
  ) async {
    try {
      if (status == 'accepted') {
        DocumentSnapshot pSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(pId)
            .get();
        String? pToken = pSnap.get('fcm_token');

        print("\n📱 [RideRequestsPage] Acceptance Flow Started:");
        print("   Passenger ID: $pId");
        print("   Ride ID: $rId");
        print("   Destination: $destName");
        print(
          "   FCM Token Retrieved: ${pToken != null && pToken.isNotEmpty ? "✓ Yes" : "✗ No"}",
        );

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference rideRef = FirebaseFirestore.instance
              .collection('rides')
              .doc(rId);
          DocumentSnapshot rideSnap = await transaction.get(rideRef);

          int seats = rideSnap['available_seats'] ?? 0;
          if (seats < 1) throw "No seats left";

          transaction.update(rideRef, {
            'available_seats': seats - 1,
            'passengers': FieldValue.arrayUnion([pId]),
          });

          transaction.update(
            FirebaseFirestore.instance.collection('bookings').doc(bId),
            {
              'status': 'accepted',
              'responded_at': FieldValue.serverTimestamp(),
            },
          );

          // Metadata for chat
          String chatId = "${rId}_$pId";
          transaction.set(
            FirebaseFirestore.instance.collection('chats').doc(chatId),
            {
              'chatId': chatId,
              'participants': [currentDriverId, pId],
              'last_message': 'Ride accepted!',
              'last_message_time': FieldValue.serverTimestamp(),
            },
          );

          // Notification record
          transaction.set(
            FirebaseFirestore.instance.collection('notifications').doc(),
            {
              'uid': pId,
              'title': 'Request Approved',
              'message': 'Driver accepted your ride to $destName.',
              'type': 'ride_approved',
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            },
          );
        });

        if (pToken != null) {
          print("   📤 Sending push notification to: $pToken");
          FCMService.sendPushNotification(
            token: pToken,
            title: "Request Approved",
            body: "Driver accepted your ride to $destName.",
          );
        } else {
          print("   ⚠️ Warning: No FCM token available for passenger!");
        }
      } else {
        await FirebaseFirestore.instance.collection('bookings').doc(bId).update(
          {'status': 'rejected'},
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }
}
