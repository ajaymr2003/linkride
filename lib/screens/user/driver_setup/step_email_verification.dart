import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StepEmailVerification extends StatefulWidget {
  final VoidCallback onVerified;
  const StepEmailVerification({super.key, required this.onVerified});

  @override
  State<StepEmailVerification> createState() => _StepEmailVerificationState();
}

class _StepEmailVerificationState extends State<StepEmailVerification> {
  User? user = FirebaseAuth.instance.currentUser;
  bool _isSent = false;
  bool _isVerified = false;
  Timer? _timer;

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _check() async {
    await user?.reload();
    user = FirebaseAuth.instance.currentUser;
    if (user?.emailVerified ?? false) { _timer?.cancel(); setState(() => _isVerified = true); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        children: [
          const Text("Verify Email", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Spacer(),
          Icon(_isVerified ? Icons.verified : Icons.email, size: 80, color: _isVerified ? Colors.green : Colors.grey),
          const SizedBox(height: 20),
          Text(user?.email ?? ""),
          const Spacer(),
          if (!_isVerified)
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: () {
                  if (!_isSent) { user?.sendEmailVerification(); setState(() => _isSent = true); _timer = Timer.periodic(const Duration(seconds: 3), (t) => _check()); }
                  else { _check(); }
                },
                child: Text(_isSent ? "CHECK STATUS" : "SEND LINK"),
              ),
            )
          else
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: widget.onVerified,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF11A860)),
                child: const Text("CONTINUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}