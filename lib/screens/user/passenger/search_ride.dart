import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../services/search_history_service.dart';
import '../../../widgets/active_ride_banner.dart'; // To show current requests
import 'step_1_source.dart';
import 'step_2_destination.dart';
import 'step_3_details.dart';
import 'ride_results_screen.dart';

class SearchRideScreen extends StatefulWidget {
  const SearchRideScreen({super.key});

  @override
  State<SearchRideScreen> createState() => _SearchRideScreenState();
}

class _SearchRideScreenState extends State<SearchRideScreen> {
  // --- SEARCH STATE ---
  Map<String, dynamic>? _source;
  Map<String, dynamic>? _destination;
  DateTime _selectedDate = DateTime.now();
  int _passengers = 1;

  // --- HISTORY STATE ---
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = true;

  final Color primaryGreen = const Color(0xFF11A860);
  final Color darkGreen = const Color(0xFF2B5145);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // --- LOAD SEARCH HISTORY ---
  Future<void> _loadHistory() async {
    final history = await SearchHistoryService.getHistory();
    if (mounted) {
      setState(() {
        _history = history;
        _isLoadingHistory = false;
      });
    }
  }

  // --- APPLY HISTORY ITEM TO SEARCH ---
  void _applyHistory(Map<String, dynamic> item) {
    setState(() {
      _source = item['source'];
      _destination = item['destination'];
      _passengers = item['passengers'] ?? 1;
    });
    // Optional: Auto-trigger search or just fill fields
  }

  // --- TRIGGER SEARCH ---
  void _onSearch() async {
    if (_source == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select both start and end locations")),
      );
      return;
    }

    // 1. Save to Search History
    await SearchHistoryService.addSearch(
      source: _source!,
      dest: _destination!,
      date: _selectedDate,
      passengers: _passengers,
    );

    if (!mounted) return;

    // 2. Refresh local history list
    _loadHistory();

    // 3. Navigate to Results
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RideResultsScreen(
          source: _source!,
          destination: _destination!,
          date: _selectedDate,
          passengers: _passengers,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(25, 80, 25, 25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. ACTIVE RIDE BANNER ---
            // Shows up automatically if user has a pending or accepted booking
            const ActiveRideBanner(),

            Text(
              "Where to?",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: darkGreen),
            ),
            const SizedBox(height: 30),

            // --- 2. MAIN SEARCH CARD ---
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                children: [
                  _buildLocationTile(
                    label: _source == null ? "Leaving from" : _source!['name'],
                    icon: Icons.circle_outlined,
                    onTap: () async {
                      final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerStepSource()));
                      if (res != null) setState(() => _source = res);
                    },
                    isActive: _source != null,
                  ),
                  const Divider(height: 1, indent: 60),
                  _buildLocationTile(
                    label: _destination == null ? "Going to" : _destination!['name'],
                    icon: Icons.location_on,
                    onTap: () async {
                      final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerStepDestination()));
                      if (res != null) setState(() => _destination = res);
                    },
                    isActive: _destination != null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 3. DATE & PASSENGERS ---
            Row(
              children: [
                Expanded(
                  child: _buildInfoBox(
                    DateFormat('EEE, d MMM').format(_selectedDate),
                    Icons.calendar_today,
                    () async {
                      final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerStepDetails(initialDate: _selectedDate, initialPassengers: _passengers)));
                      if (res != null) {
                        setState(() {
                          _selectedDate = res['date'];
                          _passengers = res['passengers'];
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildInfoBox(
                    "$_passengers Passenger",
                    Icons.person_outline,
                    () async {
                      final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => PassengerStepDetails(initialDate: _selectedDate, initialPassengers: _passengers)));
                      if (res != null) {
                        setState(() {
                          _selectedDate = res['date'];
                          _passengers = res['passengers'];
                        });
                      }
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // --- 4. SEARCH BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _onSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: const Text(
                  "SEARCH RIDE",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // --- 5. RECENT SEARCHES SECTION ---
            if (_history.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Searches",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () async {
                      await SearchHistoryService.clearHistory();
                      _loadHistory();
                    },
                    child: const Text("Clear"),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final item = _history[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history, color: Colors.grey),
                    title: Text(
                      "${item['source']['name']} → ${item['destination']['name']}",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text("${item['passengers']} Passenger"),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _applyHistory(item),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildLocationTile({required String label, required IconData icon, required VoidCallback onTap, required bool isActive}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: primaryGreen),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isActive ? Colors.black : Colors.grey,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildInfoBox(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: darkGreen),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}