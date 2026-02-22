import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../../services/fcm_service.dart';

class PassengerRequestDetailScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const PassengerRequestDetailScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  State<PassengerRequestDetailScreen> createState() =>
      _PassengerRequestDetailScreenState();
}

class _PassengerRequestDetailScreenState
    extends State<PassengerRequestDetailScreen> {
  final Color primaryGreen = const Color(0xFF11A860);
  bool _isLoading = false;

  Future<void> _handleAction(String status) async {
    setState(() => _isLoading = true);
    String rId = widget.bookingData['ride_id'];
    String pId = widget.bookingData['passenger_uid'];

    try {
      if (status == 'accepted') {
        // 1. Fetch Passenger FCM Token
        DocumentSnapshot passengerSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(pId)
            .get();
        String? passengerToken = passengerSnap.get('fcm_token');

        print("\n📱 [PassengerRequestDetail] Acceptance Flow Started:");
        print("   Passenger ID: $pId");
        print("   Ride ID: $rId");
        print(
          "   FCM Token Retrieved: ${passengerToken != null && passengerToken.isNotEmpty ? "✓ Yes" : "✗ No"}",
        );

        // 2. Run Database Transaction
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference rideRef = FirebaseFirestore.instance
              .collection('rides')
              .doc(rId);
          DocumentSnapshot rideSnap = await transaction.get(rideRef);

          if (!rideSnap.exists) throw "Ride not found";
          int seats = rideSnap['available_seats'] ?? 0;
          if (seats < 1) throw "No seats left";

          // A. Update Ride
          transaction.update(rideRef, {
            'available_seats': seats - 1,
            'passengers': FieldValue.arrayUnion([pId]),
          });

          // B. Update Booking
          transaction.update(
            FirebaseFirestore.instance
                .collection('bookings')
                .doc(widget.bookingId),
            {
              'status': 'accepted',
              'responded_at': FieldValue.serverTimestamp(),
            },
          );

          // C. Initialize Chat Metadata (Firestore)
          String chatId = "${rId}_$pId";
          transaction.set(
            FirebaseFirestore.instance.collection('chats').doc(chatId),
            {
              'chatId': chatId,
              'participants': [widget.bookingData['driver_uid'], pId],
              'driver_name': widget.bookingData['driver_name'] ?? "Driver",
              'passenger_name':
                  widget.bookingData['passenger_name'] ?? "Passenger",
              'last_message': 'Ride accepted! You can now chat.',
              'last_message_time': FieldValue.serverTimestamp(),
            },
          );

          // D. Create In-App Notification Record
          transaction.set(
            FirebaseFirestore.instance.collection('notifications').doc(),
            {
              'uid': pId,
              'title': 'Ride Accepted! 🚗',
              'message':
                  'Your trip to ${widget.bookingData['destination']['name']} is confirmed.',
              'type': 'ride_approved',
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            },
          );

          // E. Initialize RTDB System Message
          DatabaseReference rtdbRef = FirebaseDatabase.instance
              .ref("messages/$chatId")
              .push();
          await rtdbRef.set({
            'senderId': 'system',
            'text': 'Chat started. Coordinate your pickup here.',
            'timestamp': ServerValue.timestamp,
          });
        });

        // 3. Send Push Notification via FCM
        if (passengerToken != null && passengerToken.isNotEmpty) {
          print("   📤 Sending push notification to: $passengerToken");
          FCMService.sendPushNotification(
            token: passengerToken,
            title: "Ride Accepted! 🚗",
            body:
                "The driver accepted your ride to ${widget.bookingData['destination']['name']}.",
          );
        } else {
          print("   ⚠️ Warning: No FCM token available for passenger!");
        }
      } else {
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .update({
              'status': 'rejected',
              'responded_at': FieldValue.serverTimestamp(),
            });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Request $status")));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String passengerId = widget.bookingData['passenger_uid'];
    bool isPending = widget.bookingData['status'] == 'pending';

    DateTime? date;
    if (widget.bookingData['ride_date'] != null) {
      date = (widget.bookingData['ride_date'] as Timestamp).toDate();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Request Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(passengerId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Passenger profile not found"));
          }

          var user = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryGreen, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: user['profile_pic'] != null
                              ? NetworkImage(user['profile_pic'])
                              : null,
                          child: user['profile_pic'] == null
                              ? const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        user['name'] ?? "Unknown",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[700]),
                          const SizedBox(width: 5),
                          Text(
                            "${user['rating'] ?? 'New'}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(width: 1, height: 15, color: Colors.grey),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.verified,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Verified",
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 20),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Trip Details",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildDetailRow(
                        Icons.circle_outlined,
                        "From",
                        widget.bookingData['source']['name'] ?? "",
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 11),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 20,
                            width: 2,
                            color: Colors.grey[300],
                          ),
                        ),
                      ),
                      _buildDetailRow(
                        Icons.location_on,
                        "To",
                        widget.bookingData['destination']['name'] ?? "",
                      ),
                      const SizedBox(height: 25),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoBox(
                              Icons.calendar_today,
                              date != null
                                  ? DateFormat("d MMM, y").format(date)
                                  : "N/A",
                              "Date",
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildInfoBox(
                              Icons.payments_outlined,
                              "₹${widget.bookingData['price']}",
                              "Price",
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (isPending)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _handleAction('rejected'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "DECLINE",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () => _handleAction('accepted'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "ACCEPT REQUEST",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  color: Colors.grey[100],
                  child: Center(
                    child: Text(
                      "Status: ${widget.bookingData['status'].toString().toUpperCase()}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: widget.bookingData['status'] == 'accepted'
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primaryGreen, size: 24),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBox(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: primaryGreen),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}
