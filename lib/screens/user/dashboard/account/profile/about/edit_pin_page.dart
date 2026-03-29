import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditPinPage extends StatefulWidget {
  const EditPinPage({super.key});

  @override
  State<EditPinPage> createState() => _EditPinPageState();
}

class _EditPinPageState extends State<EditPinPage> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _updatePin() async {
    String pin = _pinController.text;
    String confirm = _confirmPinController.text;

    if (pin.length < 4) {
      _showMsg("PIN must be 4 digits", Colors.orange);
      return;
    }
    if (pin != confirm) {
      _showMsg("PINs do not match", Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'security_pin': pin,
      });
      if (mounted) {
        Navigator.pop(context);
        _showMsg("Security PIN updated successfully", const Color(0xFF11A860));
      }
    } catch (e) {
      _showMsg("Update failed", Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Security PIN"), elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          children: [
            const Icon(Icons.lock_reset, size: 80, color: Color(0xFF11A860)),
            const SizedBox(height: 20),
            const Text("Change Security PIN", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("This PIN is required by the driver to confirm your arrival at the destination.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            
            _buildPinField("New 4-Digit PIN", _pinController),
            const SizedBox(height: 20),
            _buildPinField("Confirm New PIN", _confirmPinController),
            
            const SizedBox(height: 60),
            
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF11A860), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _isLoading ? null : _updatePin,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("UPDATE PIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPinField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 4,
      obscureText: true,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, letterSpacing: 20, fontWeight: FontWeight.bold),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: "",
        border: const OutlineInputBorder(),
        floatingLabelAlignment: FloatingLabelAlignment.center,
      ),
    );
  }
}