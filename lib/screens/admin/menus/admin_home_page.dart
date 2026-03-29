import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../driver_request/driver_approval_screen.dart';
import 'user_management_screen.dart';
import '../ride_details/main_active.dart';
import 'admin_reports_page.dart'; 
import 'admin_inbox_page.dart'; // <--- ADD THIS IMPORT

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
          // --- UPDATED NOTIFICATION ICON LOGIC ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('admin_inbox')
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              bool hasUnread = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, size: 28),
                    onPressed: () {
                      // Navigate to Admin Inbox
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdminInboxPage()),
                      );
                    },
                  ),
                  if (hasUnread)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
                      ),
                    )
                ],
              );
            },
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
            Row(
              children: [
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
            const Text("Operations", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            Row(
              children: [
                Expanded(
                  child: _buildOpCard(
                    context,
                    title: "Ride Monitor",
                    subtitle: "Live tracking",
                    icon: Icons.map_outlined,
                    color: primaryGreen,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MainActivePage())),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildOpCard(
                    context,
                    title: "System Reports",
                    subtitle: "Analytics",
                    icon: Icons.bar_chart_rounded,
                    color: darkGreen,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportsPage())),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 25),
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

  // --- HELPER WIDGETS ---

  Widget _buildOpCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveStatCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String collection,
    String? queryField,
    String? queryValue,
    required VoidCallback onTap,
  }) {
    Query query = FirebaseFirestore.instance.collection(collection);
    if (queryField != null && queryValue != null) {
      query = query.where(queryField, isEqualTo: queryValue);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        String count = snapshot.hasData ? snapshot.data!.docs.length.toString() : "...";

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const Icon(Icons.arrow_outward, color: Colors.grey, size: 18),
                  ],
                ),
                const SizedBox(height: 15),
                Text(count, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                const SizedBox(height: 5),
                Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(IconData icon, Color color, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
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