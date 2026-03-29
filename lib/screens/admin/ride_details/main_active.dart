import 'package:flutter/material.dart';
import 'active_scheduled.dart'; // Import your Active/Scheduled file
import 'history.dart';          // Import your History file

class MainActivePage extends StatefulWidget {
  const MainActivePage({super.key});

  @override
  State<MainActivePage> createState() => _MainActivePageState();
}

class _MainActivePageState extends State<MainActivePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // LinkRide Theme Colors
  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  @override
  void initState() {
    super.initState();
    // length: 2 corresponds to the two tabs we are creating
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light grey background
      appBar: AppBar(
        title: const Text(
          "Ride Monitor", 
          style: TextStyle(fontWeight: FontWeight.bold)
        ),
        backgroundColor: Colors.white,
        foregroundColor: darkGreen,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: primaryGreen,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.directions_car),
              text: "Active / Scheduled",
            ),
            Tab(
              icon: Icon(Icons.history),
              text: "Ride History",
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          // This displays the active_scheduled.dart content
          ActiveScheduledPage(),
          
          // This displays the history.dart content
          AdminHistoryPage(),
        ],
      ),
    );
  }
}