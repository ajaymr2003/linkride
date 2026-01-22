import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../landing_screen.dart';
import 'ratings_page.dart';
import 'saved_passengers_page.dart';
import 'payment_methods_page.dart';
import 'payouts_page.dart';
import 'help_page.dart';  // Import Help
import 'terms_page.dart'; // Import Terms

class AccountTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  const AccountTab({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildTile(
          "Ratings", 
          userData['rating']?.toString() ?? "New", 
          Icons.star_border,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RatingsPage())),
        ),
        _buildTile(
          "Saved Passengers", 
          "0", 
          Icons.people_outline,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedPassengersPage())),
        ),
        _buildTile(
          "Payment methods", 
          "", 
          Icons.payment,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsPage())),
        ),

        const SizedBox(height: 20),
        
        _buildTile(
          "Payouts", 
          "", 
          Icons.account_balance_wallet_outlined,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayoutsPage())),
        ),
        
        // Static for now
        _buildTile("Payments and refunds", "", Icons.history),
        
        const SizedBox(height: 20),
        
        // Help Page Linked
        _buildTile(
          "Help", 
          "", 
          Icons.help_outline,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPage())),
        ),
        
        // Terms Page Linked
        _buildTile(
          "Terms and conditions", 
          "", 
          Icons.description_outlined,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPage())),
        ),
        
        const SizedBox(height: 30),
        
        TextButton(
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LandingScreen()), (r) => false);
          },
          child: const Text("Logout", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () {},
          child: const Text("Close my account", style: TextStyle(color: Colors.red)),
        ),
      ],
    );
  }

  Widget _buildTile(String title, String trailingText, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 5),
      leading: Icon(icon, color: const Color(0xFF2B5145)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText.isNotEmpty) 
            Text(trailingText, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 5),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}