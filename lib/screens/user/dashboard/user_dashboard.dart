import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import Pages
import '../profile/account/account_page.dart';
import '../driver_setup/driver_setup_controller.dart';
import '../driver/ride_setup.dart';
import 'rides_page.dart';
import 'inbox_page.dart';
// Import the new Passenger Search Controller
import '../passenger/search_ride.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;

  // Design System Colors
  final Color primaryGreen = const Color(0xFF11A860);
  final Color textGrey = const Color(0xFF727272);
  final Color darkGreen = const Color(0xFF2B5145);
  final Color bgGrey = const Color(0xFFF5F5F5);

  /// --- THE GATEKEEPER LOGIC ---
  /// Triggered immediately when the "Publish" menu item is tapped.
  Future<void> _handlePublishNavigation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF11A860)),
      ),
    );

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;
      Navigator.pop(context);

      String status = userDoc.data()?['driver_status'] ?? 'not_applied';

      if (status == 'approved') {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const RideSetupScreen()));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverSetupController()));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error checking driver status")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // We only show the Dashboard AppBar on the Search (Home) screen.
    // Other tabs (Rides, Inbox, Account) have their own specific AppBars.
    final bool showAppBar = _currentIndex == 0;

    return Scaffold(
      backgroundColor: bgGrey,
      
      // --- ADDED TOP BAR ---
      appBar: showAppBar ? _buildHomeAppBar() : null,
      
      body: _getBody(_currentIndex),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textGrey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 10,
        onTap: (index) {
          if (index == 1) {
            _handlePublishNavigation();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: "Publish"),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car_filled_outlined), label: "Rides"),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Inbox"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Account"),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildHomeAppBar() {
    final user = FirebaseAuth.instance.currentUser;
    String firstName = "Traveler";
    
    // Attempt to get first name from Display Name
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      firstName = user.displayName!.split(' ')[0];
    } else {
      // Fallback: Try to fetch name from Firestore if displayName isn't set in Auth
      // (This is a lightweight optimization, usually Auth has it)
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70, // Slightly taller for better look
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.near_me, color: primaryGreen, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "LinkRide",
                style: TextStyle(
                  color: darkGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                "Hello, $firstName!",
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Stack(
            children: [
              Icon(Icons.notifications_none_rounded, color: darkGreen, size: 28),
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            ],
          ),
          onPressed: () {
            // Notification logic here
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No new notifications")),
            );
          },
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _getBody(int index) {
    switch (index) {
      case 0: return const SearchRideScreen(); // <-- NEW PASSENGER SEARCH
      case 1: return const SearchRideScreen(); // Fallback (nav handled in onTap)
      case 2: return const RidesPage();
      case 3: return const InboxPage();
      case 4: return const AccountPage();
      default: return const SearchRideScreen();
    }
  }
}