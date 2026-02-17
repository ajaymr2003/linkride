import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

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

  // --- TAB 1: MESSAGES (Real-time from Firestore) ---
  Widget _buildMessagesTab() {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<QuerySnapshot>(
      // Assuming you have a 'chats' collection where users are listed in a 'participants' array
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: uid)
          .orderBy('last_message_time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(Icons.chat_bubble_outline, "No messages yet", "Chat with drivers or passengers here.");
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var chat = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            
            // Logic to find the OTHER user's name in the chat
            String otherUserName = chat['other_user_name'] ?? "User"; 
            String lastMsg = chat['last_message'] ?? "No messages yet";
            Timestamp? time = chat['last_message_time'];

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: CircleAvatar(
                backgroundColor: primaryGreen.withOpacity(0.1),
                child: Text(otherUserName[0].toUpperCase(), style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
              ),
              title: Text(otherUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(
                time != null ? DateFormat('h:mm a').format(time.toDate()) : "",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                // Navigate to specific chat screen using chat document ID
              },
            );
          },
        );
      },
    );
  }

  // --- TAB 2: NOTIFICATIONS (Real-time from Firestore) ---
  Widget _buildNotificationsTab() {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? "";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('uid', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(Icons.notifications_none, "No notifications", "We'll let you know when something happens.");
        }

        return ListView.separated(
          padding: const EdgeInsets.all(15),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (c, i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            var notif = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            
            // Dynamic Icons based on notification type
            IconData icon = Icons.notifications;
            Color iconColor = primaryGreen;
            
            if (notif['type'] == 'ride_approved') {
              icon = Icons.check_circle;
              iconColor = Colors.green;
            } else if (notif['type'] == 'ride_cancelled') {
              icon = Icons.cancel;
              iconColor = Colors.red;
            }

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              title: Text(notif['title'] ?? "Update", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(notif['message'] ?? "", style: TextStyle(color: Colors.grey.shade600)),
              ),
              trailing: Text(
                _formatTimestamp(notif['timestamp']),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  // Helper to format timestamps for notifications
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime date = timestamp.toDate();
    Duration diff = DateTime.now().difference(date);
    
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return DateFormat('d MMM').format(date);
  }

  Widget _buildEmptyState(IconData icon, String title, String sub) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          Text(sub, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}