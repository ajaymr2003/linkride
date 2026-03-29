import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:telephony/telephony.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/fcm_service.dart';

class SosButton extends StatefulWidget {
  final String uid;
  final String? passengerName;
  final String? guardianPhone;
  final LatLng? currentPos;

  const SosButton({
    super.key,
    required this.uid,
    this.passengerName,
    this.guardianPhone,
    this.currentPos,
  });

  @override
  State<SosButton> createState() => _SosButtonState();

  // Platform channel for native SMS sending (static for use in static methods)
  static const platform = MethodChannel('com.linkride/sms');

  /// STATIC METHOD: Send Guardian Mode tracking link
  static Future<bool> sendGuardianLink({
    required String passengerUid,
    String? guardianPhone,
    String? passengerName,
  }) async {
    if (guardianPhone == null || guardianPhone.isEmpty) {
      debugPrint("❌ Guardian phone not available");
      return false;
    }

    try {
      debugPrint("📱 Sending Guardian Mode link to $guardianPhone");

      // Format phone number
      String formattedPhone = _formatPhoneNumberStatic(guardianPhone);
      debugPrint("📞 Formatted phone: $formattedPhone");

      // Create tracking link
      final String trackingLink =
          "https://guardian-mode.vercel.app/?uid=$passengerUid";
      final String message =
          "🛡️ Guardian Mode Enabled\n${passengerName ?? 'A passenger'} has enabled live trip tracking.\nWatch in real-time: $trackingLink";

      debugPrint("📝 Message: $message");

      // Send via native Android SMS Manager
      try {
        final result = await platform.invokeMethod('sendSms', {
          'phoneNumber': formattedPhone,
          'message': message,
        });

        if (result == true) {
          debugPrint("✅ Guardian link sent successfully");
          return true;
        }
      } on PlatformException catch (e) {
        debugPrint("❌ Platform exception: ${e.message}");
      }
      return false;
    } catch (e) {
      debugPrint("❌ Error sending guardian link: $e");
      return false;
    }
  }

  /// Static method to format phone number
  static String _formatPhoneNumberStatic(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    if (cleaned.length == 10) {
      return "+91$cleaned";
    }

    if (cleaned.length == 12) {
      return "+$cleaned";
    }

    return "+$cleaned";
  }
}

class _SosButtonState extends State<SosButton> {
  bool _sosSending = false;
  final Telephony telephony = Telephony.instance;

  /// Validates phone number format
  String? _validatePhoneNumber(String phone) {
    if (phone.isEmpty) return "Phone number is empty";
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.length < 10) return "Invalid phone number (too short)";
    return null;
  }

  /// Format phone number with country code (adds +91 for India if needed)
  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // If already has + prefix, return as is
    if (cleaned.startsWith('+')) {
      return cleaned;
    }

    // If starts with 0, remove it
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // If 10 digits (India mobile), add +91
    if (cleaned.length == 10) {
      return "+91$cleaned";
    }

    // If already has country code, add +
    if (cleaned.length == 12) {
      return "+$cleaned";
    }

    // Return as is
    return "+$cleaned";
  }

  /// Request SMS permission from user
  Future<bool> _requestSmsPermission() async {
    try {
      PermissionStatus status = await Permission.sms.request();
      debugPrint("📋 SMS Permission Status: $status");

      if (!status.isGranted) {
        if (status.isDenied) {
          debugPrint("❌ SMS permission denied by user");
        } else if (status.isPermanentlyDenied) {
          debugPrint("❌ SMS permission permanently denied");
          openAppSettings();
        }
        return false;
      }
      debugPrint("✅ SMS permission granted");
      return true;
    } catch (e) {
      debugPrint("❌ Permission request error: $e");
      return false;
    }
  }

  /// Send SMS via native Android SMS Manager API
  Future<bool> _sendSmsDirect(String phone, String message) async {
    try {
      debugPrint("📱 Attempting direct SMS to: $phone");
      debugPrint("📝 Message: $message");

      // Format phone number properly with country code
      String formattedPhone = _formatPhoneNumber(phone);
      debugPrint("📞 Formatted phone: $formattedPhone");

      if (Platform.isAndroid) {
        debugPrint("🤖 Sending SMS via Android native API...");

        try {
          // Call native Android method
          final result = await SosButton.platform.invokeMethod('sendSms', {
            'phoneNumber': formattedPhone,
            'message': message,
          });

          if (result == true) {
            debugPrint("✅ SMS queued for sending to $formattedPhone");
            return true;
          } else {
            debugPrint("⚠️ Native SMS method returned false");
            return false;
          }
        } on PlatformException catch (e) {
          debugPrint("❌ Platform exception: ${e.message}");
          return false;
        }
      } else if (Platform.isIOS) {
        debugPrint("🍎 iOS detected - will use SMS fallback");
        return false;
      }

      return false;
    } catch (e) {
      debugPrint("❌ Direct SMS failed: $e");
      debugPrint("Error type: ${e.runtimeType}");
      return false;
    }
  }

  Future<void> _triggerEmergencySOS() async {
    if (_sosSending) return;

    // Validate input data
    if (widget.guardianPhone == null || widget.currentPos == null) {
      _showError("Location or Guardian phone not ready");
      return;
    }

    // Validate phone number format
    String? phoneError = _validatePhoneNumber(widget.guardianPhone!);
    if (phoneError != null) {
      _showError(phoneError);
      return;
    }

    setState(() => _sosSending = true);

    final String trackingLink =
        "https://guardian-mode.vercel.app/?uid=${widget.uid}";
    final String message =
        "🚨 EMERGENCY! ${widget.passengerName ?? 'LinkRide Passenger'} triggered SOS. Track: $trackingLink";

    bool smsSuccess = false;

    // --- STEP 1: REQUEST PERMISSION ---
    debugPrint("🔐 Step 1: Requesting SMS permission...");
    bool hasPermission = await _requestSmsPermission();

    // --- STEP 2: SEND SMS (if permission granted) ---
    if (hasPermission) {
      debugPrint("🔐 Step 2: Attempting to send SMS...");
      smsSuccess = await _sendSmsDirect(widget.guardianPhone!, message);
    }

    // --- STEP 3: FALLBACK TO SMS APP ---
    if (!smsSuccess) {
      debugPrint("⚠️ Step 3: Opening SMS app fallback...");
      await _launchSmsFallback(message);
    }

    // --- STEP 4: NOTIFY ADMIN ---
    debugPrint("📢 Step 4: Notifying admin...");
    await _notifyAdmin(trackingLink);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            smsSuccess
                ? "✅ SOS Sent to ${widget.guardianPhone}"
                : "⚠️ SMS app opened - send manually",
          ),
          backgroundColor: smsSuccess
              ? Colors.green.shade700
              : Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    await Future.delayed(const Duration(seconds: 10));
    if (mounted) setState(() => _sosSending = false);
  }

  /// Notify admin via Firestore
  Future<void> _notifyAdmin(String trackingLink) async {
    try {
      var adminQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: 'admin@gmail.com')
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        var adminDoc = adminQuery.docs.first;
        String adminUid = adminDoc.id;
        String? adminToken = adminDoc.data()['fcm_token'];

        await FirebaseFirestore.instance.collection('notifications').add({
          'uid': adminUid,
          'title': '🚨 SOS EMERGENCY!',
          'message': '${widget.passengerName ?? 'A user'} triggered SOS',
          'type': 'sos_alert',
          'passenger_uid': widget.uid,
          'guardian_phone': widget.guardianPhone,
          'tracking_link': trackingLink,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'location': {
            'latitude': widget.currentPos?.latitude,
            'longitude': widget.currentPos?.longitude,
          },
        });

        if (adminToken != null) {
          try {
            await FCMService.sendPushNotification(
              token: adminToken,
              title: "🚨 SOS EMERGENCY!",
              body: "${widget.passengerName ?? 'User'} needs help NOW!",
            );
            debugPrint("✅ Admin notification sent");
          } catch (e) {
            debugPrint("⚠️ Admin notification failed: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("❌ Admin notification error: $e");
    }
  }

  /// Open SMS app as fallback
  Future<void> _launchSmsFallback(String msg) async {
    try {
      final String formattedPhone = _formatPhoneNumber(widget.guardianPhone!);
      final Uri smsUri = Uri.parse(
        "sms:$formattedPhone?body=${Uri.encodeComponent(msg)}",
      );
      debugPrint("📲 Opening SMS app: $smsUri");

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        debugPrint("✅ SMS app opened successfully");
      } else {
        debugPrint("❌ Cannot launch SMS app");
      }
    } catch (e) {
      debugPrint("❌ Fallback error: $e");
    }
  }

  void _showError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("❌ Error: $error"),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _sosSending ? null : _triggerEmergencySOS,
      icon: _sosSending
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.warning_amber_rounded, color: Colors.white),
      label: Text(
        _sosSending ? "SENDING..." : "SOS",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade700,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }
}
