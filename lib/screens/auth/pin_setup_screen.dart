import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'guardian_details_screen.dart';

class PinSetupScreen extends StatefulWidget {
  final String userId;
  const PinSetupScreen({super.key, required this.userId});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _isLoading = false;

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<void> _savePin() async {
    String pin = _pinController.text.trim();
    String confirm = _confirmPinController.text.trim();

    if (pin.length != 4 || confirm.length != 4) {
      _showSnackbar("PIN must be exactly 4 digits", Colors.orange);
      return;
    }

    if (pin != confirm) {
      _showSnackbar("PINs do not match", Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
        'security_pin': pin,
        'pin_setup_completed': true,
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GuardianDetailsScreen(userId: widget.userId)),
      );
    } catch (e) {
      _showSnackbar("Error saving PIN. Try again.", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Text("Security PIN", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkGreen)),
              const SizedBox(height: 10),
              Text("Create a 4-digit PIN to secure your rides and account changes.", style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 50),

              _buildPinField("Enter 4-Digit PIN", _pinController),
              const SizedBox(height: 25),
              _buildPinField("Confirm PIN", _confirmPinController),

              const SizedBox(height: 60),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("CONTINUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, letterSpacing: 20, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        counterText: "",
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      ),
    );
  }
}