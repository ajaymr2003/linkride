import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RideViewScreen extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const RideViewScreen({
    super.key,
    required this.rideId,
    required this.rideData,
  });

  @override
  State<RideViewScreen> createState() => _RideViewScreenState();
}

class _RideViewScreenState extends State<RideViewScreen> {
  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);
  bool _isRequesting = false;
  String? _existingStatus; // To store if user already requested this specific ride

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  // Check if this user already requested THIS specific ride
  Future<void> _checkExistingRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final query = await FirebaseFirestore.instance
        .collection('bookings')
        .where('ride_id', isEqualTo: widget.rideId)
        .where('passenger_uid', isEqualTo: user.uid)
        .get();

    if (query.docs.isNotEmpty) {
      // Get the most relevant status (active ones)
      var status = query.docs.first['status'];
      if (status == 'pending' || status == 'accepted') {
        setState(() => _existingStatus = status);
      }
    }
  }

  Future<void> _sendRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (user.uid == widget.rideData['driver_uid']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot book your own ride.")),
      );
      return;
    }

    setState(() => _isRequesting = true);

    try {
      // Create the Booking Request
      await FirebaseFirestore.instance.collection('bookings').add({
        'ride_id': widget.rideId,
        'passenger_uid': user.uid,
        'driver_uid': widget.rideData['driver_uid'],
        'status': 'pending', // IMPORTANT: Starts as pending
        'created_at': FieldValue.serverTimestamp(),
        'price': widget.rideData['price_per_seat'],
        'source': widget.rideData['source'],
        'destination': widget.rideData['destination'],
        'passenger_name': user.displayName ?? "Passenger", // Optional helper
        'ride_date': widget.rideData['departure_time'], // Helper for sorting
      });

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Request Failed: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isRequesting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.send_rounded, color: Color(0xFF11A860), size: 60),
            const SizedBox(height: 20),
            const Text("Request Sent!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("The driver has been notified. We will alert you once they accept your request.", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
              onPressed: () {
                Navigator.pop(ctx); 
                Navigator.pop(context); // Go back to results
                Navigator.pop(context); // Go back to search
              },
              child: const Text("OK, WAIT FOR RESPONSE", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime depTime = (widget.rideData['departure_time'] as Timestamp).toDate();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Ride Details"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEE, d MMM • h:mm a').format(depTime),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkGreen),
                      ),
                      Text(
                        "₹${widget.rideData['price_per_seat']}",
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryGreen),
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  // Route Details
                  Row(children: [
                    Column(children: [Icon(Icons.circle_outlined, size: 16, color: primaryGreen), Container(width: 2, height: 40, color: Colors.grey.shade300), Icon(Icons.location_on, size: 16, color: primaryGreen)]),
                    const SizedBox(width: 15),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.rideData['source']['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 35),
                      Text(widget.rideData['destination']['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ])),
                  ]),
                  
                  const Divider(height: 30),
                  // Driver details (Same as previous code...)
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(widget.rideData['driver_uid']).get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      var driver = snapshot.data!.data() as Map<String, dynamic>;
                      return Row(children: [
                         CircleAvatar(backgroundImage: driver['profile_pic'] != null ? NetworkImage(driver['profile_pic']) : null, child: driver['profile_pic'] == null ? const Icon(Icons.person) : null),
                         const SizedBox(width: 15),
                         Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                           Text(driver['name'] ?? "Driver", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                           Text("Rating: ${driver['rating'] ?? 'New'}", style: const TextStyle(color: Colors.grey)),
                         ])
                      ]);
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // --- BOTTOM BUTTON LOGIC ---
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: _existingStatus == 'pending'
                  ? OutlinedButton(
                      onPressed: null, // Disabled
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.orange)),
                      child: const Text("REQUEST ALREADY SENT", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    )
                  : _existingStatus == 'accepted'
                      ? ElevatedButton(
                          onPressed: null, // Disabled
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text("RIDE BOOKED", style: TextStyle(color: Colors.white)),
                        )
                      : ElevatedButton(
                          onPressed: _isRequesting ? null : _sendRequest,
                          style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                          child: _isRequesting 
                            ? const CircularProgressIndicator(color: Colors.white) 
                            : const Text("REQUEST SEAT", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}