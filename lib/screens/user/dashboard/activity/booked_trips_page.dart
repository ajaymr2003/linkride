import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'ride_details_view.dart';

class BookedTripsPage extends StatefulWidget {
  const BookedTripsPage({super.key});

  @override
  State<BookedTripsPage> createState() => _BookedTripsPageState();
}

class _BookedTripsPageState extends State<BookedTripsPage> {
  bool _showUpcoming = true;
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(15),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              _buildFilterButton("Upcoming", _showUpcoming, () => setState(() => _showUpcoming = true)),
              _buildFilterButton("Completed", !_showUpcoming, () => setState(() => _showUpcoming = false)),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bookings')
                .where('passenger_uid', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState(_showUpcoming);
              }

              return FutureBuilder<List<Map<String, dynamic>>>(
                future: _processBookings(snapshot.data!.docs, user.uid),
                builder: (context, processedSnapshot) {
                  if (!processedSnapshot.hasData) return const SizedBox();

                  var filteredList = processedSnapshot.data!.where((item) {
                    String rideStatus = item['ride_doc_status'] ?? 'active';
                    String bookingStatus = item['status'] ?? 'pending';
                    if (_showUpcoming) {
                      return (bookingStatus == 'pending' || bookingStatus == 'accepted' || bookingStatus == 'ongoing') 
                             && rideStatus != 'completed';
                    } else {
                      return bookingStatus == 'completed' || bookingStatus == 'cancelled' || bookingStatus == 'rejected' || rideStatus == 'completed';
                    }
                  }).toList();

                  if (filteredList.isEmpty) return _buildEmptyState(_showUpcoming);

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      var data = filteredList[index];
                      DateTime dt = (data['ride_date'] as Timestamp).toDate();
                      
                      // MASTER FARE LOGIC
                      dynamic finalFare = data['ride_specific_fare'] ?? data['price'] ?? 0;
                      String method = (data['ride_payment_method'] ?? "cash").toUpperCase();

                      return InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailsView(data: data, isDriverView: false))),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(DateFormat('EEE, d MMM • h:mm a').format(dt), style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                                  _statusBadge(data['ride_doc_status'] == 'completed' ? 'completed' : data['status']),
                                ],
                              ),
                              const SizedBox(height: 15),
                              _locationRow(Icons.circle_outlined, data['source']['name'], Colors.grey),
                              const Padding(padding: EdgeInsets.only(left: 7), child: SizedBox(height: 10, child: VerticalDivider(width: 1))),
                              _locationRow(Icons.location_on, data['destination']['name'], primaryGreen),
                              const Divider(height: 30),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(data['driver_name'] ?? "Driver", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                      if(!_showUpcoming) Text("via $method", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Text(finalFare == 0 ? "FREE" : "₹$finalFare", 
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: finalFare == 0 ? Colors.blue : Colors.black)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> _processBookings(List<QueryDocumentSnapshot> docs, String myUid) async {
    List<Map<String, dynamic>> results = [];
    for (var doc in docs) {
      var bData = doc.data() as Map<String, dynamic>;
      var rideSnap = await FirebaseFirestore.instance.collection('rides').doc(bData['ride_id']).get();
      
      if (rideSnap.exists) {
        var rData = rideSnap.data()!;
        bData['ride_doc_status'] = rData['status'] ?? 'active';
        
        // Extract specific passenger route data
        var myRoute = rData['passenger_routes']?[myUid];
        if (myRoute != null) {
          bData['ride_specific_fare'] = myRoute['fare'];
          bData['ride_payment_method'] = myRoute['payment_method'];
          bData['ride_payment_status'] = myRoute['payment_status'];
        }
      }
      results.add(bData);
    }
    return results;
  }

  // --- UI Helpers (Keep existing _buildFilterButton, _statusBadge, _locationRow, _buildEmptyState) ---
  Widget _buildFilterButton(String label, bool isActive, VoidCallback onTap) {
    return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: isActive ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? primaryGreen : Colors.grey))))));
  }
  Widget _statusBadge(String status) {
    Color color = status == 'accepted' ? Colors.green : (status == 'completed' ? Colors.blue : Colors.red);
    if (status == 'pending') color = Colors.orange;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)));
  }
  Widget _locationRow(IconData icon, String text, Color color) {
    return Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 12), Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis, maxLines: 1))]);
  }
  Widget _buildEmptyState(bool isUpcoming) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(isUpcoming ? Icons.calendar_today : Icons.history, size: 70, color: Colors.grey.shade300), const SizedBox(height: 15), Text(isUpcoming ? "No upcoming trips" : "No completed trips", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey))]));
  }
}