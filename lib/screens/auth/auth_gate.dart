import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../landing_screen.dart';
import '../user/user_dashboard.dart';
import '../admin/admin_dashboard.dart';
import 'pin_setup_screen.dart';
import 'guardian_details_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. If no user is logged in, show Landing Screen
        if (!snapshot.hasData) {
          return const LandingScreen();
        }

        User user = snapshot.data!;

        // 2. If Admin is logged in, go to Admin Dashboard
        if (user.email == "admin@gmail.com") {
          return const AdminDashboard();
        }

        // 3. For Regular Users, we must check profile completion in Firestore
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            // If the document was deleted by admin or doesn't exist
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              FirebaseAuth.instance.signOut();
              return const LandingScreen();
            }

            var userData = userSnapshot.data!.data() as Map<String, dynamic>;
            bool pinSetup = userData['pin_setup_completed'] ?? false;
            bool guardianSetup = userData['guardian_details_completed'] ?? false;

            // Redirect based on setup progress
            if (!pinSetup) {
              return PinSetupScreen(userId: user.uid);
            } else if (!guardianSetup) {
              return GuardianDetailsScreen(userId: user.uid);
            } else {
              return const UserDashboard();
            }
          },
        );
      },
    );
  }
}