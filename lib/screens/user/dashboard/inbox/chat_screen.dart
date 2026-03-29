import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String? initialText;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.otherUserName,
    this.initialText,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late TextEditingController _messageController;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  late DatabaseReference _messagesRef;
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.initialText);
    _messagesRef = FirebaseDatabase.instance.ref("messages/${widget.chatId}");
  }

  // --- ACTIONS: DELETE SINGLE ---
  void _showDeleteOptions(String messageKey, String text) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.blue),
              title: const Text("Copy Text"),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Delete for Everyone"),
              onTap: () {
                _messagesRef.child(messageKey).remove();
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS: CLEAR ALL ---
  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Chat?"),
        content: const Text("All messages will be permanently removed for both users."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              _messagesRef.remove();
              FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
                'last_message': 'Conversation cleared',
                'last_message_time': FieldValue.serverTimestamp(),
              });
              Navigator.pop(ctx);
            },
            child: const Text("Clear All", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    final String text = _messageController.text.trim();
    if (text.isEmpty) return;

    final newMessageRef = _messagesRef.push();
    newMessageRef.set({
      'senderId': currentUid,
      'text': text,
      'timestamp': ServerValue.timestamp,
    });

    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'last_message': text,
      'last_message_time': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: primaryGreen.withOpacity(0.1),
              radius: 18,
              child: Text(widget.otherUserName[0], style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherUserName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Text("Trip Chat", style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => v == 'clear' ? _clearChat() : null,
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'clear', child: Text("Clear entire chat", style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FirebaseAnimatedList(
              query: _messagesRef.orderByChild('timestamp'),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
              itemBuilder: (context, snapshot, animation, index) {
                final Map data = snapshot.value as Map;
                final String key = snapshot.key!;
                bool isMe = data['senderId'] == currentUid;
                bool isSystem = data['senderId'] == 'system';
                
                DateTime time = DateTime.fromMillisecondsSinceEpoch(data['timestamp'] ?? 0);
                String formattedTime = DateFormat('h:mm a').format(time);

                if (isSystem) return _buildSystemMessage(data['text']);

                return GestureDetector(
                  onLongPress: () => _showDeleteOptions(key, data['text']),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Container(
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? primaryGreen : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : 0),
                              bottomRight: Radius.circular(isMe ? 0 : 18),
                            ),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                data['text'] ?? "",
                                style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15, height: 1.3),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedTime,
                                style: TextStyle(color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // INPUT BOX
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(String? text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
        child: Text(text ?? "", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.blueGrey)),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: const Color(0xFFF1F4F3), borderRadius: BorderRadius.circular(25)),
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: "Write a message...", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: CircleAvatar(
              backgroundColor: primaryGreen,
              radius: 24,
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}