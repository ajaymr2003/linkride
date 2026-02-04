import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'step_1_source.dart';
import 'step_2_destination.dart';
import 'step_3_details.dart';
import 'ride_results_screen.dart';
// IMPORT THE BANNER
import '../../../widgets/active_ride_banner.dart'; 

class SearchRideScreen extends StatefulWidget {
  const SearchRideScreen({super.key});

  @override
  State<SearchRideScreen> createState() => _SearchRideScreenState();
}

class _SearchRideScreenState extends State<SearchRideScreen> {
  // Store Map objects: {name, lat, lng}
  Map<String, dynamic>? _source;
  Map<String, dynamic>? _destination;

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
    if (result != null && result is Map<String, dynamic>) {
      setState(() => _source = result);
    }
  }

  Future<void> _pickDestination() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PassengerStepDestination()),
    );
    if (result != null && result is Map<String, dynamic>) {
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
    if (_source == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select leaving from and going to locations")),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideResultsScreen(
          source: _source!,
          destination: _destination!,
          date: _date,
          passengers: _passengers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String dateLabel = _isToday(_date) 
        ? "Today" 
        : DateFormat('EEE, d MMM').format(_date);
    
    String sourceName = _source != null ? _source!['name'] : "Leaving from...";
    String destName = _destination != null ? _destination!['name'] : "Going to...";

    return Stack(
      children: [
        // Background Image Layer
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

        // Scrollable Content Layer
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                
                // ----------------------------------------------------
                // 1. SEARCH CARD (Now at the top)
                // ----------------------------------------------------
                Container(
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

                      // Leaving From
                      _buildClickableField(
                        label: sourceName,
                        icon: Icons.circle_outlined,
                        onTap: _pickSource,
                        isActive: _source != null,
                      ),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Divider(height: 30, thickness: 1, color: Color(0xFFEEEEEE)),
                      ),

                      // Going To
                      _buildClickableField(
                        label: destName,
                        icon: Icons.location_on_outlined,
                        onTap: _pickDestination,
                        isActive: _destination != null,
                      ),

                      const SizedBox(height: 25),

                      // Details Row
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

                      // Search Button
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

                const SizedBox(height: 25), // Spacing between card and banner

                // ----------------------------------------------------
                // 2. ACTIVE RIDE BANNER (Now Below)
                // ----------------------------------------------------
                const ActiveRideBanner(),
              ],
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