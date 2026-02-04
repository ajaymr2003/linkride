import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_detail_view.dart'; // Ensure this import exists

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final Color primaryGreen = const Color(0xFF11A860);
  
  // Filter State
  String _selectedFilter = 'All'; // Options: 'All', 'Drivers', 'Passengers'

  // Helper to build the query based on filter
  Query _buildQuery() {
    Query query = FirebaseFirestore.instance.collection('users');
    
    if (_selectedFilter == 'Drivers') {
      return query.where('driver_status', isEqualTo: 'approved');
    } else if (_selectedFilter == 'Passengers') {
      // Using notEqualTo to find users who aren't approved drivers
      return query.where('driver_status', isNotEqualTo: 'approved'); 
    }
    return query;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$_selectedFilter Users"),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          // --- FILTER BUTTON ---
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _selectedFilter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: "All", child: Text("All Users")),
              const PopupMenuItem(value: "Drivers", child: Text("Drivers Only")),
              const PopupMenuItem(value: "Passengers", child: Text("Passengers Only")),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _buildQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No users found matching filter."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              var user = snapshot.data!.docs[index];
              var data = user.data() as Map<String, dynamic>;
              String uid = user.id;
              bool isDriver = data['driver_status'] == 'approved';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  // --- NAVIGATION TO DETAIL VIEW ---
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserDetailView(uid: uid),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: isDriver ? Colors.green.shade100 : Colors.blue.shade100,
                          backgroundImage: data['profile_pic'] != null ? NetworkImage(data['profile_pic']) : null,
                          child: data['profile_pic'] == null 
                            ? Icon(isDriver ? Icons.drive_eta : Icons.person, color: isDriver ? Colors.green : Colors.blue) 
                            : null,
                        ),
                        const SizedBox(width: 15),
                        
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? 'No Name',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                data['email'] ?? 'No Email',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                              if (isDriver)
                                Container(
                                  margin: const EdgeInsets.only(top: 5),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                                  child: const Text("DRIVER", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                )
                            ],
                          ),
                        ),

                        // Navigation Arrow (Delete button removed)
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}