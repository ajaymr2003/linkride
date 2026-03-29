import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../driver_request/user_detail_view.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final Color primaryGreen = const Color(0xFF11A860);
  String _selectedFilter = 'All'; 

  Query _buildQuery() {
    Query query = FirebaseFirestore.instance.collection('users');
    if (_selectedFilter == 'Drivers') {
      return query.where('driver_status', isEqualTo: 'approved');
    } else if (_selectedFilter == 'Passengers') {
      return query.where('driver_status', isNotEqualTo: 'approved'); 
    }
    return query;
  }

  // --- DELETE LOGIC ---
  Future<void> _deleteUser(BuildContext context, String uid, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete User?"),
        content: Text("Are you sure you want to delete $name? This action cannot be undone and will remove their profile data."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$name deleted successfully"), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error deleting user")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$_selectedFilter Users"),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _selectedFilter = value),
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
            return const Center(child: Text("No users found."));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              var user = snapshot.data!.docs[index];
              var data = user.data() as Map<String, dynamic>;
              String uid = user.id;
              String name = data['name'] ?? 'No Name';
              bool isDriver = data['driver_status'] == 'approved';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailView(uid: uid)));
                  },
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: isDriver ? Colors.green.shade100 : Colors.blue.shade100,
                    backgroundImage: data['profile_pic'] != null ? NetworkImage(data['profile_pic']) : null,
                    child: data['profile_pic'] == null 
                        ? Icon(isDriver ? Icons.drive_eta : Icons.person, color: isDriver ? Colors.green : Colors.blue) 
                        : null,
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['email'] ?? 'No Email', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDriver ? Colors.green.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4)
                        ),
                        child: Text(
                          isDriver ? "DRIVER" : "PASSENGER", 
                          style: TextStyle(fontSize: 9, color: isDriver ? Colors.green : Colors.blue, fontWeight: FontWeight.bold)
                        ),
                      )
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteUser(context, uid, name),
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