import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'driver_approval_screen.dart';
import 'user_management_screen.dart';
// If you have a specific screen for active rides, import it. 
// Otherwise, we use a placeholder.

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Admin Dashboard", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            Text("Overview & Stats", style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: darkGreen,
        elevation: 0,
        actions: [
          // --- NOTIFICATION ICON ---
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 28),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No new system notifications")),
                  );
                },
              ),
              Positioned(
                top: 15,
                right: 12,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(width: 15),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Quick Stats", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // --- CLICKABLE BANNERS GRID ---
            Row(
              children: [
                // 1. Total Users Banner
                Expanded(
                  child: _buildLiveStatCard(
                    context,
                    title: "Total Users",
                    icon: Icons.group,
                    color: Colors.blue,
                    collection: 'users',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                  ),
                ),
                const SizedBox(width: 15),
                // 2. Pending Drivers Banner
                Expanded(
                  child: _buildLiveStatCard(
                    context,
                    title: "Driver Requests",
                    icon: Icons.pending_actions,
                    color: Colors.orange,
                    collection: 'users',
                    queryField: 'driver_status',
                    queryValue: 'pending',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverApprovalScreen())),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 25),
            
            // --- ACTIVE RIDES BUTTON (LARGE BANNER) ---
            const Text("Operations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            InkWell(
              onTap: () {
                 // Navigate to Active Rides Screen (Placeholder logic)
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text("Opening Active Rides Monitor...")),
                 );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryGreen, darkGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: primaryGreen.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.directions_car_filled, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 20),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Active Rides", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text("Monitor ongoing trips", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 20),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),

            // --- RECENT ACTIVITY LIST (Visual Filler) ---
            const Text("System Health", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildInfoTile(Icons.check_circle, Colors.green, "Server Status", "Online and stable"),
            _buildInfoTile(Icons.storage, Colors.purple, "Database", "Optimized"),
            _buildInfoTile(Icons.security, Colors.red, "Security", "No threats detected"),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDER: LIVE STAT CARD ---
  Widget _buildLiveStatCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String collection,
    String? queryField,
    String? queryValue,
    required VoidCallback onTap,
  }) {
    // Determine the query
    Query query = FirebaseFirestore.instance.collection(collection);
    if (queryField != null && queryValue != null) {
      query = query.where(queryField, isEqualTo: queryValue);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        String count = "...";
        if (snapshot.hasData) {
          count = snapshot.data!.docs.length.toString();
        }

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    if (snapshot.hasData)
                      const Icon(Icons.arrow_outward, color: Colors.grey, size: 18),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  count,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- WIDGET BUILDER: INFO TILE ---
  Widget _buildInfoTile(IconData icon, Color color, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.green)),
            ],
          )
        ],
      ),
    );
  }
}