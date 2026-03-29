import 'package:cloud_firestore/cloud_firestore.dart';

class RideCleanupService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Global cleanup: Finds rides older than 24 hours and completes them
  static Future<void> globalRideCleanup() async {
    try {
      // 1. Calculate the cutoff time (24 hours ago)
      final DateTime cutoff = DateTime.now().subtract(const Duration(hours: 24));
      final Timestamp cutoffTimestamp = Timestamp.fromDate(cutoff);

      print("🧹 [Cleanup] Starting scan for rides before: ${cutoff.toLocal()}");

      // 2. Query only by time to avoid "Index Required" errors
      QuerySnapshot ridesSnapshot = await _db
          .collection('rides')
          .where('departure_time', isLessThan: cutoffTimestamp)
          .get();

      if (ridesSnapshot.docs.isEmpty) {
        print("ℹ️ [Cleanup] No past rides found.");
        return;
      }

      WriteBatch batch = _db.batch();
      int count = 0;

      for (var doc in ridesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        String status = data['status'] ?? '';

        // 3. Only update if it's NOT already completed
        if (status != 'completed') {
          print("🚀 [Cleanup] Updating Ride ID: ${doc.id}");
          batch.update(doc.reference, {
            'status': 'completed',
            'ride_status': 'completed',
            'auto_cleanup_at': FieldValue.serverTimestamp(),
          });
          count++;
        }
      }

      // Commit the changes if there were any updates
      if (count > 0) {
        await batch.commit();
        print("✅ [Cleanup] Successfully completed $count rides.");
      } else {
        print("ℹ️ [Cleanup] All past rides were already marked completed.");
      }

    } catch (e) {
      print("❌ [Cleanup] Error occurred: $e");
    }
  }
}