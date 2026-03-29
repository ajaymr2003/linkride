import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'ride_view_screen.dart';

class RideResultsScreen extends StatefulWidget {
  final Map<String, dynamic> source;
  final Map<String, dynamic> destination;
  final DateTime date; // We will now use this correctly
  final int passengers;

  const RideResultsScreen({
    super.key,
    required this.source,
    required this.destination,
    required this.date,
    required this.passengers,
  });

  @override
  State<RideResultsScreen> createState() => _RideResultsScreenState();
}

class _RideResultsScreenState extends State<RideResultsScreen> {
  final Color primaryGreen = const Color(0xFF11A860);
  String _sortBy = 'Earliest'; 

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Sort & Filter", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text("Sort By", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _filterChip("Earliest", _sortBy == 'Earliest', (val) {
                    setState(() => _sortBy = 'Earliest');
                    setModalState(() {});
                  }),
                  const SizedBox(width: 10),
                  _filterChip("Lowest Price", _sortBy == 'Price', (val) {
                    setState(() => _sortBy = 'Price');
                    setModalState(() {});
                  }),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("APPLY FILTERS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected, Function(bool) onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: primaryGreen.withOpacity(0.2),
      labelStyle: TextStyle(color: isSelected ? primaryGreen : Colors.black, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";

    // Calculate Start and End of the searched day for the query
    DateTime startOfDay = DateTime(widget.date.year, widget.date.month, widget.date.day);
    DateTime endOfDay = DateTime(widget.date.year, widget.date.month, widget.date.day, 23, 59, 59);

    // If search is for today, adjust start time to 'now'
    if (startOfDay.isBefore(DateTime.now())) {
      startOfDay = DateTime.now();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Matching Rides"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.tune), onPressed: _showFilterSheet),
          const SizedBox(width: 10),
        ],
      ),
      // OUTER STREAM: Get user's existing requests
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('passenger_uid', isEqualTo: currentUid)
            .snapshots(),
        builder: (context, bookingSnapshot) {
          Set<String> requestedRideIds = {};
          if (bookingSnapshot.hasData) {
            for (var doc in bookingSnapshot.data!.docs) {
              requestedRideIds.add(doc['ride_id']);
            }
          }

          // INNER STREAM: Get rides specifically for the searched day
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rides')
                .where('status', isEqualTo: 'active')
                .where('departure_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                .where('departure_time', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
                .snapshots(),
            builder: (context, rideSnapshot) {
              if (rideSnapshot.connectionState == ConnectionState.waiting) 
                return const Center(child: CircularProgressIndicator());

              if (!rideSnapshot.hasData || rideSnapshot.data!.docs.isEmpty) 
                return const Center(child: Text("No rides scheduled for this day."));

              // FILTER BY LOCATION RADIUS (10km)
              var filteredRides = rideSnapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                if ((data['available_seats'] ?? 0) < widget.passengers) return false;

                List path = data['path_points'] ?? [];
                if (path.isEmpty) return false;

                bool pickupMatch = false;
                int pickupIdx = -1;
                for (int i = 0; i < path.length; i++) {
                  double dist = Geolocator.distanceBetween(widget.source['lat'], widget.source['lng'], path[i]['lat'], path[i]['lng']);
                  if (dist <= 10000) { pickupMatch = true; pickupIdx = i; break; }
                }
                if (!pickupMatch) return false;

                bool dropMatch = false;
                for (int j = pickupIdx; j < path.length; j++) {
                  double dist = Geolocator.distanceBetween(widget.destination['lat'], widget.destination['lng'], path[j]['lat'], path[j]['lng']);
                  if (dist <= 10000) { dropMatch = true; break; }
                }
                return dropMatch;
              }).toList();

              // SORTING
              if (_sortBy == 'Earliest') {
                filteredRides.sort((a, b) => (a['departure_time'] as Timestamp).compareTo(b['departure_time'] as Timestamp));
              } else if (_sortBy == 'Price') {
                filteredRides.sort((a, b) => (a['price_per_seat'] as num).compareTo(b['price_per_seat'] as num));
              }

              if (filteredRides.isEmpty) return const Center(child: Text("No rides found on this route."));

              return ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: filteredRides.length,
                itemBuilder: (context, index) {
                  var doc = filteredRides[index];
                  var data = doc.data() as Map<String, dynamic>;
                  DateTime dep = (data['departure_time'] as Timestamp).toDate();
                  
                  bool isOwnRide = data['driver_uid'] == currentUid;
                  bool isAlreadyRequested = requestedRideIds.contains(doc.id);

                  final dynamic rawPrice = data['price_per_seat'] ?? 0;
                  final String priceDisplay = rawPrice == 0 ? "FREE" : "₹0 - ₹$rawPrice";

                  return GestureDetector(
                    onTap: isOwnRide ? () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You cannot book your own ride")));
                    } : () => Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (_) => RideViewScreen(
                          rideId: doc.id, 
                          rideData: data,
                          passengerSource: widget.source,
                          passengerDestination: widget.destination,
                        )
                      )
                    ),
                    child: Opacity(
                      opacity: isOwnRide ? 0.7 : 1.0,
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: (isAlreadyRequested || isOwnRide) 
                              ? BorderSide(color: isAlreadyRequested ? Colors.orange : primaryGreen, width: 2) 
                              : BorderSide.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                                children: [
                                  Text(DateFormat('h:mm a').format(dep), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(priceDisplay, style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                                      if (isOwnRide)
                                        Text("YOUR RIDE", style: TextStyle(color: primaryGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                                      if (isAlreadyRequested && !isOwnRide)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(5)),
                                          child: const Text("REQUESTED", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                              ]),
                              const SizedBox(height: 15),
                              
                              // Location Section
                              Row(children: [const Icon(Icons.circle, size: 10, color: Colors.grey), const SizedBox(width: 10), Expanded(child: Text(data['source']['name'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)))]),
                              Align(alignment: Alignment.centerLeft, child: Container(margin: const EdgeInsets.only(left: 4), height: 10, width: 1, color: Colors.grey.shade300)),
                              Row(children: [const Icon(Icons.location_on, size: 12, color: Colors.red), const SizedBox(width: 10), Expanded(child: Text(data['destination']['name'], overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)))]),
                              
                              const Divider(height: 25),
                              
                              // Footer: Seats + Driver Info
                              Row(
                                children: [
                                  const Icon(Icons.airline_seat_recline_normal, size: 16, color: Colors.orange),
                                  const SizedBox(width: 5),
                                  Text("${data['available_seats']} seats left", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                                  const Spacer(),
                                  // Fetching Driver Name quickly
                                  FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance.collection('users').doc(data['driver_uid']).get(),
                                    builder: (context, userSnap) {
                                      String dName = userSnap.hasData ? (userSnap.data!['name'] ?? "Driver").split(' ')[0] : "...";
                                      return Text("Driver: $dName", style: const TextStyle(fontSize: 11, color: Colors.grey));
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}