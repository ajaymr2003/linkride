import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class PassengerStepSource extends StatefulWidget {
  const PassengerStepSource({super.key});

  @override
  State<PassengerStepSource> createState() => _PassengerStepSourceState();
}

class _PassengerStepSourceState extends State<PassengerStepSource> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _locationResults = [];
  bool _isLoading = false;
  bool _isGettingGPS = false;

  final Color primaryGreen = const Color(0xFF11A860);

  // Search API
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _locationResults = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5&countrycodes=in');
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

  // GPS Logic
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingGPS = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) throw "Permission denied";

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=10');
      final response = await http.get(url, headers: {'User-Agent': 'com.example.linkride'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String name = data['display_name'].split(',')[0]; // Simple name
        if (mounted) {
           Navigator.pop(context, name); // Return result immediately
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not get location")));
    } finally {
      if(mounted) setState(() => _isGettingGPS = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Leaving from", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Input Field
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _searchLocation,
              decoration: InputDecoration(
                hintText: "Enter city or street",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),

            // Use Current Location
            InkWell(
              onTap: _isGettingGPS ? null : _getCurrentLocation,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    _isGettingGPS 
                       ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: primaryGreen))
                       : Icon(Icons.my_location, color: primaryGreen),
                    const SizedBox(width: 15),
                    Text("Use current location", style: TextStyle(fontWeight: FontWeight.bold, color: primaryGreen)),
                  ],
                ),
              ),
            ),
            const Divider(),

            // Results List
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _locationResults.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final place = _locationResults[index];
                      final name = place['display_name'].split(',')[0];
                      final full = place['display_name'];
                      return ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: Colors.grey),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(full, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.pop(context, name), // Return result
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}