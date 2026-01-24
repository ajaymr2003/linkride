import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- FIXED IMPORTS FOR PAGES ---
import '../profile/account/account_page.dart';           // Added ../ to reach profile
import '../driver_setup/driver_setup_controller.dart';   // Fixed ..user typo to ../
import '../driver/ride_setup.dart';                      // Already correct, keep as is
import 'rides_page.dart';                                // Same folder, no prefix needed
import 'inbox_page.dart';                                // Same folder, no prefix needed
class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;

  // Design System Colors
  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);
  final Color bgGrey = const Color(0xFFF5F5F5);
  final Color textGrey = const Color(0xFF727272);

  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  /// --- THE GATEKEEPER LOGIC ---
  /// Triggered immediately when the "Publish" menu item is tapped.
  Future<void> _handlePublishNavigation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Show a loading overlay so the user knows a check is happening
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF11A860)),
      ),
    );

    try {
      // 2. Fetch the latest driver status from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;
      Navigator.pop(context); // Remove the loading indicator

      String status = userDoc.data()?['driver_status'] ?? 'not_applied';

      // 3. Direct Redirection based on status
      if (status == 'approved') {
        // Driver is verified -> Go to Ride Creation
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RideSetupScreen()),
        );
      } else {
        // Not applied, Pending, or Rejected -> Go to Setup Controller
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DriverSetupController()),
        );
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
    return Scaffold(
      backgroundColor: bgGrey,
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
            // Intercept the click on "Publish"
            _handlePublishNavigation();
          } else {
            // Handle other tabs normally
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

  Widget _getBody(int index) {
    switch (index) {
      case 0: return _searchView();
      // Case 1 is intercepted in onTap, but we return searchView as a safe fallback
      case 1: return _searchView(); 
      case 2: return const RidesPage(); // <--- Connected Rides Page
      case 3: return const InboxPage(); // <--- Connected Inbox Page
      case 4: return const AccountPage();
      default: return _searchView();
    }
  }

  // --- VIEW: SEARCH (HOME) ---
  Widget _searchView() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                width: double.infinity,
                child: Image.asset('assets/dash.png', fit: BoxFit.cover),
              ),
            ),
            Expanded(flex: 1, child: Container(color: bgGrey)),
          ],
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _searchField("Leaving from...", Icons.circle_outlined, _fromController),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Divider(height: 30, thickness: 1, color: Color(0xFFEEEEEE)),
                  ),
                  _searchField("Going to...", Icons.location_on_outlined, _toController),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(child: _infoSelector(Icons.calendar_today_outlined, "Today")),
                      const SizedBox(width: 10),
                      Expanded(child: _infoSelector(Icons.person_outline, "1 passenger")),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("Search", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- HELPERS ---
  Widget _searchField(String hint, IconData icon, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: TextStyle(color: darkGreen, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: textGrey.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: primaryGreen),
        border: InputBorder.none,
      ),
    );
  }

  Widget _infoSelector(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: darkGreen),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: darkGreen, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}