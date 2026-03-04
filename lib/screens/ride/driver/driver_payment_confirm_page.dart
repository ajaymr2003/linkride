import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'passenger_review_page.dart';

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
  String _selectedMethod = "cash"; // Default selection

  // --- MANUAL CASH CONFIRMATION LOGIC ---
  Future<void> _handlePaymentReceived() async {
    // 1. Show Confirmation Dialog
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Confirm Payment"),
        content: Text("Are you sure you have received ₹${widget.price} in cash from ${widget.passengerName}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("No")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Yes, Received", style: TextStyle(color: Color(0xFF11A860), fontWeight: FontWeight.bold))
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isSubmitting = true);

    try {
      // 2. Update status in database
      await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).update({
        'passenger_routes.${widget.passengerUid}.payment_status': 'paid',
        'passenger_routes.${widget.passengerUid}.ride_status': 'completed',
        'passenger_routes.${widget.passengerUid}.payment_method': 'cash',
        'passenger_routes.${widget.passengerUid}.paid_by_cash': true, // Custom flag for passenger detection
      });
      
      // Success feedback is handled by the StreamBuilder below detecting the 'paid' status
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error updating status.")));
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF11A860);
    const darkGreen = Color(0xFF2B5145);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        var data = snapshot.data!.data() as Map<String, dynamic>;
        var pData = data['passenger_routes'][widget.passengerUid];
        
        // CHECK FOR EITHER MANUAL CASH UPDATES OR AUTO ONLINE UPDATES
        String currentStatus = pData['payment_status'] ?? 'unpaid';
        bool isPaidOnline = pData['paid_by_online'] == true;

        if (currentStatus == 'paid' || isPaidOnline) {
          return _buildSuccessUI(primaryGreen, darkGreen);
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text("Collect Payment", style: TextStyle(fontWeight: FontWeight.bold)),
            elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black,
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.pop(context)),
          ),
          body: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, size: 70, color: primaryGreen),
                      const SizedBox(height: 15),
                      Text(widget.passengerName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const Text("Finalize the trip payment", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                const Text("CHOOSE METHOD", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                const SizedBox(height: 15),

                // --- PAYMENT METHOD SELECTION BOXES ---
                Row(
                  children: [
                    _methodCard("Cash", Icons.payments_outlined, _selectedMethod == "cash", () => setState(() => _selectedMethod = "cash")),
                    const SizedBox(width: 15),
                    _methodCard("Online", Icons.qr_code_scanner, _selectedMethod == "online", () => setState(() => _selectedMethod = "online")),
                  ],
                ),

                const SizedBox(height: 40),
                
                // Amount Display Card
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA), 
                    borderRadius: BorderRadius.circular(20), 
                    border: Border.all(color: Colors.grey.shade200)
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Fare to Collect", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      Text("₹${widget.price}", style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: primaryGreen)),
                    ],
                  ),
                ),

                const Spacer(),

                // --- DYNAMIC ACTION FOOTER ---
                if (_selectedMethod == "online")
                  _buildOnlineStatusFooter()
                else
                  SizedBox(
                    width: double.infinity, height: 60,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0
                      ),
                      onPressed: _isSubmitting ? null : _handlePaymentReceived,
                      child: _isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("PAYMENT RECEIVED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _methodCard(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 25),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF11A860).withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isSelected ? const Color(0xFF11A860) : Colors.grey.shade300, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFF11A860) : Colors.grey, size: 30),
              const SizedBox(height: 10),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? const Color(0xFF11A860) : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineStatusFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 15),
          Expanded(child: Text("Waiting for ${widget.passengerName} to pay via Online Gateway...", style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildSuccessUI(Color pColor, Color dColor) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: pColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.check_circle, size: 100, color: pColor),
              ),
              const SizedBox(height: 25),
              const Text("Payment Verified!", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text("The transaction is complete and the trip has ended.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 60),
              
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: dColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context, 
                      MaterialPageRoute(builder: (_) => PassengerReviewPage(
                        passengerUid: widget.passengerUid, 
                        passengerName: widget.passengerName, 
                        rideId: widget.rideId,
                      ))
                    );
                  },
                  child: const Text("RATE PASSENGER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text("Skip review", style: TextStyle(color: Colors.grey)),
              )
            ],
          ),
        ),
      ),
    );
  }
}