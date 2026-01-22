import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/email_entry_screen.dart';

class AdminProfilePage extends StatelessWidget {
  const AdminProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const EmailEntryScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Account")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const CircleAvatar(radius: 50, backgroundColor: Color(0xFF11A860), child: Icon(Icons.admin_panel_settings, size: 50, color: Colors.white)),
            const SizedBox(height: 15),
            const Text("System Administrator", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("admin@gmail.com", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 40),
            _profileMenu("Edit Profile", Icons.edit),
            _profileMenu("Security Settings", Icons.security),
            _profileMenu("Support Center", Icons.help_center),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => _logout(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("LOGOUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _profileMenu(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF2B5145)),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}