import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_payment_method_page.dart';

class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const primaryGreen = Color(0xFF11A860);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Payment Methods"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .collection('payment_methods')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // --- LOADING STATE ---
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // --- EMPTY STATE ---
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.credit_card_off, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  const Text("No payment methods added", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text("Add a card to pay for rides securely.", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPaymentMethodPage())),
                    style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                    child: const Text("Add Card", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          }

          // --- LIST STATE ---
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ...snapshot.data!.docs.map((doc) {
                var data = doc.data() as Map<String, dynamic>;
                bool isVisa = data['brand'] == 'Visa';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0,5))],
                  ),
                  child: Row(
                    children: [
                      // Brand Icon
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isVisa ? Colors.blue.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(5)
                        ),
                        child: Text(
                          data['brand'] ?? "Card",
                          style: TextStyle(fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: isVisa ? Colors.blue : Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Number
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("**** **** **** ${data['last4']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text("Expires ${data['expiry']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                           await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('payment_methods')
                            .doc(doc.id)
                            .delete();
                        },
                      )
                    ],
                  ),
                );
              }),
              
              const SizedBox(height: 20),
              
              // Add Button at bottom of list
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPaymentMethodPage())),
                icon: const Icon(Icons.add, color: primaryGreen),
                label: const Text("Add another card", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primaryGreen),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}