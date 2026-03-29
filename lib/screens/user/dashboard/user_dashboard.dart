import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

// Screens
import 'home/home_mode_selection.dart';
import 'activity/rides_page.dart';
import 'inbox/inbox_page.dart';
import 'account/profile/account/account_page.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final Color primaryGreen = const Color(0xFF11A860);

  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runLocationConditionCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _runLocationConditionCheck();
    }
  }

  // --- CONDITION: CHECK IF RIDE IS WITHIN 12 HOURS ---
  Future<void> _runLocationConditionCheck() async {
    final now = DateTime.now();
    final twelveHoursFromNow = now.add(const Duration(hours: 12));

    try {
      QuerySnapshot upcomingRides = await FirebaseFirestore.instance
          .collection('rides')
          .where('departure_time', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('departure_time', isLessThanOrEqualTo: Timestamp.fromDate(twelveHoursFromNow))
          .get();

      bool conditionMet = false;

      for (var doc in upcomingRides.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List passengers = data['passengers'] ?? [];
        if (data['driver_uid'] == _uid || passengers.contains(_uid)) {
          conditionMet = true;
          break;
        }
      }

      if (conditionMet) {
        _enableLocationServices();
      } else {
        _stopTracking();
      }
    } catch (e) {
      debugPrint("Condition Error: $e");
    }
  }

  Future<void> _enableLocationServices() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showGPSDialog();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      _startTracking();
    }
  }

  void _startTracking() {
    if (_isTracking) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
    ).listen((Position position) {
      FirebaseDatabase.instance.ref('user_locations/$_uid').set({
        'lat': position.latitude,
        'lng': position.longitude,
        'last_updated': ServerValue.timestamp,
        'is_active': true,
      });
    });

    setState(() => _isTracking = true);
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _isTracking = false;
    FirebaseDatabase.instance.ref('user_locations/$_uid').update({'is_active': false});
  }

  void _showGPSDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("GPS Required"),
        content: const Text("You have a ride scheduled soon. Please enable GPS to coordinate with your co-travelers."),
        actions: [
          TextButton(
            onPressed: () async {
              await Geolocator.openLocationSettings();
              if (mounted) Navigator.pop(ctx);
            }, 
            child: const Text("ENABLE GPS")
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _getBody(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
        onTap: (index) {
          setState(() => _currentIndex = index);
          _runLocationConditionCheck(); 
        },
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
      case 0: return const HomeModeSelection();
      case 1: return const RidesPage();
      case 2: return const InboxPage();
      case 3: return const AccountPage();
      default: return const HomeModeSelection();
    }
  }
}