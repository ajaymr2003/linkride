import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'step_1_source.dart';
import 'step_2_destination.dart';
import 'step_3_details.dart';

class SearchRideScreen extends StatefulWidget {
  const SearchRideScreen({super.key});

  @override
  State<SearchRideScreen> createState() => _SearchRideScreenState();
}

class _SearchRideScreenState extends State<SearchRideScreen> {
  // --- STATE ---
  String _source = "";
  String _destination = "";
  DateTime _date = DateTime.now();
  int _passengers = 1;

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);
  final Color textGrey = const Color(0xFF727272);

  // --- NAVIGATION METHODS ---

  Future<void> _pickSource() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PassengerStepSource()),
    );
    if (result != null) {
      setState(() => _source = result);
    }
  }

  Future<void> _pickDestination() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PassengerStepDestination()),
    );
    if (result != null) {
      setState(() => _destination = result);
    }
  }

  Future<void> _pickDetails() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PassengerStepDetails(
          initialDate: _date,
          initialPassengers: _passengers,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _date = result['date'];
        _passengers = result['passengers'];
      });
    }
  }

  void _performSearch() {
    if (_source.isEmpty || _destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select leaving from and going to locations")),
      );
      return;
    }
    
    // Logic to navigate to a Results List Page would go here
    // For now, we just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Searching rides from $_source to $_destination...")),
    );
  }

  @override
  Widget build(BuildContext context) {
    String dateLabel = _isToday(_date) 
        ? "Today" 
        : DateFormat('EEE, d MMM').format(_date);

    return Stack(
      children: [
        // Background Image
        Column(
          children: [
            Expanded(
              flex: 1,
              child: SizedBox(
                width: double.infinity,
                child: Image.asset('assets/dash.png', fit: BoxFit.cover),
              ),
            ),
            Expanded(flex: 1, child: Container(color: const Color(0xFFF5F5F5))),
          ],
        ),

        // Floating Card
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Where to?", 
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 20),

                  // 1. Leaving From
                  _buildClickableField(
                    label: _source.isEmpty ? "Leaving from..." : _source,
                    icon: Icons.circle_outlined,
                    onTap: _pickSource,
                    isActive: _source.isNotEmpty,
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Divider(height: 30, thickness: 1, color: Color(0xFFEEEEEE)),
                  ),

                  // 2. Going To
                  _buildClickableField(
                    label: _destination.isEmpty ? "Going to..." : _destination,
                    icon: Icons.location_on_outlined,
                    onTap: _pickDestination,
                    isActive: _destination.isNotEmpty,
                  ),

                  const SizedBox(height: 25),

                  // 3. Details Row
                  Row(
                    children: [
                      Expanded(
                        child: _infoSelector(
                          Icons.calendar_today_outlined, 
                          dateLabel, 
                          _pickDetails
                        )
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _infoSelector(
                          Icons.person_outline, 
                          "$_passengers passenger${_passengers > 1 ? 's' : ''}", 
                          _pickDetails
                        )
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 4. Search Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _performSearch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                      child: const Text("Search", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGET HELPER METHODS ---

  Widget _buildClickableField({required String label, required IconData icon, required VoidCallback onTap, required bool isActive}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: primaryGreen, size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isActive ? darkGreen : textGrey.withOpacity(0.7),
                overflow: TextOverflow.ellipsis
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSelector(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: darkGreen),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: darkGreen, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}