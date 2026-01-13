import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'signup_screen.dart';
import 'pin_setup_screen.dart';
import 'guardian_details_screen.dart';
import '../user/user_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Colors (Matched to your Design System)
  final Color primaryGreen = const Color.fromARGB(255, 53, 121, 88);
  final Color lightGreen = const Color(0xFFA2E1CA);
  final Color darkGreen = const Color.fromARGB(255, 21, 61, 49);
  final Color mutedGreen = const Color(0xFF64AA8E);
  final Color bgColor = const Color(0xFFECECEC);
  final Color textBlack = const Color(0xFF101212);
  final Color textGrey = const Color(0xFF727272);

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _hidePassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- CENTER ERROR POPUP ---
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 10),
            Text("Login Failed", style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // --- NAVIGATION LOGIC ---
  Future<void> _handlePostLoginNavigation(User user) async {
    final userDoc = await _firestore.collection('users').doc(user.uid).get();

    if (!mounted) return;

    if (!userDoc.exists) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PinSetupScreen(userId: user.uid)),
      );
      return;
    }

    final data = userDoc.data()!;
    final bool pinDone = data['pin_setup_completed'] ?? false;
    final bool guardianDone = data['guardian_details_completed'] ?? false;

    if (!pinDone) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PinSetupScreen(userId: user.uid)),
      );
    } else if (!guardianDone) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GuardianDetailsScreen(userId: user.uid)),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserDashboard()),
      );
    }
  }

  // --- EMAIL LOGIN ---
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorDialog("Please enter both email and password.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (userCredential.user != null) {
        await _handlePostLoginNavigation(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      // Logic to determine user-friendly message
      String errorMsg = "Incorrect email or password. Please try again.";
      
      if (e.code == 'user-not-found') {
        errorMsg = "No account found with this email.";
      } else if (e.code == 'wrong-password') {
        errorMsg = "The password you entered is incorrect.";
      } else if (e.code == 'invalid-email') {
        errorMsg = "The email address is not valid.";
      }
      
      _showErrorDialog(errorMsg); // Show the Center Popup
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- GOOGLE LOGIN ---
  Future<void> _handleGoogleLogin() async {
    try {
      setState(() => _isLoading = true);
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        final userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
        if (!userDoc.exists) {
          await _firestore.collection('users').doc(userCredential.user!.uid).set({
            'uid': userCredential.user!.uid,
            'name': userCredential.user!.displayName ?? 'User',
            'email': userCredential.user!.email ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'pin_setup_completed': false,
            'guardian_details_completed': false,
          });
        }
        await _handlePostLoginNavigation(userCredential.user!);
      }
    } catch (e) {
      _showErrorDialog("Google Login failed. Please check your connection.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                const SizedBox(height: 70),
                Text("Welcome Back", 
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkGreen)),
                const SizedBox(height: 8),
                Text("Login to continue your journey", 
                    style: TextStyle(fontSize: 14, color: textGrey)),
                const SizedBox(height: 50),

                _inputLabel("EMAIL ADDRESS"),
                _inputField(_emailController, "john@example.com", Icons.email_outlined),

                const SizedBox(height: 20),
                _inputLabel("PASSWORD"),
                _passwordField(),

                const SizedBox(height: 15),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      // Forgot Password logic
                    },
                    child: Text("Forgot Password?", 
                        style: TextStyle(color: primaryGreen, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("LOGIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 25),
                
                Row(
                  children: [
                    Expanded(child: Divider(color: textGrey.withOpacity(0.3))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text("OR", style: TextStyle(color: textGrey.withOpacity(0.6), fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: textGrey.withOpacity(0.3))),
                  ],
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity, height: 52,
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _handleGoogleLogin,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: textGrey.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.g_mobiledata, color: Colors.red, size: 35),
                        const SizedBox(width: 8),
                        Text("Continue with Google", 
                            style: TextStyle(color: textBlack, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                    child: RichText(
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: textGrey),
                        children: [
                          TextSpan(text: "Sign Up", 
                              style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _inputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: darkGreen.withOpacity(0.8))),
    );
  }

  Widget _inputField(TextEditingController controller, String hint, IconData icon) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: textBlack, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: textGrey.withOpacity(0.4), fontSize: 14),
        prefixIcon: Icon(icon, color: mutedGreen, size: 20),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _hidePassword,
      style: TextStyle(color: textBlack, fontSize: 15),
      decoration: InputDecoration(
        hintText: "••••••••",
        hintStyle: TextStyle(color: textGrey.withOpacity(0.4), fontSize: 14),
        prefixIcon: Icon(Icons.lock_outline, color: mutedGreen, size: 20),
        suffixIcon: IconButton(
          icon: Icon(_hidePassword ? Icons.visibility_off : Icons.visibility, size: 18, color: textGrey),
          onPressed: () => setState(() => _hidePassword = !_hidePassword),
        ),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}