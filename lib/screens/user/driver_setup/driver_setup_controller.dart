import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import your sub-screens
import 'step_profile_pic.dart';
import 'step_dob.dart';
import 'step_email_verification.dart';
import 'step_license_details.dart';
import 'driver_status_screen.dart';

class DriverSetupController extends StatefulWidget {
  const DriverSetupController({super.key});

  @override
  State<DriverSetupController> createState() => _DriverSetupControllerState();
}

class _DriverSetupControllerState extends State<DriverSetupController> {
  final String uid = FirebaseAuth.instance.currentUser!.uid;
  bool _isSubmitting = false;

  // --- FINAL SUBMISSION LOGIC ---
  Future<void> _submitApplication() async {
    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'driver_status': 'pending',
        'appliedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF11A860);
    const Color darkGreen = Color(0xFF2B5145);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text("User data not found")));
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        String status = data['driver_status'] ?? 'not_applied';

        // 1. Check if they have already applied
        if (status == 'pending' || status == 'rejected') {
          return DriverStatusScreen(status: status, appData: data);
        }

        // 2. Extract specific field statuses from Firestore
        bool hasPhoto = data['profile_pic'] != null;
        bool hasDob = data['dob'] != null;
        bool hasEmail = data['email_verified'] == true;
        bool hasLicense = data['license_number'] != null;

        // Requirement check for the Submit button
        bool isAllStepsDone = hasPhoto && hasDob && hasEmail && hasLicense;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              "Driver Verification",
              style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(25),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Complete the Checklist",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkGreen),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Please provide these details to start earning as a driver.",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 30),

                      // STEP 1: PHOTO
                      _buildStepCard(
                        title: "Profile Photo",
                        subtitle: "A clear photo of your face.",
                        icon: Icons.face_rounded,
                        isDone: hasPhoto,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StepProfilePic())),
                      ),

                      // STEP 2: DOB
                      _buildStepCard(
                        title: "Date of Birth",
                        subtitle: "Must be 18 or older.",
                        icon: Icons.cake_rounded,
                        isDone: hasDob,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StepDob())),
                      ),

                      // STEP 3: EMAIL
                      _buildStepCard(
                        title: "Email Verification",
                        subtitle: "Secure your driver profile.",
                        icon: Icons.alternate_email_rounded,
                        isDone: hasEmail,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StepEmailVerification())),
                      ),

                      // STEP 4: LICENSE
                      _buildStepCard(
                        title: "Driving License",
                        subtitle: "Front and back images.",
                        icon: Icons.badge_rounded,
                        isDone: hasLicense,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StepLicenseDetails())),
                      ),
                    ],
                  ),
                ),
              ),

              // --- FINAL ACTION BUTTON ---
              if (isAllStepsDone)
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : _submitApplication,
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "SUBMIT APPLICATION",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDone,
    required VoidCallback onTap,
  }) {
    const Color primaryColor = Color(0xFF11A860);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: isDone ? null : onTap, // Prevent clicking finished steps
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDone ? primaryColor : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDone ? primaryColor.withOpacity(0.05) : Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDone ? primaryColor.withOpacity(0.1) : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDone ? Icons.check_circle : icon,
                  color: isDone ? primaryColor : Colors.grey.shade600,
                  size: 26,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDone ? primaryColor : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDone ? "Information saved successfully" : subtitle,
                      style: TextStyle(
                        color: isDone ? primaryColor.withOpacity(0.7) : Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDone)
                const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}