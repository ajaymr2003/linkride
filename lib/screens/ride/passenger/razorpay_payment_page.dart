import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'driver_review_page.dart';

class RazorpayPaymentPage extends StatefulWidget {
  final String rideId;
  final dynamic amount;
  const RazorpayPaymentPage({super.key, required this.rideId, required this.amount});

  @override
  State<RazorpayPaymentPage> createState() => _RazorpayPaymentPageState();
}

class _RazorpayPaymentPageState extends State<RazorpayPaymentPage> {
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (res) => Navigator.pop(context));
    _startPayment();
  }

  void _startPayment() {
    int paise = (double.parse(widget.amount.toString()) * 100).toInt();
    _razorpay.open({
      'key': 'rzp_test_RWX7GZhQZS9oN5', 
      'amount': paise,
      'name': 'LinkRide',
      'description': 'Ride Payment',
      'prefill': {'contact': '', 'email': ''},
    });
  }

  void _onSuccess(PaymentSuccessResponse res) async {
    final String uid = FirebaseAuth.instance.currentUser!.uid;
    
    // Get driver data before navigating
    DocumentSnapshot snap = await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).get();
    var data = snap.data() as Map<String, dynamic>;

    await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
      'passenger_routes.$uid.payment_status': 'paid',
      'passenger_routes.$uid.payment_method': 'online',
      'passenger_routes.$uid.paid_by_online': true, // FLAG SET
      'passenger_routes.$uid.ride_status': 'completed',
    });

    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => DriverReviewPage(
          driverUid: data['driver_uid'], 
          driverName: data['driver_name'] ?? "Driver", 
          rideId: widget.rideId,
        ))
      );
    }
  }

  @override
  void dispose() { _razorpay.clear(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF11A860))));
  }
}