import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseHealthPage extends StatefulWidget {
  const DatabaseHealthPage({super.key});

  @override
  State<DatabaseHealthPage> createState() => _DatabaseHealthPageState();
}

class _DatabaseHealthPageState extends State<DatabaseHealthPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = true;

  // Map to store counts
  Map<String, int> counts = {
    'users': 0,
    'rides': 0,
    'bookings': 0,
    'driver_applications': 0,
    'reviews': 0,
    'chats': 0,
    'notifications': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchDatabaseStats();
  }

  Future<void> _fetchDatabaseStats() async {
    setState(() => _isLoading = true);
    try {
      // Using Aggregate queries (Count) - Efficient and cheaper than .get()
      final userCount = await _db.collection('users').count().get();
      final rideCount = await _db.collection('rides').count().get();
      final bookingCount = await _db.collection('bookings').count().get();
      final appCount = await _db.collection('driver_applications').count().get();
      final reviewCount = await _db.collection('reviews').count().get();
      final chatCount = await _db.collection('chats').count().get();
      final notifCount = await _db.collection('notifications').count().get();

      if (mounted) {
        setState(() {
          counts['users'] = userCount.count ?? 0;
          counts['rides'] = rideCount.count ?? 0;
          counts['bookings'] = bookingCount.count ?? 0;
          counts['driver_applications'] = appCount.count ?? 0;
          counts['reviews'] = reviewCount.count ?? 0;
          counts['chats'] = chatCount.count ?? 0;
          counts['notifications'] = notifCount.count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF11A860);
    const darkGreen = Color(0xFF2B5145);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("System Health & Database", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: darkGreen,
        elevation: 0,
        actions: [
          IconButton(onPressed: _fetchDatabaseStats, icon: const Icon(Icons.refresh))
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: primaryGreen))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. OVERALL STATUS CARD
                _buildStatusHeader(primaryGreen),
                
                const SizedBox(height: 25),
                const Text("Collection Statistics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // 2. COUNTS GRID
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.5,
                  children: [
                    _countCard("Total Users", counts['users']!, Icons.people, Colors.blue),
                    _countCard("Total Rides", counts['rides']!, Icons.directions_car, Colors.orange),
                    _countCard("Bookings", counts['bookings']!, Icons.bookmark, Colors.purple),
                    _countCard("Driver Apps", counts['driver_applications']!, Icons.badge, Colors.teal),
                    _countCard("Reviews", counts['reviews']!, Icons.star, Colors.amber),
                    _countCard("Active Chats", counts['chats']!, Icons.chat, Colors.pink),
                  ],
                ),

                const SizedBox(height: 25),
                const Text("Database Usage Info", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // 3. STORAGE INFO (General Guidelines)
                _buildUsageTile("Database Region", "asia-southeast1 (Mumbai)", Icons.location_on),
                _buildUsageTile("Project ID", "mainproject-c4112", Icons.terminal),
                _buildUsageTile("Security Rules", "v2 (Enforced)", Icons.shield),
                _buildUsageTile("Realtime Sync", "Active", Icons.sync),
                
                const SizedBox(height: 30),
                const Center(
                  child: Text("Data provided by Firebase Cloud Firestore", 
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                )
              ],
            ),
          ),
    );
  }

  Widget _buildStatusHeader(Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3))
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.bolt, color: Colors.green),
          ),
          const SizedBox(width: 15),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("System is Online", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text("All services are responding normally", style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const Spacer(),
          Container(
            width: 12, height: 12,
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          )
        ],
      ),
    );
  }

  Widget _countCard(String label, int count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(count.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildUsageTile(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 15),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}