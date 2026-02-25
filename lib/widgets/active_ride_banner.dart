import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ActiveRideBanner extends StatelessWidget {
  const ActiveRideBanner({super.key});

  // --- UPDATED LOGIC TO CHANGE STATUS INSTEAD OF DELETING ---
  Future<void> _cancelRequest(BuildContext context, String bookingId, String status, String rideId) async {
    // 1. Confirm Dialog
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'pending' ? "Cancel Request?" : "Cancel Ride?"),
        content: const Text("Are you sure? You can view this later in your Activity tab."),
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

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 2. Handle Cancellation Logic
      if (status == 'accepted') {
        // If the ride was already accepted, we must give the seat back to the driver
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
          DocumentSnapshot rideSnap = await transaction.get(rideRef);
          
          if (rideSnap.exists) {
            int currentSeats = rideSnap['available_seats'] ?? 0;
            
            // Increment seats and remove user from the passengers array
            transaction.update(rideRef, {
              'available_seats': currentSeats + 1,
              'passengers': FieldValue.arrayRemove([user.uid]),
              // Also clean up the passenger specific route map if it exists
              'passenger_routes.${user.uid}': FieldValue.delete(),
            });
          }
          
          // Update the BOOKING status to cancelled (Do NOT delete)
          DocumentReference bookingRef = FirebaseFirestore.instance.collection('bookings').doc(bookingId);
          transaction.update(bookingRef, {
            'status': 'cancelled',
            'cancelled_at': FieldValue.serverTimestamp(),
          }); 
        });
      } else {
        // If just pending, simply change status to cancelled
        await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
          'status': 'cancelled',
          'cancelled_at': FieldValue.serverTimestamp(),
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request cancelled successfully")));
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error cancelling request")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    // Stream only listens for 'pending' or 'accepted'
    // Once status becomes 'cancelled', it will automatically disappear from this banner
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('passenger_uid', isEqualTo: user.uid)
          .where('status', whereIn: ['pending', 'accepted'])
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox(); 
        }

        var booking = snapshot.data!.docs.first;
        var data = booking.data() as Map<String, dynamic>;
        
        String status = data['status'];
        bool isAccepted = status == 'accepted';
        String destName = data['destination']['name'] ?? "Destination";
        
        DateTime? date;
        if (data['ride_date'] != null) {
          date = (data['ride_date'] as Timestamp).toDate();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 20), 
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isAccepted ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isAccepted ? Colors.green.shade200 : Colors.orange.shade200,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isAccepted ? Icons.check_circle : Icons.hourglass_top, 
                    color: isAccepted ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isAccepted ? "RIDE CONFIRMED" : "REQUEST SENT",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isAccepted ? Colors.green.shade800 : Colors.orange.shade900,
                      fontSize: 12,
                      letterSpacing: 1
                    ),
                  ),
                  const Spacer(),
                  if(date != null)
                    Text(DateFormat('EEE, d MMM').format(date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 10),
              
              Text(
                "Trip to $destName",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 5),
              Text(
                isAccepted 
                  ? "Driver accepted. Get ready!" 
                  : "Waiting for driver to approve...",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              
              const SizedBox(height: 15),
              
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  onPressed: () => _cancelRequest(context, booking.id, status, data['ride_id']),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade200),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  child: Text(isAccepted ? "CANCEL BOOKING" : "CANCEL REQUEST"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}