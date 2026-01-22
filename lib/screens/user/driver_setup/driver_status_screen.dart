import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverStatusScreen extends StatelessWidget {
  final String status;
  final Map<String, dynamic>? appData;

  const DriverStatusScreen({super.key, required this.status, this.appData});

  @override
  Widget build(BuildContext context) {
    bool isRejected = status == 'rejected';
    Color themeColor = isRejected ? Colors.red : const Color(0xFF11A860);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Progress Bar (Simple)
            Row(children: [
              _circle(Icons.check, true),
              _line(true),
              _circle(Icons.hourglass_bottom, true),
              _line(status == 'approved'),
              _circle(Icons.verified, status == 'approved'),
            ]),
            const SizedBox(height: 50),
            Icon(isRejected ? Icons.error_outline : Icons.pending_actions, size: 80, color: themeColor),
            const SizedBox(height: 20),
            Text(isRejected ? "Application Rejected" : "Review in Progress", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(isRejected ? "Reason: ${appData?['rejection_reason']}" : "Your documents are being verified by our team. Please wait 24-48 hours.", textAlign: TextAlign.center),
            const Spacer(),
            if (isRejected)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                onPressed: () => FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({'driver_status': 'not_applied'}),
                child: const Text("EDIT & RE-SUBMIT", style: TextStyle(color: Colors.white)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Back to Dashboard"))
          ],
        ),
      ),
    );
  }

  Widget _circle(IconData icon, bool active) => CircleAvatar(radius: 20, backgroundColor: active ? const Color(0xFF11A860) : Colors.grey[200], child: Icon(icon, size: 18, color: Colors.white));
  Widget _line(bool active) => Expanded(child: Container(height: 2, color: active ? const Color(0xFF11A860) : Colors.grey[200]));
}