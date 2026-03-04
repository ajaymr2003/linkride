import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PassengerReviewPage extends StatefulWidget {
  final String passengerUid;
  final String passengerName;
  final String rideId;

  const PassengerReviewPage({
    super.key,
    required this.passengerUid,
    required this.passengerName,
    required this.rideId,
  });

  @override
  State<PassengerReviewPage> createState() => _PassengerReviewPageState();
}

class _PassengerReviewPageState extends State<PassengerReviewPage> {
  int _rating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  Future<void> _submitReview() async {
    setState(() => _isSubmitting = true);
    final String driverUid = FirebaseAuth.instance.currentUser!.uid;

    try {
      // 1. Save review to the passenger's sub-collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.passengerUid)
          .collection('reviews_received')
          .add({
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'reviewer_id': driverUid,
        'reviewer_name': "Driver", // Optional: fetch driver name if needed
        'ride_id': widget.rideId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Update the passenger's average rating (Optional but recommended)
      // For now, we just finish the flow.

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Review submitted successfully!")),
        );
        // 3. Return to the very first screen (Dashboard)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error submitting review.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Rate Passenger"), 
        elevation: 0,
        automaticallyImplyLeading: false, // Prevent going back to payment
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 45,
              backgroundColor: Color(0xFFF1F1F1),
              child: Icon(Icons.person, size: 50, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Text(
              "How was your ride with ${widget.passengerName}?",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text("Your feedback helps maintain LinkRide safety.", 
              style: TextStyle(color: Colors.grey, fontSize: 13)),
            
            const SizedBox(height: 40),

            // Star Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return GestureDetector(
                  onTap: () => setState(() => _rating = index + 1),
                  child: Icon(
                    index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 50,
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 40),
            
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Write a quick comment about the passenger...",
                filled: true,
                fillColor: const Color(0xFFF9F9F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
            
            const SizedBox(height: 50),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                onPressed: _isSubmitting ? null : _submitReview,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SUBMIT REVIEW",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text("Skip and go Home", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}