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

        // 2. RUN DATABASE TRANSACTION
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference rideRef = FirebaseFirestore.instance.collection('rides').doc(rId);
          DocumentSnapshot rideSnap = await transaction.get(rideRef);

          if (!rideSnap.exists) throw "Ride not found";
          int seats = rideSnap['available_seats'] ?? 0;
          if (seats < 1) throw "No seats left";

          // --- UPDATED PART: ADDED ride_status: 'approved' ---
          transaction.update(rideRef, {
            'available_seats': seats - 1,
            'passengers': FieldValue.arrayUnion([pId]),
            'passenger_routes.$pId': {
              'pickup': widget.bookingData['source'],      
              'dropoff': widget.bookingData['destination'], 
              'passenger_name': widget.bookingData['passenger_name'] ?? "Passenger",
              'ride_status': 'approved', // <--- Added this line
            }
          });

          // 3. Update Booking status
          transaction.update(
            FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId),
            {
              'status': 'accepted',
              'responded_at': FieldValue.serverTimestamp(),
            },
          );

          // 4. Initialize Chat Metadata
          String chatId = "${rId}_$pId";
          transaction.set(
            FirebaseFirestore.instance.collection('chats').doc(chatId),
            {
              'chatId': chatId,
              'participants': [widget.bookingData['driver_uid'], pId],
              'driver_name': widget.bookingData['driver_name'] ?? "Driver",
              'passenger_name': widget.bookingData['passenger_name'] ?? "Passenger",
              'last_message': 'Ride accepted! You can now chat.',
              'last_message_time': FieldValue.serverTimestamp(),
            },
          );

          // 5. Notification Record
          transaction.set(
            FirebaseFirestore.instance.collection('notifications').doc(),
            {
              'uid': pId,
              'title': 'Ride Accepted! 🚗',
              'message': 'Your trip to ${widget.bookingData['destination']['name']} is confirmed.',
              'type': 'ride_approved',
              'timestamp': FieldValue.serverTimestamp(),
              'isRead': false,
            },
          );
        });

        // 6. Send Push Notification
        if (passengerToken != null) {
          FCMService.sendPushNotification(
            token: passengerToken,
            title: "Ride Accepted! 🚗",
            body: "The driver accepted your ride to ${widget.bookingData['destination']['name']}.",
          );
        }
      } else {
        // If status is rejected
        await FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId).update({
          'status': 'rejected',
          'responded_at': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request ${status == 'accepted' ? 'Accepted' : 'Declined'}")));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String passengerId = widget.bookingData['passenger_uid'];
    bool isPending = widget.bookingData['status'] == 'pending';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Request Details"), elevation: 0),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(passengerId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var user = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: user['profile_pic'] != null ? NetworkImage(user['profile_pic']) : null,
                        child: user['profile_pic'] == null ? const Icon(Icons.person, size: 50) : null,
                      ),
                      const SizedBox(height: 15),
                      Text(user['name'] ?? "User", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 20),
                      _locationRow(Icons.circle_outlined, "Pickup Location", widget.bookingData['source']['name']),
                      const SizedBox(height: 20),
                      _locationRow(Icons.location_on, "Drop-off Location", widget.bookingData['destination']['name']),
                    ],
                  ),
                ),
              ),
              if (isPending)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : () => _handleAction('rejected'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 15)),
                          child: const Text("DECLINE"),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () => _handleAction('accepted'),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, padding: const EdgeInsets.symmetric(vertical: 15)),
                          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("ACCEPT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                )
            ],
          );
        },
      ),
    );
  }

  Widget _locationRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primaryGreen),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }
}