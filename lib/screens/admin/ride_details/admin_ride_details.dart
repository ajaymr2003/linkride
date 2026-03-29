import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '/screens/admin/driver_request/user_detail_view.dart'; // Import the user detail page


class AdminRideDetailsPage extends StatelessWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const AdminRideDetailsPage({super.key, required this.rideId, required this.rideData});

  final Color primaryGreen = const Color(0xFF11A860);

  @override
  Widget build(BuildContext context) {
    DateTime departure = (rideData['departure_time'] as Timestamp).toDate();
    List passengers = rideData['passengers'] ?? [];
    // Access the detailed routes map
    Map<String, dynamic> passengerRoutes = rideData['passenger_routes'] ?? {};

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Ride Audit Log", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER STATUS
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: rideData['status'] == 'completed' ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(
                    rideData['status'] == 'completed' ? Icons.check_circle : Icons.cancel,
                    color: rideData['status'] == 'completed' ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Status: ${rideData['status'].toString().toUpperCase()}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: rideData['status'] == 'completed' ? Colors.green : Colors.red)),
                      Text(DateFormat('EEEE, dd MMMM yyyy').format(departure), style: const TextStyle(fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 2. OVERALL DRIVER ROUTE
            const Text("OVERALL DRIVER ROUTE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 20),
            _routeRow(Icons.radio_button_checked, "Start", rideData['source']['name'], Colors.blue),
            const Padding(padding: EdgeInsets.only(left: 11), child: SizedBox(height: 15, child: VerticalDivider(width: 1, thickness: 1))),
            _routeRow(Icons.location_on, "End", rideData['destination']['name'], Colors.red),

            const SizedBox(height: 40),

            // 3. DRIVER & VEHICLE
            const Text("DRIVER & VEHICLE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 15),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(rideData['driver_uid']).get(),
              builder: (context, snap) {
                if (!snap.hasData) return const LinearProgressIndicator();
                var driver = snap.data!.data() as Map<String, dynamic>;
                return InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailView(uid: rideData['driver_uid']))),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade100), borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(backgroundImage: driver['profile_pic'] != null ? NetworkImage(driver['profile_pic']) : null),
                      title: Text(driver['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${rideData['vehicle']['brand']} ${rideData['vehicle']['model']} • ${rideData['vehicle']['plate']}"),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                );
              },
            ),

            const Divider(height: 50),

            // 4. FINANCIALS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statTile("PRICE PER SEAT", "₹${rideData['price_per_seat']}"),
                _statTile("TOTAL PASSENGERS", "${passengers.length}"),
              ],
            ),

            const SizedBox(height: 40),

            // 5. PASSENGER LIST WITH SPECIFIC PICKUP/DROP-OFF
            const Text("ONBOARD PASSENGERS", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 15),
            if (passengers.isEmpty)
              const Text("No passengers onboarded.", style: TextStyle(color: Colors.grey, fontSize: 13))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: passengers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 15),
                itemBuilder: (context, index) {
                  String pUid = passengers[index];
                  var pRoute = passengerRoutes[pUid] ?? {}; // Get specific route for this passenger
                  
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(pUid).get(),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox();
                      var p = snap.data!.data() as Map<String, dynamic>;
                      
                      return InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailView(uid: pUid))),
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Passenger Profile Row
                              Row(
                                children: [
                                  CircleAvatar(radius: 20, backgroundImage: p['profile_pic'] != null ? NetworkImage(p['profile_pic']) : null),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p['name'] ?? "User", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text(p['phone'] ?? "No phone", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                                ],
                              ),
                              const Divider(height: 25),
                              
                              // Specific Passenger Route info
                              const Text("PASSENGER TRIP POINTS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
                              const SizedBox(height: 10),
                              
                              _miniRouteRow(Icons.circle, Colors.blue, "Pickup", pRoute['pickup']?['name'] ?? "N/A"),
                              const SizedBox(height: 8),
                              _miniRouteRow(Icons.location_on, Colors.red, "Drop-off", pRoute['dropoff']?['name'] ?? "N/A"),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // Helper for the specific passenger's smaller route display
  Widget _miniRouteRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 10),
        Text("$label: ", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _routeRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)),
      ],
    );
  }
}