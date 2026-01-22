import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for input formatters
import 'signup_password_screen.dart';

class SignupPhoneScreen extends StatefulWidget {
  final String email;
  final String name;
  const SignupPhoneScreen({super.key, required this.email, required this.name});

  @override
  State<SignupPhoneScreen> createState() => _SignupPhoneScreenState();
}

class _SignupPhoneScreenState extends State<SignupPhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Design System Colors
  final Color primaryGreen = const Color.fromARGB(255, 53, 121, 88);
  final Color darkGreen = const Color.fromARGB(255, 21, 61, 49);

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return "Phone number is required";
    
    // Check if it contains exactly 10 digits
    if (value.length != 10) return "Must be exactly 10 digits";

    // Check if starts with 6, 7, 8, or 9
    final indianMobilePattern = RegExp(r'^[6-9]');
    if (!indianMobilePattern.hasMatch(value)) {
      return "Invalid start digit. Indian numbers start with 6, 7, 8, or 9";
    }

    return null;
  }

  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SignupPasswordScreen(
            email: widget.email,
            name: widget.name,
            phone: _phoneController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Enter phone number",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "A 10-digit number is required for verification",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              TextFormField(
                controller: _phoneController,
                validator: _validatePhone,
                keyboardType: TextInputType.phone,
                maxLength: 10, // Prevents entering more than 10 digits
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly, // Blocks non-numeric keys
                ],
                style: const TextStyle(fontSize: 18, letterSpacing: 2),
                decoration: InputDecoration(
                  counterText: "", // Hides the character counter
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Text(
                      "+91 ",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                  ),
                  hintText: "00000 00000",
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  errorStyle: const TextStyle(color: Colors.redAccent),
                ),
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "NEXT",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}