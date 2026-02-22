import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverSecurityVerify extends StatefulWidget {
  final String rideId;
  const DriverSecurityVerify({super.key, required this.rideId});

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
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({'ride_status': 'ongoing'});
      if (mounted) {
        showDialog(context: context, builder: (_) => const AlertDialog(title: Text("Verified!"), content: Text("Ride has started successfully.")));
        Future.delayed(const Duration(seconds: 2), () => Navigator.pop(context));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect PIN. Please ask passenger again.")));
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
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          String correctPin = snapshot.data!.get('ride_otp') ?? "";

          return Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                const Icon(Icons.lock_person, size: 80, color: Color(0xFF11A860)),
                const SizedBox(height: 20),
                const Text("Enter 4-digit PIN", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const Text("Ask the passenger for the code shown on their screen.", textAlign: TextAlign.center),
                const SizedBox(height: 40),
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 40, letterSpacing: 20, fontWeight: FontWeight.bold),
                  onChanged: (v) => _verifyPin(v, correctPin),
                  decoration: const InputDecoration(counterText: "", hintText: "0000"),
                ),
                if (_isVerifying) const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()),
              ],
            ),
          );
        },
      ),
    );
  }
}