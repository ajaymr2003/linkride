import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';
import '../../driver/ride_requests_page.dart'; // REQUIRED IMPORT

class InboxPage extends StatelessWidget {
  const InboxPage({super.key});

  final Color primaryGreen = const Color(0xFF11A860);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text("Inbox", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            labelColor: primaryGreen,
            unselectedLabelColor: Colors.grey,
            indicatorColor: primaryGreen,
            tabs: const [
              Tab(text: "Messages"),
              Tab(text: "Notifications"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildMessagesTab(),
            _buildNotificationsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesTab() {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: uid)
          .orderBy('last_message_time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState(Icons.chat_bubble_outline, "No messages yet", "Chat with drivers or passengers here.");

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var chat = doc.data() as Map<String, dynamic>;
            bool isDriver = uid == chat['participants'][0];
            String otherUserName = isDriver ? (chat['passenger_name'] ?? "User") : (chat['driver_name'] ?? "Driver"); 
            String lastMsg = chat['last_message'] ?? "No messages yet";
            Timestamp? time = chat['last_message_time'];

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: CircleAvatar(backgroundColor: primaryGreen.withOpacity(0.1), child: Text(otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : "?", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold))),
              title: Text(otherUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(time != null ? DateFormat('h:mm a').format(time.toDate()) : "", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat['chatId'], otherUserName: otherUserName))),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationsTab() {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState(Icons.notifications_none, "No notifications", "We'll let you know when something happens.");

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var notif = doc.data() as Map<String, dynamic>;
            return _buildNotificationCard(context, doc.id, notif);
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(BuildContext context, String docId, Map<String, dynamic> notif) {
    bool isUnread = notif['isRead'] == false;
    bool isRideRequest = notif['type'] == 'new_request';
    
    DateTime? rideDate;
    if (notif['ride_time'] != null) {
      rideDate = (notif['ride_time'] as Timestamp).toDate();
    }

    return InkWell(
      onTap: () {
        if (isUnread) {
          FirebaseFirestore.instance.collection('notifications').doc(docId).update({'isRead': true});
        }
        if (isRideRequest) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const RideRequestsPage()));
        }
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isUnread ? primaryGreen.withOpacity(0.04) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isUnread ? primaryGreen.withOpacity(0.3) : Colors.grey.shade200, width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isRideRequest ? primaryGreen.withOpacity(0.1) : Colors.blue.withOpacity(0.1), shape: BoxShape.circle), child: Icon(isRideRequest ? Icons.person_pin_circle : Icons.notifications_active, color: isRideRequest ? primaryGreen : Colors.blue, size: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(notif['title'] ?? "Update", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isUnread ? Colors.black : Colors.grey.shade700)), const SizedBox(height: 2), Text(notif['message'] ?? "", style: TextStyle(color: Colors.grey.shade600, fontSize: 13))])),
                if (isUnread) const CircleAvatar(radius: 4, backgroundColor: Colors.orange),
              ],
            ),

            if (isRideRequest && notif['source_name'] != null) ...[
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
                child: Row(
                  children: [
                    Column(children: [const Icon(Icons.circle, size: 8, color: Colors.grey), Container(height: 15, width: 1, color: Colors.grey.shade300), const Icon(Icons.location_on, size: 10, color: Colors.red)]),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(notif['source_name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text(notif['destination_name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)])),
                    const SizedBox(width: 10),
                    if (rideDate != null)
                      Column(children: [Text(DateFormat('h:mm a').format(rideDate), style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen, fontSize: 13)), Text(DateFormat('d MMM').format(rideDate), style: const TextStyle(color: Colors.grey, fontSize: 10))]),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text("Tap to review request", style: TextStyle(color: primaryGreen, fontSize: 11, fontWeight: FontWeight.bold)), Icon(Icons.chevron_right, color: primaryGreen, size: 16)]),
            ],
            if (!isRideRequest) const SizedBox(height: 10),
            Align(alignment: Alignment.bottomRight, child: Text(notif['timestamp'] != null ? DateFormat('EEE, h:mm a').format((notif['timestamp'] as Timestamp).toDate()) : "", style: TextStyle(fontSize: 10, color: Colors.grey.shade500))),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String sub) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 80, color: Colors.grey.shade300), const SizedBox(height: 20), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 10), Text(sub, style: const TextStyle(color: Colors.grey))]));
  }
}