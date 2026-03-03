import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ride_moving_screen.dart';

class DriverSecurityVerify extends StatefulWidget {
  final String rideId;
  final String passengerUid;
  final Map<String, dynamic> rideData;

  const DriverSecurityVerify({super.key, required this.rideId, required this.passengerUid, required this.rideData});

  @override
  State<DriverSecurityVerify> createState() => _DriverSecurityVerifyState();
}

class _DriverSecurityVerifyState extends State<DriverSecurityVerify> {
  final TextEditingController _pinController = TextEditingController();
  bool _isVerifying = false;

  void _verifyPin(String enteredPin, String correctPin) async {
    if (enteredPin.length != 4) return;
    setState(() => _isVerifying = true);

    if (enteredPin == correctPin) {
      try {
        // 1. Update Firestore
        await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
          'passenger_routes.${widget.passengerUid}.ride_status': 'security_completed',
          'ride_status': 'ongoing' 
        });

        // 2. Fetch the LATEST ride data so the next screen isn't using stale data
        DocumentSnapshot updatedSnap = await FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .get();
        
        Map<String, dynamic> updatedData = updatedSnap.data() as Map<String, dynamic>;

        if (mounted) {
          // 3. Use pushReplacement to prevent going back to the PIN screen
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(
              builder: (_) => RideMovingScreen(
                rideId: widget.rideId, 
                rideData: updatedData
              )
            )
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isVerifying = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect PIN")));
      _pinController.clear();
      setState(() => _isVerifying = false);
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(title: const Text("Verify Passenger"), elevation: 0),
    body: StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
      builder: (context, snapshot) {
        // 1. Handle Loading state
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // 2. Safely get data map
        var data = snapshot.data!.data() as Map<String, dynamic>?;

        // 3. Check if 'ride_otp' exists. If not, wait gracefully.
        if (data == null || !data.containsKey('ride_otp')) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.orange),
                const SizedBox(height: 20),
                const Text(
                  "Waiting for passenger to generate PIN...",
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Please ask the passenger to open their app.",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        }

        // 4. If field exists, proceed with logic
        String correctPin = data['ride_otp'].toString();

        return Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const Icon(Icons.lock_person, size: 80, color: Color(0xFF11A860)),
              const SizedBox(height: 20),
              const Text("Enter 4-digit PIN", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const Text("Ask the passenger for the code shown on their screen", 
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 40),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 40, letterSpacing: 20, fontWeight: FontWeight.bold),
                onChanged: (v) => _verifyPin(v, correctPin), // Pass the pin to your existing logic
                decoration: const InputDecoration(
                  counterText: "", 
                  hintText: "0000",
                  hintStyle: TextStyle(color: Color(0xFFEEEEEE))
                ),
              ),
              if (_isVerifying) 
                const Padding(
                  padding: EdgeInsets.all(20), 
                  child: CircularProgressIndicator()
                ),
            ],
          ),
        );
      },
    ),
  );
}
}