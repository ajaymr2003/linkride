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

  Future<void> _updateUserAverageRating(String userId) async {
    final reviewsQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reviews_received')
        .get();

    if (reviewsQuery.docs.isNotEmpty) {
      double totalRating = 0;
      for (var doc in reviewsQuery.docs) {
        totalRating += (doc.data()['rating'] as num).toDouble();
      }
      double average = totalRating / reviewsQuery.docs.length;

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'rating': double.parse(average.toStringAsFixed(1)),
        'total_reviews': reviewsQuery.docs.length,
      });
    }
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final String driverUid = FirebaseAuth.instance.currentUser!.uid;
    final String comment = _commentController.text.trim();

    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Prepare Review Data
      Map<String, dynamic> reviewData = {
        'rating': _rating,
        'comment': comment,
        'reviewer_id': driverUid,
        'target_id': widget.passengerUid,
        'ride_id': widget.rideId,
        'type': 'passenger_review',
        'timestamp': FieldValue.serverTimestamp(),
      };

      // 2. Global collection entry
      DocumentReference globalRef = FirebaseFirestore.instance.collection('reviews').doc();
      batch.set(globalRef, reviewData);

      // 3. Passenger sub-collection entry
      DocumentReference userSubRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.passengerUid)
          .collection('reviews_received')
          .doc(globalRef.id);
      batch.set(userSubRef, reviewData);

      // --- NEW: UPDATE BOOKING STATUS ---
      var bookingQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('ride_id', isEqualTo: widget.rideId)
          .where('passenger_uid', isEqualTo: widget.passengerUid)
          .limit(1)
          .get();

      if (bookingQuery.docs.isNotEmpty) {
        batch.update(bookingQuery.docs.first.reference, {
          'status': 'completed',
          'completed_at': FieldValue.serverTimestamp(),
        });
      }

      // Execute all updates
      await batch.commit();

      // 4. Update Passenger profile rating stats
      await _updateUserAverageRating(widget.passengerUid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Review submitted successfully!")),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error submitting review.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Rate Passenger"), 
        elevation: 0,
        automaticallyImplyLeading: false, 
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