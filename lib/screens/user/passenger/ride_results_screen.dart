import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

// Import the edit steps
import 'step_1_source.dart';
import 'step_2_destination.dart';
import 'step_3_details.dart';

// Import the new Ride View Screen
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
  // Current search parameters (mutable so we can edit them)
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

  // --- SHOW EDIT BOX (Bottom Sheet) ---
  void _showEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Edit Search", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              _editRow("From", _source['name'], Icons.circle_outlined, () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerStepSource()));
                if (res != null) {
                  setModalState(() => _source = res);
                  setState(() => _source = res);
                }
              }),
              
              _editRow("To", _destination['name'], Icons.location_on, () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerStepDestination()));
                if (res != null) {
                  setModalState(() => _destination = res);
                  setState(() => _destination = res);
                }
              }),
              
              _editRow("Date & Seats", "${DateFormat('dd MMM').format(_date)} • $_passengers", Icons.tune, () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerStepDetails(initialDate: _date, initialPassengers: _passengers)));
                if (res != null) {
                  setModalState(() {
                    _date = res['date'];
                    _passengers = res['passengers'];
                  });
                  setState(() {
                    _date = res['date'];
                    _passengers = res['passengers'];
                  });
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
              const SizedBox(height: 10),
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
    // Determine start and end of the selected day for Firestore query
    DateTime startOfDay = DateTime(_date.year, _date.month, _date.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // --- TOP SEARCH BOX (Header) ---
            Padding(
              padding: const EdgeInsets.all(15),
              child: GestureDetector(
                onTap: _showEditSheet,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${_source['name']} → ${_destination['name']}", 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                            Text("${DateFormat('dd MMM').format(_date)} • $_passengers Passengers", 
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Icon(Icons.tune, color: primaryGreen, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            // --- RIDES LIST ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rides')
                    .where('status', isEqualTo: 'active')
                    .where('departure_time', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
                    .where('departure_time', isLessThan: Timestamp.fromDate(endOfDay))
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmpty();
                  }
                  
                  var rides = snapshot.data!.docs;
                  
                  // --- CLIENT SIDE FILTERING ---
                  // 1. Check seat count
                  // 2. Check geolocation distance (within 20km radius for Source and Dest)
                  var filtered = rides.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    
                    // Filter 1: Seats
                    if ((data['available_seats'] ?? 0) < _passengers) return false;
                    
                    // Filter 2: Location Distance
                    try {
                      double dS = Geolocator.distanceBetween(
                        _source['lat'], 
                        _source['lng'], 
                        data['source']['lat'], 
                        data['source']['lng']
                      );
                      
                      double dD = Geolocator.distanceBetween(
                        _destination['lat'], 
                        _destination['lng'], 
                        data['destination']['lat'], 
                        data['destination']['lng']
                      );

                      // 20km Radius buffer
                      return dS <= 20000 && dD <= 20000;
                    } catch (e) { 
                      return false; 
                    }
                  }).toList();

                  if (filtered.isEmpty) return _buildEmpty();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      var doc = filtered[index];
                      return _buildRideCard(doc.data() as Map<String, dynamic>, doc.id);
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

  Widget _buildRideCard(Map<String, dynamic> data, String docId) {
    DateTime dep = (data['departure_time'] as Timestamp).toDate();

    return GestureDetector(
      onTap: () {
        // NAVIGATE TO RIDE VIEW SCREEN
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RideViewScreen(
              rideId: docId, 
              rideData: data
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: [
            // Time and Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('h:mm a').format(dep), 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkGreen)
                ),
                Text(
                  "₹${data['price_per_seat']}", 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)
                ),
              ],
            ),
            const SizedBox(height: 15),
            
            // Route Graphic
            Row(
              children: [
                Column(
                  children: [
                    Icon(Icons.circle_outlined, size: 12, color: primaryGreen), 
                    Container(height: 20, width: 2, color: Colors.grey[200]), 
                    Icon(Icons.location_on, size: 12, color: primaryGreen)
                  ]
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['source']['name'], 
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis
                      ),
                      const SizedBox(height: 15),
                      Text(
                        data['destination']['name'], 
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis
                      ),
                    ]
                  ),
                ),
              ],
            ),
            
            const Divider(height: 30),
            
            // Driver and Seats Footer
            Row(
              children: [
                // --- DRIVER NAME ---
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(data['driver_uid']).get(),
                  builder: (context, snap) {
                    String name = "Driver";
                    String? profilePic;
                    
                    if (snap.hasData && snap.data!.exists) {
                      var driverData = snap.data!.data() as Map<String, dynamic>;
                      name = driverData['name'] ?? "Driver";
                      profilePic = driverData['profile_pic'];
                    }
                    
                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 12, 
                          backgroundImage: profilePic != null ? NetworkImage(profilePic) : null,
                          backgroundColor: Colors.grey[200],
                          child: profilePic == null ? const Icon(Icons.person, size: 14) : null,
                        ),
                        const SizedBox(width: 8),
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ]
                    );
                  },
                ),
                const Spacer(),
                Text(
                  "${data['available_seats']} seats left", 
                  style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined, size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text("No rides found", style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 5),
          const Text("Try changing the date or location", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}