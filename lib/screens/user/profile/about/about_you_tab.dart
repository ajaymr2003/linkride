import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_personal_details_page.dart';
import 'mini_bio_page.dart';
import 'travel_preferences_page.dart';
import 'vehicle/add_vehicle_page.dart';

class AboutYouTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  const AboutYouTab({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    const primaryGreen = Color(0xFF11A860);
    const darkGreen = Color(0xFF2B5145);

    // --- Data Extraction ---
    bool isEmailVerified = user?.emailVerified ?? false;
    bool isIdVerified = userData['driver_status'] == 'approved';
    String phone = userData['phone'] ?? "";
    bool isPhoneAdded = phone.isNotEmpty;

    String emailText = user?.email ?? "No Email Linked";
    String phoneText = isPhoneAdded ? phone : "No Phone Linked";
    String idText = isIdVerified ? "Government ID Verified" : "Government ID Not Verified";

    String? miniBio = userData['mini_bio'];
    Map<String, dynamic>? prefs = userData['travel_preferences'];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // --- HEADER ---
        Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[200],
              backgroundImage: userData['profile_pic'] != null ? NetworkImage(userData['profile_pic']) : null,
              child: userData['profile_pic'] == null ? const Icon(Icons.person, size: 40, color: Colors.grey) : null,
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userData['name'] ?? 'User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: darkGreen)),
                  Text(userData['experience'] ?? 'Newcomer', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 25),
        
        // --- EDIT PERSONAL DETAILS ---
        GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditPersonalDetailsPage(userData: userData))),
          child: const Text("Edit personal details", style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 30),

        // --- VERIFICATIONS ---
        const Text("Verifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkGreen)),
        const SizedBox(height: 10),
        _buildVerifyTile(idText, isIdVerified),
        _buildVerifyTile(emailText, isEmailVerified),
        _buildVerifyTile(phoneText, isPhoneAdded),
        const SizedBox(height: 30),

        // --- ABOUT YOU SECTION ---
        const Text("About you", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkGreen)),
        const SizedBox(height: 10),
        
        // 1. Mini Bio Button
        _buildActionTextButton(
          label: (miniBio != null && miniBio.isNotEmpty) ? "Edit mini bio" : "Add a mini bio",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MiniBioPage(currentBio: miniBio))),
        ),
        
        // 2. Travel Preferences Button
        _buildActionTextButton(
          label: "Edit travel preferences",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TravelPreferencesPage(currentPrefs: prefs))),
        ),
        
        const SizedBox(height: 30),

        // --- VEHICLES SECTION ---
        const Text("Vehicles", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkGreen)),
        const SizedBox(height: 10),
        
        // List existing vehicles
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('vehicles').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  var v = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.directions_car, color: primaryGreen),
                    title: Text("${v['brand']} ${v['model']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(v['plate'] ?? ""),
                  );
                }).toList(),
              );
            }
            return const SizedBox.shrink(); // Hide if no vehicles
          },
        ),

        // 3. Add Vehicle Button
        _buildActionTextButton(
          label: "Add vehicle",
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddVehiclePage())),
          icon: Icons.add_circle_outline,
        ),
        
        const SizedBox(height: 40),
      ],
    );
  }

  // Helper for status lines
  Widget _buildVerifyTile(String detailText, bool isVerified) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(detailText, style: TextStyle(color: isVerified ? const Color(0xFF2B5145) : Colors.grey, fontSize: 16)),
      trailing: isVerified ? const Icon(Icons.check_circle, color: Color(0xFF11A860)) : null, 
    );
  }

  // Helper for action buttons (blue text style usually, here customized)
  Widget _buildActionTextButton({required String label, required VoidCallback onTap, IconData? icon}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, color: const Color(0xFF11A860), size: 20), const SizedBox(width: 10)],
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF11A860), 
                fontWeight: FontWeight.bold, 
                fontSize: 16
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}