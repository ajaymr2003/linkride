import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../services/user_service.dart';

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

  bool isDriver = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.initialText);
    _messagesRef = FirebaseDatabase.instance.ref("messages/${widget.chatId}");
    _determineRole();
  }

  void _determineRole() {
    // chatId format is "rideId_passengerUid"
    // If current UID is the second part, user is the Passenger.
    if (widget.chatId.split('_').last == currentUid) {
      setState(() => isDriver = false);
    } else {
      setState(() => isDriver = true);
    }
  }

  // --- ACTIONS: DELETE SINGLE MESSAGE ---
  void _showDeleteOptions(String messageKey) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Delete for Everyone"),
              onTap: () {
                _messagesRef.child(messageKey).remove();
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _sendMessage(String text) {
    final String cleanText = text.trim();
    if (cleanText.isEmpty) return;

    _messagesRef.push().set({
      'senderId': currentUid,
      'text': cleanText,
      'timestamp': ServerValue.timestamp,
    });

    FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
      'last_message': cleanText,
      'last_message_time': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Character-appropriate suggestions
    final List<String> suggestions = isDriver 
      ? ["I'm on my way!", "I have arrived.", "Where exactly are you?", "I'll wait 5 mins."] 
      : ["I'm coming in 2 mins.", "I am at the location.", "Which car are you in?", "Can you wait a bit?"];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
        title: GestureDetector(
          onTap: () {
            // logic to find other user's ID from chatId
            List<String> parts = widget.chatId.split('_');
            // If I am driver (index 0), other is passenger (index 1). Vise versa.
            String otherUid = isDriver ? parts.last : parts.first; 
            // Note: If parts.first is RideID, you may need to fetch the driverUid from Firestore.
            // For now, using the common pattern.
            UserService.showUserProfile(context, otherUid);
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryGreen.withOpacity(0.1),
                radius: 18,
                child: Text(widget.otherUserName[0], style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherUserName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Text("View Profile", style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
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

                if (isSystem) return _buildSystemMessage(data['text']);

                return GestureDetector(
                  onLongPress: isMe ? () => _showDeleteOptions(key) : null,
                  child: _buildChatBubble(data['text'], isMe, DateFormat('h:mm a').format(time)),
                );
              },
            ),
          ),
          
          // --- SUGGESTIONS BAR ---
          Container(
            height: 50,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: suggestions.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: ActionChip(
                  label: Text(suggestions[index], style: const TextStyle(fontSize: 12)),
                  onPressed: () => _sendMessage(suggestions[index]),
                  backgroundColor: Colors.grey[50],
                  side: BorderSide(color: primaryGreen.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ),

          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(String? text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 15),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: Colors.blueGrey.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Text(text ?? "", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.blueGrey)),
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isMe, String time) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
            Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
            const SizedBox(height: 4),
            Text(time, style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 30),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(color: const Color(0xFFF1F4F3), borderRadius: BorderRadius.circular(25)),
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: Icon(Icons.send_rounded, color: primaryGreen),
            onPressed: () => _sendMessage(_messageController.text),
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