import 'package:flutter/material.dart';
import 'admin_home_page.dart';
import 'driver_approval_screen.dart';
import 'user_management_screen.dart';
import 'admin_inbox_page.dart';
import 'admin_profile_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final Color primaryGreen = const Color(0xFF11A860);

  // FIXED ORDER: Home(0), Requests(1), User Management(2), Inbox(3), Profile(4)
  final List<Widget> _pages = [
    const AdminHomePage(),          // Index 0
    const DriverApprovalScreen(),   // Index 1
    const UserManagementScreen(),   // Index 2
    const AdminInboxPage(),         // Index 3
    const AdminProfilePage(),       // Index 4
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed, // Essential for 5 items
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined), 
            activeIcon: Icon(Icons.home), 
            label: "Home"
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pending_actions_outlined), 
            activeIcon: Icon(Icons.pending_actions), 
            label: "Requests"
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts_outlined), 
            activeIcon: Icon(Icons.manage_accounts), 
            label: "Users"
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mail_outline), 
            activeIcon: Icon(Icons.mail), 
            label: "Inbox"
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), 
            activeIcon: Icon(Icons.person), 
            label: "Profile"
          ),
        ],
      ),
    );
  }
}