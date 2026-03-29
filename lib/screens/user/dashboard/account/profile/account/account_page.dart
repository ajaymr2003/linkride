import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../about/about_you_tab.dart';
import 'account_tab.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);
  final User? user = FirebaseAuth.instance.currentUser;

  // Key to force refresh the StreamBuilder
  Key _refreshKey = UniqueKey();

  Future<void> _handleRefresh() async {
    // Reload Firebase User to update emailVerified status
    await FirebaseAuth.instance.currentUser?.reload();
    setState(() {
      _refreshKey = UniqueKey(); // Rebuilds the StreamBuilder
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 5,
          bottom: TabBar(
            indicatorColor: primaryGreen,
            labelColor: primaryGreen,
            unselectedLabelColor: const Color(0xFF727272),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [Tab(text: "About You"), Tab(text: "Account")],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _handleRefresh,
          color: primaryGreen,
          child: StreamBuilder<DocumentSnapshot>(
            key: _refreshKey,
            stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text("User data not found"));
              }

              var data = snapshot.data!.data() as Map<String, dynamic>;
              
              return TabBarView(
                children: [
                  AboutYouTab(userData: data),
                  AccountTab(userData: data),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}