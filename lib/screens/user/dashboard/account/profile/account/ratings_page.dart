import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RatingsPage extends StatelessWidget {
  const RatingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("My Ratings"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          var userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          double avgRating = (userData['rating'] ?? 0.0).toDouble();
          int totalReviews = userData['total_reviews'] ?? 0;

          return Column(
            children: [
              // --- 1. RATING SUMMARY HEADER ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
                color: Colors.white,
                child: Column(
                  children: [
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return Icon(
                          index < avgRating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                          size: 30,
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Based on $totalReviews reviews",
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // --- 2. INDIVIDUAL REVIEWS LIST ---
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user?.uid)
                      .collection('reviews_received')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var review = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        return _buildReviewCard(review);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> data) {
    DateTime date = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    int starCount = data['rating'] ?? 5;
    String reviewerId = data['reviewer_id'] ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row for Stars and Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (i) => Icon(
                  Icons.star_rounded, 
                  size: 16, 
                  color: i < starCount ? Colors.amber : Colors.grey.shade200
                )),
              ),
              Text(
                DateFormat('MMM dd, yyyy').format(date),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reviewer Info Section (Fetching Name)
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(reviewerId).get(),
            builder: (context, userSnap) {
              String name = "User";
              String? pic;

              if (userSnap.hasData && userSnap.data!.exists) {
                var uData = userSnap.data!.data() as Map<String, dynamic>;
                name = uData['name'] ?? "User";
                pic = uData['profile_pic'];
              }

              return Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.grey.shade100,
                    backgroundImage: pic != null ? NetworkImage(pic) : null,
                    child: pic == null ? const Icon(Icons.person, size: 12, color: Colors.grey) : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 10),

          // Comment Section
          Text(
            data['comment'] != null && data['comment'].toString().isNotEmpty
                ? "\"${data['comment']}\""
                : "No comment provided.",
            style: const TextStyle(
              fontSize: 14, 
              fontStyle: FontStyle.italic,
              color: Colors.black54,
              height: 1.4
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          const Text(
            "No reviews yet",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const Text(
            "Ratings from your co-travelers will appear here.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}