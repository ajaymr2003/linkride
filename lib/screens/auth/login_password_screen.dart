import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import '../admin/admin_dashboard.dart';
import '../user/dashboard/user_dashboard.dart';
import 'pin_setup_screen.dart';
import 'guardian_details_screen.dart';
import 'forgot_password_screen.dart';

class LoginPasswordScreen extends StatefulWidget {
  final String email;
  const LoginPasswordScreen({super.key, required this.email});

  @override
  State<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
}

class _LoginPasswordScreenState extends State<LoginPasswordScreen> {
  final TextEditingController _passController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  // --- SHOW ERROR POPUP ---
  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          "Login Issue",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- REQUEST NOTIFICATION PERMISSION ---
  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    debugPrint("Notification permission status: $status");
  }

  // --- GET FCM TOKEN WITH RETRY ---
  Future<String?> _getFCMTokenWithRetry({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          return token;
        }
        debugPrint("FCM Token attempt ${i + 1}: null, retrying...");
      } catch (e) {
        debugPrint("FCM Token attempt ${i + 1} failed: $e");
        if (i < maxRetries - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    return null;
  }

  // --- LOGIN LOGIC ---
  Future<void> _login() async {
    final password = _passController.text.trim();
    if (password.isEmpty) {
      _showErrorPopup("Please enter your password.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. SIGN IN WITH FIREBASE
      UserCredential userCred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: widget.email, password: password);

      // 2. CHECK IF ADMIN
      if (userCred.user!.email == "admin@gmail.com") {
        setState(() => _isLoading = false);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
          (r) => false,
        );
        return;
      }

      // 3. REGULAR USER: CHECK FIRESTORE
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCred.user!.uid)
          .get();

      if (!userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        _showErrorPopup("This account has been disabled or deleted.");
        setState(() => _isLoading = false);
        return;
      }

      // --- 4. UPDATE FCM TOKEN (NEW LOGIC) ---
      try {
        // Request notification permission first (Android 13+)
        await _requestNotificationPermission();

        // Get FCM token with retry logic
        String? fcmToken = await _getFCMTokenWithRetry();
        if (fcmToken != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCred.user!.uid)
              .update({'fcm_token': fcmToken});
          debugPrint("FCM Token updated successfully: $fcmToken");
        } else {
          debugPrint("FCM Token is null");
        }
      } catch (e) {
        debugPrint("FCM Token Error: $e");
        // Don't stop login flow, FCM is optional
      }
      // ---------------------------------------

      // 5. FETCH SETUP FLAGS
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
      bool pinSetup = userData['pin_setup_completed'] ?? false;
      bool guardianSetup = userData['guardian_details_completed'] ?? false;

      if (!mounted) return;

      // 6. REDIRECTION LOGIC
      if (!pinSetup) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => PinSetupScreen(userId: userCred.user!.uid),
          ),
          (r) => false,
        );
      } else if (!guardianSetup) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => GuardianDetailsScreen(userId: userCred.user!.uid),
          ),
          (r) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const UserDashboard()),
          (r) => false,
        );
      }
    } on FirebaseAuthException {
      _showErrorPopup("Incorrect password or authentication failed.");
    } catch (e) {
      _showErrorPopup("A connection error occurred. Check your internet.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.email.toLowerCase() == "admin@gmail.com";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: darkGreen,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAdmin ? "Admin Portal" : "Welcome back!",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Continue as ${widget.email}",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
              const SizedBox(height: 40),

              TextFormField(
                controller: _passController,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: "Enter your password",
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
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              if (!isAdmin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ForgotPasswordScreen(email: widget.email),
                        ),
                      );
                    },
                    child: Text(
                      "Forgot Password?",
                      style: TextStyle(
                        color: primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 100),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
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
                          "LOG IN",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1,
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
    _passController.dispose();
    super.dispose();
  }
}
