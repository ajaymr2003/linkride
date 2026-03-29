import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class RideDetailsView extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDriverView;

  const RideDetailsView({super.key, required this.data, required this.isDriverView});

  @override
  Widget build(BuildContext context) {
    final Color primaryGreen = const Color(0xFF11A860);
    final Color darkGreen = const Color(0xFF2B5145);
    final String currentUid = FirebaseAuth.instance.currentUser!.uid;

    // Handle rideId regardless of whether data comes from 'bookings' or 'rides' collection
    final String rideId = data['ride_id'] ?? ""; 

    final Timestamp ts = data['ride_date'] ?? data['departure_time'] ?? Timestamp.now();
    final DateTime dt = ts.toDate();
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Trip Summary", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        // Fetch the actual ride document to get the passenger-specific fare
        future: FirebaseFirestore.instance.collection('rides').doc(rideId).get(),
        builder: (context, rideSnap) {
          // --- FARE CALCULATION LOGIC ---
          // 1. Default to what's in the 'data' map passed to this widget
          dynamic displayFare = data['price'] ?? data['price_per_seat'] ?? "0";

          // 2. If the ride document exists, try to get the specific 'fare' from passenger_routes
          if (rideSnap.hasData && rideSnap.data!.exists) {
            var rideDocData = rideSnap.data!.data() as Map<String, dynamic>;
            var routes = rideDocData['passenger_routes'] ?? {};
            
            // Determine whose fare we are looking for
            // If Driver is looking, we need the fare of the passenger mentioned in the booking
            // If Passenger is looking, we need their own fare
            String targetPassengerUid = isDriverView 
                ? (data['passenger_uid'] ?? "") 
                : currentUid;

            if (routes.containsKey(targetPassengerUid)) {
              displayFare = routes[targetPassengerUid]['fare'] ?? displayFare;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. STATUS HEADER
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: primaryGreen),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Trip details for ${DateFormat('EEE, MMM dd, yyyy').format(dt)}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: darkGreen),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 35),

                // 2. ROUTE INFO
                const Text("ROUTE DETAILS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 20),
                _routeRow(Icons.radio_button_checked, data['source']['name'] ?? "Start", Colors.blue),
                _routeDivider(),
                _routeRow(Icons.location_on, data['destination']['name'] ?? "End", Colors.red),
                
                const SizedBox(height: 40),

                // 3. TIME AND COST
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _infoBlock("DEPARTURE TIME", DateFormat('hh:mm a').format(dt)),
                    // Corrected Fare display using the logic calculated above
                    _infoBlock("TOTAL FARE", "₹$displayFare"),
                  ],
                ),

                const Divider(height: 60),

                // 4. FEEDBACK SECTION
                const Text("YOUR FEEDBACK", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 15),
                _buildReviewStream(rideId, currentUid, primaryGreen),

                const Divider(height: 60),

                // 5. COUNTER-PARTY INFO
                Text(isDriverView ? "PASSENGER DETAILS" : "DRIVER DETAILS", 
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 20),
                
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(isDriverView ? data['passenger_uid'] : data['driver_uid'])
                      .get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                    
                    var userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                    String name = userData['name'] ?? "User";
                    String? pic = userData['profile_pic'];

                    return Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(15)
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: pic != null ? NetworkImage(pic) : null,
                            child: pic == null ? const Icon(Icons.person) : null,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Colors.amber, size: 14),
                                    const SizedBox(width: 4),
                                    Text("${userData['rating'] ?? 'New'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 50),
              ],
            ),
          );
        },
      ),
    );
  }

  // HELPER TO FETCH REVIEW
  Widget _buildReviewStream(String rId, String uId, Color color) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reviews')
          .where('ride_id', isEqualTo: rId)
          .where('reviewer_id', isEqualTo: uId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text("No feedback given for this trip.", style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic));
        }

        var review = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        int rating = review['rating'] ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(5, (index) => Icon(
                index < rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 20,
              )),
            ),
            const SizedBox(height: 10),
            if (review['comment'] != null && review['comment'].isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200)
                ),
                child: Text(
                  "\"${review['comment']}\"",
                  style: const TextStyle(fontSize: 14, color: Colors.black87, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _routeRow(IconData icon, String text, Color color) {
    return Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 15), Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)))]);
  }

  Widget _routeDivider() {
    return Container(margin: const EdgeInsets.only(left: 8), height: 25, width: 1.5, color: Colors.grey.shade200);
  }

  Widget _infoBlock(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    ]);
  }
}