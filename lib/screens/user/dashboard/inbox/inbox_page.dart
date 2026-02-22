import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart'; // Ensure ChatScreen is in this same folder

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(Icons.chat_bubble_outline, "No messages yet", "Chat with drivers or passengers here.");
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var chat = doc.data() as Map<String, dynamic>;
            
            // Determine the "other" user's name
            // If I am the first participant (driver), show passenger name. Otherwise show driver name.
            bool isDriver = uid == chat['participants'][0];
            String otherUserName = isDriver ? (chat['passenger_name'] ?? "User") : (chat['driver_name'] ?? "Driver"); 
            String lastMsg = chat['last_message'] ?? "No messages yet";
            
            // FIX: Define 'time' variable here
            Timestamp? time = chat['last_message_time'];

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: CircleAvatar(
                backgroundColor: primaryGreen.withOpacity(0.1),
                child: Text(otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : "?", 
                  style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
              ),
              title: Text(otherUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(
                time != null ? DateFormat('h:mm a').format(time.toDate()) : "",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      chatId: chat['chatId'],
                      otherUserName: otherUserName,
                    ),
                  ),
                );
              },
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
            var doc = snapshot.data!.docs[index];
            var notif = doc.data() as Map<String, dynamic>;
            bool isUnread = notif['isRead'] == false;

            return Container(
              decoration: BoxDecoration(
                color: isUnread ? primaryGreen.withOpacity(0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                onTap: () {
                  if (isUnread) {
                    FirebaseFirestore.instance.collection('notifications').doc(doc.id).update({'isRead': true});
                  }
                },
                leading: const Icon(Icons.notifications, color: Colors.green),
                title: Text(notif['title'] ?? "Update", style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(notif['message'] ?? ""),
                trailing: Text(
                  notif['timestamp'] != null 
                    ? DateFormat('d MMM').format((notif['timestamp'] as Timestamp).toDate()) 
                    : "", 
                  style: const TextStyle(fontSize: 11)
                ),
              ),
            );
          },
        );
      },
    );
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