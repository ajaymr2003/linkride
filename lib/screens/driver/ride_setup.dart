import 'package:flutter/material.dart';

class RideSetupScreen extends StatelessWidget {
  const RideSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Publish a Ride"), backgroundColor: const Color(0xFF11A860), foregroundColor: Colors.white),
      body: const Center(
        child: Text("This is where the Driver creates a new ride."),
      ),
    );
  }
}