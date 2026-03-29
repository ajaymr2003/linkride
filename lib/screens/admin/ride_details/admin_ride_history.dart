import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminRideHistoryPage extends StatelessWidget {
  const AdminRideHistoryPage({super.key});

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Ride History", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: darkGreen,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rides')
            .where('status', whereIn: ['completed', 'cancelled'])
            .orderBy('departure_time', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return _buildHistoryCard(context, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> data) {
    DateTime date = (data['departure_time'] as Timestamp).toDate();
    String status = data['status'] ?? 'unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statusBadge(status),
              Text(DateFormat('dd MMM yyyy, hh:mm a').format(date),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 15),
          
          _routeRow(Icons.circle, Colors.grey, data['source']['name']),
          const Padding(padding: EdgeInsets.only(left: 7), child: SizedBox(height: 10, child: VerticalDivider())),
          _routeRow(Icons.location_on, primaryGreen, data['destination']['name']),

          const Divider(height: 30),

          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 5),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(data['driver_uid']).get(),
                builder: (context, snap) {
                  String name = snap.hasData ? (snap.data!['name'] ?? "Driver") : "Loading...";
                  return Text("Driver: $name", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13));
                },
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showHistoryDetails(context, data),
                child: Text("VIEW DETAILS", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
              )
            ],
          )
        ],
      ),
    );
  }

  void _showHistoryDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Trip Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _detailItem("Vehicle", "${data['vehicle']['brand']} ${data['vehicle']['model']} - ${data['vehicle']['plate']}"),
            _detailItem("Fare Price", "₹${data['price_per_seat']} per seat"),
            _detailItem("Route Chosen", data['route'] ?? "Standard"),
            const Divider(height: 30),
            const Text("Passengers In This Trip", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            _buildPassengerInfo(data['passengers'] ?? []),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("CLOSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerInfo(List pList) {
    if (pList.isEmpty) return const Text("No passengers were onboard.", style: TextStyle(color: Colors.grey, fontSize: 13));
    return Column(
      children: pList.map((uid) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snap) {
          String pName = snap.hasData ? (snap.data!['name'] ?? "User") : "Loading...";
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_circle, color: Colors.blue, size: 18),
            title: Text(pName, style: const TextStyle(fontSize: 14)),
            subtitle: Text("UID: $uid", style: const TextStyle(fontSize: 10)),
          );
        },
      )).toList(),
    );
  }

  Widget _detailItem(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: RichText(text: TextSpan(style: const TextStyle(color: Colors.black, fontSize: 14), children: [
      TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      TextSpan(text: value),
    ])),
  );

  Widget _statusBadge(String status) {
    Color color = status == 'completed' ? Colors.blue : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  Widget _routeRow(IconData icon, Color color, String text) => Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 10), Expanded(child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)))]);

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.history, size: 80, color: Colors.grey[300]), const SizedBox(height: 20), const Text("No history available", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))]));
}