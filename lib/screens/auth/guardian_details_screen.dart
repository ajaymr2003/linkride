import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../user/user_dashboard.dart';

class GuardianDetailsScreen extends StatefulWidget {
  final String userId;
  const GuardianDetailsScreen({super.key, required this.userId});

  @override
  State<GuardianDetailsScreen> createState() => _GuardianDetailsScreenState();
}

class _GuardianDetailsScreenState extends State<GuardianDetailsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  // --- POPUP ALERT FUNCTION ---
  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title, style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // --- SAVE LOGIC ---
  Future<void> _saveGuardian() async {
    // 1. Basic Form Validation
    if (!_formKey.currentState!.validate()) return;

    final String name = _nameController.text.trim();
    final String phone = _phoneController.text.trim();

    // 2. Strict Phone Validation for Popup
    final indianMobilePattern = RegExp(r'^[6-9]\d{9}$'); // Starts with 6-9 and exactly 10 digits
    
    if (!indianMobilePattern.hasMatch(phone)) {
      _showAlert("Invalid Number", "Please enter a valid 10-digit mobile number starting with 6, 7, 8, or 9.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 3. Check if Guardian Phone is the same as User Phone
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      
      String userPhone = userDoc['phone'] ?? "";

      if (userPhone == phone) {
        setState(() => _isLoading = false);
        _showAlert("Duplicate Number", "Guardian phone cannot be the same as your own phone number. Please provide an emergency contact.");
        return;
      }

      // 4. Update Firestore
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'guardian_name': name,
        'guardian_phone': phone,
        'guardian_details_completed': true,
      });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UserDashboard()),
        (route) => false,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showAlert("System Error", "Could not save details. Please check your internet connection.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, 
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0, foregroundColor: darkGreen),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Guardian Details", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkGreen)),
                  const SizedBox(height: 10),
                  Text("Provide an emergency contact for your safety.", style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                  const SizedBox(height: 40),

                  // NAME
                  _buildLabel("GUARDIAN FULL NAME"),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v!.isEmpty ? "Name is required" : null,
                    decoration: _inputStyle("Enter Name", Icons.person_outline),
                  ),

                  const SizedBox(height: 25),

                  // PHONE
                  _buildLabel("GUARDIAN MOBILE NUMBER"),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _inputStyle("10-Digit Number", Icons.phone_android).copyWith(
                      prefixText: "+91 ",
                      prefixStyle: TextStyle(fontWeight: FontWeight.bold, color: darkGreen),
                      counterText: "",
                    ),
                  ),

                  const SizedBox(height: 60),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveGuardian,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("FINISH SETUP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: darkGreen.withOpacity(0.7))),
    );
  }

  InputDecoration _inputStyle(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryGreen),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
    );
  }
}