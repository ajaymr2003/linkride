import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverPaymentConfirmPage extends StatefulWidget {
  final String rideId;
  final String passengerUid;
  final String passengerName;
  final dynamic price;

  const DriverPaymentConfirmPage({
    super.key, 
    required this.rideId, 
    required this.passengerUid, 
    required this.passengerName,
    required this.price
  });

  @override
  State<DriverPaymentConfirmPage> createState() => _DriverPaymentConfirmPageState();
}

class _DriverPaymentConfirmPageState extends State<DriverPaymentConfirmPage> {
  bool _isSubmitting = false;

  Future<void> _completeRideForPassenger() async {
    setState(() => _isSubmitting = true);

    try {
      // Update specific passenger status using dot notation
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'passenger_routes.${widget.passengerUid}.payment_status': 'paid',
        'passenger_routes.${widget.passengerUid}.ride_status': 'completed',
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 50),
            title: const Text("Success"),
            content: Text("Payment confirmed for ${widget.passengerName}. Ride marked as completed."),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Back to Moving Screen
                  Navigator.pop(context); // Back to Dashboard
                }, 
                child: const Text("DONE")
              )
            ],
          )
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error updating status.")));
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Confirm Payment"), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Icon(Icons.payments_outlined, size: 80, color: Color(0xFF11A860)),
            const SizedBox(height: 20),
            Text(
              "Collect Payment from ${widget.passengerName}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Fare", style: TextStyle(fontSize: 16)),
                  Text("₹${widget.price}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF11A860))),
                ],
              ),
            ),
            
            const Spacer(),
            
            const Text(
              "By clicking below, you confirm that you have received the payment and the passenger has safely reached their destination.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF11A860),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: _isSubmitting ? null : _completeRideForPassenger,
                child: _isSubmitting 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("CONFIRM & COMPLETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}