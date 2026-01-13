import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);
  final Color textGrey = const Color(0xFF727272);
  final Color bgColor = const Color(0xFFECECEC);

  String _userName = "User";
  String _userEmail = "user@example.com";
  String _userPhone = "0912345678";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_name') ?? "User";
      _userEmail = prefs.getString('user_email') ?? "user@example.com";
      _userPhone = prefs.getString('user_phone') ?? "0912345678";
    });
  }

  Future<void> _logout() async {
    // Clear saved login details
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_email');
    await prefs.remove('user_password');
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
    await prefs.remove('remember_login');

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: primaryGreen.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, size: 40, color: primaryGreen),
                ),
                const SizedBox(height: 15),
                Text(
                  _userName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: darkGreen,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _userEmail,
                  style: TextStyle(fontSize: 14, color: textGrey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // Account Information Section
          Text(
            "Account Information",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 15),

          _buildInfoTile("Email", _userEmail, Icons.email_outlined),
          _buildInfoTile("Phone", _userPhone, Icons.phone_outlined),
          _buildInfoTile("Member Since", "2024", Icons.calendar_today_outlined),

          const SizedBox(height: 25),

          // Settings Section
          Text(
            "Settings",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 15),

          _buildSettingsTile(
            "Edit Profile",
            "Update your profile information",
            Icons.edit_outlined,
            () {},
          ),
          _buildSettingsTile(
            "Payment Methods",
            "Manage your payment methods",
            Icons.credit_card_outlined,
            () {},
          ),
          _buildSettingsTile(
            "Notifications",
            "Manage notification settings",
            Icons.notifications_outlined,
            () {},
          ),
          _buildSettingsTile(
            "Privacy & Security",
            "View privacy and security settings",
            Icons.lock_outlined,
            () {},
          ),

          const SizedBox(height: 25),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _showLogoutDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                "LOGOUT",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 15),

          // App Version
          Center(
            child: Text(
              "LinkRide v1.0.0",
              style: TextStyle(fontSize: 12, color: textGrey),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryGreen, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: textGrey)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: darkGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: primaryGreen, size: 20),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: textGrey),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: textGrey, size: 16),
          ],
        ),
      ),
    );
  }
}
