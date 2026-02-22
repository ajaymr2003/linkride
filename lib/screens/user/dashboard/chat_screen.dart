import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String otherUserName;
  final String? initialText; // Added this to support auto-fill

  const ChatScreen({
    super.key, 
    required this.chatId, 
    required this.otherUserName, 
    this.initialText, // Optional parameter
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Use late to initialize with initialText in initState
  late TextEditingController _messageController;
  final String currentUid = FirebaseAuth.instance.currentUser!.uid;
  late DatabaseReference _messagesRef;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with the auto-fill text if it exists
    _messageController = TextEditingController(text: widget.initialText);
    
    // Path: messages / chatId
    _messagesRef = FirebaseDatabase.instance.ref("messages/${widget.chatId}");
  }

  void _sendMessage() {
    final String text = _messageController.text.trim();
    if (text.isEmpty) return;

    // 1. Save message to Realtime Database
    final newMessageRef = _messagesRef.push();
    newMessageRef.set({
      'senderId': currentUid,
      'text': text,
      'timestamp': ServerValue.timestamp,
    });

    // 2. Update last message in Firestore for the list view
    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'last_message': text,
      'last_message_time': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.otherUserName, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: FirebaseAnimatedList(
              query: _messagesRef.orderByChild('timestamp'),
              padding: const EdgeInsets.all(15),
              itemBuilder: (context, snapshot, animation, index) {
                final Object? dataValue = snapshot.value;
                if (dataValue == null || dataValue is! Map) return const SizedBox();
                
                final Map data = dataValue;
                bool isMe = data['senderId'] == currentUid;
                bool isSystem = data['senderId'] == 'system';

                return Align(
                  alignment: isSystem ? Alignment.center : (isMe ? Alignment.centerRight : Alignment.centerLeft),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSystem 
                          ? Colors.grey[200] 
                          : (isMe ? const Color(0xFF11A860) : Colors.grey[300]),
                      borderRadius: BorderRadius.circular(15).copyWith(
                        bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(15),
                        bottomLeft: !isMe ? const Radius.circular(0) : const Radius.circular(15),
                      ),
                    ),
                    child: Text(
                      data['text'] ?? "",
                      style: TextStyle(
                        color: isMe && !isSystem ? Colors.white : Colors.black,
                        fontSize: isSystem ? 12 : 15,
                        fontStyle: isSystem ? FontStyle.italic : FontStyle.normal
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Message Input Field
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      filled: true, 
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25), 
                        borderSide: BorderSide.none
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _sendMessage,
                  child: const CircleAvatar(
                    backgroundColor: Color(0xFF11A860),
                    radius: 24,
                    child: Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
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