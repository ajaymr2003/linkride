import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'passenger_moving_screen.dart'; // Ensure this is imported

class PassengerSecurityDisplay extends StatefulWidget {
  final String rideId;
  const PassengerSecurityDisplay({super.key, required this.rideId});

  @override
  State<PassengerSecurityDisplay> createState() => _PassengerSecurityDisplayState();
}

class _PassengerSecurityDisplayState extends State<PassengerSecurityDisplay> {
  bool _isGenerating = true;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _generateAndSavePIN();
  }

  Future<void> _generateAndSavePIN() async {
    try {
      String newOtp = (1000 + Random().nextInt(9000)).toString();
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'ride_otp': newOtp,
        'driver_arrival_confirmed_at': FieldValue.serverTimestamp(),
      });
      if (mounted) setState(() => _isGenerating = false);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Security Verification"), 
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || _isGenerating) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF11A860)));
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;
          String otp = data['ride_otp'] ?? "----";
          
          // Logic: Check the specific passenger's status inside the map
          Map<String, dynamic> routes = data['passenger_routes'] ?? {};
          String myRideStatus = routes[_uid]['ride_status'] ?? 'approved';

          // --- AUTO REDIRECT LOGIC ---
          // When Driver verifies PIN, this status updates to 'security_completed'
          if (myRideStatus == 'security_completed') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (_) => PassengerMovingScreen(rideId: widget.rideId, rideData: data))
                );
              }
            });
          }

          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user_outlined, size: 80, color: Color(0xFF11A860)),
                const SizedBox(height: 20),
                const Text("Give this code to Driver", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("Do not board until the driver confirms your PIN.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 50),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 25),
                  decoration: BoxDecoration(
                    color: const Color(0xFF11A860).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF11A860), width: 2),
                  ),
                  child: Text(
                    otp,
                    style: const TextStyle(fontSize: 55, fontWeight: FontWeight.bold, letterSpacing: 15, color: Color(0xFF11A860)),
                  ),
                ),
                
                const SizedBox(height: 60),
                const LinearProgressIndicator(color: Color(0xFF11A860), backgroundColor: Color(0xFFE8F5E9)),
                const SizedBox(height: 15),
                const Text("Waiting for Driver to verify PIN...", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
              ],
            ),
          );
        },
      ),
    );
  }
}