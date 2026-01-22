import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF11A860);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Help Centre"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("How can we help you?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          // Search Bar (Visual only)
          TextField(
            decoration: InputDecoration(
              hintText: "Search help articles...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 30),

          const Text("Frequently Asked Questions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          _buildFaqItem("How do I book a ride?", "Search for your destination, select a ride that suits your time, and tap 'Book'. You can pay via card or cash."),
          _buildFaqItem("How do I cancel my booking?", "Go to 'Your Rides', select the booking, and tap 'Cancel'. Cancellation fees may apply depending on the time."),
          _buildFaqItem("Is my ID safe?", "Yes, we use secure encryption to store your documents. They are only used for identity verification."),
          _buildFaqItem("When do I get paid as a driver?", "Payouts are processed weekly. You can track them in the Payouts section of your profile."),

          const SizedBox(height: 30),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                const Icon(Icons.support_agent, color: primaryGreen, size: 40),
                const SizedBox(width: 15),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Still need help?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("Our team is available 24/7.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {}, 
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                  child: const Text("Contact Us", style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      textColor: const Color(0xFF11A860),
      iconColor: const Color(0xFF11A860),
      childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
      children: [
        Text(answer, style: const TextStyle(color: Colors.grey, height: 1.5)),
      ],
    );
  }
}