import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddPaymentMethodPage extends StatefulWidget {
  const AddPaymentMethodPage({super.key});

  @override
  State<AddPaymentMethodPage> createState() => _AddPaymentMethodPageState();
}

class _AddPaymentMethodPageState extends State<AddPaymentMethodPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _numberController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _expController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  
  bool _isLoading = false;
  final Color primaryGreen = const Color(0xFF11A860);

  // --- SAVE CARD LOGIC ---
  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String number = _numberController.text.replaceAll(" ", "");
      String last4 = number.substring(number.length - 4);
      
      // Simple brand detection
      String brand = "Mastercard"; 
      if (number.startsWith("4")) brand = "Visa";
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('payment_methods')
          .add({
        'brand': brand,
        'last4': last4,
        'holder_name': _nameController.text.toUpperCase(),
        'expiry': _expController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save card")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Add Card"), 
        elevation: 0, 
        backgroundColor: Colors.white, 
        foregroundColor: Colors.black
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- CARD PREVIEW ---
              _buildCardPreview(),
              const SizedBox(height: 30),

              // --- FORM ---
              const Text("Card Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              _inputField(
                "Card Number", 
                _numberController, 
                icon: Icons.credit_card, 
                filter: FilteringTextInputFormatter.digitsOnly,
                maxLength: 16,
                onChanged: (v) => setState((){}), // Refresh preview
              ),
              const SizedBox(height: 15),
              
              _inputField(
                "Cardholder Name", 
                _nameController, 
                icon: Icons.person_outline,
                onChanged: (v) => setState((){}),
              ),
              const SizedBox(height: 15),
              
              Row(
                children: [
                  Expanded(
                    child: _inputField(
                      "Expiry (MM/YY)", 
                      _expController, 
                      icon: Icons.calendar_today,
                      maxLength: 5,
                      onChanged: (v) => setState((){}),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _inputField(
                      "CVV", 
                      _cvvController, 
                      icon: Icons.lock_outline, 
                      filter: FilteringTextInputFormatter.digitsOnly, 
                      maxLength: 3,
                      obscure: true,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity, height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                  onPressed: _isLoading ? null : _saveCard,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("SAVE CARD", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- VISUAL WIDGETS ---

  Widget _buildCardPreview() {
    String num = _numberController.text.padRight(16, 'X');
    // Format: XXXX XXXX XXXX XXXX
    String formattedNum = "${num.substring(0,4)} ${num.substring(4,8)} ${num.substring(8,12)} ${num.substring(12,16)}";

    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B5145), Color(0xFF11A860)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.nfc, color: Colors.white70, size: 30),
              Text(
                num.startsWith("4") ? "VISA" : "Mastercard", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, fontSize: 18)
              ),
            ],
          ),
          Text(
            formattedNum,
            style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 2, fontFamily: 'Courier'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Card Holder", style: TextStyle(color: Colors.white60, fontSize: 10)),
                  Text(_nameController.text.isEmpty ? "YOUR NAME" : _nameController.text.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Expires", style: TextStyle(color: Colors.white60, fontSize: 10)),
                  Text(_expController.text.isEmpty ? "MM/YY" : _expController.text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller, {
    IconData? icon, 
    TextInputFormatter? filter, 
    int? maxLength,
    bool obscure = false,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      obscureText: obscure,
      maxLength: maxLength,
      keyboardType: filter != null ? TextInputType.number : TextInputType.text,
      inputFormatters: filter != null ? [filter] : [],
      validator: (v) => v!.isEmpty ? "Required" : null,
      decoration: InputDecoration(
        labelText: label,
        counterText: "",
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}