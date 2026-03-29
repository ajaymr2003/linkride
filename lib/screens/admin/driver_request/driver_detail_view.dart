import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverDetailView extends StatefulWidget {
  final String uid;
  const DriverDetailView({super.key, required this.uid});

  @override
  State<DriverDetailView> createState() => _DriverDetailViewState();
}

class _DriverDetailViewState extends State<DriverDetailView> {
  final Color primaryGreen = const Color(0xFF11A860);
  final TextEditingController _customReason = TextEditingController();
  String _selectedReason = "Photos are blurry";

  final List<String> _predefinedReasons = [
    "Photos are blurry",
    "License number mismatch",
    "Expired Document",
    "Fake Documents detected",
    "Underage",
    "Other"
  ];

  // --- 1. UPDATE STATUS LOGIC ---
  Future<void> _updateStatus(String status, String reason) async {
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
      'driver_status': status,
      'rejection_reason': status == 'rejected' ? reason : "",
      // If approved, set role to driver.
      'role': status == 'approved' ? 'driver' : 'user', 
    });
    
    if (mounted) Navigator.pop(context); 
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Reason for Rejection"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ..._predefinedReasons.map((r) => RadioListTile(
                      title: Text(r),
                      value: r,
                      groupValue: _selectedReason,
                      onChanged: (v) => setState(() => _selectedReason = v!),
                    )),
                if (_selectedReason == "Other")
                  TextField(controller: _customReason, decoration: const InputDecoration(hintText: "Enter reason")),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context); 
                _updateStatus('rejected', _selectedReason == "Other" ? _customReason.text : _selectedReason);
              },
              child: const Text("Reject", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Review Driver Application"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // Fetching directly from 'users' collection
        stream: FirebaseFirestore.instance.collection('users').doc(widget.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Driver data not found"));
          }

          var userData = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- PROFILE HEADER ---
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: userData['profile_pic'] != null 
                            ? NetworkImage(userData['profile_pic']) 
                            : null,
                        child: userData['profile_pic'] == null ? const Icon(Icons.person, size: 50) : null,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        userData['name'] ?? "Unknown Name", 
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                      ),
                      Text(
                        userData['email'] ?? "No Email", 
                        style: TextStyle(color: Colors.grey[600])
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 25),

                // --- PERSONAL DETAILS ---
                const Text("Personal Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.phone, "Phone", userData['phone'] ?? "N/A"),
                      const Divider(),
                      _buildInfoRow(Icons.cake, "Date of Birth", userData['dob'] ?? "N/A"),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // --- LICENSE DETAILS ---
                const Text("License Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.badge, "License Number", userData['license_number'] ?? "N/A"),
                      const Divider(height: 30),
                      
                      const Text("Document Images", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 15),
                      
                      _buildImageSection("License Front", userData['license_front']),
                      const SizedBox(height: 15),
                      _buildImageSection("License Back", userData['license_back']),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- ACTION BUTTONS ---
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _showRejectDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 15)
                        ),
                        child: const Text("REJECT", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateStatus('approved', ""),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryGreen,
                          padding: const EdgeInsets.symmetric(vertical: 15)
                        ),
                        child: const Text("APPROVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 20),
        const SizedBox(width: 15),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        )
      ],
    );
  }

  Widget _buildImageSection(String label, String? url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        url != null 
          ? GestureDetector(
              onTap: () {
                showDialog(context: context, builder: (_) => Dialog(child: Image.network(url)));
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10), 
                child: Image.network(url, height: 180, width: double.infinity, fit: BoxFit.cover)
              ),
            )
          : Container(
              height: 150, width: double.infinity, 
              color: Colors.grey[200], 
              child: const Center(child: Text("Image missing"))
            ),
      ],
    );
  }
}