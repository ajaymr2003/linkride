import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../services/booking_service.dart';
import '../../user/dashboard/inbox/chat_screen.dart';

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

  // --- UPDATED LOGIC: USES SHARED SERVICE ---
  Future<void> _handleAction(String status) async {
    setState(() => _isLoading = true);
    final String currentDriverId = FirebaseAuth.instance.currentUser?.uid ?? "";

    try {
      if (status == 'accepted') {
        await BookingService.acceptRequest(
          bookingId: widget.bookingId,
          bookingData: widget.bookingData,
          currentDriverId: currentDriverId,
        );
      } else {
        await BookingService.rejectRequest(widget.bookingId);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- LOGIC: CANCEL EXISTING (Cleanup + Notif) ---
  Future<void> _cancelBooking() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Booking?"),
        content: const Text("This will notify the passenger and free up the seat."),
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
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference rideRef = FirebaseFirestore.instance.collection('rides').doc(widget.bookingData['ride_id']);
        DocumentSnapshot rideSnap = await transaction.get(rideRef);

        if (rideSnap.exists) {
          transaction.update(rideRef, {
            'available_seats': (rideSnap['available_seats'] ?? 0) + 1,
            'passengers': FieldValue.arrayRemove([widget.bookingData['passenger_uid']]),
            'passenger_routes.${widget.bookingData['passenger_uid']}': FieldValue.delete(),
          });
        }

        transaction.update(
          FirebaseFirestore.instance.collection('bookings').doc(widget.bookingId),
          {'status': 'cancelled', 'cancelled_at': FieldValue.serverTimestamp()},
        );
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String status = widget.bookingData['status'] ?? 'pending';

    // --- FIX: NULL FARE LOGIC ---
    // Checks 'price', then 'suggested_price', defaults to 0
    final dynamic rawFare = widget.bookingData['price'] ?? widget.bookingData['suggested_price'] ?? 0;
    final String fareDisplay = rawFare.toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Request Details", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.bookingData['passenger_uid']).get(),
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
                      // 1. Profile Section
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: user['profile_pic'] != null ? NetworkImage(user['profile_pic']) : null,
                        child: user['profile_pic'] == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                      ),
                      const SizedBox(height: 15),
                      Text(user['name'] ?? "User", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      _statusBadge(status),
                      
                      const SizedBox(height: 30),

                      // 2. Context Card
                      _buildContextCard(),
                      
                      const SizedBox(height: 25),

                      // 3. Route Details
                      const Align(
                        alignment: Alignment.centerLeft, 
                        child: Text("PASSENGER ROUTE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1))
                      ),
                      const SizedBox(height: 15),
                      _routeRow(Icons.circle_outlined, "Pickup Location", widget.bookingData['source']['name']),
                      const SizedBox(height: 20),
                      _routeRow(Icons.location_on, "Drop-off Location", widget.bookingData['destination']['name']),
                      
                      const Padding(padding: EdgeInsets.symmetric(vertical: 25), child: Divider()),
                      
                      // 4. Price Row (UPDATED TO USE fareDisplay)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Trip Fare", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              if (widget.bookingData['distance_km'] != null)
                                Text("${widget.bookingData['distance_km']} km distance", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          Text("₹$fareDisplay", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryGreen)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Sticky Bottom Buttons
              _buildBottomActions(status),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContextCard() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('rides').doc(widget.bookingData['ride_id']).get(),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        var ride = snap.data!.data() as Map<String, dynamic>;
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey.shade50, 
            borderRadius: BorderRadius.circular(15), 
            border: Border.all(color: Colors.grey.shade200)
          ),
          child: Row(
            children: [
              const Icon(Icons.directions_car, color: Colors.grey),
              const SizedBox(width: 15),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("REQUEST FOR YOUR RIDE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                Text(
                  "${ride['source']['name']} ➔ ${ride['destination']['name']}", 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), 
                  maxLines: 1, overflow: TextOverflow.ellipsis
                ),
              ])),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomActions(String status) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => _handleAction('rejected'), 
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 15)), 
                    child: const Text("DECLINE")
                  )
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _handleAction('accepted'), 
                    style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, padding: const EdgeInsets.symmetric(vertical: 15)), 
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("ACCEPT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  )
                ),
              ],
            ),
          if (status == 'accepted')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _cancelBooking, 
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), padding: const EdgeInsets.symmetric(vertical: 15)), 
                    child: const Text("CANCEL")
                  )
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: "${widget.bookingData['ride_id']}_${widget.bookingData['passenger_uid']}", otherUserName: widget.bookingData['passenger_name']))), 
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white), 
                    label: const Text("CHAT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 15))
                  )
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _routeRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: primaryGreen, size: 20),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ])),
      ],
    );
  }

  Widget _statusBadge(String status) {
    Color color = status == 'accepted' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}