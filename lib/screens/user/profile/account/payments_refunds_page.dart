import 'package:flutter/material.dart';

class PaymentsAndRefundsPage extends StatelessWidget {
  const PaymentsAndRefundsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Payments and Refunds"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Filter / Tabs visual (Static for now)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip("All", true),
                _filterChip("Payments", false),
                _filterChip("Refunds", false),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text("Recent Activity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 15),

          // Mock Data Items
          _buildTransactionItem(
            "Refund: Trip Cancelled",
            "Jan 21, 2026",
            "+ ₹150.00",
            Colors.green,
            Icons.subdirectory_arrow_left,
          ),
          _buildTransactionItem(
            "Payment: Ride to Calicut",
            "Jan 18, 2026",
            "- ₹320.00",
            Colors.black,
            Icons.arrow_outward,
          ),
          _buildTransactionItem(
            "Payment: Ride to Mukkam",
            "Jan 15, 2026",
            "- ₹80.00",
            Colors.black,
            Icons.arrow_outward,
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF11A860) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTransactionItem(String title, String date, String amount, Color amountColor, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.black54),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(
            amount,
            style: TextStyle(fontWeight: FontWeight.bold, color: amountColor, fontSize: 16),
          ),
        ],
      ),
    );
  }
}