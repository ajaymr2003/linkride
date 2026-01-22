import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_name_screen.dart';
import 'login_password_screen.dart';

class EmailEntryScreen extends StatefulWidget {
  const EmailEntryScreen({super.key});

  @override
  State<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends State<EmailEntryScreen> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  // --- STRICT EMAIL VALIDATOR ---
  String? _validateEmail(String? value) {
    final email = value?.trim() ?? "";
    
    if (email.isEmpty) return "Email is required";

    // 1. Block Capital Letters at start
    if (RegExp(r'^[A-Z]').hasMatch(email)) {
      return "Email must start with a lowercase letter";
    }

    // 2. Block Capital Letters anywhere
    if (email != email.toLowerCase()) {
      return "Please use only lowercase letters";
    }

    // 3. Block common typos like 'gmil'
    if (email.contains("gmil")) {
      return "Typo detected: Use 'gmail.com' instead of 'gmil'";
    }

    // 4. Standard Email Regex
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-zA-Z]{2,3}$');
    if (!emailRegex.hasMatch(email)) {
      return "Invalid email format";
    }

    return null;
  }

  // --- CHECK EMAIL LOGIC ---
  Future<void> _checkEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();

    // 1. ADMIN LOGIN BYPASS
    // This allows the admin to proceed without checking the 'users' collection
    if (email == "admin@gmail.com") {
      setState(() => _isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LoginPasswordScreen(email: email)),
      );
      return;
    }

    try {
      // 2. REGULAR USER FIRESTORE CHECK
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      if (!mounted) return;

      if (userQuery.docs.isNotEmpty) {
        // User Found -> Go to Password Login
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LoginPasswordScreen(email: email)),
        );
      } else {
        // New User -> Start Signup Flow
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SignupNameScreen(email: email)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Connection error. Try again."),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 0, 
        foregroundColor: darkGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "What's your email?",
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold, 
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Enter your email to continue. We'll check if you have an account.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
              const SizedBox(height: 40),
              
              TextFormField(
                controller: _emailController,
                validator: _validateEmail,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: "example@gmail.com",
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _checkEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "CONTINUE",
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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}