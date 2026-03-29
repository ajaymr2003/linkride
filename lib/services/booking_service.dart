import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart'; // <--- ADDED
import 'fcm_service.dart';

class BookingService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DatabaseReference _rtDb = FirebaseDatabase.instance.ref(); // <--- ADDED

  /// Centralized logic to accept a ride request
  static Future<void> acceptRequest({
    required String bookingId,
    required Map<String, dynamic> bookingData,
    required String currentDriverId,
  }) async {
    String rId = bookingData['ride_id'];
    String pId = bookingData['passenger_uid'];
    String destName = bookingData['destination']['name'] ?? "Destination";
    String sourceName = bookingData['source']['name'] ?? "Pickup";
    Timestamp rideTime = bookingData['ride_date'];
    String chatId = "${rId}_$pId";
    
    // The automatic greeting message
    String autoMessage = "Ride accepted! Hello, I will see you at $sourceName.";

    // 1. Fetch Passenger FCM Token
    DocumentSnapshot pSnap = await _db.collection('users').doc(pId).get();
    String? pToken = (pSnap.data() as Map<String, dynamic>?)?['fcm_token'];

    // 2. Execute Database Transaction (Firestore)
    await _db.runTransaction((transaction) async {
      DocumentReference rideRef = _db.collection('rides').doc(rId);
      DocumentSnapshot rideSnap = await transaction.get(rideRef);

      if (!rideSnap.exists) throw "Ride not found";
      
      int seats = rideSnap['available_seats'] ?? 0;
      if (seats < 1) throw "No seats left";

      // A. Update Ride Document
      transaction.update(rideRef, {
        'available_seats': seats - 1,
        'passengers': FieldValue.arrayUnion([pId]),
        'passenger_routes.$pId': {
          'pickup': bookingData['source'],
          'dropoff': bookingData['destination'],
          'passenger_name': bookingData['passenger_name'] ?? "Passenger",
          'ride_status': 'approved',
          'payment_status': 'unpaid',
        }
      });

      // B. Update Booking Status
      transaction.update(_db.collection('bookings').doc(bookingId), {
        'status': 'accepted',
        'responded_at': FieldValue.serverTimestamp(),
      });

      // C. Setup Chat Metadata in Firestore
      transaction.set(_db.collection('chats').doc(chatId), {
        'chatId': chatId,
        'participants': [currentDriverId, pId],
        'driver_name': bookingData['driver_name'] ?? "Driver",
        'passenger_name': bookingData['passenger_name'] ?? "Passenger",
        'last_message': autoMessage, // Updated to the auto message
        'last_message_time': FieldValue.serverTimestamp(),
      });

      // D. Create In-App Notification
      transaction.set(_db.collection('notifications').doc(), {
        'uid': pId,
        'title': 'Ride Accepted! 🚗',
        'message': 'Your trip to $destName is confirmed.',
        'type': 'ride_approved',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'source_name': sourceName,
        'destination_name': destName,
        'ride_time': rideTime,
        'ride_id': rId,
      });
    });

    // 3. SEND AUTOMATIC MESSAGE TO REALTIME DATABASE
    // This makes the message actually appear inside the Chat Screen bubbles
    await _rtDb.child("messages/$chatId").push().set({
      'senderId': 'system', // Marked as system or currentDriverId
      'text': autoMessage,
      'timestamp': ServerValue.timestamp,
    });

    // 4. Trigger External Push Notification (FCM)
    if (pToken != null && pToken.isNotEmpty) {
      await FCMService.sendPushNotification(
        token: pToken,
        title: "Ride Accepted! 🚗",
        body: "The driver accepted your ride to $destName.",
      );
    }
  }

  /// Logic to reject a ride request
  static Future<void> rejectRequest(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'rejected',
      'responded_at': FieldValue.serverTimestamp(),
    });
  }
} 