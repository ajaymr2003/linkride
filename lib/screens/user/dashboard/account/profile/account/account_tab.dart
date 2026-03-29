import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../../landing_screen.dart';
import 'ratings_page.dart';
import 'saved_passengers_page.dart';
import 'payment_methods_page.dart';
import 'help_page.dart';
import 'terms_page.dart';
import 'payments_refunds_page.dart';

class AccountTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  const AccountTab({super.key, required this.userData});

  // --- LOGOUT LOGIC ---
  Future<void> _handleLogout(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (_) => const LandingScreen()), 
                  (r) => false
                );
              }
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- CLOSE ACCOUNT LOGIC ---
  Future<void> _handleCloseAccount(BuildContext context) async {
    String? selectedReason;
    final List<String> reasons = [
      "I don't use this app anymore",
      "I have safety concerns",
      "The app is too difficult to use",
      "I found a better alternative",
      "Technical issues/bugs",
      "Other"
    ];

    // 1. Show Reason Dialog
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Why are you leaving?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) {
            return ListTile(
              title: Text(reason, style: const TextStyle(fontSize: 14)),
              onTap: () {
                selectedReason = reason;
                Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );

    if (selectedReason == null) return; // User cancelled

    // 2. Final Confirmation Dialog
    if (context.mounted) {
      bool confirm = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Permanently delete account?"),
          content: const Text(
            "This action cannot be undone. All your ride history, ratings, and profile data will be permanently removed.",
            style: TextStyle(color: Colors.red),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("GO BACK")),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("DELETE FOREVER", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ) ?? false;

      if (confirm) {
        _executeAccountDeletion(context, selectedReason!);
      }
    }
  }

  // 3. Deletion Execution
  Future<void> _executeAccountDeletion(BuildContext context, String reason) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      // Log the deletion reason to a separate collection (for Admin)
      await FirebaseFirestore.instance.collection('account_deletions').add({
        'uid': user.uid,
        'email': user.email,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Delete Firestore data
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();

      // Delete Firebase Auth User
      // Note: If user hasn't logged in recently, this might fail and ask for re-login
      await user.delete();

      if (context.mounted) {
        Navigator.pop(context); // Remove loading
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => const LandingScreen()), 
          (r) => false
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account successfully closed.")),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) Navigator.pop(context); // Remove loading
      if (e.code == 'requires-recent-login') {
        _showError(context, "For security, please log out and log back in before deleting your account.");
      } else {
        _showError(context, "Error: ${e.message}");
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      _showError(context, "An unexpected error occurred.");
    }
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

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
          "Payments and refunds", 
          "", 
          Icons.history,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsAndRefundsPage())),
        ),
        
        const SizedBox(height: 20),
        
        _buildTile(
          "Help", 
          "", 
          Icons.help_outline,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpPage())),
        ),
        _buildTile(
          "Terms and conditions", 
          "", 
          Icons.description_outlined,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsPage())),
        ),
        
        const SizedBox(height: 30),
        
        TextButton(
          onPressed: () => _handleLogout(context),
          child: const Text("Logout", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ),
        
        TextButton(
          onPressed: () => _handleCloseAccount(context),
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