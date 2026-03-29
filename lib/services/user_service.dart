import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  static void showUserProfile(BuildContext context, String uid) {
    if (uid.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF11A860)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return AlertDialog(
              title: const Text("Error"),
              content: const Text("User profile not found in database."),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
            );
          }
          
          var data = snapshot.data!.data() as Map<String, dynamic>;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: data['profile_pic'] != null ? NetworkImage(data['profile_pic']) : null,
                    child: data['profile_pic'] == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                  ),
                  const SizedBox(height: 15),
                  Text(data['name'] ?? "User", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(data['experience'] ?? "Newcomer", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 5),
                      Text("${data['rating'] ?? '5.0'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  if (data['mini_bio'] != null && data['mini_bio'].toString().isNotEmpty) ...[
                    const Divider(height: 30),
                    Text(
                      data['mini_bio'], 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black87)
                    ),
                  ],
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF11A860),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      child: const Text("CLOSE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}