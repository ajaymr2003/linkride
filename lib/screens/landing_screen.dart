import 'package:flutter/material.dart';
import 'auth/email_entry_screen.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Standardizing colors to match your account and auth pages
    final Color primaryGreen = const Color(0xFF11A860);
    final Color darkGreen = const Color(0xFF2B5145);

    return Scaffold(
      backgroundColor: Colors.white, // Clean white background
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            
            // 1. The Image you downloaded
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Image.asset(
                'assets/landing_image.png',
                fit: BoxFit.contain,
              ),
            ),
            
            const SizedBox(height: 40),

            // 2. Welcome Text
            Text(
              "Welcome to LinkRide",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: darkGreen,
              ),
            ),
            
            const SizedBox(height: 15),

            // 3. Subtext
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Experience the new way of commuting with safety and ease.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ),

            const Spacer(),

            // 4. Get Started Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EmailEntryScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "GET STARTED",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}