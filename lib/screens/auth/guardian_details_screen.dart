import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../user/user_dashboard.dart';

class GuardianDetailsScreen extends StatefulWidget {
  final String userId;

  const GuardianDetailsScreen({super.key, required this.userId});

  @override
  State<GuardianDetailsScreen> createState() => _GuardianDetailsScreenState();
}

class _GuardianDetailsScreenState extends State<GuardianDetailsScreen> {
  final TextEditingController _guardianNameController = TextEditingController();
  final TextEditingController _guardianPhoneController = TextEditingController();
  bool _loading = false;

  final Color primaryGreen = const Color.fromARGB(255, 53, 121, 88);
  final Color lightGreen = const Color(0xFFA2E1CA);
  final Color darkGreen = const Color.fromARGB(255, 21, 61, 49);
  final Color mutedGreen = const Color(0xFF64AA8E);
  final Color bgColor = const Color(0xFFECECEC);
  final Color textBlack = const Color(0xFF101212);
  final Color textGrey = const Color(0xFF727272);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    super.dispose();
  }

  Future<void> _uploadGuardianDetails() async {
    if (_guardianNameController.text.trim().isEmpty || _guardianPhoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please provide valid guardian details"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _firestore.collection('users').doc(widget.userId).update({
        'guardian_name': _guardianNameController.text.trim(),
        'guardian_phone': _guardianPhoneController.text.trim(),
        'guardian_details_completed': true,
      });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UserDashboard()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope prevents the user from using the hardware back button
    return PopScope(
      canPop: false, // Set to false to disable back button
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Optional: Show a message to the user
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please complete guardian details to continue"),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        body: Container(
          width: double.infinity, height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [lightGreen.withOpacity(0.6), bgColor],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 60),
                  Text("Guardian Information", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkGreen)),
                  const SizedBox(height: 8),
                  Text("This is required for your safety during rides", style: TextStyle(fontSize: 14, color: textGrey)),
                  const SizedBox(height: 40),

                  _buildLabel("GUARDIAN NAME"),
                  _buildTextField(controller: _guardianNameController, hint: "e.g. John Doe", icon: Icons.person_outline),
                  
                  const SizedBox(height: 20),
                  _buildLabel("GUARDIAN PHONE"),
                  _buildTextField(controller: _guardianPhoneController, hint: "9123456789", icon: Icons.phone_android_outlined, keyboardType: TextInputType.phone, maxLength: 10),

                  const SizedBox(height: 50),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _uploadGuardianDetails,
                      style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: _loading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("FINISH SETUP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: darkGreen.withOpacity(0.8))),
  );

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, TextInputType keyboardType = TextInputType.text, int? maxLength}) {
    return TextFormField(
      controller: controller, keyboardType: keyboardType, maxLength: maxLength,
      decoration: InputDecoration(
        hintText: hint, prefixIcon: Icon(icon, color: mutedGreen, size: 18),
        filled: true, fillColor: Colors.white, counterText: "",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}