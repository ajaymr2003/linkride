import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // --- LOGIC: CANCEL ACCEPTED BOOKING (CLEANUP + NOTIFICATIONS) ---
  Future<void> _cancelBooking() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Booking?"),
        content: const Text("This will remove the passenger, free up the seat, and notify the passenger."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    String rId = widget.bookingData['ride_id'];
    String pId = widget.bookingData['passenger_uid'];
    String destinationName = widget.bookingData['destination']['name'] ?? "Destination";

    try {
      // 1. Fetch Passenger FCM Token first
      DocumentSnapshot passengerSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(pId)
          .get();
      String? passengerToken = passengerSnap.exists ? passengerSnap.get('fcm_token') : null;

      // 2. RUN DATABASE TRANSACTION (CLEANUP + INTERNAL NOTIF)
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference rideRef = FirebaseFirestore.instance.collection('rides').doc(rId);
        DocumentSnapshot rideSnap = await transaction.get(rideRef);

        if (rideSnap.exists) {
          int currentSeats = rideSnap['available_seats'] ?? 0;
          
          // A. Clean up Ride Data: Increment seats, remove UID, delete route map
          transaction.update(rideRef, {
            'available_seats': currentSeats + 1,
            'passengers': FieldValue.arrayRemove([pId]),
            'passenger_routes.$pId': FieldValue.delete(),
          });
        }

        // B. Update the Booking document status
        transaction.update(
          FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId),
          {
            'status': 'cancelled',
            'cancelled_by': 'driver',
            'cancelled_at': FieldValue.serverTimestamp(),
          },
        );

        // C. Create In-App Notification document for Passenger
        DocumentReference notifRef = FirebaseFirestore.instance.collection('notifications').doc();
        transaction.set(notifRef, {
          'uid': pId,
          'title': 'Ride Cancelled ⚠️',
          'message': 'The driver has cancelled your seat for the ride to $destinationName.',
          'type': 'booking_cancelled',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      });

      // 3. Trigger External Push Notification (FCM)
      if (passengerToken != null && passengerToken.isNotEmpty) {
        await FCMService.sendPushNotification(
          token: passengerToken,
          title: "Ride Cancelled ⚠️",
          body: "The driver removed you from the ride to $destinationName.",
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking cancelled and passenger notified.")));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _handleAction(String status) async {
    setState(() => _isLoading = true);
    String rId = widget.bookingData['ride_id'];
    String pId = widget.bookingData['passenger_uid'];

    try {
      if (status == 'accepted') {
        DocumentSnapshot passengerSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(pId)
            .get();
        String? passengerToken = passengerSnap.exists ? passengerSnap.get('fcm_token') : null;

        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference rideRef = FirebaseFirestore.instance.collection('rides').doc(rId);
          DocumentSnapshot rideSnap = await transaction.get(rideRef);

          if (!rideSnap.exists) throw "Ride not found";
          int seats = rideSnap['available_seats'] ?? 0;
          if (seats < 1) throw "No seats left";

          transaction.update(rideRef, {
            'available_seats': seats - 1,
            'passengers': FieldValue.arrayUnion([pId]),
            'passenger_routes.$pId': {
              'pickup': widget.bookingData['source'],      
              'dropoff': widget.bookingData['destination'], 
              'passenger_name': widget.bookingData['passenger_name'] ?? "Passenger",
              'ride_status': 'approved', 
              'payment_status': 'unpaid',
            }
          });

          transaction.update(
            FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId),
            {
              'status': 'accepted',
              'responded_at': FieldValue.serverTimestamp(),
            },
          );

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

        if (passengerToken != null) {
          await FCMService.sendPushNotification(
            token: passengerToken,
            title: "Ride Accepted! 🚗",
            body: "The driver accepted your ride to ${widget.bookingData['destination']['name']}.",
          );
        }
      } else {
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
    String status = widget.bookingData['status'] ?? 'pending';
    bool isPending = status == 'pending';
    bool isAccepted = status == 'accepted';

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
                      
                      // Status Badge
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAccepted ? Colors.green.shade50 : (status == 'cancelled' ? Colors.red.shade50 : Colors.orange.shade50),
                          borderRadius: BorderRadius.circular(20)
                        ),
                        child: Text(
                          status.toUpperCase(), 
                          style: TextStyle(
                            color: isAccepted ? Colors.green : (status == 'cancelled' ? Colors.red : Colors.orange), 
                            fontWeight: FontWeight.bold, 
                            fontSize: 12
                          )
                        ),
                      ),
                      
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
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (isPending)
                      Row(
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
                    
                    if (isAccepted)
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _cancelBooking,
                          icon: _isLoading ? null : const Icon(Icons.cancel_outlined),
                          label: _isLoading 
                            ? const CircularProgressIndicator(color: Colors.red) 
                            : const Text("CANCEL THIS BOOKING", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
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