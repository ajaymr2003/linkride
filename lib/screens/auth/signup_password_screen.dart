import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pin_setup_screen.dart';

class SignupPasswordScreen extends StatefulWidget {
  final String email;
  final String name;
  final String phone;

  const SignupPasswordScreen({
    super.key,
    required this.email,
    required this.name,
    required this.phone,
  });

  @override
  State<SignupPasswordScreen> createState() => _SignupPasswordScreenState();
}

class _SignupPasswordScreenState extends State<SignupPasswordScreen> {
  final TextEditingController _passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _isPasswordVisible = false;

  final Color primaryGreen = const Color.fromARGB(255, 53, 121, 88);
  final Color darkGreen = const Color.fromARGB(255, 21, 61, 49);

  // --- FRONTEND PASSWORD VALIDATOR ---
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return "Password is required";

    if (value.length < 8) return "Minimum 8 characters required";

    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return "Must contain at least one uppercase letter";
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return "Must contain at least one lowercase letter";
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return "Must contain at least one number";
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return "Must contain at least one special character";
    }

    return null;
  }

  Future<void> _completeSignup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      // 1. Create User in Firebase Auth
      final userCred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: widget.email,
            password: _passController.text.trim(),
          );

      // 2. Save Details to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .set({
            'uid': userCred.user!.uid,
            'name': widget.name,
            'email': widget.email,
            'phone': widget.phone,
            'createdAt': FieldValue.serverTimestamp(),
            'pin_setup_completed': false, // Default false
            'guardian_details_completed': false, // Default false
          });

      if (!mounted) return;

      // 3. REDIRECT TO PIN SETUP (Not Dashboard)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PinSetupScreen(userId: userCred.user!.uid),
        ),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Signup failed"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
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
                "Create a password",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Use 8 or more characters with a mix of letters, numbers & symbols",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              TextFormField(
                controller: _passController,
                obscureText: !_isPasswordVisible,
                validator: _validatePassword,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Password",
                  filled: true,
                  fillColor: Colors.grey[200],
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  errorMaxLines: 2, // Allows long error messages to wrap
                ),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _loading ? null : _completeSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "SIGN UP",
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
