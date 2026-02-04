import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class UserDetailView extends StatefulWidget {
  final String uid;
  const UserDetailView({super.key, required this.uid});

  @override
  State<UserDetailView> createState() => _UserDetailViewState();
}

class _UserDetailViewState extends State<UserDetailView> {
  final TextEditingController _warningController = TextEditingController();
  bool _isProcessing = false;

  // --- 1. BAN / UNBAN LOGIC ---
  Future<void> _toggleBan(bool currentStatus) async {
    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'isBanned': !currentStatus,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentStatus ? "User Unbanned Successfully" : "User Banned Successfully"),
            backgroundColor: currentStatus ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error updating status")));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- 2. WARNING MESSAGE LOGIC ---
  Future<void> _sendWarning() async {
    String msg = _warningController.text.trim();
    if (msg.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'warning_message': msg,
        'warning_date': FieldValue.serverTimestamp(),
      });

      _warningController.clear();
      if (mounted) {
        Navigator.pop(context); // Close Dialog
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Warning sent successfully")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send warning")));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Send Warning Message"),
        content: TextField(
          controller: _warningController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Enter the reason for warning (e.g. Unusual activity detected)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: _isProcessing ? null : _sendWarning,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text("Send", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // --- 3. FULL SCREEN IMAGE VIEW (Zoomable) ---
  void _showFullScreenImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(child: Image.network(url, fit: BoxFit.contain)),
            ),
            SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("User Management"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
          if (!userSnap.data!.exists) return const Center(child: Text("User deleted"));

          var userData = userSnap.data!.data() as Map<String, dynamic>;
          bool isBanned = userData['isBanned'] ?? false;
          bool isDriver = userData['driver_status'] == 'approved';

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('driver_applications').doc(widget.uid).get(),
            builder: (context, appSnap) {
              // FIX: Explicitly cast to Map<String, dynamic> to avoid the dynamic error
              Map<String, dynamic> appData = (appSnap.hasData && appSnap.data!.exists)
                  ? appSnap.data!.data() as Map<String, dynamic>
                  : <String, dynamic>{};

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // --- HEADER ---
                    _buildProfileHeader(userData, isDriver, isBanned),
                    const SizedBox(height: 20),

                    // --- BASIC INFO ---
                    _buildSectionContainer([
                      _infoRow(Icons.email, "Email Address", userData['email'] ?? "N/A"),
                      _infoRow(Icons.phone, "Phone Number", userData['phone'] ?? "N/A"),
                      _infoRow(Icons.security, "Emergency Contact", userData['guardian_phone'] ?? "N/A"),
                    ]),

                    const SizedBox(height: 20),

                    // --- DOCUMENTS SECTION (If Application exists) ---
                    if (appData.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: 5, bottom: 8),
                          child: Text("Verification Documents", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      _buildSectionContainer([
                        _infoRow(Icons.badge, "DL Number", appData['license_number'] ?? "N/A"),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildThumbnail(context, appData['license_front'], "License Front"),
                            _buildThumbnail(context, appData['license_back'], "License Back"),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 20),
                    ],

                    // --- ADMINISTRATIVE ACTIONS (Danger Zone) ---
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 5, bottom: 8),
                        child: Text("Administrative Actions", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                      ),
                    ),
                    _buildSectionContainer([
                      // Warning Action
                      ListTile(
                        leading: const Icon(Icons.report_problem, color: Colors.orange),
                        title: const Text("Send Warning Message"),
                        subtitle: Text(userData['warning_message'] != null 
                            ? "Current: ${userData['warning_message']}" 
                            : "No warnings active"),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showWarningDialog,
                      ),
                      const Divider(),
                      // Ban/Unban Action
                      ListTile(
                        leading: Icon(Icons.block, color: isBanned ? Colors.green : Colors.red),
                        title: Text(isBanned ? "Lift User Ban" : "Ban User Account"),
                        subtitle: Text(isBanned ? "Restore access to this user" : "Restrict user from logging in"),
                        onTap: _isProcessing ? null : () => _toggleBan(isBanned),
                      ),
                    ]),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // --- SUB-WIDGETS ---

  Widget _buildProfileHeader(Map<String, dynamic> userData, bool isDriver, bool isBanned) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: userData['profile_pic'] != null ? NetworkImage(userData['profile_pic']) : null,
            child: userData['profile_pic'] == null ? const Icon(Icons.person, size: 50) : null,
          ),
          const SizedBox(height: 15),
          Text(userData['name'] ?? "User", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isBanned) _badge("BANNED", Colors.red),
              if (isBanned) const SizedBox(width: 8),
              _badge(isDriver ? "DRIVER" : "PASSENGER", isDriver ? Colors.green : Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
        child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      );

  Widget _buildSectionContainer(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: children),
    );
  }

  Widget _buildThumbnail(BuildContext context, String? url, String label) {
    if (url == null) return const SizedBox();
    return GestureDetector(
      onTap: () => _showFullScreenImage(context, url),
      child: Column(
        children: [
          Container(
            width: 120, height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
              image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}