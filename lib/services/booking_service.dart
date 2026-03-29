import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'fcm_service.dart';

class BookingService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DatabaseReference _rtDb = FirebaseDatabase.instance.ref();

  static Future<void> acceptRequest({
    required String bookingId,
    required Map<String, dynamic> bookingData,
    required String currentDriverId,
  }) async {
    String rId = bookingData['ride_id'];
    String pId = bookingData['passenger_uid'];
    String chatId = "${rId}_$pId";
    
    // The automatic greeting message
    String autoMessage = "Ride accepted! Hello, I will see you at ${bookingData['source']['name']}.";

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

      // A. Update Global Ride Document
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

      // B. Update Individual Booking Status
      transaction.update(_db.collection('bookings').doc(bookingId), {
        'status': 'accepted',
        'responded_at': FieldValue.serverTimestamp(),
      });

      // C. ENHANCED CHAT METADATA STORAGE
      transaction.set(_db.collection('chats').doc(chatId), {
        'chatId': chatId,
        'ride_id': rId,
        'driver_uid': currentDriverId,
        'passenger_uid': pId,
        'participants': [currentDriverId, pId],
        
        // Storing Trip Details for the Chat UI
        'driver_name': bookingData['driver_name'] ?? "Driver",
        'passenger_name': bookingData['passenger_name'] ?? "Passenger",
        'ride_date': bookingData['ride_date'], // Stored so chat can show trip date
        'source': bookingData['source'],       // Exact pickup for this passenger
        'destination': bookingData['destination'], // Exact dropoff for this passenger
        
        'last_message': autoMessage,
        'last_message_time': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // D. Create In-App Notification for Passenger
      transaction.set(_db.collection('notifications').doc(), {
        'uid': pId,
        'title': 'Ride Accepted! 🚗',
        'message': 'Your trip to ${bookingData['destination']['name']} is confirmed.',
        'type': 'ride_approved',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'ride_id': rId,
      });
    });

    // 3. Send Message to Realtime Database for Chat Bubbles
    await _rtDb.child("messages/$chatId").push().set({
      'senderId': 'system',
      'text': autoMessage,
      'timestamp': ServerValue.timestamp,
    });

    // 4. Trigger Push Notification
    if (pToken != null && pToken.isNotEmpty) {
      await FCMService.sendPushNotification(
        token: pToken,
        title: "Ride Accepted! 🚗",
        body: "The driver accepted your ride to ${bookingData['destination']['name']}.",
      );
    }
  }

  static Future<void> rejectRequest(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'rejected',
      'responded_at': FieldValue.serverTimestamp(),
    });
  }
}