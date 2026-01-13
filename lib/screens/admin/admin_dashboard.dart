import 'package:flutter/material.dart';
import '../auth/login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // Color Palette
  final Color primaryGreen = const Color(0xFF11A860);
  final Color lightGreen = const Color(0xFFA2E1CA);
  final Color darkGreen = const Color(0xFF2B5145);
  final Color mutedGreen = const Color(0xFF64AA8E);
  final Color bgColor = const Color(0xFFECECEC);
  final Color textBlack = const Color(0xFF101212);
  final Color textGrey = const Color(0xFF727272);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: primaryGreen,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [lightGreen.withOpacity(0.6), bgColor],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome, Admin!",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: darkGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Manage your platform",
                      style: TextStyle(fontSize: 14, color: textGrey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // Statistics Section
              Text(
                "Statistics",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 15),

              // Stats Grid
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStatCard(
                    icon: Icons.people,
                    title: "Total Users",
                    value: "0",
                    color: primaryGreen,
                  ),
                  _buildStatCard(
                    icon: Icons.directions_car,
                    title: "Total Rides",
                    value: "0",
                    color: mutedGreen,
                  ),
                  _buildStatCard(
                    icon: Icons.monetization_on,
                    title: "Revenue",
                    value: "\$0",
                    color: primaryGreen,
                  ),
                  _buildStatCard(
                    icon: Icons.star,
                    title: "Ratings",
                    value: "0.0",
                    color: mutedGreen,
                  ),
                ],
              ),
              const SizedBox(height: 25),

              // Admin Actions
              Text(
                "Admin Actions",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: darkGreen,
                ),
              ),
              const SizedBox(height: 15),

              // Action List
              _buildActionTile(
                icon: Icons.group,
                title: "Manage Users",
                subtitle: "View and manage user accounts",
              ),
              _buildActionTile(
                icon: Icons.directions_car,
                title: "Manage Rides",
                subtitle: "View and manage all rides",
              ),
              _buildActionTile(
                icon: Icons.bar_chart,
                title: "View Reports",
                subtitle: "Analytics and performance metrics",
              ),
              _buildActionTile(
                icon: Icons.settings,
                title: "Settings",
                subtitle: "Configure platform settings",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkGreen,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: primaryGreen, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: textGrey),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: mutedGreen, size: 16),
          ],
        ),
      ),
    );
  }
}
