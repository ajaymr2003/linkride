import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TravelPreferencesPage extends StatefulWidget {
  final Map<String, dynamic>? currentPrefs;
  const TravelPreferencesPage({super.key, this.currentPrefs});

  @override
  State<TravelPreferencesPage> createState() => _TravelPreferencesPageState();
}

class _TravelPreferencesPageState extends State<TravelPreferencesPage> {
  // 0: No, 1: Moderate, 2: Yes (For simplicity, we'll use Booleans for now, or Tri-state later)
  // Let's stick to simple toggles for "Allowed/Likes"
  bool _music = true;
  bool _smoking = false;
  bool _pets = false;
  bool _chatting = true;
  
  bool _isLoading = false;
  final Color primaryGreen = const Color(0xFF11A860);

  @override
  void initState() {
    super.initState();
    if (widget.currentPrefs != null) {
      _music = widget.currentPrefs!['music'] ?? true;
      _smoking = widget.currentPrefs!['smoking'] ?? false;
      _pets = widget.currentPrefs!['pets'] ?? false;
      _chatting = widget.currentPrefs!['chatting'] ?? true;
    }
  }

  Future<void> _savePrefs() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'travel_preferences': {
          'music': _music,
          'smoking': _smoking,
          'pets': _pets,
          'chatting': _chatting,
        }
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save preferences")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Travel Preferences"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("What do you prefer during rides?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          _buildSwitch("Chatting", Icons.chat_bubble_outline, _chatting, (v) => setState(() => _chatting = v)),
          const Divider(),
          _buildSwitch("Music", Icons.music_note_outlined, _music, (v) => setState(() => _music = v)),
          const Divider(),
          _buildSwitch("Smoking", Icons.smoking_rooms_outlined, _smoking, (v) => setState(() => _smoking = v)),
          const Divider(),
          _buildSwitch("Pets", Icons.pets_outlined, _pets, (v) => setState(() => _pets = v)),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _savePrefs,
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("SAVE PREFERENCES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitch(String title, IconData icon, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      secondary: Icon(icon, color: const Color(0xFF2B5145)),
      value: value,
      activeColor: primaryGreen,
      onChanged: onChanged,
    );
  }
}