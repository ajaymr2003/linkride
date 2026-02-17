import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added for UID check
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'step_1_source.dart';
import 'step_2_destination.dart';
import 'step_3_details.dart';
import 'ride_view_screen.dart'; 

class RideResultsScreen extends StatefulWidget {
  final Map<String, dynamic> source;
  final Map<String, dynamic> destination;
  final DateTime date;
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
  late Map<String, dynamic> _source;
  late Map<String, dynamic> _destination;
  late DateTime _date;
  late int _passengers;

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  @override
  void initState() {
    super.initState();
    _source = widget.source;
    _destination = widget.destination;
    _date = widget.date;
    _passengers = widget.passengers;
  }

  // --- UI HELPER FOR THE EDIT SHEET (NO CHANGES HERE) ---
  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Edit Search", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _editRow("From", _source['name'], Icons.circle_outlined, () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerStepSource()));
                if (res != null) { setModalState(() => _source = res); setState(() => _source = res); }
              }),
              _editRow("To", _destination['name'], Icons.location_on, () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerStepDestination()));
                if (res != null) { setModalState(() => _destination = res); setState(() => _destination = res); }
              }),
              _editRow("Date & Seats", "${DateFormat('dd MMM').format(_date)} • $_passengers", Icons.tune, () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerStepDetails(initialDate: _date, initialPassengers: _passengers)));
                if (res != null) {
                  setModalState(() { _date = res['date']; _passengers = res['passengers']; });
                  setState(() { _date = res['date']; _passengers = res['passengers']; });
                }
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("SEE UPDATED RIDES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editRow(String label, String value, IconData icon, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: primaryGreen),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    DateTime now = DateTime.now();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER SEARCH BOX ---
            Padding(
              padding: const EdgeInsets.all(15),
              child: GestureDetector(
                onTap: _showEditSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${_source['name']} → ${_destination['name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                            Text("${DateFormat('dd MMM').format(_date)} • $_passengers Passengers", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Icon(Icons.tune, color: primaryGreen, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            // --- RIDES LIST (Nested StreamBuilders) ---
            Expanded(
              // 1. GET USER'S EXISTING BOOKINGS FIRST
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('bookings')
                    .where('passenger_uid', isEqualTo: user?.uid)
                    .snapshots(),
                builder: (context, bookingSnapshot) {
                  // Create a Map of rideId -> status for quick lookup
                  Map<String, String> userBookings = {};
                  if (bookingSnapshot.hasData) {
                    for (var doc in bookingSnapshot.data!.docs) {
                      userBookings[doc['ride_id']] = doc['status'];
                    }
                  }

                  // 2. FETCH AVAILABLE RIDES
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('rides')
                        .where('status', isEqualTo: 'active')
                        .where('departure_time', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
                        .snapshots(),
                    builder: (context, rideSnapshot) {
                      if (rideSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!rideSnapshot.hasData || rideSnapshot.data!.docs.isEmpty) return _buildEmpty();

                      // Filtering logic (Radius + Seats)
                      var allAvailableRides = rideSnapshot.data!.docs.where((doc) {
                        var data = doc.data() as Map<String, dynamic>;
                        if ((data['available_seats'] ?? 0) < _passengers) return false;
                        try {
                          double dS = Geolocator.distanceBetween(_source['lat'], _source['lng'], data['source']['lat'], data['source']['lng']);
                          double dD = Geolocator.distanceBetween(_destination['lat'], _destination['lng'], data['destination']['lat'], data['destination']['lng']);
                          return dS <= 20000 && dD <= 20000;
                        } catch (e) { return false; }
                      }).toList();

                      // Categorize Rides
                      List<QueryDocumentSnapshot> exactRides = [];
                      List<QueryDocumentSnapshot> otherRides = [];

                      for (var ride in allAvailableRides) {
                        DateTime rideDate = (ride['departure_time'] as Timestamp).toDate();
                        if (rideDate.year == _date.year && rideDate.month == _date.month && rideDate.day == _date.day) {
                          exactRides.add(ride);
                        } else {
                          otherRides.add(ride);
                        }
                      }

                      exactRides.sort((a, b) => (a['departure_time'] as Timestamp).compareTo(b['departure_time']));
                      otherRides.sort((a, b) => (a['departure_time'] as Timestamp).compareTo(b['departure_time']));

                      if (exactRides.isEmpty && otherRides.isEmpty) return _buildEmpty();

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        children: [
                          if (exactRides.isNotEmpty) ...[
                            _buildSectionHeader("Rides on ${DateFormat('EEEE, d MMM').format(_date)}"),
                            ...exactRides.map((doc) {
                              // CHECK IF BOOKED
                              String? status = userBookings[doc.id];
                              return _buildRideCard(doc.data() as Map<String, dynamic>, doc.id, bookingStatus: status);
                            }).toList(),
                          ],

                          if (otherRides.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _buildSectionHeader("Available on other dates"),
                            ...otherRides.map((doc) {
                              String? status = userBookings[doc.id];
                              return _buildRideCard(doc.data() as Map<String, dynamic>, doc.id, showFullDate: true, bookingStatus: status);
                            }).toList(),
                          ],
                          const SizedBox(height: 30),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5),
      child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
    );
  }

  Widget _buildRideCard(Map<String, dynamic> data, String docId, {bool showFullDate = false, String? bookingStatus}) {
    DateTime dep = (data['departure_time'] as Timestamp).toDate();
    bool isBooked = bookingStatus != null;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideViewScreen(rideId: docId, rideData: data))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(15), 
          border: isBooked ? Border.all(color: primaryGreen.withOpacity(0.5), width: 2) : null,
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)]
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('h:mm a').format(dep), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkGreen)),
                    if (showFullDate)
                      Text(DateFormat('EEE, d MMM').format(dep), style: TextStyle(fontSize: 12, color: primaryGreen, fontWeight: FontWeight.bold)),
                  ],
                ),
                // --- PRICE OR STATUS BADGE ---
                if (isBooked)
                   _statusBadge(bookingStatus!)
                else
                   Text("₹${data['price_per_seat']}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Column(children: [Icon(Icons.circle_outlined, size: 12, color: primaryGreen), Container(height: 20, width: 2, color: Colors.grey[200]), Icon(Icons.location_on, size: 12, color: primaryGreen)]),
                const SizedBox(width: 15),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['source']['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 15), Text(data['destination']['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)])),
              ],
            ),
            const Divider(height: 30),
            Row(
              children: [
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(data['driver_uid']).get(),
                  builder: (context, snap) {
                    String name = "Driver"; String? pic;
                    if (snap.hasData && snap.data!.exists) {
                      var d = snap.data!.data() as Map<String, dynamic>;
                      name = d['name'] ?? "Driver"; pic = d['profile_pic'];
                    }
                    return Row(children: [CircleAvatar(radius: 12, backgroundImage: pic != null ? NetworkImage(pic) : null, backgroundColor: Colors.grey[200], child: pic == null ? const Icon(Icons.person, size: 14) : null), const SizedBox(width: 8), Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))]);
                  },
                ),
                const Spacer(),
                Text("${data['available_seats']} seats left", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    Color color = status == 'accepted' ? Colors.green : Colors.orange;
    String text = status == 'accepted' ? "BOOKED" : "REQUESTED";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.directions_car_outlined, size: 60, color: Colors.grey.shade300), const SizedBox(height: 15), const Text("No rides found on this route", style: TextStyle(color: Colors.grey, fontSize: 16))]));
  }
}