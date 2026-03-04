import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ride_moving_screen.dart';
import 'driver_live_tracking.dart'; // Import the tracking screen

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
        // 1. Update Firestore status to security_completed (this onboard the passenger)
        await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
          'passenger_routes.${widget.passengerUid}.ride_status': 'security_completed',
          'ride_status': 'ongoing' 
        });

        // 2. Fetch the LATEST ride data
        DocumentSnapshot updatedSnap = await FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .get();
        
        Map<String, dynamic> updatedData = updatedSnap.data() as Map<String, dynamic>;

        if (mounted) {
          // 3. Move to the next stage (Moving with passenger onboard)
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect PIN"), backgroundColor: Colors.red));
      _pinController.clear();
      setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Verify Passenger", style: TextStyle(fontWeight: FontWeight.bold)), 
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        // BACK BUTTON LOGIC:
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            // This returns the driver to the DriverLiveTracking map screen
            Navigator.pop(context);
          },
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var data = snapshot.data!.data() as Map<String, dynamic>?;

          // If passenger hasn't opened their screen yet to generate the OTP
          if (data == null || !data.containsKey('ride_otp')) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.orange),
                  const SizedBox(height: 20),
                  const Text(
                    "Waiting for passenger...",
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Ask the passenger to open their security screen.",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          String correctPin = data['ride_otp'].toString();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.verified_user, size: 80, color: Color(0xFF11A860)),
                const SizedBox(height: 25),
                const Text("Enter Security PIN", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text(
                  "Ask the passenger for the 4-digit code shown on their phone to confirm the pickup.", 
                  textAlign: TextAlign.center, 
                  style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)
                ),
                const SizedBox(height: 50),
                
                // PIN Input field
                TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  autofocus: true, // Automatically pops the keyboard
                  style: const TextStyle(fontSize: 45, letterSpacing: 25, fontWeight: FontWeight.bold, color: Color(0xFF2B5145)),
                  onChanged: (v) => _verifyPin(v, correctPin),
                  decoration: InputDecoration(
                    counterText: "", 
                    hintText: "••••",
                    hintStyle: TextStyle(color: Colors.grey.shade200),
                    border: InputBorder.none,
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade100, width: 2)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF11A860), width: 2)),
                  ),
                ),

                const SizedBox(height: 40),
                if (_isVerifying) 
                  const CircularProgressIndicator(color: Color(0xFF11A860)),
              ],
            ),
          );
        },
      ),
    );
  }
}