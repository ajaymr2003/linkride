import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'pay_by_cash_page.dart';
import 'razorpay_payment_page.dart';
import 'passenger_moving_screen.dart'; // IMPORTED

class PassengerPaymentPage extends StatelessWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const PassengerPaymentPage({super.key, required this.rideId, required this.rideData});

  // --- FETCH TRIP STATS ---
  Future<Map<String, String>> _fetchTripStats() async {
    final source = rideData['source'];
    final dest = rideData['destination'];
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/${source['lng']},${source['lat']};${dest['lng']},${dest['lat']}?overview=false');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0];
        return {
          'distance': "${(route['distance'] / 1000).toStringAsFixed(1)} km",
          'duration': "${(route['duration'] / 60).toStringAsFixed(0)} min",
        };
      }
    } catch (e) {
      debugPrint("Summary Stats Error: $e");
    }
    return {'distance': '--', 'duration': '--'};
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    final price = rideData['price_per_seat'] ?? 0;
    const primaryGreen = Color(0xFF11A860);
    const darkGreen = Color(0xFF2B5145);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rides').doc(rideId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        var data = snapshot.data!.data() as Map<String, dynamic>;
        var myRoute = data['passenger_routes'][uid];
        String status = myRoute['payment_status'] ?? 'unpaid';

        if (status == 'paid') return _buildSuccessUI(context);

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            title: const Text("Payment & Summary", style: TextStyle(fontWeight: FontWeight.bold)),
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            // --- UPDATED BACK BUTTON LOGIC ---
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () {
                // Instead of pop, we explicitly return to the Moving Screen (Map)
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (_) => PassengerMovingScreen(rideId: rideId, rideData: rideData))
                );
              },
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. TRIP DETAILS SUMMARY CARD
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
                  ),
                  child: Column(
                    children: [
                      _summaryRow(Icons.radio_button_checked, rideData['source']['name'], Colors.blue),
                      _dividerLine(),
                      _summaryRow(Icons.location_on, rideData['destination']['name'], Colors.red),
                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 20),
                      FutureBuilder<Map<String, String>>(
                        future: _fetchTripStats(),
                        builder: (context, stats) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _statItem("Distance", stats.data?['distance'] ?? "--", Icons.straighten),
                              _statItem("Duration", stats.data?['duration'] ?? "--", Icons.timer),
                              _statItem("Total Fare", "₹$price", Icons.payments_outlined),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),
                const Text("CHOOSE PAYMENT METHOD", 
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 15),

                _paymentTile(
                  context,
                  title: "Pay Online",
                  sub: "Cards, UPI, or Netbanking",
                  icon: Icons.account_balance_wallet_outlined,
                  color: primaryGreen,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => RazorpayPaymentPage(rideId: rideId, amount: price)))
                ),
                
                const SizedBox(height: 15),

                _paymentTile(
                  context,
                  title: "Pay by Cash",
                  sub: "Hand cash to the driver directly",
                  icon: Icons.payments_outlined,
                  color: Colors.orange.shade700,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => PayByCashPage(rideId: rideId, price: price)))
                ),
                
                const SizedBox(height: 40),
                const Center(
                  child: Text("Secure payment powered by LinkRide", 
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  // UI Widgets Helper methods remain the same...
  Widget _summaryRow(IconData icon, String text, Color color) {
    return Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 15), Expanded(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))]);
  }
  Widget _dividerLine() {
    return Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 9), child: Container(width: 2, height: 15, color: Colors.grey.shade200));
  }
  Widget _statItem(String label, String value, IconData icon) {
    return Column(children: [Icon(icon, color: const Color(0xFF11A860), size: 22), const SizedBox(height: 6), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11))]);
  }
  Widget _paymentTile(BuildContext context, {required String title, required String sub, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)), child: Row(children: [CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12))])), const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)])));
  }

  Widget _buildSuccessUI(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(25), decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle), child: const Icon(Icons.check_circle, size: 80, color: Color(0xFF11A860))),
            const SizedBox(height: 25),
            const Text("Payment Confirmed!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Your trip has been successfully completed.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 60),
            SizedBox(
              width: 220,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2B5145), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }, 
                child: const Text("BACK TO HOME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
              ),
            )
          ],
        ),
      ),
    );
  }
}