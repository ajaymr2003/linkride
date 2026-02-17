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

  // ===================== PRECISE NAME HELPER =====================
  String _getPreciseName(Map<String, dynamic> place) {
    final address = place['address'];

    // Best case for reverse geocode
    if (place['name'] != null &&
        place['name'].toString().trim().isNotEmpty) {
      return place['name'];
    }

    if (address == null) {
      return place['display_name']
          .split(',')
          .take(2)
          .join(', ');
    }

    String name = "";

    if (address['amenity'] != null) name = address['amenity'];
    else if (address['shop'] != null) name = address['shop'];
    else if (address['building'] != null) name = address['building'];
    else if (address['office'] != null) name = address['office'];
    else if (address['tourism'] != null) name = address['tourism'];
    else if (address['road'] != null) name = address['road'];

    String locality = "";
    if (address['suburb'] != null) locality = address['suburb'];
    else if (address['neighbourhood'] != null) locality = address['neighbourhood'];
    else if (address['city'] != null) locality = address['city'];
    else if (address['town'] != null) locality = address['town'];

    if (name.isNotEmpty && locality.isNotEmpty) {
      return "$name, $locality";
    }

    return place['display_name']
        .split(',')
        .take(3)
        .join(', ');
  }

  // ===================== SEARCH LOCATION =====================
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _locationResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=$query'
        '&format=json'
        '&addressdetails=1'
        '&limit=5'
        '&countrycodes=in',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.example.linkride'},
      );

      if (response.statusCode == 200 && mounted) {
        setState(() {
          _locationResults = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===================== CURRENT LOCATION =====================
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingGPS = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw "Permission denied";
      }

      Position position;
      Position? lastPosition =
          await Geolocator.getLastKnownPosition();

      if (lastPosition != null) {
        position = lastPosition;
      } else {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 6),
        );
      }

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=${position.latitude}'
        '&lon=${position.longitude}'
        '&zoom=19'
        '&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'com.example.linkride'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final preciseName = _getPreciseName(data);

        Navigator.pop(context, {
          'name': preciseName,
          'lat': position.latitude,
          'lng': position.longitude,
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not get exact location")),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingGPS = false);
    }
  }

  // ===================== SELECT PLACE =====================
  void _selectPlace(dynamic place) {
    final preciseName = _getPreciseName(place);

    Navigator.pop(context, {
      'name': preciseName,
      'lat': double.parse(place['lat']),
      'lng': double.parse(place['lon']),
    });
  }

  // ===================== UI =====================
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
        title: const Text(
          "Leaving from",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _searchLocation,
              decoration: InputDecoration(
                hintText: "Enter city, area or street",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 15),

            InkWell(
              onTap: _isGettingGPS ? null : _getCurrentLocation,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    _isGettingGPS
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: primaryGreen,
                            ),
                          )
                        : Icon(Icons.my_location, color: primaryGreen),
                    const SizedBox(width: 15),
                    Text(
                      "Use current location",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: _locationResults.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final place = _locationResults[index];
                        final title = _getPreciseName(place);

                        return ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Colors.grey,
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            place['display_name'],
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: () => _selectPlace(place),
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
