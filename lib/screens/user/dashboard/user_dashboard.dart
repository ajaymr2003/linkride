import 'package:flutter/material.dart';

// Import Pages
import '../profile/account/account_page.dart';
import 'rides_page.dart';
import 'inbox_page.dart';
import 'home_mode_selection.dart'; // <--- New Import

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;

  final Color primaryGreen = const Color(0xFF11A860);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      // The Body switches based on the bottom tab
      body: _getBody(_currentIndex),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Activity"),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Inbox"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Account"),
        ],
      ),
    );
  }

  Widget _getBody(int index) {
    switch (index) {
      case 0: return const HomeModeSelection(); // The Two Big Cards
      case 1: return const RidesPage();
      case 2: return const InboxPage();
      case 3: return const AccountPage();
      default: return const HomeModeSelection();
    }
  }
}