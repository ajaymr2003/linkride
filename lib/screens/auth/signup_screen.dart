import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Field Keys
  final _nameKey = GlobalKey<FormFieldState>();
  final _emailKey = GlobalKey<FormFieldState>();
  final _phoneKey = GlobalKey<FormFieldState>();
  final _passwordKey = GlobalKey<FormFieldState>();

  // FocusNodes
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _phoneFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  bool _hidePassword = true;

  // Design Colors
  final Color primaryGreen = const Color.fromARGB(255, 53, 121, 88);
  final Color darkGreen = const Color.fromARGB(255, 21, 61, 49);
  final Color mutedGreen = const Color(0xFF64AA8E);
  final Color bgColor = const Color(0xFFECECEC);
  final Color textBlack = const Color(0xFF101212);
  final Color textGrey = const Color(0xFF727272);

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
  }

  void _setupFocusListeners() {
    void handleFocus(FocusNode node, GlobalKey<FormFieldState> key) {
      node.addListener(() {
        key.currentState?.validate();
      });
    }
    handleFocus(_nameFocus, _nameKey);
    handleFocus(_emailFocus, _emailKey);
    handleFocus(_phoneFocus, _phoneKey);
    handleFocus(_passwordFocus, _passwordKey);
  }

  @override
  void dispose() {
    _nameController.dispose(); _emailController.dispose();
    _phoneController.dispose(); _passwordController.dispose();
    _nameFocus.dispose(); _emailFocus.dispose();
    _phoneFocus.dispose(); _passwordFocus.dispose();
    super.dispose();
  }

  // --- ERROR POPUP DIALOG ---
  void _showEmailInUsePopup() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 10),
            Text("Registration Error", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "This email address is already in use by another account. Please use a different email or try logging in.",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
            child: const Text("LOGIN", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- VALIDATORS ---
  String? _validateEmail(String? value) {
    if (_emailFocus.hasFocus) return null; 
    final email = value?.trim() ?? "";
    if (email.isEmpty) return "Email is required";
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[a-zA-Z]{2,4}$');
    if (!emailRegex.hasMatch(email)) return "Please enter a valid email address";
    
    List<String> parts = email.split('.');
    if (parts.length > 1) {
      String tld = parts.last;
      if (tld.length < 2 || tld.length > 3) return "Invalid extension (.co and .com allowed)";
    }
    return null;
  }

  String? _validateName(String? value) {
    if (_nameFocus.hasFocus) return null;
    if (value == null || value.trim().isEmpty) return "Name is required";
    return null;
  }

  String? _validatePhone(String? value) {
    if (_phoneFocus.hasFocus) return null;
    if (value == null || value.trim().isEmpty || value.length != 10) return "Valid 10-digit number required";
    return null;
  }

  String? _validatePassword(String? value) {
    if (_passwordFocus.hasFocus) return null;
    if (value == null || value.length < 6) return "Min 6 characters required";
    return null;
  }

  // --- EMAIL SIGN UP ACTION ---
  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 100));

    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    try {
      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
        'uid': userCred.user!.uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'pin_setup_completed': false,
        'guardian_details_completed': false,
      });

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showEmailInUsePopup(); // Display center popup for duplicate email
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- GOOGLE SIGN UP ---
  Future<void> _handleGoogleSignUp() async {
    try {
      setState(() => _loading = true);
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) { setState(() => _loading = false); return; }
      final googleAuth = await googleUser.authentication;
      final cred = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      if (userCred.user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).get();
        if (!doc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
            'uid': userCred.user!.uid, 'name': userCred.user!.displayName ?? 'User',
            'email': userCred.user!.email ?? '', 'phone': '', 'createdAt': FieldValue.serverTimestamp(),
            'pin_setup_completed': false, 'guardian_details_completed': false,
          });
        }
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Google Sign-Up failed")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: [primaryGreen.withOpacity(0.1), bgColor])),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  Text("Create Account", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkGreen)),
                  const SizedBox(height: 30),

                  _buildField(_nameKey, _nameController, _nameFocus, "FULL NAME", "John Doe", Icons.person_outline, _validateName),
                  const SizedBox(height: 16),
                  _buildField(_emailKey, _emailController, _emailFocus, "EMAIL ADDRESS", "name@gmail.com", Icons.email_outlined, _validateEmail, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildField(_phoneKey, _phoneController, _phoneFocus, "PHONE NUMBER", "9123456789", Icons.phone_android_outlined, _validatePhone, keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildPasswordField(),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("SIGN UP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: OutlinedButton(
                      onPressed: _loading ? null : _handleGoogleSignUp,
                      style: OutlinedButton.styleFrom(side: BorderSide(color: textGrey.withOpacity(0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.g_mobiledata, color: Colors.red, size: 35),
                          const SizedBox(width: 8),
                          Text("Continue with Google", style: TextStyle(color: textBlack, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: RichText(
                        text: TextSpan(
                          text: "Already have an account? ",
                          style: TextStyle(color: textGrey),
                          children: [
                            TextSpan(text: "Login", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(GlobalKey<FormFieldState> key, TextEditingController controller, FocusNode focus, String label, String hint, IconData icon, String? Function(String?) validator, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: darkGreen.withOpacity(0.8))),
        const SizedBox(height: 5),
        TextFormField(
          key: key, controller: controller, focusNode: focus, validator: validator, keyboardType: keyboardType,
          style: TextStyle(color: textBlack, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint, prefixIcon: Icon(icon, color: mutedGreen, size: 18),
            filled: true, fillColor: Colors.white,
            errorStyle: const TextStyle(color: Colors.redAccent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("PASSWORD", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: darkGreen.withOpacity(0.8))),
        const SizedBox(height: 5),
        TextFormField(
          key: _passwordKey, controller: _passwordController, focusNode: _passwordFocus,
          obscureText: _hidePassword, validator: _validatePassword,
          style: TextStyle(color: textBlack, fontSize: 15),
          decoration: InputDecoration(
            hintText: "••••••••", prefixIcon: Icon(Icons.lock_outline, color: mutedGreen, size: 18),
            suffixIcon: IconButton(icon: Icon(_hidePassword ? Icons.visibility_off : Icons.visibility, size: 18, color: textGrey), onPressed: () => setState(() => _hidePassword = !_hidePassword)),
            filled: true, fillColor: Colors.white,
            errorStyle: const TextStyle(color: Colors.redAccent),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}