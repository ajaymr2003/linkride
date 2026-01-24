  import 'package:flutter/material.dart';

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

  // --- TAB 1: MESSAGES ---
  Widget _buildMessagesTab() {
    // Placeholder Data - Connect to Firestore 'chats' collection later
    final List<Map<String, dynamic>> dummyChats = [
      {
        "name": "Arjun K",
        "message": "Hey, are you leaving from the bus stand?",
        "time": "10:30 AM",
        "unread": 2,
        "avatar": null
      },
      {
        "name": "Fathima S",
        "message": "Thanks for the ride!",
        "time": "Yesterday",
        "unread": 0,
        "avatar": null
      }
    ];

    if (dummyChats.isEmpty) {
      return _buildEmptyState(Icons.chat_bubble_outline, "No messages yet", "Chat with drivers or passengers here.");
    }

    return ListView.builder(
      itemCount: dummyChats.length,
      itemBuilder: (context, index) {
        final chat = dummyChats[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          leading: CircleAvatar(
            backgroundColor: primaryGreen.withOpacity(0.1),
            child: Text(chat['name'][0], style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
          ),
          title: Text(chat['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(chat['message'], maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(chat['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 5),
              if (chat['unread'] > 0)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: primaryGreen, shape: BoxShape.circle),
                  child: Text(chat['unread'].toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                )
            ],
          ),
          onTap: () {
            // Navigate to Chat Screen
          },
        );
      },
    );
  }

  // --- TAB 2: NOTIFICATIONS ---
  Widget _buildNotificationsTab() {
    final List<Map<String, dynamic>> dummyNotifs = [
      {
        "title": "Ride Approved",
        "body": "Your request to join Arjun's ride was approved.",
        "time": "2h ago",
        "icon": Icons.check_circle,
        "color": Colors.green
      },
      {
        "title": "Document Update",
        "body": "Your driver license has been verified successfully.",
        "time": "1d ago",
        "icon": Icons.verified_user,
        "color": Colors.blue
      }
    ];

    if (dummyNotifs.isEmpty) {
      return _buildEmptyState(Icons.notifications_none, "No notifications", "We'll let you know when something happens.");
    }

    return ListView.separated(
      padding: const EdgeInsets.all(15),
      itemCount: dummyNotifs.length,
      separatorBuilder: (c, i) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final notif = dummyNotifs[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: notif['color'].withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(notif['icon'], color: notif['color'], size: 20),
          ),
          title: Text(notif['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(notif['body'], style: TextStyle(color: Colors.grey.shade600)),
          ),
          trailing: Text(notif['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
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