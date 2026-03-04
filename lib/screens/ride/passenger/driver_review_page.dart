import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverReviewPage extends StatefulWidget {
  final String driverUid;
  final String driverName;
  final String rideId;

  const DriverReviewPage({
    super.key,
    required this.driverUid,
    required this.driverName,
    required this.rideId,
  });

  @override
  State<DriverReviewPage> createState() => _DriverReviewPageState();
}

class _DriverReviewPageState extends State<DriverReviewPage> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  final Color primaryGreen = const Color(0xFF11A860);

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);
    final String passengerUid = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.driverUid)
          .collection('reviews_received')
          .add({
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'reviewer_id': passengerUid,
        'ride_id': widget.rideId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Feedback submitted!")));
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error submitting review.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Rate your Driver"), elevation: 0, automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const CircleAvatar(radius: 45, backgroundColor: Color(0xFFF1F1F1), child: Icon(Icons.drive_eta, size: 50, color: Colors.grey)),
            const SizedBox(height: 20),
            Text("How was your trip with ${widget.driverName}?", textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(index < _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 50),
                  onPressed: () => setState(() => _rating = index + 1),
                );
              }),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Describe your experience...", 
                filled: true, 
                fillColor: const Color(0xFFF9F9F9), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade100)),
              ),
            ),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: _isSubmitting ? null : _submitReview,
                child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text("SUBMIT FEEDBACK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            TextButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), child: const Text("Skip", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }
}