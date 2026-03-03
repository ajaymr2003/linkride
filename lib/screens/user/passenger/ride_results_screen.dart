import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'ride_view_screen.dart'; 

class RideResultsScreen extends StatefulWidget {
  final Map<String, dynamic> source;
  final Map<String, dynamic> destination;
  final DateTime date;
  final int passengers;

  const RideResultsScreen({super.key, required this.source, required this.destination, required this.date, required this.passengers});

  @override
  State<RideResultsScreen> createState() => _RideResultsScreenState();
}

class _RideResultsScreenState extends State<RideResultsScreen> {
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text("Matching Rides"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rides')
            .where('status', isEqualTo: 'active')
            .where('departure_time', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var filteredRides = snapshot.data!.docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;

            // --- REMOVED THE SKIP LOGIC TO ALLOW VIEWING OWN RIDE ---

            if ((data['available_seats'] ?? 0) < widget.passengers) return false;

            List path = data['path_points'] ?? [];
            if (path.isEmpty) return false;

            bool pickupMatch = false;
            int pickupIdx = -1;

            for (int i = 0; i < path.length; i++) {
              double dist = Geolocator.distanceBetween(widget.source['lat'], widget.source['lng'], path[i]['lat'], path[i]['lng']);
              if (dist <= 10000) { // 10km radius
                pickupMatch = true;
                pickupIdx = i;
                break;
              }
            }
            if (!pickupMatch) return false;

            bool dropMatch = false;
            for (int j = pickupIdx; j < path.length; j++) {
              double dist = Geolocator.distanceBetween(widget.destination['lat'], widget.destination['lng'], path[j]['lat'], path[j]['lng']);
              if (dist <= 10000) { 
                dropMatch = true;
                break;
              }
            }
            return dropMatch;
          }).toList();

          if (filteredRides.isEmpty) return const Center(child: Text("No rides found on this route."));

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: filteredRides.length,
            itemBuilder: (context, index) {
              var data = filteredRides[index].data() as Map<String, dynamic>;
              DateTime dep = (data['departure_time'] as Timestamp).toDate();
              
              // --- CHECK IF THIS IS THE CURRENT USER'S RIDE ---
              bool isOwnRide = data['driver_uid'] == currentUid;

              return GestureDetector(
                // DISABLE NAVIGATION IF IT IS THE USER'S OWN RIDE
                onTap: isOwnRide ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("You cannot book your own ride"))
                  );
                } : () => Navigator.push(
                  context, 
                  MaterialPageRoute(
                    builder: (_) => RideViewScreen(
                      rideId: filteredRides[index].id, 
                      rideData: data,
                      passengerSource: widget.source,
                      passengerDestination: widget.destination,
                    )
                  )
                ),
                child: Opacity(
                  // Slightly dim the card if it's the driver's own ride
                  opacity: isOwnRide ? 0.7 : 1.0,
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                      // Add a border if it's the driver's own ride
                      side: isOwnRide ? BorderSide(color: primaryGreen, width: 1) : BorderSide.none,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(DateFormat('h:mm a').format(dep), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("₹${data['price_per_seat']}", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                                if (isOwnRide)
                                  Text("YOUR RIDE", style: TextStyle(color: primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [const Icon(Icons.circle, size: 10, color: Colors.grey), const SizedBox(width: 10), Expanded(child: Text(data['source']['name'], overflow: TextOverflow.ellipsis))]),
                          const SizedBox(height: 10),
                          Row(children: [const Icon(Icons.location_on, size: 12, color: Colors.red), const SizedBox(width: 10), Expanded(child: Text(data['destination']['name'], overflow: TextOverflow.ellipsis))]),
                          const Divider(),
                          Row(children: [Text("${data['available_seats']} seats left", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))]),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}