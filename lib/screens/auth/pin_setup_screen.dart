import 'package:flutter/material.dart';
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
  
  bool _hidePin = true;
  bool _hideConfirmPin = true;
  bool _loading = false;

  // Colors
  final Color primaryGreen = const Color.fromARGB(255, 53, 121, 88);
  final Color lightGreen = const Color(0xFFA2E1CA);
  final Color darkGreen = const Color.fromARGB(255, 21, 61, 49);
  final Color mutedGreen = const Color(0xFF64AA8E);
  final Color bgColor = const Color(0xFFECECEC);
  final Color textGrey = const Color(0xFF727272);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _setupPin() async {
    String pin = _pinController.text.trim();
    String confirmPin = _confirmPinController.text.trim();

    // Validation
    if (pin.isEmpty || confirmPin.isEmpty) {
      _showError("Both fields are required");
      return;
    }

    if (pin != confirmPin) {
      _showError("PINs do not match");
      return;
    }

    if (pin.length != 4 || !pin.isNumericOnly) {
      _showError("PIN must be exactly 4 digits");
      return;
    }

    setState(() => _loading = true);

    try {
      // Update Firestore
      await _firestore.collection('users').doc(widget.userId).update({
        'security_pin': pin,
        'pin_setup_completed': true,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("PIN setup successful"), backgroundColor: primaryGreen),
      );

      // Navigate to Guardian Details Screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GuardianDetailsScreen(userId: widget.userId),
        ),
      );
    } catch (e) {
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
                Text(
                  "Security PIN Setup",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkGreen),
                ),
                const SizedBox(height: 8),
                Text(
                  "Create a 4-digit PIN for your safety",
                  style: TextStyle(fontSize: 14, color: textGrey),
                ),
                const SizedBox(height: 40),
                
                _buildLabel("ENTER PIN"),
                _buildPinField(_pinController, _hidePin, () {
                  setState(() => _hidePin = !_hidePin);
                }),
                
                const SizedBox(height: 20),
                
                _buildLabel("CONFIRM PIN"),
                _buildPinField(_confirmPinController, _hideConfirmPin, () {
                  setState(() => _hideConfirmPin = !_hideConfirmPin);
                }),
                
                const SizedBox(height: 50),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _setupPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            "CONTINUE",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: darkGreen.withOpacity(0.8)),
      ),
    );
  }

  Widget _buildPinField(TextEditingController controller, bool hidePin, VoidCallback onToggle) {
    return TextFormField(
      controller: controller,
      obscureText: hidePin,
      keyboardType: TextInputType.number,
      maxLength: 4,
      decoration: InputDecoration(
        hintText: "••••",
        prefixIcon: Icon(Icons.lock_outline, color: mutedGreen),
        suffixIcon: IconButton(
          icon: Icon(hidePin ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.white,
        counterText: "", // Hides the 0/4 counter
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

extension on String {
  bool get isNumericOnly => RegExp(r'^[0-9]+$').hasMatch(this);
}