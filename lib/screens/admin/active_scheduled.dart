import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'admin_live_tracking.dart'; // Import the new map page

class ActiveScheduledPage extends StatefulWidget {
  const ActiveScheduledPage({super.key});

  @override
  State<ActiveScheduledPage> createState() => _ActiveScheduledPageState();
}

class _ActiveScheduledPageState extends State<ActiveScheduledPage> {
  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rides')
          .where('status', whereIn: ['active', 'scheduled', 'ongoing'])
          .orderBy('departure_time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return _buildEmpty();

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var rideDoc = snapshot.data!.docs[index];
            var data = rideDoc.data() as Map<String, dynamic>;
            return _buildRideAdminCard(rideDoc.id, data);
          },
        );
      },
    );
  }

  Widget _buildRideAdminCard(String rideId, Map<String, dynamic> data) {
    DateTime departure = (data['departure_time'] as Timestamp).toDate();
    bool isOngoing = data['status'] == 'ongoing';
    Map<String, dynamic> passengers = data['passenger_routes'] ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          // 1. DRIVER HEADER
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(data['driver_uid']).get(),
            builder: (context, userSnap) {
              var driver = userSnap.data?.data() as Map<String, dynamic>?;
              return Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isOngoing ? Colors.blue.shade50 : Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: driver?['profile_pic'] != null ? NetworkImage(driver!['profile_pic']) : null,
                      child: driver?['profile_pic'] == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driver?['name'] ?? "Loading...", style: const TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 12, color: Colors.amber),
                              Text(" ${driver?['rating'] ?? 'New'}", style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 10),
                              const Icon(Icons.directions_car, size: 12, color: Colors.grey),
                              Text(" ${data['vehicle']['brand']} ${data['vehicle']['model']}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isOngoing)
                      _liveBadge()
                    else
                      Text("₹${data['price_per_seat']}", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              );
            },
          ),

          // 2. RIDE INFO
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                _locationRow(Icons.circle_outlined, data['source']['name'], Colors.grey),
                const Padding(padding: EdgeInsets.only(left: 7), child: SizedBox(height: 10, child: VerticalDivider())),
                _locationRow(Icons.location_on, data['destination']['name'], Colors.red),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 5),
                    Text(DateFormat('EEE, d MMM • hh:mm a').format(departure), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text("${data['available_seats']} seats left", style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          // 3. PASSENGERS LIST
          if (passengers.isNotEmpty) ...[
            const Divider(height: 1),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              color: Colors.grey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("ACCEPTED PASSENGERS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
                  const SizedBox(height: 10),
                  ...passengers.entries.map((p) => _buildPassengerMiniRow(p.value)).toList(),
                ],
              ),
            ),
          ],

          // 4. ACTION FOOTER
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminLiveTracking(rideId: rideId, rideData: data))),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text("MONITOR LIVE"),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(rideId),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPassengerMiniRow(Map<String, dynamic> p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.person, size: 14, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['passenger_name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                Text("${p['pickup']['name']} ➔ ${p['dropoff']['name']}", 
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          _statusSmall(p['ride_status'] ?? 'approved'),
        ],
      ),
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(5)),
      child: const Row(
        children: [
          Icon(Icons.sensors, color: Colors.white, size: 12),
          Text(" LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statusSmall(String status) {
    return Text(status.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue));
  }

  Widget _locationRow(IconData icon, String text, Color color) {
    return Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))]);
  }

  Widget _buildEmpty() => const Center(child: Text("No rides to monitor"));

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Ride?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(onPressed: () { 
            FirebaseFirestore.instance.collection('rides').doc(id).delete();
            Navigator.pop(ctx);
          }, child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}