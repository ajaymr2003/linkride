import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../services/cloudinary_service.dart';

// Import your sub-screens exactly as they are named in your directory
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
  final PageController _pageController = PageController();
  final User? user = FirebaseAuth.instance.currentUser;

  // --- LOADING / STATUS STATES ---
  bool _isLoading = true;       
  bool _isSubmitting = false;   
  String _driverStatus = 'not_applied';
  Map<String, dynamic>? _appData;

  // --- IN-MEMORY DATA STORAGE (The "Fix") ---
  // We store these here so we don't upload them step-by-step
  File? _tempProfilePic;
  String? _tempDob;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
  }

  Future<void> _checkCurrentStatus() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();

      _driverStatus = userDoc.data()?['driver_status'] ?? 'not_applied';

      if (_driverStatus == 'pending' || _driverStatus == 'rejected') {
        final appDoc = await FirebaseFirestore.instance
            .collection('driver_applications')
            .doc(user!.uid)
            .get();
        _appData = appDoc.data();
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// --- FINAL SUBMISSION LOGIC ---
  /// This is the ONLY function that touches Cloudinary and Firestore
  Future<void> _handleFinalSubmission(String dlNumber, File frontImg, File backImg) async {
    setState(() => _isSubmitting = true);

    try {
      // 1. Upload all 3 images to Cloudinary at once
      // We use Future.wait to upload them in parallel (faster)
      final results = await Future.wait([
        CloudinaryService.uploadImage(_tempProfilePic!),
        CloudinaryService.uploadImage(frontImg),
        CloudinaryService.uploadImage(backImg),
      ]);

      final String? pUrl = results[0];
      final String? fUrl = results[1];
      final String? bUrl = results[2];

      if (pUrl == null || fUrl == null || bUrl == null) {
        throw Exception("Image upload failed. Please check your connection.");
      }

      // 2. Update Database using a Batch (Atomic)
      final WriteBatch batch = FirebaseFirestore.instance.batch();
      final DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final DocumentReference appRef = FirebaseFirestore.instance.collection('driver_applications').doc(user!.uid);

      batch.update(userRef, {
        'driver_status': 'pending',
      });

      batch.set(appRef, {
        'uid': user!.uid,
        'license_number': dlNumber.toUpperCase().replaceAll(" ", ""),
        'dob': _tempDob,
        'profile_pic': pUrl,
        'license_front': fUrl,
        'license_back': bUrl,
        'status': 'pending',
        'rejection_reason': '',
        'appliedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Refresh to show the Status Screen
      await _checkCurrentStatus();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If user has already applied, show status
    if (_driverStatus == 'pending' || _driverStatus == 'rejected') {
      return DriverStatusScreen(
        status: _driverStatus, 
        appData: _appData
      );
    }

    // REGISTRATION FLOW (In-Memory)
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Registration"),
        elevation: 0,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), 
        children: [
          // Step 1: Profile Pic
          // Parameter: onNext(File)
          StepProfilePic(onNext: (file) {
            _tempProfilePic = file;
            _nextPage();
          }),

          // Step 2: Date of Birth
          // Parameter: onDateSelected(String)
          StepDob(onDateSelected: (date) {
            _tempDob = date;
            _nextPage();
          }),

          // Step 3: Email Verification
          // Parameter: onVerified()
          StepEmailVerification(onVerified: () {
            _nextPage();
          }),

          // Step 4: License & Final Submit
          // Parameters: isSubmitting, onFinalSubmit(String, File, File)
          StepLicenseDetails(
            isSubmitting: _isSubmitting,
            onFinalSubmit: (dl, front, back) => _handleFinalSubmission(dl, front, back),
          ),
        ],
      ),
    );
  }
}