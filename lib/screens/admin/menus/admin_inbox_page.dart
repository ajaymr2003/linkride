import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../driver_request/user_detail_view.dart';

class AdminInboxPage extends StatelessWidget {
  const AdminInboxPage({super.key});

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  // --- ACTIONS ---

  Future<void> _markAsRead(String docId) async {
    await FirebaseFirestore.instance.collection('admin_inbox').doc(docId).update({
      'isRead': true,
    });
  }

  Future<void> _deleteMessage(String docId) async {
    await FirebaseFirestore.instance.collection('admin_inbox').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Admin Inbox", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: darkGreen,
        elevation: 0,
        actions: [
          // Counter for unread messages
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('admin_inbox')
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
              return Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 15),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    "${snapshot.data!.docs.length} NEW",
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('admin_inbox')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              bool isRead = data['isRead'] ?? false;
              String type = data['type'] ?? 'support';

              return _buildMessageCard(context, doc.id, data, isRead, type);
            },
          );
        },
      ),
    );
  }

  Widget _buildMessageCard(BuildContext context, String docId, Map<String, dynamic> data, bool isRead, String type) {
    DateTime time = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    
    // UI logic based on message type
    IconData icon;
    Color color;
    if (type == 'sos') {
      icon = Icons.warning_amber_rounded;
      color = Colors.red;
    } else if (type == 'report') {
      icon = Icons.report_problem_outlined;
      color = Colors.orange;
    } else {
      icon = Icons.chat_bubble_outline;
      color = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isRead ? null : Border.all(color: primaryGreen.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                data['title'] ?? "No Title",
                style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
              ),
            ),
            Text(
              DateFormat('h:mm a').format(time),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              data['message'] ?? "",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isRead ? Colors.grey : Colors.black87),
            ),
            const SizedBox(height: 10),
            Text("From: ${data['sender_name'] ?? 'User'}", 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryGreen)),
          ],
        ),
        onTap: () => _showMessageDetail(context, docId, data),
      ),
    );
  }

  void _showMessageDetail(BuildContext context, String docId, Map<String, dynamic> data) {
    // Mark as read immediately when opened
    _markAsRead(docId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _badge(data['type'] ?? 'support'),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 15),
            Text(data['title'] ?? "Message", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(
              DateFormat('MMMM dd, yyyy • hh:mm a').format((data['timestamp'] as Timestamp).toDate()),
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const Divider(height: 40),
            const Text("MESSAGE CONTENT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Text(data['message'] ?? "", style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 30),
            
            // Link to User Profile
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
              child: Row(
                children: [
                  const Icon(Icons.person_outline),
                  const SizedBox(width: 15),
                  Expanded(child: Text("Sent by ${data['sender_name'] ?? 'User'}", style: const TextStyle(fontWeight: FontWeight.bold))),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailView(uid: data['sender_uid'])));
                    }, 
                    child: const Text("VIEW USER")
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _deleteMessage(docId);
                      Navigator.pop(context);
                    }, 
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text("Delete", style: TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
                    onPressed: () => Navigator.pop(context), 
                    child: const Text("Close", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _badge(String type) {
    Color color = type == 'sos' ? Colors.red : (type == 'report' ? Colors.orange : Colors.blue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(type.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mail_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          const Text("Inbox is empty", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const Text("User reports and SOS alerts will appear here.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}