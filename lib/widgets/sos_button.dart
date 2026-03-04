import 'dart:io';
import 'package:flutter/material.dart';
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
}

class _SosButtonState extends State<SosButton> {
  bool _sosSending = false;
  final Telephony telephony = Telephony.instance;

  Future<void> _triggerEmergencySOS() async {
    if (_sosSending) return; // Prevent multiple clicks
    
    if (widget.guardianPhone == null || widget.currentPos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location or Guardian data not ready..."))
      );
      return;
    }

    setState(() => _sosSending = true);

    // The tracking link for the guardian/admin
    final String trackingLink = "https://guardian-mode.vercel.app/?uid=${widget.uid}";
    final String message = "🚨 EMERGENCY! LinkRide SOS triggered by ${widget.passengerName ?? 'Passenger'}. Track live location: $trackingLink";

    // --- 1. SEND SMS TO GUARDIAN ---
    try {
      if (Platform.isAndroid) {
        // Request Permission
        var status = await Permission.sms.request();
        
        if (status.isGranted) {
          // CRITICAL: Removed statusListener to prevent Android 14 crash
          await telephony.sendSms(
            to: widget.guardianPhone!, 
            message: message,
          );
          debugPrint("Background SMS sent");
        } else {
          // Fallback if permission denied
          await _launchSmsFallback(message);
        }
      } else {
        // iOS Fallback
        await _launchSmsFallback(message);
      }
    } catch (e) {
      debugPrint("SMS Error: $e");
      // UI Fallback if background sending fails
      await _launchSmsFallback(message);
    }

    // --- 2. NOTIFY ADMIN (Firestore + Push) ---
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

        // Add to Admin Notifications collection
        await FirebaseFirestore.instance.collection('notifications').add({
          'uid': adminUid,
          'title': '🚨 SOS EMERGENCY ALERT!',
          'message': '${widget.passengerName ?? 'A user'} triggered SOS. Track here: $trackingLink',
          'type': 'sos_alert',
          'passenger_uid': widget.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });

        // Send Push Notification via your FCM Service
        if (adminToken != null) {
          await FCMService.sendPushNotification(
            token: adminToken,
            title: "🚨 SOS EMERGENCY ALERT!",
            body: "${widget.passengerName ?? 'A user'} needs help! Tracking link sent to Inbox.",
          );
        }
      }
    } catch (e) {
      debugPrint("Admin notify error: $e");
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("🆘 SOS ALERT BROADCASTED"), 
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        )
      );
    }

    // Cooldown to prevent SMS flooding (10 seconds)
    await Future.delayed(const Duration(seconds: 10));
    if (mounted) setState(() => _sosSending = false);
  }

  // --- FALLBACK: OPENS MESSAGE APP ---
  Future<void> _launchSmsFallback(String msg) async {
    final Uri smsUri = Uri.parse("sms:${widget.guardianPhone}?body=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _sosSending ? null : _triggerEmergencySOS,
      icon: _sosSending
          ? const SizedBox(
              width: 18, 
              height: 18, 
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            )
          : const Icon(Icons.warning_amber_rounded, color: Colors.white),
      label: Text(
        _sosSending ? "SENDING..." : "SOS",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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