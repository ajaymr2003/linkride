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
    "Other"
  ];

  Future<void> _updateStatus(String status, String reason) async {
    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
      'driver_status': status,
      'rejection_reason': status == 'rejected' ? reason : "",
      'role': status == 'approved' ? 'driver' : 'user',
    });
    Navigator.pop(context); // Close Detail View
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Reason for Rejection"),
          content: Column(
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
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => _updateStatus('rejected', _selectedReason == "Other" ? _customReason.text : _selectedReason),
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
      appBar: AppBar(title: const Text("Review Documents")),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('driver_applications').doc(widget.uid).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var data = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel("License Number: ${data['license_number']}"),
                const SizedBox(height: 20),
                _buildImageSection("Profile Photo", data['profile_pic']),
                _buildImageSection("License Front", data['license_front']),
                _buildImageSection("License Back", data['license_back']),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _showRejectDialog,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text("REJECT"),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateStatus('approved', ""),
                        style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                        child: const Text("APPROVE", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _buildImageSection(String title, String? url) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        url != null 
          ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(url, height: 200, width: double.infinity, fit: BoxFit.cover))
          : const Text("No image"),
        const SizedBox(height: 20),
      ],
    );
  }
}