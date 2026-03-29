import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MiniBioPage extends StatefulWidget {
  final String? currentBio;
  const MiniBioPage({super.key, this.currentBio});

  @override
  State<MiniBioPage> createState() => _MiniBioPageState();
}

class _MiniBioPageState extends State<MiniBioPage> {
  late TextEditingController _bioController;
  bool _isLoading = false;
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.currentBio ?? "");
  }

  Future<void> _saveBio() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'mini_bio': _bioController.text.trim()});
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save bio")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Mini Bio"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveBio,
            child: Text("Save", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Tell us about yourself", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Share your hobbies, why you travel, or what kind of music you like.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            TextField(
              controller: _bioController,
              maxLines: 5,
              maxLength: 300,
              decoration: InputDecoration(
                hintText: "I love hiking and 80s rock music...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryGreen, width: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}