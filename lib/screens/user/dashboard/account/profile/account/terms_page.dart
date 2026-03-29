import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Terms and Conditions"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Last Updated: January 2026", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            
            Text("1. Introduction", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(
              "Welcome to LinkRide. By accessing or using our mobile application, you agree to be bound by these Terms and Conditions and our Privacy Policy.",
              style: TextStyle(height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 20),

            Text("2. User Accounts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(
              "You must create an account to use the Service. You agree to provide accurate, current, and complete information during the registration process and to update such information to keep it accurate, current, and complete.",
              style: TextStyle(height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 20),

            Text("3. Driver Obligations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(
              "Drivers must hold a valid driver's license and insurance. Drivers are responsible for the safety and maintenance of their vehicles. LinkRide reserves the right to suspend any driver found violating safety protocols.",
              style: TextStyle(height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 20),

            Text("4. Cancellations and Refunds", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(
              "Cancellations made 24 hours before the ride are fully refundable. Cancellations made within 24 hours may incur a fee.",
              style: TextStyle(height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 20),
            
            Text("5. Liability", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Text(
              "LinkRide is a platform connecting drivers and passengers. We are not responsible for the behavior of users, though we take safety seriously and investigate all reports.",
              style: TextStyle(height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}