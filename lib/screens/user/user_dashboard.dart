import 'package:flutter/material.dart';
import 'account_page.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _currentIndex = 0;

  final Color primaryGreen = const Color(0xFF11A860);
  final Color lightGreen = const Color.fromARGB(255, 14, 53, 38);
  final Color darkGreen = const Color(0xFF2B5145);
  final Color mutedGreen = const Color(0xFF64AA8E);
  final Color bgGrey = const Color(0xFFECECEC);
  final Color textBlack = const Color(0xFF101212);
  final Color textGrey = const Color(0xFF727272);

  late TextEditingController _sourceController;
  late TextEditingController _destinationController;

  @override
  void initState() {
    super.initState();
    _sourceController = TextEditingController();
    _destinationController = TextEditingController();
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: Text(
          "Search",
          style: TextStyle(color: darkGreen, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: lightGreen.withOpacity(0.3),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(Icons.settings, color: darkGreen),
          ),
        ],
      ),

      body: _getBody(),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textGrey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Search"),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: "Publish",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            label: "Your Rides",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox_outlined),
            label: "Inbox",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Account",
          ),
        ],
      ),
    );
  }

  // MAIN BODY SWITCH
  Widget _getBody() {
    switch (_currentIndex) {
      case 0:
        return _searchPage();
      case 1:
        return _placeholder("Publish Ride");
      case 2:
        return _placeholder("Your Rides");
      case 3:
        return _placeholder("Inbox");
      case 4:
        return const AccountPage();
      default:
        return _searchPage();
    }
  }

  // SEARCH PAGE (MATCHING IMAGE)
  Widget _searchPage() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _inputBox("Leaving From", _sourceController),
                const SizedBox(height: 15),

                _inputBox("Going To", _destinationController),
                const SizedBox(height: 15),

                _dateBox(),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {},
                    child: const Text(
                      "Search",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // INPUT BOX
  Widget _inputBox(String hint, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: textGrey),
        filled: true,
        fillColor: bgGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  // DATE SELECTION
  Widget _dateBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bgGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Date Selection",
            style: TextStyle(color: textGrey, fontSize: 14),
          ),
          const Icon(Icons.keyboard_arrow_down),
        ],
      ),
    );
  }

  // PLACEHOLDER PAGES
  Widget _placeholder(String title) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
