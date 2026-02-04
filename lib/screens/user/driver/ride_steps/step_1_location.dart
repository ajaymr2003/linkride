import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class RideStepLocation extends StatefulWidget {
  final String title;
  final String hint;
  final IconData icon;
  // CHANGED: Returns a Map with name and coordinates
  final Function(Map<String, dynamic>) onLocationSelected;

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

  // Store the selected data temporarily
  Map<String, dynamic>? _selectedData;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() => _hasInput = _controller.text.trim().isNotEmpty);
    });
  }

  // --- 1. SEARCH API ---
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() { _locationResults = []; _isLoading = false; });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=in');
      final response = await http.get(url, headers: {'User-Agent': 'com.example.linkride'});

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _locationResults = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 2. GPS LOCATION ---
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingGPS = true);
    FocusScope.of(context).unfocus();

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw "Location permission denied";

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10');
      final response = await http.get(url, headers: {'User-Agent': 'com.example.linkride'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String displayName = data['display_name'].split(',').take(2).join(',').trim();

        if (mounted) {
          setState(() {
            _controller.text = displayName;
            _selectedData = {
              'name': displayName,
              'lat': position.latitude,
              'lng': position.longitude,
            };
            _locationResults = [];
            _hasInput = true;
          });
        }
      }
    } catch (e) {
      // Error handling
    } finally {
      if(mounted) setState(() => _isGettingGPS = false);
    }
  }

  // --- 3. SELECT SUGGESTION ---
  void _onSuggestionSelected(dynamic place) {
    String name = place['display_name'].split(',')[0].trim();
    double lat = double.parse(place['lat']);
    double lng = double.parse(place['lon']);

    setState(() {
      _controller.text = name;
      _selectedData = {
        'name': name,
        'lat': lat,
        'lng': lng,
      };
      _locationResults = [];
      FocusScope.of(context).unfocus();
    });
  }

  // --- 4. ON NEXT ---
  void _onNextPressed() {
    if (_selectedData != null) {
      widget.onLocationSelected(_selectedData!);
    } else {
      // Fallback if they typed but didn't select (Not recommended for GPS apps, but safeguards crash)
      // Ideally force selection, but here is a basic fallback:
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a location from the list or use GPS")));
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

              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _searchLocation,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: Icon(widget.icon, color: Colors.grey),
                  filled: true, fillColor: Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: _hasInput ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _controller.clear(); setState(() => _hasInput = false); }) : null
                ),
              ),
              const SizedBox(height: 15),

              InkWell(
                onTap: _isGettingGPS ? null : _getCurrentLocation,
                child: Row(
                  children: [
                    _isGettingGPS 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, color: Color(0xFF11A860)),
                    const SizedBox(width: 15),
                    const Text("Use current location", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF11A860))),
                  ],
                ),
              ),
              const Divider(height: 30),

              Expanded(
                child: ListView.separated(
                  itemCount: _locationResults.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const Icon(Icons.location_on, color: Color(0xFF11A860)),
                      title: Text(_locationResults[index]['display_name'].split(',')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_locationResults[index]['display_name'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _onSuggestionSelected(_locationResults[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (_hasInput && _selectedData != null)
          Positioned(
            bottom: 30, right: 30,
            child: FloatingActionButton(
              onPressed: _onNextPressed,
              backgroundColor: const Color(0xFF11A860),
              child: const Icon(Icons.arrow_forward, color: Colors.white),
            ),
          ),
      ],
    );
  }
}