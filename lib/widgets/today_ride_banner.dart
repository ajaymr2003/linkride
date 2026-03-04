import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Driver Screens
import '../screens/ride/driver/ride_summary_page.dart';
import '../screens/ride/driver/driver_live_tracking.dart';
import '../screens/ride/driver/ride_moving_screen.dart';
import '../screens/ride/driver/no_passenger_nav_screen.dart';
// Passenger Screens
import '../screens/ride/passenger/passenger_live_tracking.dart';
import '../screens/ride/passenger/passenger_moving_screen.dart';
import '../screens/ride/passenger/passenger_payment_page.dart';

class TodayRideBanner extends StatelessWidget {
  final String uid;
  const TodayRideBanner({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final endOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day, 23, 59));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rides')
          .where('departure_time', isGreaterThanOrEqualTo: startOfDay)
          .where('departure_time', isLessThanOrEqualTo: endOfDay)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

        // --- ENHANCED FILTERING LOGIC ---
        var myRideDoc = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          bool isDriver = data['driver_uid'] == uid;
          List passengers = data['passengers'] ?? [];
          bool isPassenger = passengers.contains(uid);
          Map<String, dynamic> routes = data['passenger_routes'] ?? {};

          if (isPassenger) {
            // PASSENGER CHECK: Hide if my specific ride_status is 'completed'
            var myRoute = routes[uid] ?? {};
            return myRoute['ride_status'] != 'completed';
          } 
          
          if (isDriver) {
            // DRIVER CHECK: Hide only if ALL passengers have completed the ride
            if (passengers.isEmpty) return true; // Show if no one joined yet
            
            bool anyActivePassenger = false;
            for (var pId in passengers) {
              if (routes[pId] != null && routes[pId]['ride_status'] != 'completed') {
                anyActivePassenger = true;
                break;
              }
            }
            return anyActivePassenger;
          }

          return false;
        }).toList();

        if (myRideDoc.isEmpty) return const SizedBox.shrink();

        var rideData = myRideDoc.first.data() as Map<String, dynamic>;
        var rideId = myRideDoc.first.id;
        bool isDriver = rideData['driver_uid'] == uid;
        bool liveStarted = rideData['live_navigation_pressed'] == true;

        return GestureDetector(
          onTap: () {
            if (isDriver) {
              if (liveStarted) {
                _navigateDriverLive(context, rideId, rideData);
              } else {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (_) => RideSummaryPage(rideId: rideId, rideData: rideData))
                );
              }
            } else {
              _navigatePassengerLive(context, rideId, rideData);
            }
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2B5145), Color(0xFF11A860)]),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Icon(liveStarted ? Icons.navigation : Icons.stars, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        liveStarted ? "Trip is currently Live" : "You have a ride today!",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        liveStarted ? "Tap to return to navigation" : "Tap to open trip details",
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===================== NAVIGATION HELPERS =====================

  void _navigateDriverLive(BuildContext context, String rideId, Map<String, dynamic> rideData) {
    List passengers = rideData['passengers'] ?? [];
    Map<String, dynamic> routes = rideData['passenger_routes'] ?? {};

    // Only consider passengers not marked as 'completed'
    List activePassengers = passengers.where((pId) => routes[pId]?['ride_status'] != 'completed').toList();

    if (activePassengers.isEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => NoPassengerNavScreen(rideId: rideId, rideData: rideData)));
      return;
    }

    bool anyPendingPickup = false;
    for (var pId in activePassengers) {
      if (routes[pId]['ride_status'] != 'security_completed') {
        anyPendingPickup = true;
        break;
      }
    }

    if (anyPendingPickup) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DriverLiveTracking(rideData: rideData, rideId: rideId)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => RideMovingScreen(rideId: rideId, rideData: rideData)));
    }
  }

  void _navigatePassengerLive(BuildContext context, String rideId, Map<String, dynamic> rideData) {
    Map<String, dynamic> routes = rideData['passenger_routes'] ?? {};
    var myRouteData = routes[uid] ?? {};

    if (myRouteData['passenger_destinatin_reached_clicked'] == true) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerPaymentPage(rideId: rideId, rideData: rideData)));
      return;
    }

    if (myRouteData['ride_status'] == 'security_completed') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerMovingScreen(rideId: rideId, rideData: rideData)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerLiveTracking(rideData: rideData, rideId: rideId)));
    }
  }
}