import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PassengerSecurityDisplay extends StatefulWidget {
  final String rideId;
  const PassengerSecurityDisplay({super.key, required this.rideId});

  @override
  State<PassengerSecurityDisplay> createState() => _PassengerSecurityDisplayState();
}

class _PassengerSecurityDisplayState extends State<PassengerSecurityDisplay> {
  @override
  void initState() {
    super.initState();
    _ensureOtpExists();
  }

  Future<void> _ensureOtpExists() async {
    final doc = await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).get();
    if (doc.exists && (doc.data()?['ride_otp'] == null)) {
      String newOtp = (1000 + Random().nextInt(9000)).toString();
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({'ride_otp': newOtp});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Ride Security"), elevation: 0),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          String otp = snapshot.data!.get('ride_otp') ?? "----";
          String status = snapshot.data!.get('ride_status') ?? "";

          if (status == 'ongoing') {
            Future.delayed(Duration.zero, () => Navigator.pop(context));
          }

          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_user, size: 80, color: Color(0xFF11A860)),
                const SizedBox(height: 20),
                const Text("Share this PIN with Driver", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  decoration: BoxDecoration(color: const Color(0xFF11A860).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF11A860), width: 2)),
                  child: Text(otp, style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, letterSpacing: 10, color: Color(0xFF11A860))),
                ),
                const SizedBox(height: 40),
                const Text("Do not board the vehicle if the driver cannot verify this code.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }
}