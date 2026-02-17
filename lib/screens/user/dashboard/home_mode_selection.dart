import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../passenger/search_ride.dart';
import 'driver_dashboard.dart';
import '../driver_setup/driver_setup_controller.dart'; 

// Enum to track what the Home Tab is currently showing
enum HomeViewState { selection, passenger, driver }

class HomeModeSelection extends StatefulWidget {
  const HomeModeSelection({super.key});

  @override
  State<HomeModeSelection> createState() => _HomeModeSelectionState();
}

class _HomeModeSelectionState extends State<HomeModeSelection> {
  HomeViewState _currentView = HomeViewState.selection;
  
  // --- STATE VARIABLES FOR ONE-TIME CHECK ---
  String _driverStatus = 'loading'; 
  bool _isLoadingStatus = true;
  String _firstName = "Traveler";

  @override
  void initState() {
    super.initState();
    _fetchDriverStatus();
  }

  // --- 1. FETCH STATUS ON LANDING (RUNS ONCE) ---
  Future<void> _fetchDriverStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch User Doc
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          
          if (mounted) {
            setState(() {
              _driverStatus = data['driver_status'] ?? 'not_applied';
              // Also grab name while we are here
              String fullName = data['name'] ?? "Traveler";
              _firstName = fullName.split(' ')[0]; 
              _isLoadingStatus = false;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _driverStatus = 'not_applied';
          _isLoadingStatus = false;
        });
      }
    }
  }

  // --- 2. HANDLE CLICK BASED ON STORED RESULT ---
  void _handleDriverClick() {
    if (_isLoadingStatus) return; // Prevent click while loading

    if (_driverStatus == 'approved') {
      // CASE A: Approved -> Show Dashboard (Switch View)
      setState(() => _currentView = HomeViewState.driver);
    } else {
      // CASE B: Not Approved -> Redirect to Setup Page
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DriverSetupController()),
      ).then((_) {
        // Optional: Refresh status when they come back from setup
        setState(() => _isLoadingStatus = true);
        _fetchDriverStatus();
      });
    }
  }

  Future<bool> _onWillPop() async {
    if (_currentView != HomeViewState.selection) {
      setState(() => _currentView = HomeViewState.selection);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: _currentView == HomeViewState.selection ? _buildSelectionAppBar() : null,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentView) {
      case HomeViewState.passenger:
        return Stack(
          children: [
            // FIX IS HERE: 'const' keyword removed
            SearchRideScreen(), 
            Positioned(
              top: 40, left: 15,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black), 
                  onPressed: () => setState(() => _currentView = HomeViewState.selection)
                ),
              ),
            ),
          ],
        );

      case HomeViewState.driver:
        // Pass callback to return to selection
        return DriverDashboard(
          onBack: () => setState(() => _currentView = HomeViewState.selection),
        );

      case HomeViewState.selection:
      default:
        return _buildSelectionView();
    }
  }

  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFFF5F5F5),
      toolbarHeight: 70,
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Use the name fetched from Firestore or Default
          Text("Hello, $_firstName 👋", style: const TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
          const Text("What would you like to do today?", style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSelectionView() {
    // Determine Badge based on static variable (no stream)
    Widget? statusBadge;
    if (!_isLoadingStatus) {
      if (_driverStatus == 'pending') {
        statusBadge = _buildBadge(Icons.hourglass_top, "Pending", Colors.orange);
      } else if (_driverStatus == 'rejected') {
        statusBadge = _buildBadge(Icons.error_outline, "Action Needed", Colors.red);
      } else if (_driverStatus == 'approved') {
        statusBadge = _buildBadge(Icons.check_circle, "Verified", const Color(0xFF11A860));
      } else {
        // Not applied
        statusBadge = _buildBadge(Icons.star, "Start Earning", Colors.amber);
      }
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Expanded(
            child: _buildBigOptionCard(
              title: "Find a Ride",
              subtitle: "Book a seat and travel cheaply.",
              icon: Icons.search,
              color: const Color(0xFF11A860),
              badge: _buildBadge(Icons.bolt, "Fastest", Colors.orange),
              onTap: () => setState(() => _currentView = HomeViewState.passenger),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoadingStatus 
              ? const Center(child: CircularProgressIndicator()) 
              : _buildBigOptionCard(
                  title: "Offer a Ride",
                  subtitle: "Drive, share costs, and earn.",
                  icon: Icons.directions_car,
                  color: const Color(0xFF2B5145),
                  badge: statusBadge,
                  // Use the new handler instead of direct setState
                  onTap: _handleDriverClick, 
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 5), Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11))]),
    );
  }

  Widget _buildBigOptionCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap, Widget? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Stack(
          children: [
            Positioned(right: -20, bottom: -20, child: Icon(icon, size: 150, color: Colors.white.withOpacity(0.1))),
            if (badge != null) Positioned(top: 20, right: 20, child: badge),
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 30)),
                  const Spacer(),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [Text("Continue", style: TextStyle(color: color, fontWeight: FontWeight.bold)), const SizedBox(width: 5), Icon(Icons.arrow_forward, size: 16, color: color)]),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}