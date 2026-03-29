import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StepEmailVerification extends StatefulWidget {
  /// Made optional by using [this.onVerified] without the 'required' keyword.
  /// This fixes the compile error in the Controller page.
  final VoidCallback? onVerified; 
  const StepEmailVerification({super.key, this.onVerified});

  @override
  State<StepEmailVerification> createState() => _StepEmailVerificationState();
}

class _StepEmailVerificationState extends State<StepEmailVerification> {
  User? user = FirebaseAuth.instance.currentUser;
  bool _isSent = false;
  bool _isVerified = false;
  bool _isLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // 1. Initial check: Is the user already verified in Firebase Auth?
    _isVerified = user?.emailVerified ?? false;
    if (_isVerified) {
      _updateFirestoreAndFinish();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- LOGIC: SYNC WITH DB AND RETURN TO HUB ---
  Future<void> _updateFirestoreAndFinish() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        // Sync the verification status to Firestore so the Hub Controller sees it
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'email_verified': true,
        });

        if (mounted) {
          setState(() => _isVerified = true);
          
          // Trigger optional callback if provided
          widget.onVerified?.call();

          // Return to the Hub after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context);
          });
        }
      } catch (e) {
        debugPrint("Firestore update error: $e");
      }
    }
  }

  // --- LOGIC: POLL FIREBASE FOR STATUS CHANGE ---
  Future<void> _checkEmailStatus() async {
    try {
      // Reload is required to refresh the 'emailVerified' boolean from the server
      await user?.reload(); 
      user = FirebaseAuth.instance.currentUser;

      if (user != null && user!.emailVerified) {
        _timer?.cancel();
        await _updateFirestoreAndFinish(); 
      }
    } catch (e) {
      debugPrint("Status check failed: $e");
    }
  }

  // --- LOGIC: SEND VERIFICATION EMAIL ---
  Future<void> _sendVerificationLink() async {
    setState(() => _isLoading = true);
    try {
      await user?.sendEmailVerification();
      setState(() {
        _isSent = true;
        _isLoading = false;
      });

      // Start checking for verification status every 5 seconds
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 5), (t) => _checkEmailStatus());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Verification link sent! Check your inbox.")),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String msg = "Check your internet connection.";
      if (e.code == 'too-many-requests') msg = "Too many requests. Try again later.";
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $msg"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF11A860);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 0, 
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            const Text(
              "Verify Your Email",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2B5145)),
            ),
            const SizedBox(height: 15),
            const Text(
              "We've sent a link to your email. Please click it to continue your driver registration.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const Spacer(),
            
            // Visual feedback Icon
            Icon(
              _isVerified ? Icons.verified : (_isSent ? Icons.mark_email_read : Icons.email_outlined),
              size: 100,
              color: _isVerified ? primaryGreen : Colors.orange,
            ),
            
            const SizedBox(height: 20),
            Text(
              user?.email ?? "No email found", 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
            ),
            
            if (_isSent && !_isVerified) ...[
              const SizedBox(height: 30),
              const CircularProgressIndicator(),
              const SizedBox(height: 10),
              const Text("Checking verification status...", style: TextStyle(fontStyle: FontStyle.italic)),
            ],
            
            const Spacer(),

            if (!_isVerified)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : (_isSent ? _checkEmailStatus : _sendVerificationLink),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_isSent ? "I HAVE CLICKED THE LINK" : "SEND VERIFICATION LINK", 
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  if (_isSent)
                    TextButton(
                      onPressed: _sendVerificationLink,
                      child: const Text("Resend Email", style: TextStyle(color: Colors.grey)),
                    ),
                ],
              )
            else
              Text("Email Verified! Returning to checklist...", 
                style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}