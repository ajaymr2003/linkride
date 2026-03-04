import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'driver_review_page.dart';

class PayByCashPage extends StatefulWidget {
  final String rideId;
  final dynamic price;
  const PayByCashPage({super.key, required this.rideId, required this.price});

  @override
  State<PayByCashPage> createState() => _PayByCashPageState();
}

class _PayByCashPageState extends State<PayByCashPage> {
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          var myRoute = data['passenger_routes'][_uid];
          
          // DETECT IF DRIVER CLICKED RECEIVED
          if (myRoute['paid_by_cash'] == true || myRoute['payment_status'] == 'paid') {
            Future.delayed(Duration.zero, () {
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (_) => DriverReviewPage(
                  driverUid: data['driver_uid'], 
                  driverName: data['driver_name'] ?? "Driver", 
                  rideId: widget.rideId,
                ))
              );
            });
          }
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Pay by Cash"), elevation: 0),
          body: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.orange),
                const SizedBox(height: 40),
                const Text("Please hand over", style: TextStyle(color: Colors.grey)),
                Text("₹${widget.price}", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                const Text(
                  "Waiting for driver to confirm receipt of cash...",
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.5, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Change Payment Method"))
              ],
            ),
          ),
        );
      },
    );
  }
}