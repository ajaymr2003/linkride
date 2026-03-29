import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'fcm_service.dart';

class BookingService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final DatabaseReference _rtDb = FirebaseDatabase.instance.ref();

  static String _getPersistentChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort(); 
    return ids.join("_");
  }

  static Future<void> acceptRequest({
    required String bookingId,
    required Map<String, dynamic> bookingData,
    required String currentDriverId,
  }) async {
    final String rId = bookingData['ride_id'];
    final String pId = bookingData['passenger_uid'];
    
    // Finalized trip fare
    final dynamic tripFare = bookingData['suggested_price'] ?? bookingData['price'] ?? 0;
    
    final String chatId = _getPersistentChatId(currentDriverId, pId);
    String autoMessage = "Ride accepted! Hello, I will see you at ${bookingData['source']['name']}.";

    DocumentSnapshot pSnap = await _db.collection('users').doc(pId).get();
    String? pToken = (pSnap.data() as Map<String, dynamic>?)?['fcm_token'];

    await _db.runTransaction((transaction) async {
      DocumentReference rideRef = _db.collection('rides').doc(rId);
      DocumentReference chatRef = _db.collection('chats').doc(chatId);
      DocumentReference bookingRef = _db.collection('bookings').doc(bookingId);
      
      DocumentSnapshot rideSnap = await transaction.get(rideRef);
      if (!rideSnap.exists) throw "Ride not found";
      
      int seats = rideSnap['available_seats'] ?? 0;
      if (seats < 1) throw "No seats left";

      // 1. Update Ride Document
      transaction.update(rideRef, {
        'available_seats': seats - 1,
        'passengers': FieldValue.arrayUnion([pId]),
        'passenger_routes.$pId': {
          'pickup': bookingData['source'],
          'dropoff': bookingData['destination'],
          'passenger_name': bookingData['passenger_name'] ?? "Passenger",
          'ride_status': 'approved',
          'payment_status': 'unpaid',
          'fare': tripFare, 
        }
      });

      // 2. Update Booking Document (Sync the price here to prevent null in activity)
      transaction.update(bookingRef, {
        'status': 'accepted',
        'price': tripFare, // <--- Syncing price to booking doc
        'responded_at': FieldValue.serverTimestamp(),
      });

      // 3. Persistent Chat
      transaction.set(chatRef, {
        'chatId': chatId,
        'driver_uid': currentDriverId,
        'passenger_uid': pId,
        'participants': [currentDriverId, pId],
        'ride_id': rId, 
        'driver_name': bookingData['driver_name'] ?? "Driver",
        'passenger_name': bookingData['passenger_name'] ?? "Passenger",
        'source': bookingData['source'],
        'destination': bookingData['destination'],
        'last_message': autoMessage,
        'last_message_time': FieldValue.serverTimestamp(),
        'status': 'active', 
      }, SetOptions(merge: true));

      // 4. In-App Notification
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

    await _rtDb.child("messages/$chatId").push().set({
      'senderId': 'system',
      'text': autoMessage,
      'timestamp': ServerValue.timestamp,
    });

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