import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class RideStepLocation extends StatefulWidget {
  final String title;
  final String hint;
  final IconData icon;
  final Function(String) onLocationSelected;

  const RideStepLocation({
    super.key,
    required this.title,
    required this.hint,
    required this.icon,
    required this.onLocationSelected,
  });

  @override
  State<RideStepLocation> createState() => _RideStepLocationState();
}

class _RideStepLocationState extends State<RideStepLocation> {
  final TextEditingController _controller = TextEditingController();
  
  List<dynamic> _locationResults = [];
  bool _isLoading = false;      
  bool _isGettingGPS = false;   
  bool _hasInput = false;       

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _hasInput = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // --- 1. SEARCH API (Instant) ---
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _locationResults = [];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=in');

      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.example.linkride'}, 
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _locationResults = json.decode(response.body);
            _isLoading = false;
          });
        }
      } else {
        // Handle API limit errors silently
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Search Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. GPS LOCATION ---
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingGPS = true);
    FocusScope.of(context).unfocus(); 

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw "Location services are disabled.";

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw "Location permissions are denied";
      }
      if (permission == LocationPermission.deniedForever) throw "Location permissions are permanently denied.";

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10');

      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.example.linkride'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String displayName = data['display_name'];
        
        List<String> parts = displayName.split(',');
        String simplifiedName = parts.take(2).join(',').trim();

        if (mounted) {
          setState(() {
            _controller.text = simplifiedName;
            _locationResults = []; 
            _hasInput = true;
          });
        }
      } else {
        throw "Failed to fetch address";
      }

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if(mounted) setState(() => _isGettingGPS = false);
    }
  }

  // --- 3. ON TYPING (No Delay) ---
  void _onSearchChanged(String query) {
    // Directly call search without Timer/Debounce
    _searchLocation(query);
  }

  // --- 4. ON SUGGESTION TAP ---
  void _onSuggestionSelected(String locationName) {
    setState(() {
      _controller.text = locationName;
      _locationResults = []; 
      _hasInput = true;
      FocusScope.of(context).unfocus(); 
    });
  }

  // --- 5. ON NEXT BUTTON TAP ---
  void _onNextPressed() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onLocationSelected(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2B5145))),
              const SizedBox(height: 20),

              // Search Field
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: Icon(widget.icon, color: Colors.grey),
                  suffixIcon: _isLoading 
                    ? const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2))
                    : (_hasInput 
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                            _controller.clear(); 
                            setState(() { _locationResults = []; _hasInput = false; });
                          })
                        : null),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 15),

              // Use Current Location
              InkWell(
                onTap: _isGettingGPS ? null : _getCurrentLocation,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                  child: Row(
                    children: [
                      _isGettingGPS 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF11A860)))
                        : const Icon(Icons.my_location, color: Color(0xFF11A860)),
                      const SizedBox(width: 15),
                      Text(
                        _isGettingGPS ? "Fetching location..." : "Use current location",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF11A860), fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              
              const Divider(height: 30),

              // Results List
              Expanded(
                child: _locationResults.isNotEmpty
                    ? ListView.separated(
                        itemCount: _locationResults.length,
                        separatorBuilder: (c, i) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final place = _locationResults[index];
                          final String displayName = place['display_name'];
                          
                          final List<String> parts = displayName.split(',');
                          final String title = parts[0].trim();
                          final String subtitle = parts.sublist(1).join(',').trim();

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.location_on, color: Color(0xFF11A860))),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => _onSuggestionSelected(title),
                          );
                        },
                      )
                    : Container(), 
              ),
            ],
          ),
        ),

        // Floating Next Button
        if (_hasInput)
          Positioned(
            bottom: 30,
            right: 30,
            child: FloatingActionButton(
              onPressed: _onNextPressed,
              backgroundColor: const Color(0xFF11A860),
              elevation: 5,
              shape: const CircleBorder(),
              child: const Icon(Icons.arrow_forward, color: Colors.white, size: 28),
            ),
          ),
      ],
    );
  }
}