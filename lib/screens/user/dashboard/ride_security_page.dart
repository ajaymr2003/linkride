import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RideSecurityPage extends StatefulWidget {
  final String rideId;
  final bool isDriver;
  final String passengerUid;

  const RideSecurityPage({
    super.key,
    required this.rideId,
    required this.isDriver,
    required this.passengerUid,
  });

  @override
  State<RideSecurityPage> createState() => _RideSecurityPageState();
}

class _RideSecurityPageState extends State<RideSecurityPage> {
  final TextEditingController _pinInput = TextEditingController();
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  void initState() {
    super.initState();

    // Generate OTP only if driver opens screen
    if (widget.isDriver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _generateAndStoreRandomPin();
      });
    }
  }

  // ---------------- GENERATE RANDOM OTP ----------------
  Future<void> _generateAndStoreRandomPin() async {
    try {
      final random = Random();

      // Generate 4 digit number (1000 - 9999)
      String randomPin = (1000 + random.nextInt(9000)).toString();

      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .set({
        'ride_otp': randomPin,
        'ride_status': 'verifying',
        'otp_created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print("🔐 OTP Generated: $randomPin");
    } catch (e) {
      print("❌ OTP Generation Error: $e");
    }
  }

  // ---------------- VERIFY OTP ----------------
  void _verifyPin(String entered, String correct) async {
    if (entered.length == 4) {
      if (entered == correct) {
        await FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .update({
          'ride_status': 'ongoing',
        });

        _goNext();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Incorrect Code"),
            backgroundColor: Colors.red,
          ),
        );
        _pinInput.clear();
      }
    }
  }

  void _goNext() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: Center(
            child: Text(
              "Ride Verified & Ongoing!",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Security Handshake"),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data!.data() as Map<String, dynamic>?;
          String dbPin = data?['ride_otp'] ?? "";
          String status = data?['ride_status'] ?? "";

          // Passenger auto-move when ride starts
          if (!widget.isDriver && status == 'ongoing') {
            WidgetsBinding.instance.addPostFrameCallback((_) => _goNext());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              children: [
                const SizedBox(height: 30),

                Icon(
                  widget.isDriver
                      ? Icons.lock_open_rounded
                      : Icons.vpn_key_rounded,
                  size: 100,
                  color: primaryGreen,
                ),

                const SizedBox(height: 30),

                Text(
                  widget.isDriver
                      ? "Ask Passenger for Code"
                      : "Tell Driver this Code",
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                Text(
                  "Ride Security OTP",
                  style:
                      TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),

                const SizedBox(height: 60),

                // DRIVER INPUT
                if (widget.isDriver)
                  TextField(
                    controller: _pinInput,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 45,
                      letterSpacing: 30,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      hintText: "0000",
                      counterText: "",
                      hintStyle: TextStyle(color: Colors.black12),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey)),
                      focusedBorder: UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: Colors.green, width: 2)),
                    ),
                    onChanged: (v) => _verifyPin(v, dbPin),
                  )

                // PASSENGER DISPLAY
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDisplayCard(
                          dbPin.isNotEmpty ? dbPin.substring(0, 2) : "--"),
                      const SizedBox(width: 20),
                      _buildDisplayCard(
                          dbPin.length == 4 ? dbPin.substring(2, 4) : "--"),
                    ],
                  ),

                const SizedBox(height: 100),

                const Text(
                  "This ensures you are getting into the correct vehicle with the correct person.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDisplayCard(String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: BoxDecoration(
        color: primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryGreen, width: 2),
      ),
      child: Text(
        val,
        style: TextStyle(
          fontSize: 50,
          fontWeight: FontWeight.bold,
          color: primaryGreen,
          letterSpacing: 5,
        ),
      ),
    );
  }
}
