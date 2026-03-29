import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final TextEditingController _reportController = TextEditingController();
  bool _isSubmitting = false;

  // LinkRide Theme Colors
  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);
  final Color accentGreen = const Color(0xFFE8F5E9);

  final List<String> _callbackReasons = [
    "Payment or Refund Issue",
    "Safety or Security Concern",
    "Account or Verification Help",
    "Ride Related Issue",
    "General Feedback",
    "Other"
  ];

  Future<void> _sendToAdmin({
    required String type,
    required String title,
    required String message,
  }) async {
    setState(() => _isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      String senderName = userDoc.exists ? (userDoc['name'] ?? "User") : "Anonymous";
      String senderPhone = userDoc.exists ? (userDoc['phone'] ?? "N/A") : "N/A";

      await FirebaseFirestore.instance.collection('admin_inbox').add({
        'sender_uid': user.uid,
        'sender_name': senderName,
        'sender_phone': senderPhone,
        'type': type,
        'title': title,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(type == 'report' ? "✅ Report submitted successfully" : "📞 Request sent! Admin will call soon."),
            backgroundColor: darkGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _reportController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Failed to send. Check connection.")));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showContactDialog() {
    String? selectedReason;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            title: Column(
              children: [
                Icon(Icons.phone_in_talk_rounded, color: primaryGreen, size: 40),
                const SizedBox(height: 10),
                Text("Request Callback", style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Select a reason for support and our team will reach out to you.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedReason,
                      isExpanded: true,
                      hint: const Text("Choose a reason"),
                      icon: Icon(Icons.keyboard_arrow_down, color: primaryGreen),
                      items: _callbackReasons.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 14)))).toList(),
                      onChanged: (v) => setModalState(() => selectedReason = v),
                    ),
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold))),
              ElevatedButton(
                onPressed: selectedReason == null ? null : () { Navigator.pop(context); _sendToAdmin(type: 'callback_request', title: 'Callback: $selectedReason', message: 'User requested a call for $selectedReason'); },
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text("CONFIRM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Help Centre", style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios_new, color: darkGreen, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image/Icon Section
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: accentGreen, shape: BoxShape.circle),
                    child: Icon(Icons.headset_mic_rounded, size: 50, color: primaryGreen),
                  ),
                  const SizedBox(height: 15),
                  Text("How can we help?", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: darkGreen)),
                  const SizedBox(height: 5),
                  const Text("Find answers or contact our team", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            
            const SizedBox(height: 35),
            
            _sectionTitle("Frequently Asked Questions"),
            const SizedBox(height: 10),
            _buildFaqItem("How do I book a ride?", "Navigate to the home screen, search for your destination, pick a driver that suits your schedule, and tap 'Request to Join'."),
            _buildFaqItem("Is my personal data safe?", "LinkRide uses industry-standard encryption. Your ID documents are stored securely and only accessible by authorized admins for verification."),
            _buildFaqItem("How does the PIN system work?", "When the driver arrives, ask them for the PIN. Enter it on your phone to confirm you've boarded the correct vehicle safely."),

            const SizedBox(height: 30),

            _sectionTitle("Report an Issue"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _reportController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "E.g. Issues with a driver, technical bugs...",
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : () { if (_reportController.text.trim().isNotEmpty) _sendToAdmin(type: 'report', title: 'Issue Report', message: _reportController.text.trim()); },
                      icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      label: const Text("Submit Report", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE74C3C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Premium Contact Card
            _buildContactCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkGreen));
  }

  Widget _buildFaqItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        title: Text(question, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: darkGreen)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        iconColor: primaryGreen,
        collapsedIconColor: Colors.grey,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        children: [Text(answer, style: const TextStyle(color: Colors.black54, height: 1.5, fontSize: 13))],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [darkGreen, primaryGreen], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: primaryGreen.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Talk to a Human", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("We'll call you back to resolve your concerns immediately.", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _showContactDialog,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: darkGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20)),
            child: const Text("Contact Us", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }
}