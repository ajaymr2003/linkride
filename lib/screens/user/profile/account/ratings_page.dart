import 'package:flutter/material.dart';

class RatingsPage extends StatelessWidget {
  const RatingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF11A860);
    const darkGreen = Color(0xFF2B5145);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Ratings"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            labelColor: primaryGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryGreen,
            tabs: [
              Tab(text: "Received"),
              Tab(text: "Given"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Received Ratings
            _buildRatingList(isReceived: true),

            // Tab 2: Given Ratings
            _buildRatingList(isReceived: false),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingList({required bool isReceived}) {
    // Placeholder logic. Later you can wrap this in a StreamBuilder to fetch real ratings from Firestore.
    // collection('users').doc(uid).collection('reviews_received') 
    // vs collection('users').doc(uid).collection('reviews_given')

    bool hasRatings = false; // Set to true to test the list view

    if (!hasRatings) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isReceived ? Icons.star_border : Icons.rate_review_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              isReceived ? "No ratings received yet" : "No ratings given yet",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 10),
            Text(
              isReceived 
                ? "Ratings you receive from other members will appear here." 
                : "Ratings you leave for other members will appear here.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Example List Item if data existed
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: const Text("John Doe", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Great passenger, very punctual!"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text("5.0", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF11A860))),
                  Icon(Icons.star, size: 16, color: Color(0xFF11A860)),
                ],
              ),
            ),
            const Divider(),
          ],
        );
      },
    );
  }
}