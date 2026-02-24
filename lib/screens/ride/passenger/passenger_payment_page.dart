import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PassengerPaymentPage extends StatefulWidget {
  final String rideId;
  final Map<String, dynamic> rideData;

  const PassengerPaymentPage({super.key, required this.rideId, required this.rideData});

  @override
  State<PassengerPaymentPage> createState() => _PassengerPaymentPageState();
}

class _PassengerPaymentPageState extends State<PassengerPaymentPage> {
  late Razorpay _razorpay;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  
  // Prefill details for Razorpay
  String? _userEmail;
  String? _userPhone;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    
    // Razorpay Handlers
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    if (doc.exists) {
      setState(() {
        _userEmail = doc.get('email');
        _userPhone = doc.get('phone');
      });
    }
  }

  // --- 1. RAZORPAY ONLINE PAYMENT ---
  void _startOnlinePayment() {
    double price = (widget.rideData['price_per_seat'] ?? 0).toDouble();
    int amountInPaise = (price * 100).toInt();

    var options = {
      'key': 'rzp_test_YOUR_KEY_HERE', // REPLACE WITH YOUR RAZORPAY KEY
      'amount': amountInPaise,
      'name': 'LinkRide',
      'description': 'Ride Payment',
      'prefill': {
        'contact': _userPhone ?? '',
        'email': _userEmail ?? '',
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Razorpay Error: $e');
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // On Success, update Firestore directly to 'paid'
    await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
      'passenger_routes.$_uid.payment_status': 'paid',
      'passenger_routes.$_uid.payment_method': 'online',
      'passenger_routes.$_uid.razorpay_id': response.paymentId,
      'passenger_routes.$_uid.ride_status': 'completed',
    });
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message}"), backgroundColor: Colors.red),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  // --- 2. CASH PAYMENT FLOW ---
  Future<void> _requestCashPayment() async {
    // Update status to 'waiting_for_driver'
    // This triggers the Driver's screen to show the confirmation prompt
    await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
      'passenger_routes.$_uid.payment_method': 'cash',
      'passenger_routes.$_uid.payment_status': 'waiting_for_driver',
    });
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.rideData['price_per_seat'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Payment Selection"), 
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var data = snapshot.data!.data() as Map<String, dynamic>;
          var myRoute = data['passenger_routes'][_uid];
          String paymentStatus = myRoute['payment_status'] ?? 'unpaid';

          // SCENARIO 1: PAYMENT SUCCESSFUL (Online or Driver confirmed Cash)
          if (paymentStatus == 'paid') {
            return _buildSuccessUI();
          }

          // SCENARIO 2: WAITING FOR DRIVER TO CONFIRM CASH
          if (paymentStatus == 'waiting_for_driver') {
            return _buildWaitingUI();
          }

          // SCENARIO 3: INITIAL CHOICE (Show selection buttons)
          return Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: Icon(Icons.account_balance_wallet_outlined, size: 80, color: Color(0xFF11A860))),
                const SizedBox(height: 10),
                const Center(child: Text("Total Fare", style: TextStyle(color: Colors.grey))),
                Center(child: Text("₹$price", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold))),
                
                const SizedBox(height: 50),
                const Text("SELECT PAYMENT METHOD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey, letterSpacing: 1)),
                const SizedBox(height: 20),

                // RAZORPAY BUTTON
                _methodTile(
                  title: "Pay Online",
                  subtitle: "Cards, UPI, Netbanking",
                  icon: Icons.payment_rounded,
                  color: const Color(0xFF11A860),
                  onTap: _startOnlinePayment,
                ),

                const SizedBox(height: 15),

                // CASH BUTTON
                _methodTile(
                  title: "Pay by Cash",
                  subtitle: "Pay directly to the driver",
                  icon: Icons.money_rounded,
                  color: Colors.orange,
                  onTap: _requestCashPayment,
                ),

                const Spacer(),
                const Center(child: Text("Transactions are secured by LinkRide", style: TextStyle(color: Colors.grey, fontSize: 10))),
              ],
            ),
          );
        },
      ),
    );
  }

  // UI: Success State
  Widget _buildSuccessUI() {
    // Automatically close the screen after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pop(context);
    });

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle, size: 80, color: Colors.green),
          ),
          const SizedBox(height: 20),
          const Text("Payment Successful!", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Your trip is officially complete.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  // UI: Waiting for Driver State
  Widget _buildWaitingUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 30),
            const Text("Handover Cash", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              "Please give the fare amount to the driver. The screen will update once the driver confirms receipt.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Widget for the payment selection buttons
  Widget _methodTile({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}