import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../driver/ride_steps/edit_ride_page.dart';

class RidesPage extends StatefulWidget {
  const RidesPage({super.key});

  @override
  State<RidesPage> createState() => _RidesPageState();
}

class _RidesPageState extends State<RidesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _appBarTitle = "Passenger Activity"; // Default title
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  void initState() {
    super.initState();
    // length 2 for the two tabs
    _tabController = TabController(length: 2, vsync: this);

    // Listener to change the AppBar Title when tabs are switched
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _appBarTitle = _tabController.index == 0 
              ? "Passenger Activity" 
              : "Driver Activity";
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- DELETE LOGIC (For Driver's own rides) ---
  Future<void> _deleteRide(BuildContext context, String docId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Ride?"),
        content: const Text("Are you sure you want to delete this ride offer? All passengers will be notified."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Yes, Cancel", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      await FirebaseFirestore.instance.collection('rides').doc(docId).delete();
    }
  }

  // --- HELPER: GET LOCATION NAME ---
  String _getLocationName(dynamic locationData) {
    if (locationData == null) return "Unknown";
    if (locationData is String) return locationData;
    if (locationData is Map<String, dynamic>) {
      return locationData['name'] ?? "Unknown Location";
    }
    return "Unknown";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(_appBarTitle, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController, // Added custom controller
          labelColor: primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryGreen,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Booked Trips"), // Passenger Role
            Tab(text: "Offered Rides"), // Driver Role
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController, // Added custom controller
        children: [
          _buildPassengerRideList(),
          _buildDriverRideList(),
        ],
      ),
    );
  }

  // --- TAB 1: PASSENGER RIDES ---
  Widget _buildPassengerRideList() {
    final user = FirebaseAuth.instance.currentUser;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('passenger_uid', isEqualTo: user?.uid)
          .orderBy('created_at', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(Icons.directions_walk, "No bookings yet", "Rides you join will appear here.");
        }
        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _buildPassengerCard(data);
          },
        );
      },
    );
  }

  // --- TAB 2: DRIVER RIDES (WITH REQUESTS AT TOP) ---
  Widget _buildDriverRideList() {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      children: [
        // 1. TOP WIDGET: PENDING REQUESTS
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .where('driver_uid', isEqualTo: user?.uid)
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              color: Colors.orange.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notification_important, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text("Booking Requests (${snapshot.data!.docs.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        return _buildRequestSmallCard(context, doc.id, doc.data() as Map<String, dynamic>);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // 2. LIST: OFFERED RIDES
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('rides')
                .where('driver_uid', isEqualTo: user?.uid)
                .orderBy('departure_time', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(Icons.drive_eta, "No offered rides", "Rides you publish will appear here.");
              }
              return ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  return _buildDriverCard(context, doc.id, doc.data() as Map<String, dynamic>);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- LOGIC: UPDATE STATUS ---
  Future<void> _updateRequestStatus(BuildContext context, String bookingId, String rideId, String status) async {
    Navigator.pop(context);
    try {
      if (status == 'accepted') {
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          DocumentReference rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
          DocumentSnapshot rideSnap = await transaction.get(rideRef);
          if (!rideSnap.exists) throw "Ride does not exist";
          int available = rideSnap['available_seats'] ?? 0;
          if (available < 1) throw "No seats available";
          transaction.update(rideRef, {'available_seats': available - 1});
          transaction.update(FirebaseFirestore.instance.collection('bookings').doc(bookingId), {'status': 'accepted'});
        });
      } else {
        await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({'status': 'rejected'});
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request $status")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  // --- UI: REQUEST SMALL CARD ---
  Widget _buildRequestSmallCard(BuildContext context, String bookingId, Map<String, dynamic> data) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(data['passenger_uid']).get(),
      builder: (context, snapshot) {
        String name = "Loading...";
        String? pic;
        if (snapshot.hasData && snapshot.data!.exists) {
          var user = snapshot.data!.data() as Map<String, dynamic>;
          name = user['name'] ?? "User";
          pic = user['profile_pic'];
        }
        return GestureDetector(
          onTap: () => _showRequestDetailSheet(context, bookingId, data, name, pic),
          child: Container(
            width: 150, margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade200)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(radius: 15, backgroundImage: pic != null ? NetworkImage(pic) : null),
                const SizedBox(height: 5),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                Text("To ${_getLocationName(data['destination'])}", style: const TextStyle(fontSize: 10, color: Colors.grey), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- UI: REQUEST DETAIL SHEET ---
  void _showRequestDetailSheet(BuildContext context, String bookingId, Map<String, dynamic> data, String name, String? pic) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Booking Request", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: CircleAvatar(radius: 30, backgroundImage: pic != null ? NetworkImage(pic) : null),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: const Text("Verified Passenger"),
            ),
            const Divider(),
            _locationRow(Icons.circle_outlined, _getLocationName(data['source']), Colors.grey),
            _locationRow(Icons.location_on, _getLocationName(data['destination']), primaryGreen),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => _updateRequestStatus(context, bookingId, data['ride_id'], 'rejected'), child: const Text("Reject", style: TextStyle(color: Colors.red)))),
                const SizedBox(width: 15),
                Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: primaryGreen), onPressed: () => _updateRequestStatus(context, bookingId, data['ride_id'], 'accepted'), child: const Text("Accept Request", style: TextStyle(color: Colors.white)))),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- UI: CARD DESIGNS ---
  Widget _buildPassengerCard(Map<String, dynamic> data) {
    DateTime dt = (data['ride_date'] as Timestamp).toDate();
    String status = data['status'] ?? "pending";
    Color statusColor = status == 'accepted' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(DateFormat('EEE, d MMM • h:mm a').format(dt), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            _statusBadge(status.toUpperCase(), statusColor),
          ]),
          const SizedBox(height: 10),
          _locationRow(Icons.circle_outlined, _getLocationName(data['source']), Colors.grey),
          _locationRow(Icons.location_on, _getLocationName(data['destination']), primaryGreen),
          const Divider(),
          Row(children: [const Text("Cost: ", style: TextStyle(color: Colors.grey, fontSize: 13)), Text("₹${data['price']}", style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), if (status == 'accepted') const Text("Confirmed", style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold))]),
        ],
      ),
    );
  }

  Widget _buildDriverCard(BuildContext context, String docId, Map<String, dynamic> data) {
    DateTime dt = (data['departure_time'] as Timestamp).toDate();
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(DateFormat('EEE, d MMM • h:mm a').format(dt), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz, color: Colors.grey),
              onSelected: (val) {
                if (val == 'edit') Navigator.push(context, MaterialPageRoute(builder: (_) => EditRidePage(docId: docId, initialData: data)));
                if (val == 'delete') _deleteRide(context, docId);
              },
              itemBuilder: (ctx) => [const PopupMenuItem(value: 'edit', child: Text("Edit Ride")), const PopupMenuItem(value: 'delete', child: Text("Cancel Ride", style: TextStyle(color: Colors.red)))],
            ),
          ]),
          _locationRow(Icons.circle_outlined, _getLocationName(data['source']), Colors.grey),
          _locationRow(Icons.location_on, _getLocationName(data['destination']), primaryGreen),
          const Divider(),
          Row(children: [const Icon(Icons.people, size: 16, color: Colors.grey), const SizedBox(width: 5), Text("${data['available_seats']} seats left", style: const TextStyle(fontSize: 12)), const Spacer(), Text("₹${data['price_per_seat']}", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold))]),
        ],
      ),
    );
  }

  // --- UTILS ---
  Widget _locationRow(IconData icon, String text, Color color) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis))]));
  }

  Widget _statusBadge(String text, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5)), child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  Widget _buildEmptyState(IconData icon, String title, String sub) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 70, color: Colors.grey.shade300), const SizedBox(height: 15), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)), Text(sub, style: const TextStyle(color: Colors.grey))]));
  }
}